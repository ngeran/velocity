// =============================================================================
// HudMeterBar.qml — thin glow progress bar (VRAM / swap / sub-engines / pump)
// =============================================================================
// Well rectangle + fill + a soft bleed behind the fill (the mock's amber
// box-shadow). width is consumer-driven (Layout.fillWidth / anchors).
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: root

    property real value: 0          // 0..100
    property real maximum: 100
    property color fill: Config.HudConfig.amber
    property real glowAlpha: 0.35
    property int barHeight: 4
    property color wellColor: Config.HudConfig.well

    implicitWidth: 120
    height: barHeight
    radius: 1
    color: wellColor
    clip: false

    readonly property real frac: maximum > 0
        ? Math.max(0, Math.min(1, value / maximum)) : 0

    // glow bleed (taller than the well, renders outside — clip is off)
    Rectangle {
        x: 0
        y: -2
        width: parent.width * parent.frac
        height: parent.height + 4
        radius: 2
        color: Config.ThemeConfig.tint(root.fill, root.glowAlpha)
        visible: parent.frac > 0
    }
    Rectangle {
        width: parent.width * parent.frac
        height: parent.height
        radius: 1
        color: root.fill
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
    }
}
