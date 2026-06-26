// =============================================================================
// DashboardCard.qml — Theme-reactive glass card for dashboard bento grid
// =============================================================================
//
// A container card with theme-aware background and border, designed for the
// dashboard bento grid. Binds to ThemeConfig.colors.surfaceContainer for
// OLED-aware theming (pure black when OLED clamp is enabled).
//
// PUBLIC API:
//   default property alias content: contentItem.children  — content slot
//
// USAGE:
//   DashboardCard {
//       Text { text: "Hello"; anchors.centerIn: parent }
//   }
//
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: root

    // =========================================================================
    // PUBLIC API — content slot
    // =========================================================================
    default property alias content: contentItem.data

    // =========================================================================
    // VISUALS — theme-reactive glass card
    // =========================================================================
    color: "transparent"
    radius: Config.SettingsConfig.radiusMd
    border.color: Config.ThemeConfig.colors.outlineVariant
    border.width: 1

    // Hover state — border brightens
    property bool isHovered: false

    Behavior on color {
        ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    Behavior on border.color {
        ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    // =========================================================================
    // LAYOUT
    // =========================================================================
    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: 16
        // CRITICAL: clip prevents ColumnLayout/RowLayout children from
        // driving their implicitHeight back up through the parent chain
        // and expanding the card beyond its assigned bento-grid size.
        clip: true
    }

    // Faint accent top-edge highlight — brightens on hover for depth.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Config.ThemeConfig.colors.secondary
        opacity: root.isHovered ? 0.55 : 0.12
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // =========================================================================
    // HOVER DETECTION
    // =========================================================================
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.isHovered = true
        onExited: root.isHovered = false
        cursorShape: Qt.ArrowCursor
        // Pass mouse events through to content
        propagateComposedEvents: true
        onClicked: mouse.accepted = false
        onPressAndHold: mouse.accepted = false
        onPressed: mouse.accepted = false
        onReleased: mouse.accepted = false
    }

    // Apply hover state
    onIsHoveredChanged: {
        border.color = isHovered
            ? Config.ThemeConfig.colors.secondary
            : Config.ThemeConfig.colors.outlineVariant
    }
}
