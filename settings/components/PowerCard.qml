// =============================================================================
// PowerCard.qml — Full-bleed power action grid for bento dashboard
// VERSION: V2.0
//
// FIXES vs V1:
//   - No longer extends DashboardCard (was causing double-card nesting)
//   - Root is Item — parent card controls size
//   - Buttons fill available height via Layout.fillHeight
//   - Larger icons (28px), cleaner label, teal hover border accent
//   - Power Off gets a red tint on hover to signal destructive action
//   - radius: 0 everywhere per Obsidian Core constraints
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config
import "." as Components

Item {
    id: root

    // -------------------------------------------------------------------------
    // PROCESS — deferred power command execution
    // -------------------------------------------------------------------------
    Process {
        id: powerExec
        command: ["sh", "-c", ""]
        onRunningChanged: {
            if (!running && exitCode !== 0)
                console.log("[PowerCard] failed: " + command.join(" "))
        }
    }

    function execCmd(cmd) {
        powerExec.command = ["sh", "-c", cmd]
        powerExec.running = true
    }

    // -------------------------------------------------------------------------
    // LAYOUT
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header + uptime label
        Item {
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            height: 18

            Components.WidgetHeader {
                icon: "󰐥"
                label: "POWER"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "UPTIME"
                color: Config.ThemeConfig.colors.secondary
                font.pixelSize: 8
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
                opacity: 0.7
            }
        }

        // ── BUTTON GRID — 2×2 ────────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: [
                    { label: "SUSPEND",   icon: "󰒲",  cmd: "systemctl suspend",  hover: "warning" },
                    { label: "LOCK",      icon: "󰌾",  cmd: "hyprlock",           hover: "primary" },
                    { label: "RESTART",   icon: "󰜉",  cmd: "systemctl reboot",   hover: "accent" },
                    { label: "POWER OFF", icon: "⏻",  cmd: "systemctl poweroff", hover: "error" }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: btnArea.containsMouse
                           ? Config.ThemeConfig.tint(Config.ThemeConfig.colors[modelData.hover], 0.15)
                           : Config.ThemeConfig.colors.surface
                    radius: 0
                    border.width: 1
                    border.color: btnArea.containsMouse
                                  ? Config.ThemeConfig.colors[modelData.hover]
                                  : Config.ThemeConfig.colors.border

                    Behavior on color       { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: modelData.icon
                            font.pixelSize: 24
                            font.family: "JetBrains Mono Nerd Font Mono"
                            color: btnArea.containsMouse
                                   ? Config.ThemeConfig.colors[modelData.hover]
                                   : Config.ThemeConfig.colors.textDim
                            Layout.alignment: Qt.AlignHCenter
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Text {
                            text: modelData.label
                            font.pixelSize: 8
                            font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            color: btnArea.containsMouse
                                   ? Config.ThemeConfig.colors[modelData.hover]
                                   : Config.ThemeConfig.colors.textDim
                            Layout.alignment: Qt.AlignHCenter
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.execCmd(modelData.cmd)
                    }
                }
            }
        }
    }
}
