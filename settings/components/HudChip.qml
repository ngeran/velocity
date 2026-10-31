// =============================================================================
// HudChip.qml — bordered mono micro-badge (mock's RTX 5080 / ACTIVE / FIXED)
// =============================================================================
// `filled` renders the active state: accent background + black text.
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: root

    property string text: ""
    property color accent: Config.HudConfig.amber
    property bool filled: false

    signal picked()

    height: 16
    width: chipText.implicitWidth + 12
    radius: 3
    color: filled ? accent
                  : (chipMA.containsMouse
                     ? Config.ThemeConfig.tint(accent, 0.10)
                     : "transparent")
    border.color: filled ? accent : Config.ThemeConfig.tint(accent, 0.45)
    border.width: 1
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        id: chipText
        anchors.centerIn: parent
        text: root.text.toUpperCase()
        color: root.filled ? "#0a0a0a" : root.accent
        font.family: Config.HudConfig.fontData
        font.pixelSize: 9
        font.bold: true
        font.letterSpacing: 0.6
    }
    MouseArea {
        id: chipMA
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()   // no-op unless a consumer connected a handler
    }
}
