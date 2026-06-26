// =============================================================================
// WidgetHeader.qml — compact in-card header for dashboard widgets
// =============================================================================
//
// Reusable header row: [accent Nerd-Font glyph] [UPPERCASE label]. Gives every
// dashboard widget a consistent header so the bento grid reads as one system.
//
//   Components.WidgetHeader { icon: "󰥔"; label: "CLOCK" }
//
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    id: root
    implicitHeight: 18
    height: 18

    property string icon: ""     // Nerd Font glyph (optional)
    property string label: ""
    property color iconColor: Config.ThemeConfig.colors.secondary
    property color labelColor: Config.ThemeConfig.colors.textDim
    property real letterSpacing: 2.0
    property int pixelSize: 9

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.iconColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: root.pixelSize + 2
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.label
            color: root.labelColor
            font.family: Config.SettingsConfig.fontFamily
            font.pixelSize: root.pixelSize
            font.letterSpacing: root.letterSpacing
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
