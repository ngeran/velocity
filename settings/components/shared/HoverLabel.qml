// =============================================================================
// settings/components/shared/HoverLabel.qml — Interactive Hover Label
// =============================================================================
//
// Interactive label with hover color animation and click handling.
// Used for buttons, navigation items, and interactive text.
//
// Usage:
//   HoverLabel {
//       text: "CLICK ME"
//       onClicked: { console.log("Clicked!") }
//   }
//
// =============================================================================

import QtQuick
import "../config" as Config

Text {
    id: root

    // =========================================================================
    // API
    // =========================================================================

    property bool hovered: false
    signal clicked()

    // Default typography (can be overridden)
    font.pixelSize: 9
    font.family: Config.SettingsConfig.fontFamily
    font.letterSpacing: 1.8

    // Color based on hover state
    color: hovered ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim

    // =========================================================================
    // ANIMATIONS
    // =========================================================================

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    // =========================================================================
    // INTERACTION
    // =========================================================================

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.clicked()
    }
}
