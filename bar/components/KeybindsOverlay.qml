// =============================================================================
// KeybindsOverlay.qml — mod+K keybinds cheat-sheet (pure QML, no python)
// =============================================================================
// Replaces the old `kitty -e python3 keybinds_viewer.py` flow (python3 isn't on
// PATH under NixOS). A centered, themed PanelWindow overlay with the keybinds
// grouped by section. Toggled via IPC: `quickshell ipc -c bar call keybinds toggle`
// (bound to SUPER+K in configs/hypr/keybindings.lua). Esc or outside-click closes.
// =============================================================================

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../config" as Config

PanelWindow {
    id: root

    property bool shown: false
    visible: false
    function open()  { visible = true; shown = true }
    function close() { shown = false; hideTimer.restart() }
    function toggle() { shown ? close() : open() }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    onShownChanged: if (!shown) hideTimer.restart()
    Timer { id: hideTimer; interval: 220; onTriggered: if (!root.shown) root.visible = false }

    // ---- dim backdrop (click-outside = close) ----
    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        opacity: root.shown ? 0.45 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ---- centered card ----
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Config.PopupMetrics.px(900), parent.width - Config.PopupMetrics.px(48))
        height: Math.min(Config.PopupMetrics.px(680), parent.height - Config.PopupMetrics.px(48))
        // Island look: pure black (pixels off on QD-OLED), rounded, no stroke.
        color: "#000000"
        radius: Config.PopupMetrics.px(18)
        clip: true
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
        Behavior on scale { NumberAnimation { duration: Config.MotionConfig.swap; easing.type: Config.MotionConfig.ease } }

        Keys.onEscapePressed: root.close()
        MouseArea { anchors.fill: parent }   // stop click-through to the backdrop

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.PopupMetrics.px(24)
            spacing: Config.PopupMetrics.px(12)

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.PopupMetrics.px(8)
                Text {
                    text: "󰬃"
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: Config.PopupMetrics.px(16)
                    color: Config.BarConfig.colorAccent
                }
                Text {
                    text: "KEYBINDINGS"
                    color: Config.ThemeConfig.colors.text
                    font.pixelSize: Config.PopupMetrics.px(16)
                    font.bold: true
                    font.family: Config.BarConfig.fontFamily
                    font.letterSpacing: 2.5
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "ESC to close"
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: Config.PopupMetrics.px(10)
                    font.family: Config.BarConfig.fontFamily
                }
            }
            Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: Config.ThemeConfig.colors.border }

            // ---- scrollable sections ----
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: sectionsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: sectionsCol
                    width: parent.width
                    spacing: Config.PopupMetrics.px(16)

                    Repeater {
                        model: root.keybindModel
                        delegate: ColumnLayout {
                            id: sec
                            // pull the section's data into local props for unambiguous binding
                            property string sectionTitle: modelData.sectionName
                            property var sectionBinds: modelData.binds
                            Layout.fillWidth: true
                            spacing: Config.PopupMetrics.px(6)

                            Text {
                                text: sec.sectionTitle
                                color: Config.ThemeConfig.colors.primary
                                font.pixelSize: Config.PopupMetrics.px(10)
                                font.bold: true
                                font.family: Config.BarConfig.fontFamily
                                font.letterSpacing: 1.8
                            }

                            Repeater {
                                model: sec.sectionBinds
                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.PopupMetrics.px(12)
                                    Rectangle {
                                        Layout.preferredWidth: keyLbl.implicitWidth + Config.PopupMetrics.px(18)
                                        Layout.preferredHeight: Config.PopupMetrics.px(20)
                                        color: Config.ThemeConfig.colors.surfaceVariant
                                        border.color: Config.ThemeConfig.colors.border
                                        border.width: Config.PopupMetrics.hairline(parent)
                                        Text {
                                            id: keyLbl
                                            anchors.centerIn: parent
                                            text: modelData.key
                                            color: Config.ThemeConfig.colors.text
                                            font.pixelSize: Config.PopupMetrics.px(10)
                                            font.bold: true
                                            font.family: Config.BarConfig.fontFamily
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.desc
                                        color: Config.ThemeConfig.colors.textDim
                                        font.pixelSize: Config.PopupMetrics.px(11)
                                        font.family: Config.BarConfig.fontFamily
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- keybinds data (mirrors configs/hypr/keybindings.lua) ----
    property var keybindModel: [
        { sectionName: "CORE APPLICATIONS", binds: [
            { key: "SUPER + X",         desc: "Terminal" },
            { key: "SUPER + B",         desc: "Chromium" },
            { key: "SUPER + SPACE",     desc: "App launcher (rofi; velocity.launcher rebind pending)" },
            { key: "SUPER + C",         desc: "Close window" },
            { key: "SUPER + SHIFT + F", desc: "File manager" }
        ]},
        { sectionName: "QUICKSHELL", binds: [
            { key: "SUPER + A",         desc: "Settings dashboard" },
            { key: "SUPER + P",         desc: "Power menu" },
            { key: "SUPER + K",         desc: "This keybinds overlay" },
            { key: "SUPER + Z",         desc: "Z.ai usage analytics" },
            { key: "SUPER + T",         desc: "System logs overlay" },
            { key: "SUPER + SHIFT + B", desc: "Toggle the bar" },
            { key: "SUPER + SHIFT + T", desc: "Network / Bluetooth center" }
        ]},
        { sectionName: "WINDOW MANAGEMENT", binds: [
            { key: "SUPER + V",   desc: "Toggle floating" },
            { key: "SUPER + J",   desc: "Toggle split orientation" },
            { key: "SUPER + F",   desc: "Fullscreen" },
            { key: "SUPER + ±",   desc: "Resize window" }
        ]},
        { sectionName: "NAVIGATION", binds: [
            { key: "SUPER + Arrows",         desc: "Move focus" },
            { key: "SUPER + SHIFT + Arrows", desc: "Move window" }
        ]},
        { sectionName: "WORKSPACES", binds: [
            { key: "SUPER + 1..9",         desc: "Switch workspace" },
            { key: "SUPER + SHIFT + 1..9", desc: "Move window to workspace" }
        ]},
        { sectionName: "SESSION", binds: [
            { key: "SUPER + L", desc: "Lock screen" },
            { key: "SUPER + M", desc: "Exit / shutdown" }
        ]},
        { sectionName: "SCREENSHOTS", binds: [
            { key: "SUPER + S",         desc: "Region → file" },
            { key: "SUPER + SHIFT + S", desc: "Region → clipboard" }
        ]}
    ]
}
