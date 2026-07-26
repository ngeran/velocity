// =============================================================================
// SymmetryNodeWidget.qml — dual square-tile stat pair (Dashboard tab)
// =============================================================================
// Mirrors the mockup's "Symmetry Node" module: header + two square tiles
// side by side. Built as a GENERIC presentational widget rather than one
// wired to a guessed service — I don't have the GpuService/ThermalService
// property names in front of me, and binding to a property that doesn't
// exist breaks the file at load, so this exposes plain public properties
// instead. Given the RTX 5080 in this rig, GPU temp/load is a natural fit
// for nodeA/nodeB — wire it up via:
//
//   Components.SymmetryNodeWidget {
//       nodeALabel: "GPU_TEMP"; nodeAValue: Math.round(Services.GpuService.temp).toString(); nodeAUnit: "°C"
//       nodeBLabel: "GPU_LOAD"; nodeBValue: Math.round(Services.GpuService.load).toString(); nodeBUnit: "%"
//   }
//
// (adjust property names to whatever GpuService actually exposes).
//
// PUBLIC API:
//   nodeALabel / nodeAValue / nodeAUnit / nodeAColor
//   nodeBLabel / nodeBValue / nodeBUnit / nodeBColor
//   headerIcon / headerLabel
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Item {
    id: root

    property string headerIcon: "󰘖"
    property string headerLabel: "SYMMETRY NODE"

    property string nodeALabel: "NODE_ALPHA"
    property string nodeAValue: "—"
    property string nodeAUnit: ""
    property color  nodeAColor: Config.ThemeConfig.colors.secondary

    property string nodeBLabel: "NODE_BETA"
    property string nodeBValue: "—"
    property string nodeBUnit: ""
    property color  nodeBColor: Config.ThemeConfig.colors.warning

    // Reusable square tile — same shape/paddings as CpuInfoWidget's Tile so
    // the two widgets read as one family.
    component Tile: Rectangle {
        property string tileLabel: ""
        property string tileValue: ""
        property string tileUnit: ""
        property color  valueColor: Config.ThemeConfig.colors.secondary
        Layout.fillWidth: true; Layout.fillHeight: true
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.3)
        border.color: Config.ThemeConfig.colors.border; border.width: 1
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 1
            Text {
                text: parent.parent.tileLabel
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.letterSpacing: 1
                Layout.alignment: Qt.AlignHCenter
            }
            Item { Layout.fillHeight: true }
            Text {
                text: parent.parent.tileValue
                color: parent.parent.valueColor
                font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 22; font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: parent.parent.tileUnit
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.letterSpacing: 1
                Layout.alignment: Qt.AlignHCenter
            }
            Item { Layout.fillHeight: true }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            WidgetHeader { icon: root.headerIcon; label: root.headerLabel; iconColor: Config.ThemeConfig.colors.primary }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Tile {
                tileLabel: root.nodeALabel
                tileValue: root.nodeAValue
                tileUnit: root.nodeAUnit
                valueColor: root.nodeAColor
            }
            Tile {
                tileLabel: root.nodeBLabel
                tileValue: root.nodeBValue
                tileUnit: root.nodeBUnit
                valueColor: root.nodeBColor
            }
        }
    }
}
