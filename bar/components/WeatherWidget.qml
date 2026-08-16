// WeatherWidget.qml — tray-area condition glyph + temperature.
// Click toggles the settings dashboard (where the rich WeatherCard lives) —
// same contract as ClockWidget: the bar shows status, settings holds depth.
// Entirely hidden until the first valid sample lands (no "—" in the bar).
import QtQuick
import Quickshell.Io
import "../services" as Services
import "../config" as Config

Item {
    id: root
    width: weatherRow.implicitWidth + 6
    height: Config.BarConfig.barHeight
    visible: Services.WeatherService.hasData

    Row {
        id: weatherRow
        anchors.centerIn: parent
        spacing: 5
        Text {
            text: Services.WeatherService.glyph
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.BarConfig.fontSizeIcon
            color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorText
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            text: Services.WeatherService.temp
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: 11
            color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorText
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: settingsProc.running = true
    }

    Process {
        id: settingsProc
        command: ["quickshell", "ipc", "-c", "settings", "call", "SettingsWindow", "toggle"]
    }
}
