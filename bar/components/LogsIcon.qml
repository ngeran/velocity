// LogsIcon.qml — System Logs overlay glyph; hover reveals "LOGS".
import QtQuick
import "../config" as Config

Item {
    id: root
    implicitWidth: iconRow.implicitWidth
        height: Config.BarConfig.barHeight
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    property bool isActive: false
    signal triggered()

    readonly property bool expanded: mouseArea.containsMouse

    Row {
        id: iconRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.expanded ? 6 : 0

        Text {
            text: "󰗋"
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.BarConfig.fontSizeIcon
            color: (mouseArea.containsMouse || root.isActive) ? Config.ThemeConfig.colors.accent : Config.ThemeConfig.colors.primary
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            visible: root.expanded
            text: "LOGS"
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: 11
            color: Config.ThemeConfig.colors.text
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
