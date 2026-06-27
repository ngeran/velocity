// NetworkIcon.qml — tray glyph; emits trayRequested on click.
// The shared TrayCard (in shell.qml) shows the network info.
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
        text: !Services.NetworkService.isConnected ? "󰖪"
              : (Services.NetworkService.connectionType === "wifi" ? "󰖩" : "󰈀")
        font.family: Config.BarConfig.fontNerd
        font.pixelSize: 14
        color: root.isActive ? Config.BarConfig.colorAccent : Config.BarConfig.colorText
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.trayRequested()
    }
}
