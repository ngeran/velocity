// =============================================================================
// SettingsCard.qml — soft content card (Shibumi refresh, Controls-scoped)
// =============================================================================
// The Controls section's card primitive: radius-10 surface, 1px outline,
// 16px inner padding, content drops into an inner ColumnLayout via the
// default `content` alias — same shape as HudCard, modern styling.
//
// HudCard (corner brackets, zero radius) is deliberately NOT touched: it is
// used by 15+ components in Core/Theme/Wallpaper/Dashboard, which are
// outside this refresh's section scope.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root
    default property alias content: slot.data

    // Accent is informational only for now (reserved for a future top tick);
    // kept for API compatibility with HudCard call sites.
    property color accent: Config.ControlConfig.accent
    property int contentSpacing: Config.ControlConfig.space3

    radius: Config.ControlConfig.radiusCard
    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.55)
    border.color: Config.ThemeConfig.colors.outlineVariant
    border.width: 1

    // Preferred height = content + 16px top/bottom padding. Only
    // implicitHeight is exposed so a layout may still stretch the card.
    implicitHeight: slot.implicitHeight + 32

    ColumnLayout {
        id: slot
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.leftMargin: 16; anchors.rightMargin: 16
        anchors.topMargin: 16; anchors.bottomMargin: 16
        spacing: root.contentSpacing
    }
}
