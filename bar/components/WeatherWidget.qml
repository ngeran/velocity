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
    // Extra trailing pad: Nerd Font glyphs overshoot their advance width, so
    // the condition glyph's ink can visually collide with the next tray icon
    // even when the layouts don't overlap.
    width: weatherRow.implicitWidth + 12
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
            // Theme tokens (Lunar: success #E0AF68 / textDim #73A6CB) — picked
            // from the active palette but token-bound so they follow theme swaps.
            color: Config.ThemeConfig.colors.success
        }
        Text {
            text: Services.WeatherService.temp
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: 11
            color: Config.ThemeConfig.colors.textDim
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
