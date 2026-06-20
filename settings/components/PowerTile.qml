import QtQuick
import "../config" as Config

Rectangle {
    id: tile

    signal activated()

    property string iconText:  "⏻"
    property string labelText: "ACTION"

    // Internal hover state
    property bool hovered: false

    color:  Config.ThemeConfig.colors.surface
    border.color: hovered ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border
    border.width: 1
    clip: true

    // Radial glow overlay (visible on hover)
    Rectangle {
        anchors.fill: parent
        opacity: tile.hovered ? 1 : 0
        color: Qt.rgba(Config.ThemeConfig.colors.secondary.r, Config.ThemeConfig.colors.secondary.g, Config.ThemeConfig.colors.secondary.b, 0.15)
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    // Scale transform
    transform: Scale {
        id: tileScale
        xScale: tile.hovered ? 1.01 : 1.0
        yScale: tile.hovered ? 1.01 : 1.0
        origin.x: tile.width  / 2
        origin.y: tile.height / 2
        Behavior on xScale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on yScale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    // Icon
    Text {
        id: tileIcon
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -16
        text: tile.iconText
        font.pixelSize: 48
        color: tile.hovered ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
        states: State {
            when: tile.hovered
            PropertyChanges { target: tileIcon; anchors.verticalCenterOffset: -28 }
        }
    }

    // Label
    Text {
        anchors {
            bottom: parent.bottom
            bottomMargin: 32
            horizontalCenter: parent.horizontalCenter
        }
        text: tile.labelText
        font.family:      "JetBrainsMono Nerd Font"
        font.pixelSize:   12
        font.weight:      Font.Medium
        font.letterSpacing: tile.hovered ? 4 : 1.8
        color: tile.hovered ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.outline
        opacity: tile.hovered ? 1.0 : 0.5
        Behavior on opacity      { NumberAnimation { duration: 200 } }
        Behavior on color        { ColorAnimation  { duration: 200 } }
        Behavior on font.letterSpacing { NumberAnimation { duration: 200 } }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered:  tile.hovered = true
        onExited:   tile.hovered = false
        onClicked:  tile.activated()
        onPressed:  {
            tileScale.xScale = 0.97
            tileScale.yScale = 0.97
        }
        onReleased: {
            tileScale.xScale = tile.hovered ? 1.01 : 1.0
            tileScale.yScale = tile.hovered ? 1.01 : 1.0
        }
    }
}
