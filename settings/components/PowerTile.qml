// =============================================================================
// PowerTile.qml — modern icon-forward action card for the Power menu
// =============================================================================
// Clean vertical card: centred glyph over a label, a faint surface fill that
// washes to the action's accent on hover, the glyph scaling up and an accent
// bar sliding in along the bottom. Sharp corners + System Info card vocabulary.
// `accent` gives each action a semantic tint (error/warning/secondary/primary).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: tile

    signal activated()

    property string iconText:  "⏻"
    property string labelText: "ACTION"
    property color  accent:    Config.ThemeConfig.colors.secondary

    color: ma.containsMouse
        ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.10)
        : Qt.rgba(Config.ThemeConfig.colors.surfaceVariant.r, Config.ThemeConfig.colors.surfaceVariant.g, Config.ThemeConfig.colors.surfaceVariant.b, 0.22)
    border.color: ma.containsMouse ? tile.accent : Config.ThemeConfig.colors.border
    border.width: 1
    clip: true
    Behavior on color        { ColorAnimation { duration: 180 } }
    Behavior on border.color { ColorAnimation { duration: 180 } }

    transform: Scale {
        id: tileScale
        xScale: 1; yScale: 1
        origin.x: tile.width / 2; origin.y: tile.height / 2
        Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    ColumnLayout {
        anchors.fill: parent; spacing: 10

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: tile.iconText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 42
            scale: ma.containsMouse ? 1.08 : 1.0
            color: ma.containsMouse ? tile.accent : Config.ThemeConfig.colors.textDim
            Behavior on scale  { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color  { ColorAnimation  { duration: 150 } }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: tile.labelText
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 11; font.bold: true; font.letterSpacing: 2.5
            color: ma.containsMouse ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Item { Layout.fillHeight: true }
    }

    // accent "active" indicator along the bottom
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 2; color: tile.accent
        opacity: ma.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked:  tile.activated()
        onPressed:  { tileScale.xScale = 0.97; tileScale.yScale = 0.97 }
        onReleased: { tileScale.xScale = 1.0;   tileScale.yScale = 1.0 }
    }
}
