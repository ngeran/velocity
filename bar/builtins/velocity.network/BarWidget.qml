// velocity.network — built-in bar widget, a thin wrapper over components/NetworkIcon.qml.
import QtQuick
import "../../components" as Components

// The host owns the one tray card (ctx.host.toggleTray); it opens on this
// widget's window, centered under it.
Components.NetworkIcon {
    id: root
    property var ctx: null
    readonly property var host: ctx ? ctx.host : null

    isActive: !!host && host.trayOpenOn(ctx.window, "network")
    onTrayRequested: if (host) host.toggleTray(ctx.window, "network", root)
}
