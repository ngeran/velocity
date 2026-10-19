// velocity.bluetooth — built-in bar widget, a thin wrapper over components/BluetoothIcon.qml.
import QtQuick
import "../../components" as Components

// The host owns the one tray card (ctx.host.toggleTray); it opens on this
// widget's window, centered under it.
Components.BluetoothIcon {
    id: root
    property var ctx: null
    readonly property var host: ctx ? ctx.host : null

    isActive: !!host && host.trayOpenOn(ctx.window, "bluetooth")
    onTrayRequested: if (host) host.toggleTray(ctx.window, "bluetooth", root)
}
