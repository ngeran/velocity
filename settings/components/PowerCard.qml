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

        // ── HEADER ────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 12

            Text {
                text: "POWER"
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 9
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 2.5
            }

            Item { Layout.fillWidth: true }

            // Uptime badge (static label — replace with Process probe if desired)
            Text {
                text: "UPTIME"
                color: Config.ThemeConfig.colors.secondary
                font.pixelSize: 8
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
                opacity: 0.6
            }
        }

        // Thin rule
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Config.ThemeConfig.colors.outlineVariant
            Layout.bottomMargin: 12
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
                    { label: "SUSPEND",   icon: "󰒲",  cmd: "systemctl suspend",  danger: false },
                    { label: "LOCK",      icon: "󰌾",  cmd: "hyprlock",           danger: false },
                    { label: "RESTART",   icon: "󰜉",  cmd: "systemctl reboot",   danger: false },
                    { label: "POWER OFF", icon: "⏻",  cmd: "systemctl poweroff", danger: true  }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: btnArea.containsMouse
                           ? (modelData.danger ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.15) : Config.ThemeConfig.colors.surfaceVariant)
                           : Config.ThemeConfig.colors.surface
                    radius: 0
                    border.width: 1
                    border.color: btnArea.containsMouse
                                  ? (modelData.danger ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.secondary)
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
                                   ? (modelData.danger ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.secondary)
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
                                   ? (modelData.danger ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.primary)
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
