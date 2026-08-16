// LogsIcon.qml — tray glyph for the System Logs overlay; emits triggered on
// click. The LogsOverlay (instantiated in shell.qml) shows the journal view.
import QtQuick
import "../config" as Config

Item {
    id: root
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.barHeight

    property bool isActive: false
    signal triggered()

    Text {
        anchors.centerIn: parent
        text: "󰗋"
        font.family: Config.BarConfig.fontNerd
        font.pixelSize: Config.BarConfig.fontSizeIcon
        color: (mouseArea.containsMouse || root.isActive) ? Config.BarConfig.colorAccent : Config.BarConfig.colorText
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
