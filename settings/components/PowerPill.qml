import QtQuick
import "../config" as Config

Rectangle {
    property bool on: false
    signal clicked()

    width: 42; height: 20
    color: on ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.18) : "transparent"
    border.color: Config.ControlConfig.accent; border.width: 1
    radius: 10

    Behavior on color { ColorAnimation { duration: 140 } }

    Rectangle {
        x: on ? parent.width - width - 2 : 2
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14
        radius: 7
        color: Config.ControlConfig.accent

        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
}
