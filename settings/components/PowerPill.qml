import QtQuick
import "../config" as Config

Rectangle {
    property bool on: false
    signal clicked()

    width: 44; height: 24
    color: on ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.22)
              : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
    border.color: on ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
    border.width: 1
    radius: 12

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    Rectangle {
        x: on ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 18; height: 18
        radius: 9
        color: Config.ControlConfig.accent

        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: parent.clicked()
    }
}
