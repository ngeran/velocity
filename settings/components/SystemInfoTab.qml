// =============================================================================
// SystemInfoTab.qml — tab 0: the telemetry dashboard
// =============================================================================
// Replaces the bento OverviewTab as the dashboard landing tab (the bar's
// FastfetchOverlay interior, rehosted as an embedded settings view). Same
// card family as the overlay: Hardware (CPU/GPU/BOARD + RAM radial), Session,
// Storage, Network, Health, and the full-width Software & OS strip. No title
// header — the shared Header (clock, identity, power strip) carries the
// identity; the grid starts flush (user call).
//
// Data comes through HostBridge (import-split law — this tree never imports
// "../bar/…"): bar MetricsService + NetworkService. MetricsService is
// lease-gated AND profile-lazy (boot runs refreshStatic only), so the tab
// pulls `refresh()` on every open: the kick is gated on SharedState.
// dashboardVisible (the WINDOW edge), not on `visible` — the tab is created
// at first open with visible=true and the bridge already attached, so
// neither onVisibleChanged nor onMChanged ever fires on the paths that
// matter (the blank-dashboard incident). A renewal Timer holds a 45s lease
// while the tab is on screen; polls stop within one lease period of leaving.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "." as Components
import "../config" as Config
import "../services" as Services

Item {
    id: root

    // The wallpaper card's OPEN click deep-links to the Wallpaper tab —
    // SettingsWindowShell owns the tab switcher (openWallpapersTab()).
    signal wallpaperRequested()

    // ── bar services (null until the bar shell attaches; bindings re-run) ──
    readonly property var m: Services.HostBridge.metrics
    readonly property var net: Services.HostBridge.network

    // ── palette (every accent token; recolours with the live theme) ────────
    readonly property color cText:      Config.ThemeConfig.colors.text
    readonly property color cDim:       Config.ThemeConfig.colors.textDim
    readonly property color cBorder:    Config.ThemeConfig.colors.border
    readonly property color cOutline:   Config.ThemeConfig.colors.outlineVariant
    readonly property color cSurface:   Config.ThemeConfig.colors.surfaceVariant
    readonly property color cSecondary: Config.ThemeConfig.colors.secondary   // hardware / radial / storage
    readonly property color cPrimary:   Config.ThemeConfig.colors.primary     // session / software / lock
    readonly property color cSuccess:   Config.ThemeConfig.colors.success     // network / healthy
    readonly property color cWarn:      Config.ThemeConfig.colors.warning     // restart / temp tiers
    readonly property color cErr:       Config.ThemeConfig.colors.error       // shutdown
    readonly property color cAccent2:   Config.ThemeConfig.colors.accent      // GPU util highlight
    readonly property string fontM:     Config.ControlConfig.fontMono

    function diskColor(pct) { if (pct >= 90) return cErr; if (pct >= 75) return cWarn; return cSecondary }
    function tempColor(c)   { if (!c) return cDim; if (c >= 80) return cErr; if (c >= 60) return cWarn; return cSuccess }
    function fmtNum(n) { return (n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",") }

    // =========================================================================
    // METRICS KICK — pull the profile on every window-open, lease while shown
    // =========================================================================
    // `visible` alone never fires here (tab created visible with the bridge
    // attached) — the reliable edges are the WINDOW shown state and the
    // tab's own re-entry from another tab.
    readonly property bool shown: Config.SharedState.dashboardVisible
    Component.onCompleted: if (shown) root._kickMetrics()
    onShownChanged:    if (shown) root._kickMetrics()
    onVisibleChanged:  if (visible && shown) root._kickMetrics()
    onMChanged:        if (shown && visible) root._kickMetrics()
    function _kickMetrics() {
        if (!m) return
        m.extendLease(45)
        m.refresh()
        m.refreshUptime()
    }
    Timer {
        interval: 20000
        running: root.shown && root.visible && root.m !== null
        repeat: true
        onTriggered: if (root.m) root.m.extendLease(45)
    }

    // =========================================================================
    // BACKDROP GRID (the System-Info family decoration, dimmed)
    // =========================================================================
    Item {
        anchors.fill: parent
        opacity: 0.15
        Repeater {
            model: Math.floor(root.width / 40)
            Rectangle { width: 1; height: root.height; x: index * 40; color: root.cBorder }
        }
        Repeater {
            model: Math.floor(root.height / 40)
            Rectangle { height: 1; width: root.width; y: index * 40; color: root.cBorder }
        }
    }

    // =========================================================================
    // CONTENT
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.ControlConfig.space4
        spacing: Config.ControlConfig.space3


        // ---- card grid (scrollable on the 480px-floor viewport) ----
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: grid.height
            flickableDirection: Flickable.VerticalFlick

            GridLayout {
                id: grid
                width: flick.width
                columns: 4
                rowSpacing: Config.ControlConfig.space3
                columnSpacing: Config.ControlConfig.space3

                // =========================================================
                // HARDWARE TELEMETRY (span 2)
                // =========================================================
                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                    border.color: root.cBorder; border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14
                        spacing: Config.ControlConfig.space2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Config.ControlConfig.space2
                            Rectangle { width: 8; height: 8; radius: 2; color: root.cSecondary; Layout.alignment: Qt.AlignVCenter }
                            Text {
                                text: "HARDWARE TELEMETRY"
                                color: root.cText
                                font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: badge.implicitWidth + 12; height: 16
                                color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.12)
                                border.color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.35); border.width: 1
                                Text {
                                    id: badge
                                    anchors.centerIn: parent
                                    text: "REAL-TIME"
                                    color: root.cSecondary
                                    font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                                }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Config.ControlConfig.space4

                            // CPU / GPU / BOARD column
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: 0
                                spacing: Config.ControlConfig.space3

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "CPU"; color: root.cDim; font.family: root.fontM; font.pixelSize: 10; font.letterSpacing: 1 }
                                        Text {
                                            text: root.m ? root.m.cpuModel : "—"
                                            color: root.cText
                                            font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignRight
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: ((root.m ? root.m.cpuThreads : 0) || 0) + " Threads"
                                            color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                            font.family: root.fontM; font.pixelSize: 9
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: (root.m && root.m.cpuMaxGhz > 0) ? root.m.cpuMaxGhz.toFixed(2) + " GHz Max" : "—"
                                            color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                            font.family: root.fontM; font.pixelSize: 9
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "GPU"; color: root.cDim; font.family: root.fontM; font.pixelSize: 10; font.letterSpacing: 1 }
                                        Text {
                                            text: root.m ? root.m.gpuName : "—"
                                            color: root.cText
                                            font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignRight
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: (root.m && root.m.gpuType) || "—"
                                            color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.85)
                                            font.family: root.fontM; font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                        }
                                        Text {
                                            text: (root.m && root.m.gpuDriver) || "—"
                                            color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.85)
                                            font.family: root.fontM; font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 180
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "BOARD"; color: root.cDim; font.family: root.fontM; font.pixelSize: 10; font.letterSpacing: 1 }
                                        Text {
                                            text: root.m ? root.m.boardName : "—"
                                            color: root.cText
                                            font.family: root.fontM; font.pixelSize: 12; font.bold: true
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignRight
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: (root.m && root.m.boardVendor !== "—" && root.m.boardVendor.length > 0) ? root.m.boardVendor : ""
                                            color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                            font.family: root.fontM; font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                        }
                                        Text {
                                            text: (root.m && root.m.chipset !== "—" && root.m.chipset.length > 0)
                                                  ? "CHIPSET " + root.m.chipset : ""
                                            color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                            font.family: root.fontM; font.pixelSize: 9; font.bold: true
                                        }
                                    }
                                }
                                Item { Layout.fillHeight: true }
                            }

                            // RAM radial + numbers
                            RowLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Config.ControlConfig.space3

                                Item {
                                    width: 108; height: 108
                                    Layout.alignment: Qt.AlignVCenter
                                    Canvas {
                                        id: ramRadial
                                        anchors.fill: parent
                                        property real pct: root.m ? root.m.memPct : 0
                                        function rgba(c, a) {
                                            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
                                        }
                                        onPctChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.clearRect(0, 0, width, height)
                                            var cx = width / 2, cy = height / 2
                                            var r = Math.min(width, height) / 2 - 9
                                            var start = -Math.PI / 2
                                            var frac = Math.min(100, Math.max(0, pct)) / 100
                                            var ac = root.cSecondary
                                            ctx.strokeStyle = rgba(ac, 0.20)
                                            ctx.lineWidth = 13
                                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start + Math.PI * 2 * frac); ctx.stroke()
                                            ctx.strokeStyle = rgba(ac, 0.12)
                                            ctx.lineWidth = 8
                                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
                                            ctx.strokeStyle = rgba(ac, 1)
                                            ctx.lineWidth = 8
                                            ctx.beginPath(); ctx.arc(cx, cy, r, start, start + Math.PI * 2 * frac); ctx.stroke()
                                        }
                                        Connections {
                                            target: root.m
                                            function onMemPctChanged() { ramRadial.requestPaint() }
                                        }
                                        Connections {
                                            target: root
                                            function onCSecondaryChanged() { ramRadial.requestPaint() }
                                        }
                                        Component.onCompleted: ramRadial.requestPaint()
                                    }
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 0
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: Math.round(root.m ? root.m.memPct : 0) + "%"
                                            color: root.cText
                                            font.family: root.fontM; font.pixelSize: 20; font.bold: true
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "RAM"
                                            color: root.cDim
                                            font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2
                                    Text {
                                        text: (root.m ? root.m.memUsedGiB : 0).toFixed(2) + " GiB"
                                        color: root.cText
                                        font.family: root.fontM; font.pixelSize: 12; font.bold: true
                                    }
                                    Text {
                                        text: (root.m && root.m.memTotalGiB > 0) ? root.m.memTotalGiB.toFixed(2) + " GiB Total" : "—"
                                        color: root.cDim
                                        font.family: root.fontM; font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }
                }

                // =========================================================
                // ACTIVE WALLPAPER (recovered from the bento OverviewTab —
                // identity card: live preview + name + path; click → tab 2)
                // =========================================================
                Components.ActiveWallpaperCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    Layout.minimumWidth: 0
                    onChangeRequested: root.wallpaperRequested()
                }

                // =========================================================
                // SESSION
                // =========================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                    border.color: root.cBorder; border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14
                        spacing: Config.ControlConfig.space2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Config.ControlConfig.space2
                            Rectangle { width: 8; height: 8; radius: 2; color: root.cPrimary; Layout.alignment: Qt.AlignVCenter }
                            Text {
                                text: "SESSION"
                                color: root.cText
                                font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                            }
                            Item { Layout.fillWidth: true }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 2
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "UPTIME"
                                color: root.cDim
                                font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.m ? root.m.uptimeStr : "—"
                                color: root.cPrimary
                                font.family: root.fontM; font.pixelSize: 22; font.bold: true
                            }
                            Item { Layout.preferredHeight: 4 }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Config.ControlConfig.space2
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48
                                    color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.4)
                                    border.color: root.cOutline; border.width: 1
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 1
                                        Text { text: "OS AGE"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: ((root.m ? root.m.osAgeDays : 0) || 0) + "d"; color: root.cText; font.family: root.fontM; font.pixelSize: 13; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48
                                    color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.4)
                                    border.color: root.cOutline; border.width: 1
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 1
                                        Text { text: "INSTALLED"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: (root.m && root.m.installDate) || "—"; color: root.cText; font.family: root.fontM; font.pixelSize: 11; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                // =========================================================
                // STORAGE (span 2 — fills the 4-col row beside Network+Health)
                // =========================================================
                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    clip: true
                    color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                    border.color: root.cBorder; border.width: 1

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14
                        spacing: Config.ControlConfig.space2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Config.ControlConfig.space2
                            Rectangle { width: 8; height: 8; radius: 2; color: root.cSecondary; Layout.alignment: Qt.AlignVCenter }
                            Text {
                                text: "STORAGE"
                                color: root.cText
                                font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: ((root.m && root.m.profileDisks ? root.m.profileDisks.length : 0)) + " VOL"
                                color: root.cDim
                                font.family: root.fontM; font.pixelSize: 9
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Config.ControlConfig.space2
                            Repeater {
                                model: root.m ? root.m.profileDisks : []
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: modelData.dev; color: root.cText; font.family: root.fontM; font.pixelSize: 10; font.bold: true }
                                        Item { Layout.fillWidth: true }
                                        Text { text: modelData.usedLabel + " / " + modelData.totalLabel; color: root.cDim; font.family: root.fontM; font.pixelSize: 9 }
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 5
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.7)
                                        }
                                        Rectangle {
                                            anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
                                            width: parent.width * Math.min(modelData.pct, 100) / 100
                                            color: root.diskColor(modelData.pct)
                                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                // =========================================================
                // NETWORK
                // =========================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                    border.color: root.cBorder; border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14
                        spacing: Config.ControlConfig.space2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Config.ControlConfig.space2
                            Rectangle {
                                width: 8; height: 8; radius: 4; color: root.cSuccess; Layout.alignment: Qt.AlignVCenter
                                SequentialAnimation on opacity {
                                    running: root.visible; loops: Animation.Infinite
                                    NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                }
                            }
                            Text {
                                text: "NETWORK"
                                color: root.cText
                                font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                            }
                            Item { Layout.fillWidth: true }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Config.ControlConfig.space1
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 30
                                color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.4)
                                border.color: root.cOutline; border.width: 1
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8
                                    Text { text: "LOCAL IP"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                    Item { Layout.fillWidth: true }
                                    Text { text: (root.net && root.net.ipAddress) || "—"; color: root.cSecondary; font.family: root.fontM; font.pixelSize: 10; font.bold: true }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 30
                                color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.4)
                                border.color: root.cOutline; border.width: 1
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8
                                    Text {
                                        text: (root.net && root.net.connectionType === "wifi") ? "SSID" : "LINK"
                                        color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: (root.net && root.net.ssid) || "—"
                                        color: root.cText; font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                        elide: Text.ElideRight
                                        Layout.minimumWidth: 0
                                        Layout.maximumWidth: 220
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 30
                                color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.4)
                                border.color: root.cOutline; border.width: 1
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8
                                    Text { text: "GEO"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: (root.m && root.m.geoCity)
                                              ? root.m.geoCity + (root.m.geoCountry ? ", " + root.m.geoCountry : "")
                                              : "—"
                                        color: root.cPrimary; font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                // =========================================================
                // HEALTH
                // =========================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                    border.color: root.cBorder; border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14
                        spacing: Config.ControlConfig.space2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Config.ControlConfig.space2
                            Rectangle { width: 8; height: 8; radius: 2; color: root.cSuccess; Layout.alignment: Qt.AlignVCenter }
                            Text {
                                text: "HEALTH"
                                color: root.cText
                                font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                            }
                            Item { Layout.fillWidth: true }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "GPU TEMP"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1 }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: (root.m && root.m.gpuTempC) ? root.m.gpuTempC + "°C" : "—"
                                    color: root.tempColor(root.m ? root.m.gpuTempC : 0)
                                    font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                }
                            }
                            Item {
                                Layout.fillWidth: true; Layout.preferredHeight: 4
                                Rectangle { anchors.fill: parent; color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.7) }
                                Rectangle {
                                    anchors.fill: parent
                                    color: root.tempColor(root.m ? root.m.gpuTempC : 0)
                                    opacity: (root.m && root.m.gpuTempC) ? Math.min(1, root.m.gpuTempC / 100) : 0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "GPU POWER"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1 }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: (root.m && root.m.gpuPowerW > 0) ? root.m.gpuPowerW.toFixed(1) + " W" : "—"
                                    color: root.cSecondary
                                    font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                }
                            }
                            Item {
                                Layout.fillWidth: true; Layout.preferredHeight: 4
                                Rectangle { anchors.fill: parent; color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.7) }
                                Rectangle {
                                    anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
                                    width: parent.width * Math.min((root.m ? root.m.gpuPowerW : 0) / 450, 1)
                                    color: root.cSecondary
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "GPU UTIL"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (root.m ? root.m.gpuUsagePct : 0) + "%"
                                color: root.cAccent2
                                font.family: root.fontM; font.pixelSize: 10; font.bold: true
                            }
                        }
                    }
                }

                // =========================================================
                // SOFTWARE & OS (full width)
                // =========================================================
                Rectangle {
                    Layout.columnSpan: 4
                    Layout.fillWidth: true
                    Layout.preferredHeight: 106
                    color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                    border.color: root.cBorder; border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14
                        spacing: Config.ControlConfig.space2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Config.ControlConfig.space2
                            Rectangle { width: 8; height: 8; radius: 2; color: root.cPrimary; Layout.alignment: Qt.AlignVCenter }
                            Text {
                                text: "SOFTWARE & OS"
                                color: root.cText
                                font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                            }
                            Item { Layout.fillWidth: true }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Config.ControlConfig.space5

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 1
                                Rectangle { width: 16; height: 2; color: root.cPrimary }
                                Text { text: "OPERATING SYSTEM"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                Text {
                                    text: ((root.m && root.m.osName) || "—") + ((root.m && root.m.osVersion) ? " " + root.m.osVersion : "")
                                    color: root.cPrimary; font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                    elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 0
                                }
                                Text {
                                    text: (root.m && root.m.osCodename)
                                          ? "(" + root.m.osCodename + ") " + ((root.m && root.m.arch) || "")
                                          : ((root.m && root.m.arch) || "")
                                    color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.italic: true
                                    elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 0
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 1
                                Rectangle { width: 16; height: 2; color: root.cSecondary }
                                Text { text: "KERNEL"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                Text {
                                    text: ((root.m && root.m.kernelName) || "—") + " " + ((root.m && root.m.kernelRelease) || "")
                                    color: root.cText; font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                    elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 0
                                }
                                Text { text: (root.m && root.m.arch) || ""; color: root.cDim; font.family: root.fontM; font.pixelSize: 9 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 1
                                Rectangle { width: 16; height: 2; color: root.cSuccess }
                                Text { text: "PACKAGES"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                Text {
                                    text: root.fmtNum(root.m ? root.m.pkgAll : 0) + " Total"
                                    color: root.cSuccess; font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                }
                                Text {
                                    text: ((root.m ? root.m.pkgSystem : 0) || 0) + " sys / " + ((root.m ? root.m.pkgUser : 0) || 0) + " user"
                                    color: root.cDim; font.family: root.fontM; font.pixelSize: 9
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 1
                                Rectangle { width: 16; height: 2; color: root.cAccent2 }
                                Text { text: "SHELL"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                Text {
                                    text: (root.m && root.m.shellName) || "—"
                                    color: root.cAccent2; font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                }
                                Text { text: "Quickshell"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9 }
                            }
                        }
                    }
                }
            }
        }
    }
}
