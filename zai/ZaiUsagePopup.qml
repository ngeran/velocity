import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Obsidian Core styled popup for Z.ai usage.
// Toggle from anywhere with: qs ipc call zaiUsage toggle
// Hyprland keybind (add to hyprland.conf):
//   bind = $mainMod, Z, exec, qs -c <your-config-name> ipc call zaiUsage toggle
//
// Drop into e.g. modules/ZaiUsagePopup.qml and instantiate once from shell.qml:
//   ZaiUsagePopup {}

PanelWindow {
    id: popup

    // ---- Obsidian Core tokens ----
    readonly property color bgColor: "#000000"
    readonly property color panelColor: "#0a0a0a"
    readonly property color borderColor: "#1a1a1a"
    readonly property color accent: "#00dce5"
    readonly property color accentDim: "#00dce555"
    readonly property color textPrimary: "#e8e8e8"
    readonly property color textDim: "#6b6b6b"
    readonly property color warnColor: "#e5b800"
    readonly property color critColor: "#e53e3e"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    visible: false
    color: "transparent"

    // screen-proportional sizing, matches PowerMenu-style panels
    implicitWidth: Math.round(screen.width * 0.22)
    implicitHeight: Math.round(screen.height * 0.30)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "zai-usage-popup"

    anchors {
        top: true
        right: true
    }
    margins {
        top: 60
        right: 20
    }

    IpcHandler {
        target: "zaiUsage"

        function toggle(): void {
            popup.visible = !popup.visible;
            if (popup.visible)
                ZaiUsageService.refresh();
        }

        function show(): void {
            popup.visible = true;
            ZaiUsageService.refresh();
        }

        function hide(): void {
            popup.visible = false;
        }
    }

    // click-outside / Escape to close
    HyprlandFocusGrab {
        active: popup.visible
        windows: [popup]
        onCleared: popup.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: popup.bgColor
        border.color: popup.borderColor
        border.width: 1
        radius: 0

        Keys.onEscapePressed: popup.visible = false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 18

            // header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Z.AI USAGE"
                    color: popup.textPrimary
                    font.family: popup.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    font.letterSpacing: 1.5
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 8
                    height: 8
                    radius: 0
                    color: ZaiUsageService.hasError ? popup.critColor : popup.accent
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: popup.borderColor
            }

            // error state
            Text {
                visible: ZaiUsageService.hasError
                Layout.fillWidth: true
                text: ZaiUsageService.errorMessage
                color: popup.critColor
                font.family: popup.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            // gauges
            ColumnLayout {
                visible: !ZaiUsageService.hasError
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 22

                UsageRow {
                    label: "SESSION"
                    sublabel: "5h window · resets in " + ZaiUsageService.sessionResetIn
                    percentage: ZaiUsageService.sessionPercentage
                    accent: popup.accent
                    warnColor: popup.warnColor
                    critColor: popup.critColor
                    textPrimary: popup.textPrimary
                    textDim: popup.textDim
                    fontFamily: popup.fontFamily
                }

                UsageRow {
                    label: "WEEKLY"
                    sublabel: "7d window · resets in " + ZaiUsageService.weeklyResetIn
                    percentage: ZaiUsageService.weeklyPercentage
                    accent: popup.accent
                    warnColor: popup.warnColor
                    critColor: popup.critColor
                    textPrimary: popup.textPrimary
                    textDim: popup.textDim
                    fontFamily: popup.fontFamily
                }
            }

            Item { Layout.fillHeight: true }

            // footer
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: ZaiUsageService.loading ? "refreshing…" : "updated " + ZaiUsageService.lastUpdated
                    color: popup.textDim
                    font.family: popup.fontFamily
                    font.pixelSize: 9
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "[Z] refresh"
                    color: popup.textDim
                    font.family: popup.fontFamily
                    font.pixelSize: 9

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ZaiUsageService.refresh()
                    }
                }
            }
        }
    }
}
