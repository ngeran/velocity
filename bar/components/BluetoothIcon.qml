// BluetoothIcon.qml — tray glyph; emits trayRequested on click.
// The shared TrayCard (in shell.qml) shows the bluetooth info.
import QtQuick
import "../services" as Services
import "../config" as Config

Item {
    id: root
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.barHeight

    property bool isActive: false
    signal trayRequested()

    Text {
        anchors.centerIn: parent
        text: Services.BluetoothService.powered ? "󰂯" : "󰂲"
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
        onClicked: root.trayRequested()
    }
}
