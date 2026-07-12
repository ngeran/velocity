// BatteryIcon.qml — tray glyph; emits trayRequested on click.
// The shared TrayCard (in shell.qml) shows the power info.
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
        text: Services.BatteryService.glyph
        font.family: Config.BarConfig.fontNerd
        font.pixelSize: Config.BarConfig.fontSizeIcon
        color: {
            if (root.isActive) return Config.BarConfig.colorAccent
            if (!Services.BatteryService.hasBattery) return Config.BarConfig.colorText
            if (Services.BatteryService.charging)       return "#68d391"
            if (Services.BatteryService.percentage <= 20) return "#f87171"
            if (Services.BatteryService.percentage <= 50) return "#fbbf24"
            return Config.BarConfig.colorText
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.trayRequested()
    }
}
