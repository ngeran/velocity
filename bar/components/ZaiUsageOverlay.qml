// =============================================================================
// ZaiUsageOverlay.qml — HUD-style Z.ai usage analytics panel
// =============================================================================
// A 900×680 overlay that mirrors KeybindsOverlay's shell (full-screen
// transparent PanelWindow, dim backdrop, centered card, Esc / click-outside,
// shown/visible + 220ms hide timer). Toggled via IPC:
//   quickshell ipc -c bar call zaiUsage toggle    (bound to SUPER+Z)
//
// CONTENT is the provided HUD reference, re-tinted by the LIVE theme
// (Config.ThemeConfig.colors.*) so it recolors with the rest of the shell:
//   - grid background (Repeater of thin lines), 8 corner brackets
//   - a scanline that sweeps while shown (paused when hidden — CPU + burn-in)
//   - a metric grid of segmented quota gauges (one per Z.ai window)
//   - a token-total figure + a Canvas sparkline of the 5h session %
// All static decorations stay dim (≤0.4 opacity) per the OLED burn-in policy.
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
    visible: false
    function open()  { visible = true; shown = true; if (!Services.ZaiUsageService.loading) Services.ZaiUsageService.refresh() }
    function close() { shown = false; hideTimer.restart() }
    function toggle() { shown ? close() : open() }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    onShownChanged: if (!shown) hideTimer.restart()
    Timer { id: hideTimer; interval: 220; onTriggered: if (!root.shown) root.visible = false }

    // ---- theme-tinted HUD palette (live — recolors with ThemeConfig) ----
    readonly property color cBg:     Config.ThemeConfig.colors.background
    readonly property color cText:   Config.ThemeConfig.colors.text
    readonly property color cDim:    Config.ThemeConfig.colors.textDim
    readonly property color cBorder: Config.ThemeConfig.colors.border
    readonly property color cSurface:Config.ThemeConfig.colors.surfaceVariant
    readonly property color cAccent: Config.ThemeConfig.colors.secondary   // nominal HUD glow
    readonly property color cWarn:   Config.ThemeConfig.colors.warning
    readonly property color cCrit:   Config.ThemeConfig.colors.error
    readonly property string fontM:  Config.BarConfig.fontFamily
    readonly property string fontN:  Config.BarConfig.fontNerd

    function tierColor(tier) {
        if (tier >= 2) return root.cCrit
        if (tier === 1) return root.cWarn
        return root.cAccent
    }
    function formatTokens(n) {
        var v = Math.max(0, Math.round(n || 0))
        return v.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }

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
    // CENTERED CARD (900×680 — same as KeybindsOverlay)
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

        // ----- (decoration) grid background — dim, behind everything -----
        Item {
            id: gridBg
            anchors.fill: parent
            opacity: 0.22
            z: 0
            Repeater {
                model: Math.floor(card.width / 40)
                Rectangle { width: 1; height: card.height; x: index * 40; color: root.cBorder }
            }
            Repeater {
                model: Math.floor(card.height / 40)
                Rectangle { height: 1; width: card.width; y: index * 40; color: root.cBorder }
            }
        }

        // ----- (decoration) corner brackets (4 corners × H+V arms) -----
        // Positioned by x/y only (no anchors) — avoids conditional-anchor quirks.
        Repeater {
            model: 4   // 0=TL 1=TR 2=BL 3=BR
            Item {
                width: 14; height: 14
                opacity: 0.55
                z: 0
                x: (index === 0 || index === 2) ? 0 : (card.width - 14)
                y: (index === 0 || index === 1) ? 0 : (card.height - 14)
                property bool isRight: (index === 1 || index === 3)
                property bool isBottom: (index === 2 || index === 3)
                Rectangle {   // horizontal arm
                    width: 14; height: 2; color: root.cAccent
                    y: parent.isBottom ? 12 : 0
                }
                Rectangle {   // vertical arm
                    width: 2; height: 14; color: root.cAccent
                    x: parent.isRight ? 12 : 0
                }
            }
        }

        // ----- (decoration) scanline — bright but MOVING, paused when hidden -----
        Rectangle {
            id: scanline
            width: card.width
            height: 3
            x: 0
            y: 0
            z: 1
            visible: root.shown
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0) }
                GradientStop { position: 0.5; color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.22) }
                GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0) }
            }
            NumberAnimation on y {
                from: 0; to: card.height; duration: 4200
                loops: Animation.Infinite; running: root.shown
            }
        }

        // ----- CONTENT -----
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 14
            z: 10

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    width: 10; height: 10; color: Services.ZaiUsageService.hasError ? root.cCrit : root.cAccent
                    Layout.alignment: Qt.AlignVCenter
                    SequentialAnimation on opacity {
                        running: root.shown; loops: Animation.Infinite
                        NumberAnimation { from: 0.35; to: 1; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1; to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: "USAGE ANALYTICS"
                    color: root.cText
                    font.family: root.fontM
                    font.pixelSize: 20
                    font.bold: true
                    font.letterSpacing: 3
                    Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "ACTIVE CONNECTION"
                        color: root.cDim
                        font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "Z.AI // GLM CODING"
                        color: root.cAccent
                        font.family: root.fontM; font.pixelSize: 12; font.bold: true
                    }
                }
                Text {
                    text: "󰬃"
                    color: root.cAccent
                    font.family: root.fontN
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignVCenter
                    RotationAnimation on rotation { from: 0; to: 360; duration: 3000; loops: Animation.Infinite; running: root.shown }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "GLOBAL TELEMETRY // PLAN " + Services.ZaiUsageService.level + "  //  LAST SYNC  " + (Services.ZaiUsageService.lastUpdated || "—")
                color: root.cDim
                font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

            // ---- error state ----
            Text {
                visible: Services.ZaiUsageService.hasError
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 40
                text: Services.ZaiUsageService.errorMessage
                color: root.cCrit
                font.family: root.fontM; font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // ---- metric grid (one gauge per Z.ai window) ----
            GridLayout {
                visible: !Services.ZaiUsageService.hasError
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 12
                columnSpacing: 12

                Repeater {
                    model: Services.ZaiUsageService.windows
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 178
                        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
                        border.color: root.cBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "L-0" + (index + 1) + "  //  " + modelData.label
                                    color: root.tierColor(modelData.tier)
                                    font.family: root.fontM; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "[" + modelData.statusWord + "]"
                                    color: root.tierColor(modelData.tier)
                                    font.family: root.fontM; font.pixelSize: 9; font.bold: true
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: modelData.pct.toFixed(1) + "%"
                                    color: root.tierColor(modelData.tier)
                                    font.family: root.fontM; font.pixelSize: 34; font.bold: true
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "USED"
                                    color: root.cDim
                                    font.family: root.fontM; font.pixelSize: 9
                                    Layout.alignment: Qt.AlignBottom
                                }
                            }

                            // segmented bar: track + tier fill + 10 dividers
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 14
                                Rectangle {   // track
                                    anchors.fill: parent
                                    color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.04)
                                    border.color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.6)
                                    border.width: 1
                                }
                                Rectangle {   // fill (animated, tier-colored — not a static bright block)
                                    anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
                                    width: parent.width * Math.min(modelData.pct, 100) / 100
                                    color: root.tierColor(modelData.tier)
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                Repeater {   // 9 segment dividers (=> 10 segments)
                                    model: 9
                                    Rectangle {
                                        width: 1; height: parent.height
                                        x: parent.width * (index + 1) / 10
                                        color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.5)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "RESET: " + modelData.resetLabel
                                    color: root.cDim
                                    font.family: root.fontM; font.pixelSize: 8
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: (modelData.remaining != null) ? (root.formatTokens(modelData.remaining) + " LEFT") : "—"
                                    color: root.cDim
                                    font.family: root.fontM; font.pixelSize: 8
                                }
                            }
                        }
                    }
                }
            }

            // ---- token total + sparkline ----
            Rectangle {
                visible: !Services.ZaiUsageService.hasError
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.30)
                border.color: root.cBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 24

                    // peak window — the HUD headline figure
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2
                        RowLayout {
                            spacing: 8
                            Rectangle { width: 28; height: 12; color: root.tierColor(Services.ZaiUsageService.peakTier); Layout.alignment: Qt.AlignVCenter }
                            Text {
                                text: "PEAK USAGE"
                                color: root.cAccent
                                font.family: root.fontM; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                            }
                        }
                        Text {
                            text: Math.round(Services.ZaiUsageService.peakPct) + "%"
                            color: root.tierColor(Services.ZaiUsageService.peakTier)
                            font.family: root.fontM; font.pixelSize: 40; font.bold: true
                        }
                        Text {
                            text: Services.ZaiUsageService.peakLabel + " WINDOW"
                            color: root.cDim
                            font.family: root.fontM; font.pixelSize: 9
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // live sparkline of the 5h session %
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 320
                        spacing: 4
                        Text {
                            text: "SESSION %  //  LIVE"
                            color: root.cDim
                            font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
                        }
                        Canvas {
                            id: spark
                            Layout.fillWidth: true
                            Layout.preferredHeight: 90
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var w = width, h = height
                                ctx.clearRect(0, 0, w, h)

                                // faint horizontal gridlines
                                ctx.strokeStyle = root.cBorder.toString()
                                ctx.globalAlpha = 0.25
                                ctx.lineWidth = 1
                                for (var g = 1; g <= 4; g++) {
                                    var gy = h * g / 4
                                    ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(w, gy); ctx.stroke()
                                }
                                ctx.globalAlpha = 1

                                var data = Services.ZaiUsageService.sparkline
                                if (data.length < 2) return

                                var accent = root.cAccent.toString()
                                ctx.strokeStyle = accent
                                ctx.lineWidth = 2
                                ctx.beginPath()
                                for (var i = 0; i < data.length; i++) {
                                    var x = (i / (data.length - 1)) * w
                                    var y = h - (Math.min(data[i], 100) / 100) * h
                                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                                }
                                ctx.stroke()

                                // faint area fill
                                ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath()
                                ctx.fillStyle = accent
                                ctx.globalAlpha = 0.12
                                ctx.fill()
                                ctx.globalAlpha = 1
                            }
                            Connections {
                                target: Services.ZaiUsageService
                                function onDataRefreshed() { spark.requestPaint() }
                            }
                            Connections {
                                target: root
                                function onCAccentChanged() { spark.requestPaint() }
                            }
                            Component.onCompleted: spark.requestPaint()
                        }
                        Text {
                            text: Services.ZaiUsageService.sparkline.length + " SAMPLES // 60s INTERVAL"
                            color: root.cDim
                            font.family: root.fontM; font.pixelSize: 8
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // ---- footer ----
            RowLayout {
                Layout.fillWidth: true
                opacity: 0.7
                Text {
                    text: "DATA_SRC: api.z.ai  //  LAST_UPDT: " + (Services.ZaiUsageService.lastUpdated || "—")
                    color: root.cAccent
                    font.family: root.fontM; font.pixelSize: 8
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "[Z] REFRESH"
                    color: root.cAccent
                    font.family: root.fontM; font.pixelSize: 9; font.bold: true
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.ZaiUsageService.refresh()
                    }
                }
            }
        }
    }
}
