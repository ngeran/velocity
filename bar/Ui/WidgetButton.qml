// qs.Ui/WidgetButton.qml — compat button for Quattro bar-widget plugins.
// Passive surface + onPressed(mouse) carrying the Qt.MouseButton; the
// deriving plugin draws its own label content on top (labelRow pattern).
import QtQuick
import "../Commons" as CT

Item {
    id: wbtn

    property string text: " "
    property real fixedWidth: 0
    property real scaledHorizontalMargin: 8
    property color foreground: "#ffffff"
    property bool active: hoverMa.containsMouse
    property bool useActiveColor: true
    property color activeColor: CT.Theme.colors.primary
    property string fontFamily: "monospace"
    property int fontSize: 13
    property var bar: null
    property string tooltipText: ""

    readonly property bool tooltipHovered: visible && hoverMa.containsMouse

    signal pressed(int button)
    signal wheelMoved(int delta)

    implicitWidth: fixedWidth > 0 ? fixedWidth : iconText.implicitWidth + scaledHorizontalMargin * 2
    implicitHeight: 26

    Text {
        id: iconText
        anchors.centerIn: parent
        text: wbtn.text
        font.family: wbtn.fontFamily
        font.pixelSize: wbtn.fontSize
        // Render the button's own text (upstream behaviour). Plugins that draw
        // their own labels pass text: " " so nothing shows behind them.
        color: wbtn.foreground
    }

    MouseArea {
        id: hoverMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) { wbtn.pressed(mouse.button) }
        onWheel: function(wheel) { wbtn.wheelMoved(wheel.angleDelta.y) }
    }
}
