// =============================================================================
// Pill.qml — the small click-action chip (C4 primitive, I7)
// =============================================================================
// One pill for plugin rows and display actions: mono label, three styles
// (default surface · accentStyle · danger), hover brighten, `activated()` out.
// Caller owns the action; the pill holds no state.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root

    property string text: ""
    property bool accentStyle: false
    property bool danger: false
    signal activated()

    Layout.alignment: Qt.AlignVCenter
    width: label.implicitWidth + 18
    height: 24
    radius: Config.ControlConfig.radiusPill
    color: root.danger ? (ma.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.22)
                                           : Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.12))
                       : root.accentStyle ? (ma.containsMouse ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.24)
                                                              : Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.14))
                       : (ma.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.08)
                                           : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5))
    border.color: root.danger ? Config.ThemeConfig.colors.error
                              : root.accentStyle ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
    border.width: 1
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 9
        font.bold: true
        color: root.danger ? Config.ThemeConfig.colors.error
                           : root.accentStyle ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
