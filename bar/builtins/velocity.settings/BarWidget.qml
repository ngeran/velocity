// velocity.settings — built-in bar widget, a thin wrapper over components/SettingsIcon.qml.
// Left click: Control Center (host tray card "control"); right click: the
// hosted settings dashboard (P2.1 — same process, via ctx.host).
import QtQuick
import "../../components" as Components

Components.SettingsIcon {
    id: root
    property var ctx: null
    readonly property var host: ctx ? ctx.host : null

    controlCenter: !!host
    isActive: !!host && host.trayOpenOn(ctx.window, "control")
    onControlRequested: if (host) host.toggleTray(ctx.window, "control", root)
    onSettingsRequested: if (host) host.settingsToggle()
}
