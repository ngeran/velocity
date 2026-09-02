// CoreBar.qml — neon progress bar (track + glow + fill), theme-token colours.
// value: 0..100. barColor defaults to secondary (blue). Pure visual, no data.

import QtQuick
import "../config" as Config

Item {
    id: root
    property real value: 0.0
    property color barColor: Config.ThemeConfig.colors.secondary
    property color trackColor: Config.ThemeConfig.colors.outlineVariant
    property real barHeight: 4
    // Animate width transitions? Default false: CoreBar is used for live
    // telemetry (CPU/GPU/memory) that refreshes ~1×/s — animating width on
    // every tick produces N concurrent 250ms relayouts across the grid for no
    // perceptible benefit. Set animate: true only for interactive sliders.
    property bool animate: false
    height: barHeight
    clip: false

    readonly property real _frac: Math.max(0, Math.min(100, value)) / 100.0

    Rectangle { anchors.fill: parent; radius: height / 2; color: root.trackColor }   // track

    Rectangle {                                                       // neon glow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * root._frac
        height: parent.height + 4
        radius: (parent.height + 4) / 2
        color: root.barColor
        opacity: root._frac > 0 ? 0.30 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Rectangle {                                                       // fill
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * root._frac
        height: parent.height
        radius: parent.height / 2
        color: root.barColor
        Behavior on width { enabled: root.animate; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }
}
