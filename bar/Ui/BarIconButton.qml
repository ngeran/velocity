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

    // Hover intent: glyph tint lands after a short entry delay (sweeping
    // must not shimmer); exit instant. 70/90ms literals mirror the
    // MotionConfig snap scale (Ui imports no config singletons — D13).
    readonly property bool hoverLive: ma.containsMouse
    property bool hot: false
    onHoverLiveChanged: {
        if (hoverLive) hotDelay.restart()
        else { hotDelay.stop(); hot = false }
    }
    Timer {
        id: hotDelay
        interval: 70
        onTriggered: root.hot = true
    }
    // Press grammar (transient 16% ink plate + 1px settle — QD-OLED-safe).
    // Named `down`: `pressed` is this component's compat signal.
    readonly property bool down: ma.pressed
    readonly property color ink: CT.Theme.colors.text

    Rectangle {
        anchors.fill: parent
        color: root.down ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16) : "transparent"
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        color: root.hot ? CT.Theme.colors.primary : CT.Theme.colors.text
        Behavior on color { ColorAnimation { duration: 120 } }
        transform: Translate {
            y: root.down ? 1 : 0
            Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        }
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
