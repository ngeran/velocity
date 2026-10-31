// =============================================================================
// FastfetchOverlay.qml — SYSTEM INFO telemetry dashboard
// =============================================================================
// Opened from the Arch logo in the bar. Rebuilt from a plain fastfetch text
// dump into a structured dashboard matching the NixOS System Info reference:
// a size-clamped card (≤900×≤680, like ZaiUsageOverlay) with a grid of themed cards —
// Hardware (CPU/GPU + RAM radial), Session, Storage, Network, Health, and a
// full-width Software & OS strip.
//
// All data comes from Services.MetricsService (fastfetch JSON profile +
// live metrics engine (lease-gated) + geo). Every accent is bound
// to Config.ThemeConfig.colors.* so the whole panel recolors with the live
// theme, and it deliberately uses ALL accent tokens (secondary/primary/success/
// warning/error/info/accent) rather than one.
//
// Shell mirrors ZaiUsageOverlay: transparent PanelWindow, dim backdrop, dim
// dim grid. Esc / click-outside closes. Decorations stay dim
// per the OLED burn-in policy.
// =============================================================================

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import bar.config as Config
import bar.services as Services

// Shared overlay chrome (DU11): backdrop/Esc/card/timer live in OverlayShell
// (backdropDim keeps this overlay's slightly stronger 0.55; the old hardcoded
// 200ms fades become the MotionConfig tokens). This file contributes the
// system-info interior + the probe side effects.
OverlayShell {
    id: root

    backdropDim: 0.55

    property string clockText: "--:--:--"

    onAboutToOpen: {
        Services.MetricsService.active = true
        Services.MetricsService.refresh()
        clockTimer.restart()
    }
    onDismissed: Services.MetricsService.active = false

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

    // (backdrop + centered card shell are OverlayShell's — backdropDim 0.55.)

    // =========================================================================
    // CARD INTERIOR

        // ----- (decoration) dim grid background -----
        Item {
            anchors.fill: parent
            opacity: 0.22; z: 0
            Repeater {
                model: Math.floor(root.cardItem.width / Config.PopupMetrics.px(40))
                Rectangle { width: Config.PopupMetrics.hairline(parent); height: root.cardItem.height; x: index * Config.PopupMetrics.px(40); color: root.cBorder }
            }
            Repeater {
                model: Math.floor(root.cardItem.height / Config.PopupMetrics.px(40))
                Rectangle { height: Config.PopupMetrics.hairline(parent); width: root.cardItem.width; y: index * Config.PopupMetrics.px(40); color: root.cBorder }
            }
        }

        // ----- CONTENT -----
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.PopupMetrics.px(30)
            spacing: Config.PopupMetrics.px(12)
            z: 10

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.PopupMetrics.px(10)
                Rectangle {
                    width: Config.PopupMetrics.px(10); height: Config.PopupMetrics.px(10); radius: Config.PopupMetrics.px(5)
                    color: Services.MetricsService.loading ? root.cWarn : root.cSecondary
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
                    font.pixelSize: Config.PopupMetrics.px(18)
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "SYSTEM INFO"
                    color: root.cText
                    font.family: root.fontM
                    font.pixelSize: Config.PopupMetrics.px(18)
                    font.bold: true
                    font.letterSpacing: 3
                    Layout.alignment: Qt.AlignVCenter
                }
                // live palette swatches (drawn from the active theme, not hard-coded)
                Row {
                    spacing: Config.PopupMetrics.px(4)
                    Layout.leftMargin: Config.PopupMetrics.px(10)
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: 7
                        Rectangle {
                            width: Config.PopupMetrics.px(9); height: Config.PopupMetrics.px(9); radius: Config.PopupMetrics.px(2)
                            color: root.swatchAt(index)
                            border.color: root.cBorder; border.width: Config.PopupMetrics.hairline(parent)
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Config.PopupMetrics.px(1)
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "HOST"
                        color: root.cDim
                        font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.letterSpacing: 1
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: (Services.MetricsService.userName || "—") + "@" + (Services.MetricsService.hostName || "—")
                        color: root.cSecondary
                        font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true
                    }
                }
                Text {
                    text: "ESC"
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9)
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: Config.PopupMetrics.px(8)
                }
            }

            // ---- sub-header telemetry strip ----
            Text {
                Layout.fillWidth: true
                text: "REAL-TIME  //  " +
                      (Services.MetricsService.osName || "—") + " " + (Services.MetricsService.osVersion || "") + "  //  " +
                      (Services.MetricsService.kernelName || "") + " " + (Services.MetricsService.kernelRelease || "")
                color: root.cDim
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.letterSpacing: 1
            }
            Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: root.cBorder }

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
                    rowSpacing: Config.PopupMetrics.px(12)
                    columnSpacing: Config.PopupMetrics.px(12)

                    // ============================================================
                    // HARDWARE TELEMETRY  (colSpan 2)
                    // ============================================================
                    Rectangle {
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        Layout.preferredHeight: Config.PopupMetrics.px(209)
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: Config.PopupMetrics.hairline(parent)

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: Config.PopupMetrics.px(16)
                            spacing: Config.PopupMetrics.px(10)

                            // card header
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Config.PopupMetrics.px(8)
                                Rectangle { width: Config.PopupMetrics.px(8); height: Config.PopupMetrics.px(8); radius: Config.PopupMetrics.px(2); color: root.cSecondary; Layout.alignment: Qt.AlignVCenter }
                                Text {
                                    text: "HARDWARE TELEMETRY"
                                    color: root.cText
                                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true; font.letterSpacing: 2
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: badge.implicitWidth + Config.PopupMetrics.px(12); height: Config.PopupMetrics.px(16)
                                    color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.12)
                                    border.color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.35); border.width: Config.PopupMetrics.hairline(parent)
                                    Text {
                                        id: badge
                                        anchors.centerIn: parent
                                        text: "REAL-TIME"
                                        color: root.cSecondary
                                        font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.bold: true; font.letterSpacing: 1
                                    }
                                }
                            }
                            Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: root.cBorder }

                            // body: CPU/GPU (left) + RAM radial (right)
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: Config.PopupMetrics.px(20)

                                // CPU + GPU
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: Config.PopupMetrics.px(14)

                                    // CPU
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Config.PopupMetrics.px(2)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Config.PopupMetrics.px(6)
                                            Text { text: "CPU"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(10); font.letterSpacing: 1 }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Services.MetricsService.cpuModel
                                                color: root.cText
                                                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(15); font.bold: true
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: (Services.MetricsService.cpuThreads || 0) + " Threads"
                                                color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9)
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Services.MetricsService.cpuMaxGhz > 0 ? Services.MetricsService.cpuMaxGhz.toFixed(2) + " GHz Max" : "—"
                                                color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9)
                                            }
                                        }
                                    }

                                    // GPU
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Config.PopupMetrics.px(2)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "GPU"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(10); font.letterSpacing: 1 }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Services.MetricsService.gpuName
                                                color: root.cText
                                                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(15); font.bold: true
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: Services.MetricsService.gpuType || "—"
                                                color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.85)
                                                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9)
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Services.MetricsService.gpuDriver || "—"
                                                color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.85)
                                                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9)
                                            }
                                        }
                                    }

                                    // BOARD (motherboard model + parsed chipset)
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Config.PopupMetrics.px(2)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "BOARD"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(10); font.letterSpacing: 1 }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Services.MetricsService.boardName
                                                color: root.cText
                                                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(14); font.bold: true
                                                elide: Text.ElideRight; Layout.maximumWidth: Config.PopupMetrics.px(300)
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: Services.MetricsService.boardVendor
                                                color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9)
                                                visible: Services.MetricsService.boardVendor !== "—" && Services.MetricsService.boardVendor.length > 0
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: "CHIPSET " + Services.MetricsService.chipset
                                                color: Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.8)
                                                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                                                visible: Services.MetricsService.chipset !== "—" && Services.MetricsService.chipset.length > 0
                                            }
                                        }
                                    }
                                    Item { Layout.fillHeight: true }
                                }

                                // RAM radial
                                RowLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: Config.PopupMetrics.px(14)

                                    Item {
                                        width: Config.PopupMetrics.px(116); height: Config.PopupMetrics.px(116)
                                        Layout.alignment: Qt.AlignVCenter
                                        Canvas {
                                            id: ramRadial
                                            anchors.fill: parent
                                            property real pct: Services.MetricsService.memPct
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
                                            Connections { target: Services.MetricsService; function onMemPctChanged() { ramRadial.requestPaint() } }
                                            Connections { target: root; function onCSecondaryChanged() { ramRadial.requestPaint() } }
                                            Component.onCompleted: ramRadial.requestPaint()
                                        }
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 0
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: Math.round(Services.MetricsService.memPct) + "%"
                                                color: root.cText
                                                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(22); font.bold: true
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: "RAM"
                                                color: root.cDim
                                                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: Config.PopupMetrics.px(2)
                                        Text {
                                            text: Services.MetricsService.memUsedGiB.toFixed(2) + " GiB"
                                            color: root.cText
                                            font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(13); font.bold: true
                                        }
                                        Text {
                                            text: (Services.MetricsService.memTotalGiB > 0 ? Services.MetricsService.memTotalGiB.toFixed(2) + " GiB Total" : "—")
                                            color: root.cDim
                                            font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(10)
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
                        border.color: root.cBorder; border.width: Config.PopupMetrics.hairline(parent)

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: Config.PopupMetrics.px(16)
                            spacing: Config.PopupMetrics.px(10)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Config.PopupMetrics.px(8)
                                Rectangle { width: Config.PopupMetrics.px(8); height: Config.PopupMetrics.px(8); radius: Config.PopupMetrics.px(2); color: root.cPrimary; Layout.alignment: Qt.AlignVCenter }
                                Text {
                                    text: "SESSION"
                                    color: root.cText
                                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true; font.letterSpacing: 2
                                }
                                Item { Layout.fillWidth: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: root.cBorder }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                spacing: Config.PopupMetrics.px(2)
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "UPTIME"
                                    color: root.cDim
                                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.letterSpacing: 1
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Services.MetricsService.uptimeStr
                                    color: root.cPrimary
                                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(26); font.bold: true
                                }
                                Item { Layout.preferredHeight: Config.PopupMetrics.px(4) }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.PopupMetrics.px(8)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Config.PopupMetrics.px(52)
                                        color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.4)
                                        border.color: root.cOutline; border.width: Config.PopupMetrics.hairline(parent)
                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: Config.PopupMetrics.px(1)
                                            Text { text: "OS AGE"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: (Services.MetricsService.osAgeDays || 0) + "d"; color: root.cText; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(14); font.bold: true; Layout.alignment: Qt.AlignHCenter }
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Config.PopupMetrics.px(52)
                                        color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.4)
                                        border.color: root.cOutline; border.width: Config.PopupMetrics.hairline(parent)
                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: Config.PopupMetrics.px(1)
                                            Text { text: "INSTALLED"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: Services.MetricsService.installDate || "—"; color: root.cText; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(12); font.bold: true; Layout.alignment: Qt.AlignHCenter }
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
                        Layout.preferredHeight: Config.PopupMetrics.px(168)
                        clip: true   // variable disk count — never bleed into the next card
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: Config.PopupMetrics.hairline(parent)

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: Config.PopupMetrics.px(16)
                            spacing: Config.PopupMetrics.px(10)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Config.PopupMetrics.px(8)
                                Rectangle { width: Config.PopupMetrics.px(8); height: Config.PopupMetrics.px(8); radius: Config.PopupMetrics.px(2); color: root.cSecondary; Layout.alignment: Qt.AlignVCenter }
                                Text { text: "STORAGE"; color: root.cText; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true; font.letterSpacing: 2 }
                                Item { Layout.fillWidth: true }
                                Text { text: (Services.MetricsService.profileDisks ? Services.MetricsService.profileDisks.length : 0) + " VOL"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9) }
                            }
                            Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: root.cBorder }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Config.PopupMetrics.px(8)
                                Repeater {
                                    model: Services.MetricsService.profileDisks
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Config.PopupMetrics.px(3)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: modelData.dev; color: root.cText; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(10); font.bold: true }
                                            Item { Layout.fillWidth: true }
                                            Text { text: modelData.usedLabel + " / " + modelData.totalLabel; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9) }
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Config.PopupMetrics.px(5)
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
                        Layout.preferredHeight: Config.PopupMetrics.px(168)
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: Config.PopupMetrics.hairline(parent)

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: Config.PopupMetrics.px(16)
                            spacing: Config.PopupMetrics.px(8)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Config.PopupMetrics.px(8)
                                Rectangle {
                                    width: Config.PopupMetrics.px(8); height: Config.PopupMetrics.px(8); radius: Config.PopupMetrics.px(4); color: root.cSuccess; Layout.alignment: Qt.AlignVCenter
                                    SequentialAnimation on opacity {
                                        running: root.shown; loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                    }
                                }
                                Text { text: "NETWORK"; color: root.cText; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true; font.letterSpacing: 2 }
                                Item { Layout.fillWidth: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: root.cBorder }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Config.PopupMetrics.px(6)
                                // Local IP
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: Config.PopupMetrics.px(32)
                                    color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.4)
                                    border.color: root.cOutline; border.width: Config.PopupMetrics.hairline(parent)
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: Config.PopupMetrics.px(8)
                                        Text { text: "LOCAL IP"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: Services.NetworkService.ipAddress || "—"; color: root.cSecondary; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true }
                                    }
                                }
                                // SSID
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: Config.PopupMetrics.px(32)
                                    color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.4)
                                    border.color: root.cOutline; border.width: Config.PopupMetrics.hairline(parent)
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: Config.PopupMetrics.px(8)
                                        Text { text: Services.NetworkService.connectionType === "wifi" ? "SSID" : "LINK"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: Services.NetworkService.ssid || "—"; color: root.cText; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true }
                                    }
                                }
                                // Geo
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: Config.PopupMetrics.px(32)
                                    color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.4)
                                    border.color: root.cOutline; border.width: Config.PopupMetrics.hairline(parent)
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: Config.PopupMetrics.px(8)
                                        Text { text: "GEO"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1 }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: Services.MetricsService.geoCity
                                                  ? Services.MetricsService.geoCity + (Services.MetricsService.geoCountry ? ", " + Services.MetricsService.geoCountry : "")
                                                  : "—"
                                            color: root.cPrimary; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true
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
                        Layout.preferredHeight: Config.PopupMetrics.px(168)
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: Config.PopupMetrics.hairline(parent)

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: Config.PopupMetrics.px(16)
                            spacing: Config.PopupMetrics.px(10)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Config.PopupMetrics.px(8)
                                Rectangle { width: Config.PopupMetrics.px(8); height: Config.PopupMetrics.px(8); radius: Config.PopupMetrics.px(2); color: root.cSuccess; Layout.alignment: Qt.AlignVCenter }
                                Text { text: "HEALTH"; color: root.cText; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true; font.letterSpacing: 2 }
                                Item { Layout.fillWidth: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: root.cBorder }

                            // GPU temp
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Config.PopupMetrics.px(3)
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "GPU TEMP"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.letterSpacing: 1 }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: Services.MetricsService.gpuTempC ? Services.MetricsService.gpuTempC + "°C" : "—"
                                        color: root.tempColor(Services.MetricsService.gpuTempC)
                                        font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true; Layout.preferredHeight: Config.PopupMetrics.px(4)
                                    Rectangle { anchors.fill: parent; color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.7) }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: root.tempColor(Services.MetricsService.gpuTempC)
                                        opacity: Services.MetricsService.gpuTempC ? Math.min(1, Services.MetricsService.gpuTempC / 100) : 0
                                        Behavior on opacity { NumberAnimation { duration: 300 } }
                                    }
                                }
                            }

                            // GPU power
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Config.PopupMetrics.px(3)
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "GPU POWER"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.letterSpacing: 1 }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: Services.MetricsService.gpuPowerW > 0 ? Services.MetricsService.gpuPowerW.toFixed(1) + " W" : "—"
                                        color: root.cSecondary
                                        font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true; Layout.preferredHeight: Config.PopupMetrics.px(4)
                                    Rectangle { anchors.fill: parent; color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.7) }
                                    Rectangle {
                                        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
                                        width: parent.width * Math.min(Services.MetricsService.gpuPowerW / 450, 1)
                                        color: root.cSecondary
                                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }

                            // footer: utilization
                            RowLayout {
                                Layout.fillWidth: true
                                Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.5) }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "GPU UTIL"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1 }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Services.MetricsService.gpuUsagePct + "%"
                                    color: root.cAccent2
                                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(10); font.bold: true
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
                        Layout.preferredHeight: Config.PopupMetrics.px(118)
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder; border.width: Config.PopupMetrics.hairline(parent)

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: Config.PopupMetrics.px(16)
                            spacing: Config.PopupMetrics.px(10)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Config.PopupMetrics.px(8)
                                Rectangle { width: Config.PopupMetrics.px(8); height: Config.PopupMetrics.px(8); radius: Config.PopupMetrics.px(2); color: root.cPrimary; Layout.alignment: Qt.AlignVCenter }
                                Text { text: "SOFTWARE & OS"; color: root.cText; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true; font.letterSpacing: 2 }
                                Item { Layout.fillWidth: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: root.cBorder }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: Config.PopupMetrics.px(24)

                                // OS
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.PopupMetrics.px(1)
                                    Rectangle { width: Config.PopupMetrics.px(16); height: Config.PopupMetrics.px(2); color: root.cPrimary; Layout.alignment: Qt.AlignLeft }
                                    Text { text: "OPERATING SYSTEM"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1 }
                                    Text {
                                        text: (Services.MetricsService.osName || "—") + (Services.MetricsService.osVersion ? " " + Services.MetricsService.osVersion : "")
                                        color: root.cPrimary; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(15); font.bold: true
                                    }
                                    Text {
                                        text: Services.MetricsService.osCodename ? "(" + Services.MetricsService.osCodename + ") " + (Services.MetricsService.arch || "") : (Services.MetricsService.arch || "")
                                        color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.italic: true
                                    }
                                }
                                // Kernel
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.PopupMetrics.px(1)
                                    Rectangle { width: Config.PopupMetrics.px(16); height: Config.PopupMetrics.px(2); color: root.cSecondary; Layout.alignment: Qt.AlignLeft }
                                    Text { text: "KERNEL"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1 }
                                    Text {
                                        text: (Services.MetricsService.kernelName || "—") + " " + (Services.MetricsService.kernelRelease || "")
                                        color: root.cText; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(15); font.bold: true
                                    }
                                    Text { text: Services.MetricsService.arch || ""; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9) }
                                }
                                // Packages
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.PopupMetrics.px(1)
                                    Rectangle { width: Config.PopupMetrics.px(16); height: Config.PopupMetrics.px(2); color: root.cSuccess; Layout.alignment: Qt.AlignLeft }
                                    Text { text: "PACKAGES"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1 }
                                    Text {
                                        text: root.fmtNum(Services.MetricsService.pkgAll) + " Total"
                                        color: root.cSuccess; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(15); font.bold: true
                                    }
                                    Text {
                                        text: (Services.MetricsService.pkgSystem || 0) + " sys / " + (Services.MetricsService.pkgUser || 0) + " user"
                                        color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9)
                                    }
                                }
                                // Shell
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.PopupMetrics.px(1)
                                    Rectangle { width: Config.PopupMetrics.px(16); height: Config.PopupMetrics.px(2); color: root.cAccent2; Layout.alignment: Qt.AlignLeft }
                                    Text { text: "SHELL"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1 }
                                    Text {
                                        text: Services.MetricsService.shellName || "—"
                                        color: root.cAccent2; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(15); font.bold: true
                                    }
                                    Text { text: "Quickshell"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9) }
                                }
                            }
                        }
                    }
                }
            }

            // ---- footer ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.PopupMetrics.px(16)
                opacity: 0.7
                RowLayout {
                    spacing: Config.PopupMetrics.px(6)
                    Rectangle { width: Config.PopupMetrics.px(6); height: Config.PopupMetrics.px(6); radius: Config.PopupMetrics.px(3); color: root.cSuccess; Layout.alignment: Qt.AlignVCenter }
                    Text { text: "KERNEL OK"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1 }
                }
                RowLayout {
                    spacing: Config.PopupMetrics.px(6)
                    Rectangle { width: Config.PopupMetrics.px(6); height: Config.PopupMetrics.px(6); radius: Config.PopupMetrics.px(3); color: root.cSuccess; Layout.alignment: Qt.AlignVCenter }
                    Text { text: "DAEMONS ACTIVE"; color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "[ " + (Services.MetricsService.hostName || "host") + " ]"
                    color: root.cDim; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9)
                }
                Text {
                    text: root.clockText
                    color: root.cSecondary; font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
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
