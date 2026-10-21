import QtQuick
Rectangle {
    id: root
    property string label: ""
    property string description: ""
    property bool checked: false
    property color foreground: "#c0caf5"
    property color accent: "#BB9AF7"
    property string fontFamily: "JetBrains Mono"
    property int titleSize: 11
    property int descriptionSize: 10
    property int radius: 6
    signal clicked()
    implicitHeight: content.implicitHeight + 10
    color: ma.containsMouse ? Qt.rgba(0.75, 0.78, 0.9, 0.05) : "transparent"
    Behavior on color { ColorAnimation { duration: 90 } }
    Row {
        id: content
        anchors.left: parent.left
        anchors.right: indicator.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: root.fontFamily
            font.pixelSize: root.titleSize
            color: root.checked ? root.accent : root.foreground
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.description !== ""
            text: root.description
            font.family: root.fontFamily
            font.pixelSize: root.descriptionSize
            color: root.foreground
            opacity: 0.55
            elide: Text.ElideRight
            width: Math.min(implicitWidth, content.width - x)
        }
    }
    Rectangle {
        id: indicator
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 8
        radius: 4
        color: root.checked ? root.accent : Qt.rgba(0.75, 0.78, 0.9, 0.18)
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
