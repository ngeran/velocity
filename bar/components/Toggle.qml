// =============================================================================
// Toggle.qml — labeled toggle row: title (+ optional description) on the left,
// a ToggleSwitch on the right. Clicking anywhere on the row emits clicked();
// the caller flips `checked` (the component is value-stateless so it composes
// with model-driven UI and services that track desired state optimistically).
// =============================================================================
import QtQuick
import "../config" as Config

Item {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false
    property bool busy: false

    signal clicked()

    readonly property bool hot: mouse.containsMouse

    implicitHeight: Math.max(40, content.implicitHeight + 10)
    implicitWidth: content.implicitWidth

    Row {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Column {
            width: parent.width - track.width - parent.spacing
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            Text {
                textFormat: Text.PlainText
                text: root.label
                color: root.hot ? Config.ThemeConfig.colors.accent : Config.ThemeConfig.colors.text
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
                Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
            }
            Text {
                visible: root.description !== ""
                text: root.description
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: 9
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }

        ToggleSwitch {
            id: track
            checked: root.checked
            busy: root.busy
            interactive: false   // the row owns the click
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
