// =============================================================================
// LcdControllerPanel.qml — DeepCool Mystique AIO LCD controller (HUD cluster)
// =============================================================================
// The SHARED control surface: embedded in the Core telemetry pane AND hosted
// standalone by CoreLcdPane (MYSTIQUE AIO nav item). All state lives in
// LcdConfigService (both instances are alive at once — no local copies).
//
// Faithful-to-mock substitutions (fixed HUD palette, honest data):
//   · CONNECTED 60Hz chip ↔ metrics.lcdPresent (pgrep probe) — OFFLINE dim chip
//   · LCD preview renders LIVE from the slot config (metricValue helpers)
//   · Pump tach is not measurable over this link → static FIXED 100% row
//   · Display modes ship the three the daemon knows: cpu | gpu | gpu_focus
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: root

    property bool embedded: false
    readonly property var lcd: Services.LcdConfigService
    readonly property var m: Services.HostBridge.metrics
    readonly property bool daemonUp: !!m && m.lcdPresent

    radius: Config.HudConfig.radiusMd
    color: Config.HudConfig.panel
    border.color: Config.HudConfig.borderLo
    border.width: 1

    function assignSlot(slot, key) {
        if (slot === "main") lcd.setMainTempSource(key)
        else if (slot === "gpu") lcd.setGpuTempSource(key)
        else if (slot === "usage") lcd.setUsageSource(key)
        else if (slot === "ram") lcd.setRamSource(key)
    }

    // Local seg button (HUD look; taller than HudChip for the mode grid)
    component PanelSeg: Rectangle {
        property string text: ""
        property bool sel: false
        property color segAccent: Config.HudConfig.cyan
        signal picked()
        Layout.fillWidth: true
        Layout.preferredHeight: 22
        radius: 3
        color: sel ? Config.ThemeConfig.tint(segAccent, 0.22) : Config.HudConfig.well
        border.color: sel ? segAccent : Config.HudConfig.borderHi
        border.width: 1
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            anchors.centerIn: parent
            text: parent.text
            color: parent.sel ? parent.segAccent : Config.HudConfig.textMid
            font.family: Config.HudConfig.fontData
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.8
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!parent.sel) parent.picked()
        }
    }

    // One TELEMETRY SLOT ASSIGNMENT row: label · live value · source chips
    component SlotRow: Rectangle {
        id: slotRoot
        property string label: ""
        property string slotId: ""
        property string current: ""
        property var options: []
        readonly property string liveVal: root.lcd.metricValue(current)
        Layout.fillWidth: true
        Layout.preferredHeight: 24
        radius: 3
        color: Config.HudConfig.wellDeep
        border.color: Config.HudConfig.borderHi
        border.width: 1
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 6
            Text {
                text: slotRoot.label
                color: Config.HudConfig.textMid
                font.family: Config.HudConfig.fontData
                font.pixelSize: 10
            }
            Item { Layout.fillWidth: true }
            Text {
                text: slotRoot.liveVal
                color: Config.HudConfig.amber
                font.family: Config.HudConfig.fontData
                font.pixelSize: 10
                font.bold: true
            }
            Repeater {
                model: slotRoot.options
                delegate: HudChip {
                    property var opt: modelData
                    text: opt.t
                    accent: opt.k === slotRoot.current ? Config.HudConfig.amber
                                                       : Config.HudConfig.textFaint
                    filled: opt.k === slotRoot.current
                    onPicked: root.assignSlot(slotRoot.slotId, opt.k)
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.embedded ? 12 : 16
        spacing: 10

        // ── header ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                width: 24; height: 24; radius: 4
                color: Config.ThemeConfig.tint(Config.HudConfig.cyan, 0.10)
                border.color: Config.ThemeConfig.tint(Config.HudConfig.cyan, 0.40)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "󰍹"
                    font.family: Config.ControlConfig.fontNerd
                    font.pixelSize: 13
                    color: Config.HudConfig.cyan
                }
            }
            ColumnLayout {
                spacing: 1
                RowLayout {
                    spacing: 8
                    Text {
                        text: "DEEPCOOL MYSTIQUE // AIO LCD CONTROLLER"
                        color: Config.HudConfig.textBody
                        font.family: Config.HudConfig.fontData
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                    }
                    HudChip {
                        text: root.daemonUp ? "CONNECTED 60Hz" : "OFFLINE"
                        accent: root.daemonUp ? Config.HudConfig.cyan : Config.HudConfig.textFaint
                    }
                    HudChip { text: "2.8\" TFT 640×480"; accent: Config.HudConfig.amber }
                }
                Text {
                    text: "PATH " + root.lcd.cfgPath + "   |   DAEMON: " +
                          (root.daemonUp ? "SYNCED" : "NOT RUNNING")
                    color: Config.HudConfig.textFaint
                    font.family: Config.HudConfig.fontData
                    font.pixelSize: 9
                }
            }
            Item { Layout.fillWidth: true }
            // AIO DISPLAY: enabled toggle + unit segs
            RowLayout {
                spacing: 8
                Text {
                    text: "AIO DISPLAY"
                    color: Config.HudConfig.textMid
                    font.family: Config.HudConfig.fontData
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.0
                }
                HudChip {
                    text: root.lcd.lcdEnabled ? "ENABLED" : "DISABLED"
                    accent: root.lcd.lcdEnabled ? Config.HudConfig.amber : Config.HudConfig.textFaint
                    filled: root.lcd.lcdEnabled
                    onPicked: root.lcd.setEnabled(!root.lcd.lcdEnabled)
                }
                RowLayout {
                    spacing: 0
                    PanelSeg {
                        text: "°C"; segAccent: Config.HudConfig.amber
                        sel: root.lcd.unit === "C"
                        onPicked: root.lcd.setUnit("C")
                    }
                    PanelSeg {
                        text: "°F"; segAccent: Config.HudConfig.amber
                        sel: root.lcd.unit === "F"
                        onPicked: root.lcd.setUnit("F")
                    }
                }
            }
        }

        // ── content row: 5 preview | 7 controls (mock lg:grid-cols-12) ──
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // LEFT — circular live preview
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 5.0 / 12.0
                radius: Config.HudConfig.radiusSm
                color: Config.HudConfig.wellDeep
                border.color: Config.HudConfig.borderHi
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Item {
                        Layout.fillWidth: true
                        height: 12
                        Text {
                            anchors.left: parent.left
                            text: "MYSTIQUE 360 LCD PREVIEW"
                            color: Config.HudConfig.textMid
                            font.family: Config.HudConfig.fontData
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1.0
                        }
                        Text {
                            anchors.right: parent.right
                            visible: root.daemonUp && root.lcd.lcdEnabled
                            text: "LIVE 60FPS"
                            color: Config.HudConfig.cyan
                            font.family: Config.HudConfig.fontData
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }

                    // The device: outer ring · dashed cyan halo · black screen
                    Item {
                        id: deviceWrap
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        width: 176
                        height: 176

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.color: Config.HudConfig.borderLo
                            border.width: 4
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: width / 2
                            color: "transparent"
                            border.color: Config.ThemeConfig.tint(Config.HudConfig.cyan, 0.18)
                            border.width: 1
                        }
                        // dashed halo — pulses only while the display is live
                        Canvas {
                            id: halo
                            anchors.fill: parent
                            anchors.margins: 10
                            visible: root.lcd.lcdEnabled
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.strokeStyle = Config.ThemeConfig.tint(Config.HudConfig.cyan, 0.35)
                                ctx.lineWidth = 1
                                ctx.setLineDash([3, 5])
                                ctx.beginPath()
                                ctx.arc(width / 2, height / 2, width / 2 - 1, 0, Math.PI * 2)
                                ctx.stroke()
                            }
                            SequentialAnimation on opacity {
                                running: root.lcd.lcdEnabled
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 0.25; duration: 2000; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 0.25; to: 1.0; duration: 2000; easing.type: Easing.InOutQuad }
                            }
                            onWidthChanged: requestPaint()
                            onPainted: if (width > 0 && !paintedOnce) { paintedOnce = true; requestPaint() }
                            property bool paintedOnce: false
                        }

                        // the screen itself — rotation mirrors the device config
                        Rectangle {
                            id: screen
                            anchors.centerIn: parent
                            width: 130
                            height: 130
                            radius: width / 2
                            color: "#000000"
                            border.color: Config.HudConfig.borderHi
                            border.width: 2
                            rotation: root.lcd.rotation
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 2

                                Item {
                                    Layout.fillWidth: true
                                    height: 12
                                    Text {
                                        anchors.left: parent.left
                                        text: "DEEPCOOL"
                                        color: Config.HudConfig.cyan
                                        font.family: Config.HudConfig.fontData
                                        font.pixelSize: 8
                                        font.bold: true
                                        font.letterSpacing: 1.0
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: root.lcd.lcdEnabled ? "PUMP 100%" : "OFF"
                                        color: Config.HudConfig.amber
                                        font.family: Config.HudConfig.fontData
                                        font.pixelSize: 8
                                        font.bold: true
                                    }
                                }
                                Item { Layout.fillHeight: true }
                                ColumnLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 0
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: root.lcd.metricValue(root.lcd.mainTempSource)
                                        color: Config.HudConfig.amber
                                        font.family: Config.HudConfig.fontData
                                        font.pixelSize: 30
                                        font.bold: true
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "MAIN"
                                        color: Config.HudConfig.textMid
                                        font.family: Config.HudConfig.fontData
                                        font.pixelSize: 7
                                        font.bold: true
                                        font.letterSpacing: 1.2
                                    }
                                }
                                Item { Layout.fillHeight: true }
                                // bottom triple: gpu · usage · ram slots
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Config.HudConfig.borderLo
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Repeater {
                                        model: [
                                            { cap: "GPU", src: root.lcd.gpuTempSource },
                                            { cap: "LOAD", src: root.lcd.usageSource },
                                            { cap: "RAM", src: root.lcd.ramSource }
                                        ]
                                        delegate: ColumnLayout {
                                            property var cell: modelData
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: cell.cap
                                                color: Config.HudConfig.textFaint
                                                font.family: Config.HudConfig.fontData
                                                font.pixelSize: 7
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: root.lcd.metricValue(cell.src)
                                                color: cell.cap === "GPU" ? Config.HudConfig.cyan
                                                       : cell.cap === "LOAD" ? Config.HudConfig.amber
                                                       : Config.HudConfig.textBody
                                                font.family: Config.HudConfig.fontData
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }
                                    }
                                }
                            }
                            // cyan underline glow (mock's bottom accent)
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                width: 44
                                height: 2
                                radius: 1
                                color: Config.ThemeConfig.tint(Config.HudConfig.cyan, 0.60)
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.fillWidth: true
                        text: "ORIENTATION: " + root.lcd.rotation + "°  |  PUMP DUTY: 100% FIXED"
                        color: Config.HudConfig.textFaint
                        font.family: Config.HudConfig.fontData
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // RIGHT — control stack
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // LCD DISPLAY MODE
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: modeCol.implicitHeight + 20
                    radius: Config.HudConfig.radiusSm
                    color: Config.HudConfig.wellDeep
                    border.color: Config.HudConfig.borderHi
                    border.width: 1
                    ColumnLayout {
                        id: modeCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "LCD DISPLAY MODE"
                                color: Config.HudConfig.textBody
                                font.family: Config.HudConfig.fontData
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1.0
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "QUICKSHELL PROFILE"
                                color: Config.HudConfig.textFaint
                                font.family: Config.HudConfig.fontData
                                font.pixelSize: 9
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            PanelSeg {
                                text: "CPU"; segAccent: Config.HudConfig.amber
                                sel: root.lcd.mode === "cpu"
                                onPicked: root.lcd.setMode("cpu")
                            }
                            PanelSeg {
                                text: "GPU"; segAccent: Config.HudConfig.amber
                                sel: root.lcd.mode === "gpu"
                                onPicked: root.lcd.setMode("gpu")
                            }
                            PanelSeg {
                                text: "GFOCUS"; segAccent: Config.HudConfig.cyan
                                sel: root.lcd.mode === "gpu_focus"
                                onPicked: root.lcd.setMode("gpu_focus")
                            }
                        }
                    }
                }

                // TELEMETRY SLOT ASSIGNMENT
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: slotCol.implicitHeight + 20
                    radius: Config.HudConfig.radiusSm
                    color: Config.HudConfig.wellDeep
                    border.color: Config.HudConfig.borderHi
                    border.width: 1
                    ColumnLayout {
                        id: slotCol
                        // top/left/right (NOT fill): the well is the pane's
                        // fillHeight stretch — anchoring all four sides made
                        // the layout redistribute its extra height across the
                        // rows (they spread ~100px apart in the standalone
                        // pane). Packed at the top, slack stays at the bottom.
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 5
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "TELEMETRY SLOT ASSIGNMENT"
                                color: Config.HudConfig.textBody
                                font.family: Config.HudConfig.fontData
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1.0
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "LIVE BINDINGS"
                                color: Config.HudConfig.amber
                                font.family: Config.HudConfig.fontData
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }
                        SlotRow {
                            label: "MAIN DIAL"
                            slotId: "main"
                            current: root.lcd.mainTempSource
                            options: [
                                { k: "cpu_temp", t: "CPU" }, { k: "gpu_temp", t: "GPU" },
                                { k: "coolant_temp", t: "COOL" }, { k: "nvme_temp", t: "NVME" }
                            ]
                        }
                        SlotRow {
                            label: "SUB 1 · GPU"
                            slotId: "gpu"
                            current: root.lcd.gpuTempSource
                            options: [
                                { k: "gpu_temp", t: "GPU" }, { k: "cpu_temp", t: "CPU" },
                                { k: "nvme_temp", t: "NVME" }
                            ]
                        }
                        SlotRow {
                            label: "SUB 2 · USAGE"
                            slotId: "usage"
                            current: root.lcd.usageSource
                            options: [
                                { k: "cpu_usage", t: "CPU" }, { k: "gpu_usage", t: "GPU" }
                            ]
                        }
                        SlotRow {
                            label: "SUB 3 · MEM"
                            slotId: "ram"
                            current: root.lcd.ramSource
                            options: [
                                { k: "ram_pct", t: "RAM" }, { k: "swap_pct", t: "SWAP" },
                                { k: "disk_pct", t: "DISK" }
                            ]
                        }
                    }
                }

                // rotation + pump row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Config.HudConfig.radiusSm
                        color: Config.HudConfig.wellDeep
                        border.color: Config.HudConfig.borderHi
                        border.width: 1
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 5
                            Text {
                                text: "SCREEN ROTATION"
                                color: Config.HudConfig.textMid
                                font.family: Config.HudConfig.fontData
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 1.0
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Repeater {
                                    model: [0, 90, 180, 270]
                                    delegate: PanelSeg {
                                        property int deg: modelData
                                        text: deg + "°"
                                        sel: root.lcd.rotation === deg
                                        onPicked: root.lcd.setRotation(deg)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Config.HudConfig.radiusSm
                        color: Config.HudConfig.wellDeep
                        border.color: Config.HudConfig.borderHi
                        border.width: 1
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 5
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "AIO PUMP"
                                    color: Config.HudConfig.textMid
                                    font.family: Config.HudConfig.fontData
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1.0
                                }
                                Item { Layout.fillWidth: true }
                                HudChip {
                                    text: root.lcd.lcdEnabled ? "FIXED 100%" : "OFF"
                                    accent: Config.HudConfig.amber
                                }
                            }
                            HudMeterBar {
                                Layout.fillWidth: true
                                value: root.lcd.lcdEnabled ? 100 : 0
                                barHeight: 4
                            }
                        }
                    }
                }
            }
        }

        // ── footer ──────────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.HudConfig.borderHi }
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: (root.daemonUp
                       ? "QUICKSHELL DAEMON ACTIVE · CHANGES AUTO-APPLIED IN REALTIME"
                       : "DAEMON NOT RUNNING · CONFIG PERSISTS — PICKED UP ON NEXT deepcool-py START")
                color: root.daemonUp ? Config.HudConfig.textFaint : Config.HudConfig.textDim
                font.family: Config.HudConfig.fontData
                font.pixelSize: 9
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "DRIVER: HID-DEEPCOOL-MYSTIQUE"
                color: Config.HudConfig.textFaint
                font.family: Config.HudConfig.fontData
                font.pixelSize: 9
            }
        }
    }
}
