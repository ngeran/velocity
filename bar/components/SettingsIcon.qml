// =============================================================================
// SettingsIcon.qml — bar trigger for the settings dashboard (gear glyph)
// =============================================================================
// Sits in the right-side rail (bar-config.json "rightLayout": "settings").
// Click: if the settings instance is running, IPC-toggle its window; if not,
// spawn it detached. One sh line covers both — ipc exits non-zero with
// "Target not found" when nothing owns the target, and the || branch spawns.
//
// Self-contained on purpose: unlike LogsIcon/NotificationButton (which route
// through the host to in-process overlays), the dashboard is a SEPARATE
// process — there is no host handler to call. The `show` verb is
// intentionally avoided: `show` is a quickshell ipc CLI subcommand and never
// parses as a function name (see ModernDashboard). Toggle is also honest UX:
// click the gear when open → closes.
// =============================================================================

import QtQuick
import Quickshell.Io
import "../config" as Config

Item {
    id: root
    implicitWidth: iconRow.implicitWidth
    height: Config.BarConfig.barHeight
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // Rail parity (LogsIcon/NotificationButton carry it); no feedback channel
    // from the settings process exists yet — the bar cannot know its state.
    property bool isActive: false

    readonly property bool expanded: mouseArea.containsMouse

    Process {   // unbounded-ok: one-shot ipc toggle / detached spawn — exits at once
        id: launcher
        command: []
    }

    function activate() {
        launcher.command = ["sh", "-c",
            "quickshell ipc -c settings call SettingsWindow toggle 2>/dev/null || " +
            "setsid quickshell -c settings >/dev/null 2>&1 &"]
        launcher.running = true
    }

    Row {
        id: iconRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.expanded ? 6 : 0

        Text {
            text: "\u{F0492}"   // nf-md-settings — the gear
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.BarConfig.fontSizeIcon
            color: (mouseArea.containsMouse || root.isActive) ? Config.ThemeConfig.colors.accent : Config.ThemeConfig.colors.primary
            anchors.verticalCenter: parent.verticalCenter
            scale: mouseArea.containsMouse ? 1.08 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
        Text {
            visible: root.expanded
            text: "SETTINGS"
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: 11
            color: Config.ThemeConfig.colors.text
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }
}
