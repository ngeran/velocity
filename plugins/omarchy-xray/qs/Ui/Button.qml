import QtQuick
Rectangle {
    id: root
    property string iconText: ""
    property string text: ""
    property int fontSize: 12
    property int iconSize: 14
    property bool leftAlign: false
    property bool bordered: false
    property bool focusable: false
    property bool selected: false
    property string tooltipText: ""
    property color foreground: "#c0caf5"
    property color background: "transparent"
    property color accent: "#BB9AF7"
    property string fontFamily: "JetBrains Mono"
    property int radius: 6
    property int horizontalPadding: 8
    property int verticalPadding: 6
    signal clicked()
    color: ma.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
                            : (selected ? Qt.rgba(accent.r, accent.g, accent.b, 0.12) : background)
    border.width: (bordered || activeFocus || selected) ? 1 : 0
    border.color: selected ? accent : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.16)
    Behavior on color { ColorAnimation { duration: 90 } }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        x: root.leftAlign ? root.horizontalPadding : (parent.width - width) / 2
        text: root.text !== "" ? root.text : root.iconText
        font.family: root.fontFamily
        font.pixelSize: root.text !== "" ? root.fontSize : root.iconSize
        color: root.foreground
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
