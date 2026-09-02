// CoreCard.qml — Core section card (Shibumi / DESIGN_TOKENS): radius 12,
// tinted surface, 1px outline, top-gradient accent line. Content is laid out
// in an inner ColumnLayout; the card sizes to content but a layout may still
// stretch it (only implicitHeight is exposed for width/height management).

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root
    default property alias content: slot.data
    property color accent: Config.ThemeConfig.colors.primary
    property int contentSpacing: Config.ControlConfig.space3
    radius: 12
    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.55)
    border.color: Config.ThemeConfig.colors.outlineVariant
    border.width: 1
    // Size to content (12px padding per DESIGN_TOKENS row padding).
    implicitHeight: slot.implicitHeight + 24

    ColumnLayout {
        id: slot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: root.contentSpacing
    }

    // Top gradient accent line (mock's data-card::before)
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 1
        opacity: 0.25
        gradient: Gradient {
            orientation: Qt.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: root.accent }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
