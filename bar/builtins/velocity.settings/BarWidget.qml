// velocity.settings — built-in bar widget, a thin wrapper over components/SettingsIcon.qml.
// Left click: the Control Center floating panel (UX U1 — was the tray card
// "control" body); right click: the hosted settings dashboard (P2.1 — same
// process, via ctx.host). The dashboard has no keybind; SUPER+A is the CC.
import QtQuick
import "../../components" as Components

Components.SettingsIcon {
    id: root
    property var ctx: null
    readonly property var host: ctx ? ctx.host : null

    controlCenter: !!host
    isActive: !!host && host.ccShown === true
    onControlRequested: if (host) host.toggleControlCenter()
    onSettingsRequested: if (host) host.settingsToggle()
}
