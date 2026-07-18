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
    height: barHeight
    clip: false

    readonly property real _frac: Math.max(0, Math.min(100, value)) / 100.0

    Rectangle { anchors.fill: parent; color: root.trackColor }       // track

    Rectangle {                                                       // neon glow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * root._frac
        height: parent.height + 4
        color: root.barColor
        opacity: root._frac > 0 ? 0.30 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Rectangle {                                                       // fill
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * root._frac
        height: parent.height
        color: root.barColor
        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }
}
