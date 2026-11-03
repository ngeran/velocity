// =============================================================================
// SystemInfoTab.qml — tab 0: the telemetry dashboard
// =============================================================================
// Replaces the bento OverviewTab as the dashboard landing tab (the bar's
// old FastfetchOverlay interior, rehosted as an embedded settings view;
// the overlay plugin itself was removed — this tab is the system info).
//
// MOCKUP REWORK (2026-10-31, user call: "make the Control Settings look like
// the Stitch mockup, adapting the active theme colors"): the grid follows the
// mockup's 12-unit proportions — row 1 = Hardware 5 / Wallpaper 4 / Session 3,
// row 2 = Storage 4 / Network 4 / Health 4, then the full-width Software & OS
// shelf. Rows are plain anchored Items with width = unit * n (NOT a
// GridLayout: columnSpan silently collapsed to equal columns on this window,
// and layout-engine span distribution is exactly what the mockup doesn't
// need). Card chrome follows the hud language: radius 10, corner brackets
// (accent top-left, primary bottom-right), dot + caps header, right chip.
//
// FULL-CHROME PASS (same day, window raised to the mockup's ~1100×1000): the
// mockup's remaining furniture is in — command strip (NODE/PROFILE chips +
// live clock; the shell header already has the power actions + operator),
// footer ticker (DAEMON ONLINE / IPC · distro right), sensor
// footer (CPU temp · FAN · COOLANT hwmon feeds), LED segment meters, and
// fixed-height network rows so slack pools under them instead of stretching
// the LOCAL IP panel. The mockup's rebuild/rollback buttons stay out — the
// dashboard reads, omni-apply writes.
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
//
// DISSOLVED-IN (2026-11-01): the former CORE › SYSTEM pane (CoreSystemPane —
// the instrument cluster + the DeepCool LCD controller) lives at the bottom
// of the scroll as the TELEMETRY + LCD section, and owns the coreVisible
// telemetry grant CoreEngineTab used to hold. scrollToCluster() serves the
// openCore system/lcd deep links; "events" remaps to the Logs tab.
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
    // FIXED HUD tokens — this tab is HUD chrome now, the same instrument
    // cluster language as CoreSystemPane (deliberately theme-independent).
    readonly property color cText:      Config.HudConfig.textHi
    readonly property color cDim:       Config.HudConfig.textDim
    readonly property color cBorder:    Config.HudConfig.borderLo
    readonly property color cOutline:   Config.HudConfig.borderHi
    readonly property color cSurface:   Config.HudConfig.well
    readonly property color cSecondary: Config.HudConfig.cyan       // hardware / radial / storage
    readonly property color cPrimary:   Config.HudConfig.amber      // session / software
    readonly property color cSuccess:   Config.HudConfig.cyan       // network / healthy (telemetry cool)
    readonly property color cWarn:      Config.HudConfig.amber      // restart / temp tiers
    readonly property color cErr:       Config.HudConfig.red        // shutdown / hot
    readonly property color cAccent2:   Config.HudConfig.amber      // GPU util highlight
    readonly property string fontM:     Config.HudConfig.fontData

    // active-theme card data (ThemeConfig stays the user-theme SSOT; read-only here)
    readonly property var themeMeta:   Config.ThemeConfig.metadata
    readonly property var themeColors: Config.ThemeConfig.colors

    function diskColor(pct) { if (pct >= 90) return cErr; if (pct >= 75) return cWarn; return cSecondary }
    function tempColor(c)   { if (!c) return cDim; if (c >= 80) return cErr; if (c >= 60) return cWarn; return cSuccess }
    function loadColor(p)   { if (p >= 85) return cErr; if (p >= 60) return cWarn; return cSuccess }
    function fmtNum(n) { return (n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",") }
    function fmtRate(kb) {
        var v = kb || 0
        return v >= 1024 ? (v / 1024).toFixed(1) + " MB/s" : Math.round(v) + " KB/s"
    }
    // profileDisks rows carry display labels but no filesystem; the metrics
    // `disks` array (proc/lsblk parse) has fstype — join on the mountpoint.
    function fsTypeFor(mount) {
        var d = root.m ? root.m.disks : []
        for (var i = 0; i < d.length; i++)
            if (d[i].mount === mount) return (d[i].fstype || "").toUpperCase()
        return ""
    }

    // ── Nix generation (mockup: "Gen #142 (Active)" chip in SESSION) ────────
    // One readlink at tab construction — it only moves on a rebuild, so a
    // per-session snapshot is plenty.
    property string nixGen: ""
    Services.BoundedProcess {
        id: genProbe
        command: ["sh", "-c", "readlink /nix/var/nix/profiles/system"]
        onDone: function(out) {
            var g = (out.trim() || "").match(/-(\d+)-link/)
            if (g) root.nixGen = g[1]
        }
    }

    // ── command-strip clock (mockup header: "Saturday 09:08:42") ────────────
    // Gated 1 s Timer (not SystemClock): costs nothing while the window is
    // hidden, and the tab lives for the whole session once opened.
    property date hudNow: new Date()
    Timer {
        interval: 1000
        running: root.shown && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.hudNow = new Date()
    }

    // ── row height ──────────────────────────────────────────────────────────
    // The two card rows split the height the window gives the tab (mockup
    // rows are equal). Clamped so a shrunken window scrolls instead of
    // crushing the cards.
    readonly property int softwareStripH: 126
    readonly property real rowH: Math.max(180, (flick.height - softwareStripH - 2 * Config.ControlConfig.space3) / 2)


    // =========================================================================
    // HUD KIT — card chrome shared by every tile (mockup hud-card language)
    // =========================================================================

    // Bordered status chip (mockup badges: REAL-TIME, NOMINAL, Gen #…).
    component HudChip: Rectangle {
        property string label: ""
        property color chipColor: root.cSecondary
        property bool pulse: false
        implicitWidth: chipRow.implicitWidth + 12; implicitHeight: 16; radius: 3
        color: Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.12)
        border.color: Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.35); border.width: 1
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            Rectangle {
                visible: parent.parent.pulse
                width: 5; height: 5; radius: 2
                color: parent.parent.chipColor
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: root.shown && root.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.3; to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Text {
                text: parent.parent.label
                color: parent.parent.chipColor
                font.family: root.fontM; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Card header: accent dot + caps title + optional chip, over a hairline.
    component HudHeader: ColumnLayout {
        id: hdr
        property string title: ""
        property color dotColor: root.cSecondary
        property bool pulse: false
        property string chipLabel: ""
        property color chipColor: root.cSecondary
        property bool chipPulse: false
        Layout.fillWidth: true
        spacing: Config.ControlConfig.space2
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.ControlConfig.space2
            Rectangle {
                width: 8; height: 8; radius: 2
                color: parent.parent.dotColor
                Layout.alignment: Qt.AlignVCenter
                SequentialAnimation on opacity {
                    // NOTE: from inside the animation, parent.parent is the
                    // RowLayout (not this header) — reference the id instead.
                    running: root.shown && hdr.pulse && root.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.3; to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Text {
                text: parent.parent.title
                color: root.cText
                font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
            }
            Item { Layout.fillWidth: true }
            HudChip {
                visible: parent.parent.chipLabel !== ""
                label: parent.parent.chipLabel
                chipColor: parent.parent.chipColor
                pulse: parent.parent.chipPulse
                Layout.alignment: Qt.AlignVCenter
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }
    }

    // Inset spec panel (the mockup's obsidian-850 boxes).
    component InsetPanel: Rectangle {
        color: root.cSurface                      // HUD well
        border.color: root.cOutline; border.width: 1
        radius: 4
    }

    // =========================================================================
    // METRICS KICK — pull the profile on every window-open, lease while shown
    // =========================================================================
    // `visible` alone never fires here (tab created visible with the bridge
    // attached) — the reliable edges are the WINDOW shown state and the
    // tab's own re-entry from another tab.
    readonly property bool shown: Config.SharedState.dashboardVisible
    Component.onCompleted: {
        genProbe.run()
        if (shown) root._kickMetrics()
    }
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

    // ── TELEMETRY + LCD section scroll (openCore deep links + search) ───────
    // Deferred a tick: the deep link can land before the layout pass has
    // placed the section (cold open), and contentY needs its final y.
    function scrollToCluster() {
        clusterScrollNudge.restart()
    }
    Timer {
        id: clusterScrollNudge
        interval: 60
        onTriggered: {
            var maxY = Math.max(0, flick.contentHeight - flick.height)
            flick.contentY = Math.min(clusterSection.y, maxY)
        }
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

        // ── COMMAND STRIP (mockup header centre/right: node · profile · live
        // clock; the window shell already carries the power actions and the
        // operator card, so those are not duplicated here) ───────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            readonly property color chipBg: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.5)
            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: Config.ControlConfig.space2
                Rectangle {
                    height: 20; width: nodeRow.implicitWidth + 16; radius: 10
                    color: parent.parent.chipBg; border.color: root.cOutline; border.width: 1
                    Row {
                        id: nodeRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "NODE:"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: (root.m && root.m.hostname && root.m.hostname !== "unknown") ? root.m.hostname.toUpperCase() : "—"
                            color: root.cPrimary; font.family: root.fontM; font.pixelSize: 9; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                Rectangle {
                    height: 20; width: profRow.implicitWidth + 16; radius: 10
                    color: parent.parent.chipBg; border.color: root.cOutline; border.width: 1
                    Row {
                        id: profRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "PROFILE:"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: (root.m && root.m.osCodename) ? root.m.osCodename.toUpperCase() : "—"
                            color: root.cAccent2; font.family: root.fontM; font.pixelSize: 9; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8
                Text {
                    text: Qt.formatDateTime(root.hudNow, "dddd").toUpperCase()
                    color: root.cDim; font.family: root.fontM; font.pixelSize: 9
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Qt.formatDateTime(root.hudNow, "HH:mm:ss")
                    color: root.cText; font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle { width: 1; height: 14; color: root.cBorder; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    // Bell (mockup header): opens the bar's notification
                    // center through the HostBridge ncToggle hook. Drawn as a
                    // Canvas — plain JetBrains Mono has no bell glyph.
                    id: bellBtn
                    width: 24; height: 24; radius: 6
                    visible: Services.HostBridge.ncToggle !== null
                    color: bellMa.containsMouse
                           ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.15)
                           : Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.5)
                    border.color: bellMa.containsMouse ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.6) : root.cOutline
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Canvas {
                        anchors.centerIn: parent
                        width: 12; height: 13
                        property color strokeColor: bellMa.containsMouse ? root.cPrimary : root.cDim
                        onStrokeColorChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = strokeColor.toString()
                            ctx.lineWidth = 1.4
                            ctx.lineJoin = "round"
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.moveTo(2, 9)
                            ctx.lineTo(2, 7.5)
                            ctx.arc(6, 7.5, 4, Math.PI, 0)
                            ctx.lineTo(10, 9)
                            ctx.lineTo(11, 10.5)
                            ctx.lineTo(1, 10.5)
                            ctx.closePath()
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.arc(6, 12, 1.1, 0, Math.PI)
                            ctx.stroke()
                        }
                    }
                    MouseArea {
                        id: bellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (Services.HostBridge.ncToggle) Services.HostBridge.ncToggle()
                    }
                }
            }
        }

        // ---- card rows (scrollable on the 480px-floor viewport) ----
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: rowsCol.height
            flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: rowsCol
                width: flick.width
                spacing: Config.ControlConfig.space3

                // ═════════════════════════════════════════════════════════
                // ROW 1 — HARDWARE (8) · WALLPAPER (4)
                // ═════════════════════════════════════════════════════════
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.rowH - 30
                    readonly property real unit: (width - 1 * Config.ControlConfig.space3) / 12

                    // ── HARDWARE TELEMETRY ────────────────────────────────
                    Rectangle {
                        id: hwCard
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: parent.unit * 8
                        color: Config.HudConfig.panel
                        border.color: root.cBorder; border.width: 1
                        radius: 0
                        clip: true


                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 14
                            spacing: Config.ControlConfig.space2

                            HudHeader {
                                title: "HARDWARE TELEMETRY"
                                dotColor: root.cSecondary
                                chipLabel: "REAL-TIME"
                                chipColor: root.cSecondary
                                chipPulse: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: Config.ControlConfig.space3

                                // CPU / GPU / BOARD spec panels
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumWidth: 0
                                    spacing: Config.ControlConfig.space2

                                    // ── CPU ──────────────────────────────
                                    InsetPanel {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        ColumnLayout {
                                            anchors.fill: parent; anchors.margins: 10
                                            spacing: 3
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "CPU"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1 }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: (root.m && root.m.cpuTemp > 0 ? Math.round(root.m.cpuTemp) + "°C · " : "")
                                                          + Math.round(root.m ? root.m.cpuUsage : 0) + "% LOAD"
                                                    color: root.loadColor(root.m ? root.m.cpuUsage : 0)
                                                    font.family: root.fontM; font.pixelSize: 9; font.bold: true
                                                }
                                            }
                                            Text {
                                                text: root.m ? root.m.cpuModel : "—"
                                                color: root.cText
                                                font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true; Layout.minimumWidth: 0
                                            }
                                            Text {
                                                text: ((root.m ? root.m.cpuThreads : 0) || 0) + " THREADS"
                                                      + ((root.m && root.m.cpuMaxGhz > 0) ? " · " + root.m.cpuMaxGhz.toFixed(2) + " GHZ MAX" : "")
                                                color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.85)
                                                font.family: root.fontM; font.pixelSize: 9
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true; Layout.minimumWidth: 0
                                            }
                                            Components.HudLedBar {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 7
                                                segments: 30; segmentGap: 2
                                                glowAlpha: 0.25
                                                value: root.m ? root.m.cpuUsage : 0
                                                litColor: root.loadColor(root.m ? root.m.cpuUsage : 0)
                                            }
                                        }
                                    }

                                    // ── GPU ──────────────────────────────
                                    InsetPanel {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        ColumnLayout {
                                            anchors.fill: parent; anchors.margins: 10
                                            spacing: 3
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "GPU"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1 }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: ((root.m && root.m.gpuType) ? root.m.gpuType.toUpperCase() : "—")
                                                    color: root.cWarn
                                                    font.family: root.fontM; font.pixelSize: 9; font.bold: true
                                                }
                                            }
                                            Text {
                                                text: root.m ? root.m.gpuName : "—"
                                                color: root.cText
                                                font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true; Layout.minimumWidth: 0
                                            }
                                            Text {
                                                text: ((root.m && root.m.gpuDriver) ? "DRIVER " + root.m.gpuDriver : "—")
                                                      + ((root.m && root.m.gpuTempC) ? " · " + root.m.gpuTempC + "°C" : "")
                                                color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.85)
                                                font.family: root.fontM; font.pixelSize: 9
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true; Layout.minimumWidth: 0
                                            }
                                        }
                                    }

                                    // ── BOARD ────────────────────────────
                                    InsetPanel {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        ColumnLayout {
                                            anchors.fill: parent; anchors.margins: 10
                                            spacing: 3
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "BOARD & UEFI"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1 }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: (root.m && root.m.boardVendor && root.m.boardVendor !== "—") ? root.m.boardVendor.toUpperCase() : "—"
                                                    color: root.cText
                                                    font.family: root.fontM; font.pixelSize: 9; font.bold: true
                                                }
                                            }
                                            Text {
                                                text: root.m ? root.m.boardName : "—"
                                                color: root.cText
                                                font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true; Layout.minimumWidth: 0
                                            }
                                            HudChip {
                                                visible: root.m && root.m.chipset && root.m.chipset !== "—"
                                                label: "CHIPSET " + (root.m ? root.m.chipset : "")
                                                chipColor: root.cSecondary
                                            }
                                        }
                                    }
                                }

                                // RAM radial + capacity footer
                                ColumnLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 6

                                    // the cluster's dot ring (HudDotRing):
                                    // 40 dots, Doto numeral core
                                    Components.HudDotRing {
                                        width: 200; height: 200
                                        Layout.alignment: Qt.AlignHCenter
                                        value: root.m ? root.m.memPct : 0
                                        valueText: String(Math.round(root.m ? root.m.memPct : 0))
                                        caption: "RAM · " + (root.m ? root.m.memUsedGiB : 0).toFixed(0) + "G"
                                        accent: root.cSecondary
                                    }
                                    ColumnLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 1
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: (root.m ? root.m.memUsedGiB : 0).toFixed(2) + " GiB USED"
                                            color: root.cSecondary
                                            font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: (root.m && root.m.memTotalGiB > 0) ? root.m.memTotalGiB.toFixed(2) + " GiB TOTAL" : "—"
                                            color: root.cDim
                                            font.family: root.fontM; font.pixelSize: 8
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── ACTIVE WALLPAPER ─────────────────────────────────────
                    Components.ActiveWallpaperCard {
                        id: wallpaperCard
                        anchors {
                            left: hwCard.right; leftMargin: Config.ControlConfig.space3
                            top: parent.top; bottom: parent.bottom
                        }
                        width: parent.unit * 4
                        onChangeRequested: root.wallpaperRequested()
                    }

                }

                // ═════════════════════════════════════════════════════════
                // ROW 2 — STORAGE / HEALTH (5) · NETWORK (4) · SESSION / THEME (3)
                // ═════════════════════════════════════════════════════════
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.rowH + 30
                    readonly property real unit: (width - 2 * Config.ControlConfig.space3) / 12

                    // ── STORAGE ──────────────────────────────────────────────
                    Rectangle {
                        id: stCard
                        anchors { left: parent.left; top: parent.top }
                        height: (parent.height - Config.ControlConfig.space3) / 2
                        width: parent.unit * 5
                        color: Config.HudConfig.panel
                        border.color: root.cBorder; border.width: 1
                        radius: 0
                        clip: true


                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 12
                            spacing: Config.ControlConfig.space2

                            HudHeader {
                                title: "STORAGE"
                                dotColor: root.cSecondary
                                chipLabel: ((root.m && root.m.profileDisks ? root.m.profileDisks.length : 0)) + " VOLUMES"
                                chipColor: root.cPrimary
                            }

                            // Disk rows — plain anchored stack (the unit-row
                            // pattern; a Repeater inside a fillHeight
                            // ColumnLayout pooled its stretch into one dead
                            // gap here at the taller card height).
                            Item {
                                id: stBody
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                readonly property int n: (root.m && root.m.profileDisks) ? root.m.profileDisks.length : 0
                                readonly property real rowH2: n > 0 ? Math.max(26, (height - (n - 1) * 6) / n) : 0
                                Repeater {
                                    model: root.m ? root.m.profileDisks : []
                                    Item {
                                        width: stBody.width
                                        height: stBody.rowH2
                                        y: index * (stBody.rowH2 + 6)
                                        Column {
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                            spacing: 2
                                            RowLayout {
                                                width: parent.width
                                                spacing: 6
                                                Text {
                                                    text: modelData.dev
                                                    color: root.cText; font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                                }
                                                Text {
                                                    text: modelData.mount === "/" ? "(/)" : "(" + modelData.mount + ")"
                                                    color: root.cDim; font.family: root.fontM; font.pixelSize: 8
                                                }
                                                Text {
                                                    text: modelData.usedLabel + " / " + modelData.totalLabel
                                                    color: root.cDim; font.family: root.fontM; font.pixelSize: 9
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true; Layout.minimumWidth: 0
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }
                                            Components.HudLedBar {
                                                width: parent.width
                                                height: 7
                                                segments: 44; segmentGap: 2
                                                glowAlpha: 0.25
                                                value: Math.min(modelData.pct, 100)
                                                litColor: root.diskColor(modelData.pct)
                                            }
                                            RowLayout {
                                                width: parent.width
                                                Text {
                                                    text: "FS: " + (root.fsTypeFor(modelData.mount) || "—")
                                                    color: root.cDim; font.family: root.fontM; font.pixelSize: 8
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: Math.round(modelData.pct) + "% USED"
                                                    color: root.diskColor(modelData.pct); font.family: root.fontM; font.pixelSize: 8; font.bold: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── NETWORK ──────────────────────────────────────────────
                    Rectangle {
                        id: netCard
                        anchors {
                            left: stCard.right; leftMargin: Config.ControlConfig.space3
                            top: parent.top; bottom: parent.bottom
                        }
                        width: parent.unit * 4
                        color: Config.HudConfig.panel
                        border.color: root.cBorder; border.width: 1
                        radius: 0
                        clip: true


                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 14
                            spacing: Config.ControlConfig.space2

                            HudHeader {
                                title: "NETWORK"
                                dotColor: root.cSuccess
                                pulse: true
                                chipLabel: {
                                    if (!root.net) return "OFFLINE"
                                    var st = root.net.connectionStatus
                                    return (st && st.connected) ? ((st.type === "wifi" ? "WLAN" : "ETH") + " LINK") : "OFFLINE"
                                }
                                chipColor: (root.net && root.net.connectionStatus && root.net.connectionStatus.connected) ? root.cSuccess : root.cErr
                                chipPulse: root.net && root.net.connectionStatus && root.net.connectionStatus.connected
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: Config.ControlConfig.space2

                                // LOCAL IP
                                InsetPanel {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 56
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 10
                                        ColumnLayout {
                                            spacing: 1
                                            Text { text: "LOCAL IP" + ((root.net && root.net.iface) ? " (" + root.net.iface.toUpperCase() + ")" : ""); color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                            Text {
                                                // connectionStatus.ip is maintained on
                                                // attach + every change by the service's
                                                // link probe (route src / nmcli);
                                                // .ipAddress is the popup-diagnostics
                                                // string (only filled while the network
                                                // popup probes).
                                                text: (root.net && (root.net.connectionStatus.ip || root.net.ipAddress)) || "—"
                                                color: root.cSecondary; font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }

                                // SSID + signal
                                InsetPanel {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 56
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 10
                                        spacing: Config.ControlConfig.space2
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            spacing: 1
                                            Text {
                                                text: (root.net && root.net.connectionType === "wifi") ? "SSID ACCESS POINT" : "LINK"
                                                color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
                                            }
                                            Text {
                                                text: (root.net && root.net.ssid) || "—"
                                                color: root.cText; font.family: root.fontM; font.pixelSize: 11; font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true; Layout.minimumWidth: 0
                                            }
                                        }
                                        HudChip {
                                            visible: (root.net ? root.net.signalStrength : 0) > 0
                                            label: (root.net ? root.net.signalStrength : 0) + "%"
                                            chipColor: root.cPrimary
                                        }
                                    }
                                }

                                // GEO / gateway
                                InsetPanel {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 56
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 10
                                        spacing: Config.ControlConfig.space2
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            spacing: 1
                                            Text { text: "GEO / GATEWAY"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                            Text {
                                                text: (root.m && root.m.geoCity)
                                                      ? root.m.geoCity + (root.m.geoCountry ? ", " + root.m.geoCountry : "")
                                                      : "—"
                                                color: root.cText; font.family: root.fontM; font.pixelSize: 11; font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true; Layout.minimumWidth: 0
                                            }
                                        }
                                        Text {
                                            text: ((root.net && root.net.lossPct >= 0) ? root.net.lossPct.toFixed(0) + "% LOSS" : "")
                                            color: root.cSuccess; font.family: root.fontM; font.pixelSize: 9; font.bold: true
                                        }
                                    }
                                }

                                // Slack pools here — the three spec rows keep
                                // mockup height and the footer pins to the
                                // card bottom instead of the rows stretching.
                                Item { Layout.fillHeight: true }
                            }

                            // Live throughput footer (dashboard lease keeps the
                            // traffic sampler running while the window is open)
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Config.ControlConfig.space4
                                ColumnLayout {
                                    spacing: 0
                                    Text { text: "↓ RX DOWN"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8 }
                                    Text {
                                        text: root.net ? root.fmtRate(root.net.trafficRxKB) : "—"
                                        color: root.cPrimary; font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                    }
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Text { text: "↑ TX UP"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8 }
                                    Text {
                                        text: root.net ? root.fmtRate(root.net.trafficTxKB) : "—"
                                        color: root.cSecondary; font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: (root.net && root.net.rxTotalMB > 0)
                                          ? "Σ " + Math.round(root.net.rxTotalMB) + " / " + Math.round(root.net.txTotalMB) + " MB"
                                          : ""
                                    color: root.cDim; font.family: root.fontM; font.pixelSize: 8
                                }
                            }
                        }
                    }

                    // ── HEALTH ───────────────────────────────────────────────
                    Rectangle {
                        id: healthCard
                        anchors {
                            left: parent.left; top: stCard.bottom; topMargin: Config.ControlConfig.space3
                            bottom: parent.bottom
                        }
                        width: parent.unit * 5
                        color: Config.HudConfig.panel
                        border.color: root.cBorder; border.width: 1
                        radius: 0
                        clip: true


                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 14
                            spacing: Config.ControlConfig.space2

                            HudHeader {
                                title: "HEALTH"
                                dotColor: root.cSuccess
                                chipLabel: {
                                    var t = root.m ? root.m.gpuTempC : 0
                                    return (!t || t < 60) ? "NOMINAL" : (t < 80 ? "WARM" : "HOT")
                                }
                                chipColor: root.tempColor(root.m ? root.m.gpuTempC : 0)
                            }

                            // GPU TEMPERATURE
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 2
                                Item { Layout.fillHeight: true }   // vertical centering within the band
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "GPU TEMPERATURE"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1 }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: (root.m && root.m.gpuTempC) ? root.m.gpuTempC + "°C / 85°C" : "—"
                                        color: root.tempColor(root.m ? root.m.gpuTempC : 0)
                                        font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                    }
                                }
                                Components.HudLedBar {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 7
                                    segments: 44; segmentGap: 2
                                    glowAlpha: 0.25
                                    value: Math.min((root.m ? root.m.gpuTempC : 0) / 85 * 100, 100)
                                    litColor: root.tempColor(root.m ? root.m.gpuTempC : 0)
                                }
                                Item { Layout.fillHeight: true }
                            }

                            // GPU BOARD POWER
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "GPU BOARD POWER"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1 }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: (root.m && root.m.gpuPowerW > 0) ? root.m.gpuPowerW.toFixed(1) + " W / 450 W" : "—"
                                        color: root.cSecondary
                                        font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                    }
                                }
                                Components.HudLedBar {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 7
                                    segments: 44; segmentGap: 2
                                    glowAlpha: 0.25
                                    value: Math.min((root.m ? root.m.gpuPowerW : 0) / 450 * 100, 100)
                                    litColor: root.cSecondary
                                }
                            }

                            // GPU UTILIZATION
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 2
                                Item { Layout.fillHeight: true }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "GPU UTILIZATION"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1 }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: (root.m ? root.m.gpuUsagePct : 0) + "%"
                                        color: root.cAccent2
                                        font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                    }
                                }
                                Components.HudLedBar {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 7
                                    segments: 44; segmentGap: 2
                                    glowAlpha: 0.25
                                    value: Math.min((root.m ? root.m.gpuUsagePct : 0), 100)
                                    litColor: root.cAccent2
                                }
                                Item { Layout.fillHeight: true }
                            }

                            // Sensor footer (mockup fan/AIO row — cpu temp and
                            // fan duty are the hwmon feeds we actually have)
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "CPU " + ((root.m && root.m.cpuTemp > 0) ? Math.round(root.m.cpuTemp) + "°C" : "—")
                                          + " · FAN " + Math.round(root.m ? root.m.gpuFanPct : 0) + "%"
                                    color: root.cDim; font.family: root.fontM; font.pixelSize: 8
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    visible: root.m && root.m.coolantTemp > 0
                                    text: "COOLANT " + Math.round(root.m ? root.m.coolantTemp : 0) + "°C"
                                    color: root.cSuccess; font.family: root.fontM; font.pixelSize: 8; font.bold: true
                                }
                            }
                        }
                    }

                    // ── SESSION — stacked over ACTIVE THEME ───────────────
                    Rectangle {
                        id: sessCard
                        anchors { right: parent.right; top: parent.top }
                        height: (parent.height - Config.ControlConfig.space3) / 2
                        width: parent.unit * 3
                        color: Config.HudConfig.panel
                        border.color: root.cBorder; border.width: 1
                        radius: 0
                        clip: true


                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 14
                            spacing: Config.ControlConfig.space2

                            HudHeader {
                                title: "SESSION"
                                dotColor: root.cPrimary
                                chipLabel: "HYPRLAND"
                                chipColor: root.cPrimary
                            }

                            // Hero uptime counter (mockup: unboxed centrepiece)
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "SYSTEM UPTIME"
                                        color: root.cDim
                                        font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 2; font.bold: true
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: root.m ? root.m.uptimeStr : "—"
                                        color: root.cText
                                        font.family: Config.HudConfig.fontDoto
                                        font.variableAxes: ({ "ROND": 100, "wght": 600 })
                                        font.pixelSize: 26
                                    }
                                }
                            }

                            // Age + installation tiles
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Config.ControlConfig.space2
                                InsetPanel {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 1
                                        Text { text: "OS AGE"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: ((root.m ? root.m.osAgeDays : 0) || 0) + "d"; color: root.cText; font.family: Config.HudConfig.fontDoto; font.pixelSize: 16; font.variableAxes: ({ "ROND": 100, "wght": 700 }); Layout.alignment: Qt.AlignHCenter }
                                    }
                                }
                                InsetPanel {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 1
                                        Text { text: "INSTALLED"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: (root.m && root.m.installDate) || "—"; color: root.cText; font.family: Config.HudConfig.fontDoto; font.pixelSize: 14; font.variableAxes: ({ "ROND": 100, "wght": 700 }); Layout.alignment: Qt.AlignHCenter }
                                    }
                                }
                            }

                            // Nix generation footer
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "NIX GENERATION"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                Item { Layout.fillWidth: true }
                                HudChip {
                                    visible: root.nixGen !== ""
                                    label: "GEN #" + root.nixGen + " (ACTIVE)"
                                    chipColor: root.cSecondary
                                }
                            }
                        }
                    }

                    // ── ACTIVE THEME — stacked under SESSION ──────────────
                    Rectangle {
                        anchors {
                            right: parent.right; top: sessCard.bottom; topMargin: Config.ControlConfig.space3
                            bottom: parent.bottom
                        }
                        width: parent.unit * 3
                        color: Config.HudConfig.panel
                        border.color: root.cBorder; border.width: 1
                        radius: 0
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 12
                            spacing: 4

                            HudHeader {
                                title: "ACTIVE THEME"
                                dotColor: root.cPrimary
                                chipLabel: (root.themeMeta.source || "preset").toUpperCase()
                                chipColor: root.cSecondary
                            }

                            Text {
                                text: root.themeMeta.name || "—"
                                color: root.cText
                                font.family: root.fontM; font.pixelSize: 14; font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true; Layout.minimumWidth: 0
                            }

                            Item { Layout.fillHeight: true }

                            // live palette — 2×4 swatch grid straight from the SSOT
                            Grid {
                                columns: 4
                                columnSpacing: 6; rowSpacing: 6
                                Layout.fillWidth: true
                                Repeater {
                                    model: [
                                        { k: "PRI",  c: root.themeColors.primary },
                                        { k: "SEC",  c: root.themeColors.secondary },
                                        { k: "ACC",  c: root.themeColors.accent },
                                        { k: "OK",   c: root.themeColors.success },
                                        { k: "WARN", c: root.themeColors.warning },
                                        { k: "ERR",  c: root.themeColors.error },
                                        { k: "TXT",  c: root.themeColors.text },
                                        { k: "BG",   c: root.themeColors.background }
                                    ]
                                    delegate: Column {
                                        spacing: 2
                                        Rectangle {
                                            width: 44; height: 20
                                            color: modelData.c
                                            border.color: root.cOutline; border.width: 1
                                        }
                                        Text {
                                            text: modelData.k
                                            color: root.cDim; font.family: root.fontM
                                            font.pixelSize: 7; font.letterSpacing: 1; font.bold: true
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }

                            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }
                            RowLayout {
                                Layout.fillWidth: true
                                HudChip {
                                    label: root.themeMeta.matugenEnabled ? "MATUGEN ON" : "MATUGEN OFF"
                                    chipColor: root.themeMeta.matugenEnabled ? root.cSuccess : root.cDim
                                }
                                Item { Layout.fillWidth: true }
                                HudChip {
                                    visible: root.themeMeta.oledClamp !== false
                                    label: "OLED CLAMP"
                                    chipColor: root.cPrimary
                                }
                            }
                        }
                    }
                }

                // ═════════════════════════════════════════════════════════
                // SHELF — SOFTWARE & OS (full width)
                // ═════════════════════════════════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.softwareStripH
                    color: Config.HudConfig.panel
                    border.color: root.cBorder; border.width: 1
                    radius: 0
                    clip: true


                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 10
                        spacing: Config.ControlConfig.space2

                        HudHeader {
                            title: "SOFTWARE & OS"
                            dotColor: root.cPrimary
                            chipLabel: (root.m && root.m.osCodename) ? root.m.osCodename.toUpperCase() : ""
                            chipColor: root.cPrimary
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Config.ControlConfig.space2

                            InsetPanel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: 0
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 8
                                    spacing: 1
                                    Text { text: "OPERATING SYSTEM"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                    Text {
                                        text: ((root.m && root.m.osName) || "—") + ((root.m && root.m.osVersion) ? " " + root.m.osVersion : "")
                                        color: root.cPrimary; font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                        elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 0
                                    }
                                    Text {
                                        text: (root.m && root.m.arch) ? "ARCH: " + root.m.arch : ""
                                        color: root.cDim; font.family: root.fontM; font.pixelSize: 9
                                        elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 0
                                    }
                                }
                            }
                            InsetPanel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: 0
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 8
                                    spacing: 1
                                    Text { text: "KERNEL"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                    Text {
                                        text: ((root.m && root.m.kernelName) || "—") + " " + ((root.m && root.m.kernelRelease) || "")
                                        color: root.cText; font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                        elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 0
                                    }
                                    Text { text: (root.m && root.m.arch) ? "TYPE: " + root.m.arch : ""; color: root.cDim; font.family: root.fontM; font.pixelSize: 9 }
                                }
                            }
                            InsetPanel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: 0
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 8
                                    spacing: 1
                                    Text { text: "MANAGED PACKAGES"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                    Text {
                                        text: root.fmtNum(root.m ? root.m.pkgAll : 0) + " Total"
                                        color: root.cSuccess; font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                    }
                                    Text {
                                        text: ((root.m ? root.m.pkgSystem : 0) || 0) + " sys · " + ((root.m ? root.m.pkgUser : 0) || 0) + " user"
                                        color: root.cDim; font.family: root.fontM; font.pixelSize: 9
                                    }
                                }
                            }
                            InsetPanel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: 0
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 8
                                    spacing: 1
                                    Text { text: "SHELL & COMPOSITOR"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
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

                // ═════════════════════════════════════════════════════════
                // TELEMETRY + LCD — the former CORE › SYSTEM pane, dissolved
                // into the dashboard (openCore system|lcd deep links scroll
                // here). Hosted on a fixed ~960px band matching the pane's
                // natural composition (header 28 + load 128 + hero 296 + LCD
                // 348 + precision fill): the viewport scrolls, the card rows
                // above keep their rowH-derived sizes (floor law untouched).
                // ═════════════════════════════════════════════════════════
                ColumnLayout {
                    id: clusterSection
                    Layout.fillWidth: true
                    spacing: Config.ControlConfig.space2

                    HudHeader {
                        title: "TELEMETRY + LCD"
                        dotColor: root.cSecondary
                        chipLabel: "INSTRUMENT CLUSTER"
                        chipColor: root.cSecondary
                    }

                    // The grant is the load-bearing part: coreVisible is the
                    // ONLY switch for MetricsService's dmonLoop (nvidia-smi
                    // dmon), history rings and per-core rows — the 45s lease
                    // the dashboard keeps does NOT flip it. Grant moved 1:1
                    // from the deleted CoreEngineTab; the loader gates on the
                    // window edge exactly like the old tab loader did, so
                    // dmon runs only while the panel is open. Gating on the
                    // metrics identity too makes the grant self-heal a bridge
                    // re-attach (new object → reload → re-grant).
                    Loader {
                        id: clusterLoader
                        Layout.fillWidth: true
                        Layout.preferredHeight: 960
                        active: root.shown && root.m !== null
                        sourceComponent: Components.CoreSystemPane { anchors.fill: parent }
                        onLoaded: if (root.m) root.m.coreVisible = true
                        onActiveChanged: if (!active && root.m) root.m.coreVisible = false
                    }
                }
            }
        }

        // ── TICKER (mockup footer strip: daemon state left, distro right) ───
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 8
                Rectangle {
                    width: 6; height: 6; radius: 3; color: root.cSuccess
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        running: root.shown && root.visible; loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.25; duration: 1100 }
                        NumberAnimation { from: 0.25; to: 1; duration: 1100 }
                    }
                }
                Text {
                    text: "DAEMON ONLINE"
                    color: root.cPrimary; font.family: root.fontM; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text { text: "|"; color: root.cBorder; font.family: root.fontM; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "IPC: HYPRLAND SOCKET2"
                    color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: (root.m && root.m.osName)
                      ? ((root.m.osName + (root.m.osVersion ? " " + root.m.osVersion : "")).toUpperCase()
                         + ((root.m && root.m.arch) ? "  ·  " + root.m.arch.toUpperCase() : ""))
                      : ""
                color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
            }
        }
    }
}
