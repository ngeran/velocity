// =============================================================================
// PowerCard.qml — Power icon row for dashboard
// =============================================================================
//
// Four power buttons: Suspend ☾ / Lock 🔒 / Restart ↺ / PowerOff ⏻
// Runs actual systemctl/hyprlock commands through a deferred Process.
//
// =============================================================================


import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config

DashboardCard {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Section label
        Text {
            text:               "POWER"
            font.pixelSize:     7
            font.family:        Config.SettingsConfig.fontFamily
            font.letterSpacing: 2.0
            color:              Config.ThemeConfig.colors.textDim
            Layout.bottomMargin: 4
        }

        // Power button row
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Repeater {
                model: [
                    { label: "Suspend", icon: "☾", cmd: "systemctl suspend" },
                    { label: "Lock",   icon: "🔒", cmd: "hyprlock" },
                    { label: "Restart", icon: "↺", cmd: "systemctl reboot" },
                    { label: "Power Off", icon: "⏻", cmd: "systemctl poweroff" }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: btnHover.containsMouse
                           ? Config.ThemeConfig.colors.surfaceVariant
                           : Config.ThemeConfig.colors.surface
                    radius: 6
                    border.width: 1
                    border.color: Config.ThemeConfig.colors.border

                    Behavior on color {
                        ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        // Icon (JetBrains Mono Nerd Font)
                        Text {
                            text:             modelData.icon
                            font.pixelSize:   20
                            font.family:      "JetBrains Mono Nerd Font Mono"
                            color:            Config.ThemeConfig.colors.primary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // Label (Inter)
                        Text {
                            text:             modelData.label
                            font.pixelSize:   9
                            font.bold:        true
                            font.family:      "Inter"
                            font.letterSpacing: 0.5
                            color:            Config.ThemeConfig.colors.text
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    MouseArea {
                        id: btnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: powerExecCmd(modelData.cmd)
                    }
                }
            }
        }
    }

    // Execute power command (deferred, like PowerMenu.qml)
    Process {
        id: powerExec
        command: ["sh", "-c", ""]

        onRunningChanged: {
            if (!running && exitCode !== 0) {
                console.log("[PowerCard] Command failed: " + command.join(" "))
            }
        }
    }

    function powerExecCmd(cmd) {
        powerExec.command = ["sh", "-c", cmd]
        powerExec.running = true
    }
}
