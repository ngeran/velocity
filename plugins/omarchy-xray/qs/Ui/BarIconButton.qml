import QtQuick
Rectangle {
    id: root
    property var bar: null
    property string text: ""
    property string fontFamily: "JetBrainsMono Nerd Font"
    property string tooltipText: ""
    signal pressed(var button)
    implicitWidth: 30
    implicitHeight: 22
    radius: 4
    color: ma.containsMouse ? Qt.rgba(0.75, 0.78, 0.9, 0.08) : "transparent"
    Behavior on color { ColorAnimation { duration: 90 } }
    Text {
        anchors.centerIn: parent
        text: root.text
        font.family: root.fontFamily
        font.pixelSize: 14
        color: ma.containsMouse ? "#c0caf5" : "#a9b1d6"
        Behavior on color { ColorAnimation { duration: 90 } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.pressed(root)
    }
}
