// =============================================================================
// DashboardCard.qml — Theme-reactive card for the dashboard bento grid
// =============================================================================
// Container card with theme-aware border/background. Default look is the
// original glass card (radius respects SettingsConfig.radiusMd, no brackets).
// Opt into the tactical HUD look (matching HudCard) with:
//   DashboardCard { accent: ThemeConfig.colors.secondary; showBrackets: true; ... }
// → sharp zero-radius corners + 4 corner brackets + accent-tinted top line.
//
// PUBLIC API:
//   default property alias content: contentItem.data  — content slot
//   property color accent   — top-line + bracket + hover-border colour
//   property bool showBrackets — tactical corner brackets + radius 0
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: root

    default property alias content: contentItem.data

    property color accent: Config.ThemeConfig.colors.secondary
    property bool showBrackets: false

    color: root.showBrackets ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4) : "transparent"
    radius: root.showBrackets ? 0 : Config.SettingsConfig.radiusMd
    border.color: Config.ThemeConfig.colors.outlineVariant
    border.width: 1

    property bool isHovered: false

    Behavior on color { ColorAnimation { duration: Config.SettingsConfig.animDurationSlow; easing.type: Easing.OutQuad } }
    Behavior on border.color { ColorAnimation { duration: Config.SettingsConfig.animDurationSlow; easing.type: Easing.OutQuad } }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: 16
        // CRITICAL: clip prevents ColumnLayout/RowLayout children from
        // driving their implicitHeight back up through the parent chain
        // and expanding the card beyond its assigned bento-grid size.
        clip: true
    }

    // Accent top-edge highlight — brightens on hover for depth.
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 1
        color: root.accent
        opacity: root.isHovered ? 0.55 : 0.12
        Behavior on opacity { NumberAnimation { duration: Config.SettingsConfig.animDurationSlow; easing.type: Easing.OutQuad } }
    }

    // Tactical corner brackets (only when showBrackets). index 0=TL 1=TR 2=BL 3=BR.
    Repeater {
        model: root.showBrackets ? 4 : 0
        Item {
            width: 12; height: 12; opacity: 0.7
            x: (index === 0 || index === 2) ? -1 : (root.width - 11)
            y: (index === 0 || index === 1) ? -1 : (root.height - 11)
            property bool isRight: (index === 1 || index === 3)
            property bool isBottom: (index === 2 || index === 3)
            Rectangle { width: 12; height: 2; color: root.accent; y: parent.isBottom ? 10 : 0 }
            Rectangle { width: 2; height: 12; color: root.accent; x: parent.isRight ? 10 : 0 }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.isHovered = true
        onExited: root.isHovered = false
        cursorShape: Qt.ArrowCursor
        propagateComposedEvents: true
        onClicked: mouse.accepted = false
        onPressAndHold: mouse.accepted = false
        onPressed: mouse.accepted = false
        onReleased: mouse.accepted = false
    }

    onIsHoveredChanged: {
        border.color = isHovered ? root.accent : Config.ThemeConfig.colors.outlineVariant
    }
}
