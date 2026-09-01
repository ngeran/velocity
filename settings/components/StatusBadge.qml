// =============================================================================
// StatusBadge.qml — semantic dot + label chip (Shibumi refresh)
// =============================================================================
// Tiny status indicator: colored dot + 10px uppercase label. Colors resolve
// through ThemeConfig semantic tokens — kind drives the mapping.
//
//   kind: "ok" (success) · "warn" (warning) · "err" (error)
//         "accent" (active) · "idle" (textDim)
// =============================================================================

import QtQuick
import "../config" as Config

Row {
    id: root

    property string label: ""
    property string kind: "accent"

    readonly property color c: kind === "ok"     ? Config.ThemeConfig.colors.success
                             : kind === "warn"   ? Config.ThemeConfig.colors.warning
                             : kind === "err"    ? Config.ThemeConfig.colors.error
                             : kind === "idle"   ? Config.ThemeConfig.colors.textDim
                                                 : Config.ControlConfig.accent

    spacing: 6

    Rectangle {
        width: 6; height: 6; radius: 3
        color: root.c
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: root.label
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 0.6
        color: root.c
        anchors.verticalCenter: parent.verticalCenter
    }
}
