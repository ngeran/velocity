// CoreCard.qml — Command-Center card: rounded, bordered, top-gradient accent
// line. Content is laid out in an inner ColumnLayout; the card's height follows
// the content (childrenRect) so it stacks correctly in a scrolling column.

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root
    default property alias content: slot.data
    property color accent: Config.ThemeConfig.colors.primary
    property int contentSpacing: 14
    radius: 4
    color: "transparent"
    border.color: Config.ThemeConfig.colors.outlineVariant
    border.width: 1
    // Size to content (16px top + 16px bottom padding). Layouts read
    // implicitHeight to size managed children; height mirrors it so the card
    // also renders correctly when anchored standalone.
    implicitHeight: slot.implicitHeight + 32
    height: slot.implicitHeight + 32

    ColumnLayout {
        id: slot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 16
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
