// qs.Ui/BarIconButton.qml — compat icon button for Quattro bar-widgets.
// Surface converted plugins use (xray): bar (ignored — compat theme is
// process-wide), text (glyph), fontFamily, tooltipText, onPressed(button).
import QtQuick
import "../Commons" as CT

Item {
    id: root

    property var bar: null              // accepted for source compat; theme is CT.Theme
    property string text: ""
    property string fontFamily: "monospace"
    property int fontPixelSize: 13
    property string tooltipText: ""
    signal pressed(var button)

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 8

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        color: ma.containsMouse ? CT.Theme.colors.primary : CT.Theme.colors.text
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.pressed(root)
    }

    Rectangle {
        visible: ma.containsMouse && root.tooltipText !== ""
        anchors.top: parent.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: tipLabel.implicitWidth + 14
        height: tipLabel.implicitHeight + 8
        radius: 6
        color: CT.Theme.colors.background
        border.color: CT.Theme.colors.border
        border.width: 1
        z: 100
        Text {
            id: tipLabel
            anchors.centerIn: parent
            text: root.tooltipText
            font.family: "monospace"
            font.pixelSize: 9
            color: CT.Theme.colors.text
        }
    }
}
