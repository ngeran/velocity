// KeyboardWidget.qml — active XKB layout code (US/GR) + keyboard glyph.
// Click cycles to the next configured layout (kb_layout in look-and-feel.lua,
// switched via KeyboardService / hyprctl switchxkblayout). Hidden until the
// layout list is known — same no-placeholder contract as WeatherWidget.
import QtQuick
import "../services" as Services
import "../config" as Config

Item {
    id: root
    // Trailing pad matches WeatherWidget: Nerd Font glyph ink overshoots its
    // advance width and can visually collide with the neighbour widget.
    width: layoutRow.implicitWidth + 12
    height: Config.BarConfig.barHeight
    visible: Services.KeyboardService.layoutCount > 0

    Row {
        id: layoutRow
        anchors.centerIn: parent
        // ADJUSTMENT: Move the entire row down by 2px to vertically center
        // the keyboard icon with the text glyph. The Nerd Font icon sits
        // slightly high in its bounding box; this offset compensates for it.
        anchors.verticalCenterOffset: 0
        spacing: 5
        Text {
            text: "󰌌"   // nf-md-keyboard
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.BarConfig.fontSizeIcon
            color: Config.ThemeConfig.colors.textDim
        }
        Text {
            text: Services.KeyboardService.activeLabel
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
            color: mouseArea.containsMouse
                ? Config.BarConfig.colorAccent
                : Config.ThemeConfig.colors.textDim
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Services.KeyboardService.switchNext()
    }
}
