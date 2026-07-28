// =============================================================================
// BrightnessControlView.qml — DISPLAY section view (tactical HUD, read-only)
// =============================================================================
// Filename retained (avoids qmldir/TerminalBody churn); the content is now the
// Display section. Shows REAL monitor topology from MonitorService (hyprctl
// monitors -j) as status.
//
// Why read-only: runtime monitor reconfiguration isn't possible on this
// Lua-generated Hyprland build — `hyprctl keyword monitor` is rejected
// ("non-legacy parsers"), `hyprctl eval` expects Hyprlang/Lua, and `hyprctl
// dispatch` is routed through the Lua wrapper and errors. Monitor mode/scale are
// set only in the Lua source or the monitor's OSD. Brightness is also
// uncontrollable (no /sys/class/backlight, no DDC/CI — brightnessctl sees only
// keyboard LEDs). So this section is honest status, not fake controls.
//
// Stack (~440px wide, scrolls with the parent Flickable):
//   1. Header         — title + DPMS-state pill + monitor name
//   2. MONITOR_TOPOLOGY — HudCard: make/model + RESOLUTION/REFRESH/SCALE/FORMAT
//                        grid + VRR / color-preset / size chips
//   3. Backlight note — honest "unavailable" line
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 10

    // The focused monitor (fallback: first). Null until the poll lands.
    readonly property var mon: Services.MonitorService.primary

    // Small bordered chip (VRR / color preset / physical size) — read-only.
    component Chip: Rectangle {
        property string text: ""
        property color chipColor: Config.ThemeConfig.colors.textDim
        height: 16
        width: chipLbl.implicitWidth + 12
        color: Config.ThemeConfig.tint(chipColor, 0.10)
        border.color: chipColor
        border.width: 1
        Text {
            id: chipLbl; anchors.centerIn: parent
            text: parent.text
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
            color: chipColor
        }
    }

    // Label/value stat cell for the 4-cell info grid.
    component Stat: ColumnLayout {
        property string label: ""
        property string value: "—"
        spacing: 2
        Text {
            text: parent.label
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
            color: Config.ThemeConfig.colors.textDim
        }
        Text {
            Layout.fillWidth: true
            text: parent.value
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
            color: Config.ThemeConfig.colors.text
            elide: Text.ElideRight
        }
    }

    // =========================================================================
    // 1. HEADER
    // =========================================================================
    RowLayout {
        width: parent.width
        spacing: 8

        Rectangle { width: 3; height: 16; color: Config.ControlConfig.accent; Layout.alignment: Qt.AlignVCenter }

        Text {
            text: "DISPLAY"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 13; font.bold: true
            color: Config.ThemeConfig.colors.text
            Layout.alignment: Qt.AlignVCenter
        }

        // DPMS-state pill
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: stateLbl.implicitWidth + 14; height: 16
            color: view.mon && view.mon.dpms
                   ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.12)
                   : Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.10)
            border.color: view.mon && view.mon.dpms ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
            border.width: 1
            Text {
                id: stateLbl; anchors.centerIn: parent
                text: view.mon && view.mon.dpms ? "● ACTIVE" : "○ STANDBY"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                color: view.mon && view.mon.dpms ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: view.mon ? view.mon.name : "—"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.textDim
        }
    }

    // =========================================================================
    // 2. MONITOR_TOPOLOGY
    // =========================================================================
    HudCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.primary

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "MONITOR_TOPOLOGY"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                    color: Config.ThemeConfig.colors.textDim
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: view.mon !== null
                    text: (view.mon && view.mon.transform ? "ROTATED " : "") + "ID " + (view.mon ? view.mon.name : "")
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                    color: Config.ThemeConfig.colors.primary
                }
            }

            // Big line: make + model (or NO_DISPLAY)
            Text {
                Layout.fillWidth: true
                text: view.mon ? ((view.mon.make + " " + view.mon.model).trim() || view.mon.desc || view.mon.name) : "NO_DISPLAY"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 16; font.bold: true
                color: view.mon ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.textDim
                elide: Text.ElideRight
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

            // 4-cell info grid: RESOLUTION · REFRESH · SCALE · FORMAT
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "RESOLUTION"; value: view.mon ? (view.mon.w + "×" + view.mon.h) : "—" }
                Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "REFRESH";    value: view.mon ? (Math.round(view.mon.refreshHz) + " Hz") : "—" }
                Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "SCALE";      value: view.mon ? ("" + view.mon.scale) : "—" }
                Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "FORMAT";     value: view.mon ? view.mon.format : "—" }
            }

            // Read-only chips: VRR · color preset · physical size
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Chip { text: view.mon && view.mon.vrr ? "VRR ON" : "VRR OFF"; chipColor: view.mon && view.mon.vrr ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.textDim }
                Chip {
                    visible: view.mon && view.mon.colorPreset.length > 0
                    text: (view.mon ? view.mon.colorPreset : "").toUpperCase()
                    chipColor: Config.ThemeConfig.colors.primary
                }
                Chip {
                    visible: view.mon && view.mon.physW > 0
                    text: view.mon ? (view.mon.physW + "×" + view.mon.physH + "mm") : ""
                    chipColor: Config.ThemeConfig.colors.textDim
                }
                Item { Layout.fillWidth: true }
            }
        }
    }

    // =========================================================================
    // 3. BACKLIGHT NOTE — honest "unavailable"
    // =========================================================================
    Rectangle {
        width: parent.width
        height: blRow.implicitHeight + 16
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.06)
        border.color: Config.ThemeConfig.colors.outlineVariant
        border.width: 1

        RowLayout {
            id: blRow
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 8

            Text {
                text: "󰃜"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 13
                color: Config.ThemeConfig.colors.error
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: "BACKLIGHT: NONE"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                    color: Config.ThemeConfig.colors.error
                }
                Text {
                    Layout.fillWidth: true
                    text: "no /sys/class/backlight, no DDC/CI (ddcutil missing) — use the monitor OSD"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                    color: Config.ThemeConfig.colors.textDim
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
