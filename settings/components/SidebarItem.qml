// =============================================================================
// SidebarItem.qml — Reusable Sidebar Navigation Item
// =============================================================================
//
// A clickable sidebar item with hover and active states.
//
// =============================================================================

import QtQuick
import QtQuick.Controls
import "../config" as Config

Rectangle {
    id: root

    // =========================================================================
    // PROPERTIES
    // =========================================================================

    property string text: ""
    property bool isActive: false
    signal clicked()

    // =========================================================================
    // APPEARANCE
    // =========================================================================

    color: isActive ? Config.SettingsConfig.primary : "transparent"
    implicitHeight: 40

    radius: Config.SettingsConfig.radiusSmall

    // =========================================================================
    // CONTENT
    // =========================================================================

    Text {
        anchors {
            left: parent.left
            leftMargin: Config.SettingsConfig.spacingMedium
            verticalCenter: parent.verticalCenter
        }
        text: root.text
        font.pixelSize: Config.SettingsConfig.fontSizeBody
        font.family: Config.SettingsConfig.fontFamily
        color: root.isActive ? Config.ThemeConfig.colors.background : Config.SettingsConfig.text

        Behavior on color {
            ColorAnimation { duration: Config.SettingsConfig.animDurationFast }
        }
    }

    // =========================================================================
    // INTERACTION
    // =========================================================================

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // Hover effect
    Rectangle {
        anchors.fill: parent
        color: Config.SettingsConfig.border
        opacity: mouseArea.containsMouse && !root.isActive ? 0.3 : 0
        radius: Config.SettingsConfig.radiusSmall

        Behavior on opacity {
            NumberAnimation { duration: Config.SettingsConfig.animDurationFast }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onClicked: mouse.accepted = false
    }
}
