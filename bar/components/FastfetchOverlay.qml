// =============================================================================
// FastfetchOverlay.qml — SYSTEM INFO telemetry dashboard
// =============================================================================
// Opened from the Arch logo in the bar. Rebuilt from a plain fastfetch text
// dump into a structured dashboard matching the NixOS System Info reference:
// a 900×680 card (same size as ZaiUsageOverlay) with a grid of themed cards —
// Hardware (CPU/GPU + RAM radial), Session, Storage, Network, Health, and a
// full-width Software & OS strip.
//
// All data comes from Services.SystemInfoService (fastfetch JSON profile +
// live /proc/meminfo / /proc/uptime / nvidia-smi + geo). Every accent is bound
// to Config.ThemeConfig.colors.* so the whole panel recolors with the live
// theme, and it deliberately uses ALL accent tokens (secondary/primary/success/
// warning/error/info/accent) rather than one.
//
// Shell mirrors ZaiUsageOverlay: transparent PanelWindow, dim backdrop, dim
// grid + corner brackets. Esc / click-outside closes. Decorations stay dim
// per the OLED burn-in policy.
// =============================================================================

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

PanelWindow {
    id: root

    property bool shown: false
    property string clockText: "--:--:--"

    visible: false
    function open() {
        visible = true
        shown = true
        Services.SystemInfoService.active = true
        Services.SystemInfoService.refresh()
        clockTimer.restart()
    }
    function close() {
        shown = false
        hideTimer.restart()
        Services.SystemInfoService.active = false
    }
    function toggle() { shown ? close() : open() }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    onShownChanged: if (!shown) hideTimer.restart()
    Timer { id: hideTimer; interval: 220; onTriggered: if (!root.shown) root.visible = false }

    // ---- theme palette (every accent token is used below) ----
    readonly property color cBg:        Config.ThemeConfig.colors.background
    readonly property color cText:      Config.ThemeConfig.colors.text
    readonly property color cDim:       Config.ThemeConfig.colors.textDim
    readonly property color cBorder:    Config.ThemeConfig.colors.border
    readonly property color cOutline:   Config.ThemeConfig.colors.outlineVariant
    readonly property color cSurface:   Config.ThemeConfig.colors.surfaceVariant
    readonly property color cSecondary: Config.ThemeConfig.colors.secondary   // hardware / radial / storage
    readonly property color cPrimary:   Config.ThemeConfig.colors.primary     // session / software
    readonly property color cSuccess:   Config.ThemeConfig.colors.success     // network / healthy
    readonly property color cWarn:      Config.ThemeConfig.colors.warning
    readonly property color cErr:       Config.ThemeConfig.colors.error
    readonly property color cInfo:      Config.ThemeConfig.colors.info
    readonly property color cAccent2:   Config.ThemeConfig.colors.accent      // power-draw highlight
    readonly property string fontM:     Config.BarConfig.fontFamily
    readonly property string fontN:     Config.BarConfig.fontNerd

    function diskColor(pct) { if (pct >= 90) return cErr; if (pct >= 75) return cWarn; return cSecondary }
    function tempColor(c)   { if (!c) return cDim; if (c >= 80) return cErr; if (c >= 60) return cWarn; return cSuccess }
    function swatchAt(i) {
        var a = [cSecondary, cPrimary, cSuccess, cWarn, cErr, cInfo, cAccent2]
        return a[i] || cBorder
    }
    function fmtNum(n) { return (n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",") }

    // =========================================================================
    // DIM BACKDROP (click-outside = close)
    // =========================================================================
    Rectangle {
        anchors.fill: parent
        color: root.cBg
        opacity: root.shown ? 0.55 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // =========================================================================
    // CENTERED CARD (900×680 — same as ZaiUsageOverlay / KeybindsOverlay)
    // =========================================================================
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 900
        height: 680
        color: root.cBg
        border.color: root.cBorder
        border.width: 1
        clip: true
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: root.close()
        MouseArea { anchors.fill: parent }   // swallow clicks so they don't close the overlay

        // ----- (decoration) dim grid background -----
        Item {
            anchors.fill: parent
            opacity: 0.22; z: 0
            Repeater {
                model: Math.floor(card.width / 40)
                Rectangle { width: 1; height: card.height; x: index * 40; color: root.cBorder }
            }
            Repeater {
                model: Math.floor(card.height / 40)
                Rectangle { height: 1; width: card.width; y: index * 40; color: root.cBorder }
            }
        }

        // ----- (decoration) corner brackets -----
        Repeater {
            model: 4
            Item {
                width: 14; height: 14; opacity: 0.55; z: 0
                x: (index === 0 || index === 2) ? 0 : (card.width - 14)
                y: (index === 0 || index === 1) ? 0 : (card.height - 14)
                property bool isRight: (index === 1 || index === 3)
                property bool isBottom: (index === 2 || index === 3)
                Rectangle { width: 14; height: 2; color: root.cSecondary; y: parent.isBottom ? 12 : 0 }
                Rectangle { width: 2; height: 14; color: root.cSecondary; x: parent.isRight ? 12 : 0 }
            }
        }

        // ----- CONTENT -----
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 12
            z: 10

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: Services.SystemInfoService.loading ? root.cWarn : root.cSecondary
                    Layout.alignment: Qt.AlignVCenter
                    SequentialAnimation on opacity {
                        running: root.shown; loops: Animation.Infinite
                        NumberAnimation { from: 0.4; to: 1; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: "󰻠"
                    color: root.cSecondary
                    font.family: root.fontN
                    font.pixelSize: 18
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "SYSTEM INFO"
                    color: root.cText
                    font.family: root.fontM
                    font.pixelSize: 18
                    font.bold: true
                    font.letterSpacing: 3
                    Layout.alignment: Qt.AlignVCenter
                }
                // live palette swatches (drawn from the active theme, not hard-coded)
                Row {
                    spacing: 4
                    Layout.leftMargin: 10
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: 7
                        Rectangle {
                            width: 9; height: 9; radius: 2
                            color: root.swatchAt(index)
                            border.color: root.cBorder; border.width: 1
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "HOST"
                        color: root.cDim
                        font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: (Services.SystemInfoService.userName || "—") + "@" + (Services.SystemInfoService.hostName || "—")
                        color: root.cSecondary
                        font.family: root.fontM; font.pixelSize: 11; font.bold: true
                    }
                }
                Text {
                    text: "ESC"
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: 9
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8
                }
            }

            // ---- sub-header telemetry strip ----
            Text {
                Layout.fillWidth: true
                text: "REAL-TIME  //  " +
                      (Services.SystemInfoService.osName || "—") + " " + (Services.SystemInfoService.osVersion || "") + "  //  " +
                      (Services.SystemInfoService.kernelName || "") + " " + (Services.SystemInfoService.kernelRelease || "")
                color: root.cDim
                font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

            // ---- card grid (scrollable if it ever overflows) ----
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
                    columns: 3
                    rowSpacing: 12
                    columnSpacing: 12

                    // ============================================================
                    // HARDWARE TELEMETRY  (colSpan 2)
                    // ============================================================
                    Rectangle {
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        Layout.preferredHeight: 209
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            spacing: 10

                            // card header
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
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

                            // body: CPU/GPU (left) + RAM radial (right)
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 20

                                // CPU + GPU
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 14

                                    // CPU
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Text { text: "CPU"; color: root.cDim; font.family: root.fontM; font.pixelSize: 10; font.letterSpacing: 1 }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Services.SystemInfoService.cpuModel
                                                color: root.cText
                                                font.family: root.fontM; font.pixelSize: 15; font.bold: true
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: (Services.SystemInfoService.cpuThreads || 0) + " Threads"
                                                color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                                font.family: root.fontM; font.pixelSize: 9
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Services.SystemInfoService.cpuMaxGhz > 0 ? Services.SystemInfoService.cpuMaxGhz.toFixed(2) + " GHz Max" : "—"
                                                color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                                font.family: root.fontM; font.pixelSize: 9
                                            }
                                        }
                                    }

                                    // GPU
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "GPU"; color: root.cDim; font.family: root.fontM; font.pixelSize: 10; font.letterSpacing: 1 }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Services.SystemInfoService.gpuName
                                                color: root.cText
                                                font.family: root.fontM; font.pixelSize: 15; font.bold: true
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: Services.SystemInfoService.gpuType || "—"
                                                color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.85)
                                                font.family: root.fontM; font.pixelSize: 9
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Services.SystemInfoService.gpuDriver || "—"
                                                color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.85)
                                                font.family: root.fontM; font.pixelSize: 9
                                            }
                                        }
                                    }

                                    // BOARD (motherboard model + parsed chipset)
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "BOARD"; color: root.cDim; font.family: root.fontM; font.pixelSize: 10; font.letterSpacing: 1 }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Services.SystemInfoService.boardName
                                                color: root.cText
                                                font.family: root.fontM; font.pixelSize: 14; font.bold: true
                                                elide: Text.ElideRight; Layout.maximumWidth: 300
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: Services.SystemInfoService.boardVendor
                                                color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                                font.family: root.fontM; font.pixelSize: 9
                                                visible: Services.SystemInfoService.boardVendor !== "—" && Services.SystemInfoService.boardVendor.length > 0
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: "CHIPSET " + Services.SystemInfoService.chipset
                                                color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                                font.family: root.fontM; font.pixelSize: 9; font.bold: true
                                                visible: Services.SystemInfoService.chipset !== "—" && Services.SystemInfoService.chipset.length > 0
                                            }
                                        }
                                    }
                                    Item { Layout.fillHeight: true }
                                }

                                // RAM radial
                                RowLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 14

                                    Item {
                                        width: 116; height: 116
                                        Layout.alignment: Qt.AlignVCenter
                                        Canvas {
                                            id: ramRadial
                                            anchors.fill: parent
                                            property real pct: Services.SystemInfoService.memPct
                                            // build a CSS rgba string from a QML color (color.toString() is
                                            // unreliable for semi-alpha on Canvas strokeStyle)
                                            function rgba(c, a) {
                                                return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
                                            }
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.reset()
                                                ctx.clearRect(0, 0, width, height)
                                                var cx = width / 2, cy = height / 2
                                                var r = Math.min(width, height) / 2 - 9
                                                var start = -Math.PI / 2
                                                var frac = Math.min(100, Math.max(0, pct)) / 100
                                                var ac = root.cSecondary
                                                // glow (wide, faint) — only the filled portion
                                                ctx.strokeStyle = rgba(ac, 0.20)
                                                ctx.lineWidth = 13
                                                ctx.beginPath(); ctx.arc(cx, cy, r, start, start + Math.PI * 2 * frac); ctx.stroke()
                                                // track (full ring, dim accent — visible even on OLED-black)
                                                ctx.strokeStyle = rgba(ac, 0.12)
                                                ctx.lineWidth = 8
                                                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
                                                // value
                                                ctx.strokeStyle = rgba(ac, 1)
                                                ctx.lineWidth = 8
                                                ctx.beginPath(); ctx.arc(cx, cy, r, start, start + Math.PI * 2 * frac); ctx.stroke()
                                            }
                                            Connections { target: Services.SystemInfoService; function onMemPctChanged() { ramRadial.requestPaint() } }
                                            Connections { target: root; function onCSecondaryChanged() { ramRadial.requestPaint() } }
                                            Component.onCompleted: ramRadial.requestPaint()
                                        }
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 0
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: Math.round(Services.SystemInfoService.memPct) + "%"
                                                color: root.cText
                                                font.family: root.fontM; font.pixelSize: 22; font.bold: true
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
                                            text: Services.SystemInfoService.memUsedGiB.toFixed(2) + " GiB"
                                            color: root.cText
                                            font.family: root.fontM; font.pixelSize: 13; font.bold: true
                                        }
                                        Text {
                                            text: (Services.SystemInfoService.memTotalGiB > 0 ? Services.SystemInfoService.memTotalGiB.toFixed(2) + " GiB Total" : "—")
                                            color: root.cDim
                                            font.family: root.fontM; font.pixelSize: 10
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ============================================================
                    // SESSION  (uptime + OS age / install date)
                    // ============================================================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
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
                                    text: Services.SystemInfoService.uptimeStr
                                    color: root.cPrimary
                                    font.family: root.fontM; font.pixelSize: 26; font.bold: true
                                }
                                Item { Layout.preferredHeight: 4 }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 52
                                        color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.4)
                                        border.color: root.cOutline; border.width: 1
                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: 1
                                            Text { text: "OS AGE"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: (Services.SystemInfoService.osAgeDays || 0) + "d"; color: root.cText; font.family: root.fontM; font.pixelSize: 14; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 52
                                        color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.4)
                                        border.color: root.cOutline; border.width: 1
                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: 1
                                            Text { text: "INSTALLED"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: Services.SystemInfoService.installDate || "—"; color: root.cText; font.family: root.fontM; font.pixelSize: 12; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    // ============================================================
                    // STORAGE
                    // ============================================================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 168
                        clip: true   // variable disk count — never bleed into the next card
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle { width: 8; height: 8; radius: 2; color: root.cSecondary; Layout.alignment: Qt.AlignVCenter }
                                Text { text: "STORAGE"; color: root.cText; font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2 }
                                Item { Layout.fillWidth: true }
                                Text { text: (Services.SystemInfoService.disks ? Services.SystemInfoService.disks.length : 0) + " VOL"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9 }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Repeater {
                                    model: Services.SystemInfoService.disks
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

                    // ============================================================
                    // NETWORK
                    // ============================================================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 168
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    width: 8; height: 8; radius: 4; color: root.cSuccess; Layout.alignment: Qt.AlignVCenter
                                    SequentialAnimation on opacity {
                                        running: root.shown; loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                    }
                                }
                                Text { text: "NETWORK"; color: root.cText; font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2 }
                                Item { Layout.fillWidth: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                // Local IP
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 32
                                    color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.4)
                                    border.color: root.cOutline; border.width: 1
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 8
                                        Text { text: "LOCAL IP"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: Services.NetworkService.ipAddress || "—"; color: root.cSecondary; font.family: root.fontM; font.pixelSize: 11; font.bold: true }
                                    }
                                }
                                // SSID
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 32
                                    color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.4)
                                    border.color: root.cOutline; border.width: 1
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 8
                                        Text { text: Services.NetworkService.connectionType === "wifi" ? "SSID" : "LINK"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: Services.NetworkService.ssid || "—"; color: root.cText; font.family: root.fontM; font.pixelSize: 11; font.bold: true }
                                    }
                                }
                                // Geo
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 32
                                    color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.4)
                                    border.color: root.cOutline; border.width: 1
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 8
                                        Text { text: "GEO"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: Services.SystemInfoService.geoCity
                                                  ? Services.SystemInfoService.geoCity + (Services.SystemInfoService.geoCountry ? ", " + Services.SystemInfoService.geoCountry : "")
                                                  : "—"
                                            color: root.cPrimary; font.family: root.fontM; font.pixelSize: 11; font.bold: true
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    // ============================================================
                    // HEALTH  (GPU temp / power, tier-colored)
                    // ============================================================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 168
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle { width: 8; height: 8; radius: 2; color: root.cSuccess; Layout.alignment: Qt.AlignVCenter }
                                Text { text: "HEALTH"; color: root.cText; font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2 }
                                Item { Layout.fillWidth: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                            // GPU temp
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "GPU TEMP"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1 }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: Services.SystemInfoService.gpuTempC ? Services.SystemInfoService.gpuTempC + "°C" : "—"
                                        color: root.tempColor(Services.SystemInfoService.gpuTempC)
                                        font.family: root.fontM; font.pixelSize: 11; font.bold: true
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true; Layout.preferredHeight: 4
                                    Rectangle { anchors.fill: parent; color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.7) }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: root.tempColor(Services.SystemInfoService.gpuTempC)
                                        opacity: Services.SystemInfoService.gpuTempC ? Math.min(1, Services.SystemInfoService.gpuTempC / 100) : 0
                                        Behavior on opacity { NumberAnimation { duration: 300 } }
                                    }
                                }
                            }

                            // GPU power
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "GPU POWER"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1 }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: Services.SystemInfoService.gpuPowerW > 0 ? Services.SystemInfoService.gpuPowerW.toFixed(1) + " W" : "—"
                                        color: root.cSecondary
                                        font.family: root.fontM; font.pixelSize: 11; font.bold: true
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true; Layout.preferredHeight: 4
                                    Rectangle { anchors.fill: parent; color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.7) }
                                    Rectangle {
                                        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
                                        width: parent.width * Math.min(Services.SystemInfoService.gpuPowerW / 450, 1)
                                        color: root.cSecondary
                                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }

                            // footer: utilization
                            RowLayout {
                                Layout.fillWidth: true
                                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.5) }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "GPU UTIL"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Services.SystemInfoService.gpuUsagePct + "%"
                                    color: root.cAccent2
                                    font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                }
                            }
                        }
                    }

                    // ============================================================
                    // SOFTWARE & OS  (full width)
                    // ============================================================
                    Rectangle {
                        Layout.columnSpan: 3
                        Layout.fillWidth: true
                        Layout.preferredHeight: 118
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle { width: 8; height: 8; radius: 2; color: root.cPrimary; Layout.alignment: Qt.AlignVCenter }
                                Text { text: "SOFTWARE & OS"; color: root.cText; font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2 }
                                Item { Layout.fillWidth: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 24

                                // OS
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Rectangle { width: 16; height: 2; color: root.cPrimary; Layout.alignment: Qt.AlignLeft }
                                    Text { text: "OPERATING SYSTEM"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                    Text {
                                        text: (Services.SystemInfoService.osName || "—") + (Services.SystemInfoService.osVersion ? " " + Services.SystemInfoService.osVersion : "")
                                        color: root.cPrimary; font.family: root.fontM; font.pixelSize: 15; font.bold: true
                                    }
                                    Text {
                                        text: Services.SystemInfoService.osCodename ? "(" + Services.SystemInfoService.osCodename + ") " + (Services.SystemInfoService.arch || "") : (Services.SystemInfoService.arch || "")
                                        color: root.cDim; font.family: root.fontM; font.pixelSize: 9; font.italic: true
                                    }
                                }
                                // Kernel
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Rectangle { width: 16; height: 2; color: root.cSecondary; Layout.alignment: Qt.AlignLeft }
                                    Text { text: "KERNEL"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                    Text {
                                        text: (Services.SystemInfoService.kernelName || "—") + " " + (Services.SystemInfoService.kernelRelease || "")
                                        color: root.cText; font.family: root.fontM; font.pixelSize: 15; font.bold: true
                                    }
                                    Text { text: Services.SystemInfoService.arch || ""; color: root.cDim; font.family: root.fontM; font.pixelSize: 9 }
                                }
                                // Packages
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Rectangle { width: 16; height: 2; color: root.cSuccess; Layout.alignment: Qt.AlignLeft }
                                    Text { text: "PACKAGES"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                    Text {
                                        text: root.fmtNum(Services.SystemInfoService.pkgAll) + " Total"
                                        color: root.cSuccess; font.family: root.fontM; font.pixelSize: 15; font.bold: true
                                    }
                                    Text {
                                        text: (Services.SystemInfoService.pkgSystem || 0) + " sys / " + (Services.SystemInfoService.pkgUser || 0) + " user"
                                        color: root.cDim; font.family: root.fontM; font.pixelSize: 9
                                    }
                                }
                                // Shell
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Rectangle { width: 16; height: 2; color: root.cAccent2; Layout.alignment: Qt.AlignLeft }
                                    Text { text: "SHELL"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                                    Text {
                                        text: Services.SystemInfoService.shellName || "—"
                                        color: root.cAccent2; font.family: root.fontM; font.pixelSize: 15; font.bold: true
                                    }
                                    Text { text: "Quickshell"; color: root.cDim; font.family: root.fontM; font.pixelSize: 9 }
                                }
                            }
                        }
                    }
                }
            }

            // ---- footer ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                opacity: 0.7
                RowLayout {
                    spacing: 6
                    Rectangle { width: 6; height: 6; radius: 3; color: root.cSuccess; Layout.alignment: Qt.AlignVCenter }
                    Text { text: "KERNEL OK"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                }
                RowLayout {
                    spacing: 6
                    Rectangle { width: 6; height: 6; radius: 3; color: root.cSuccess; Layout.alignment: Qt.AlignVCenter }
                    Text { text: "DAEMONS ACTIVE"; color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "[ " + (Services.SystemInfoService.hostName || "host") + " ]"
                    color: root.cDim; font.family: root.fontM; font.pixelSize: 9
                }
                Text {
                    text: root.clockText
                    color: root.cSecondary; font.family: root.fontM; font.pixelSize: 9; font.bold: true
                }
            }
        }
    }

    // ---- live clock (1s, runs only while shown) ----
    Timer {
        id: clockTimer
        interval: 1000
        repeat: true
        running: root.shown
        onTriggered: {
            var d = new Date()
            var hh = d.getHours(); if (hh < 10) hh = "0" + hh
            var mm = d.getMinutes(); if (mm < 10) mm = "0" + mm
            var ss = d.getSeconds(); if (ss < 10) ss = "0" + ss
            root.clockText = hh + ":" + mm + ":" + ss
        }
        triggeredOnStart: true
    }
}
