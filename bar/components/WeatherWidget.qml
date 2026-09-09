// WeatherWidget.qml — tray-area condition glyph + temperature.
// Click toggles the shared TrayCard's weather body (same tray contract as
// Network/Bluetooth/Volume/Battery/Timezone icons). Entirely hidden until the
// first valid sample lands (no "—" in the bar).
import QtQuick
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

    property bool isActive: false
    signal trayRequested()

    Row {
        id: weatherRow
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Text {
            text: Services.WeatherService.glyph
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.BarConfig.fontSizeIcon
            color: (root.isActive || mouseArea.containsMouse)
                   ? Config.BarConfig.colorAccent
                   : Config.ThemeConfig.colors.success
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            text: Services.WeatherService.temp
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: 11
            color: (root.isActive || mouseArea.containsMouse)
                   ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.textDim
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.trayRequested()
    }
}
