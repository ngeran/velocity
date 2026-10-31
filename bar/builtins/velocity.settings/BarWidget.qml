// velocity.settings — built-in bar widget, a thin wrapper over components/SettingsIcon.qml.
// Both buttons open the hosted settings dashboard (P2.1 — same process, via
// ctx.host). UX U1 removal: the Control Center panel is gone and its unique
// controls were dropped, not ported. SUPER+A/N open the dashboard too.
import QtQuick
import "../../components" as Components

Components.SettingsIcon {
    id: root
    property var ctx: null
    readonly property var host: ctx ? ctx.host : null

    isActive: !!host && host.settingsShown === true
    onSettingsRequested: if (host) host.settingsToggle()
}
