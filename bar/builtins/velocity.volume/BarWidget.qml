// velocity.volume — built-in bar widget, a thin wrapper over components/VolumeIcon.qml.
import QtQuick
import "../../components" as Components

// The host owns the one tray card (ctx.host.toggleTray); it opens on this
// widget's window, centered under it.
Components.VolumeIcon {
    id: root
    property var ctx: null
    readonly property var host: ctx ? ctx.host : null

    isActive: !!host && host.trayOpenOn(ctx.window, "volume")
    onTrayRequested: if (host) host.toggleTray(ctx.window, "volume", root)

    // IPC parity with the plugin pills (QA scenarios open the card this way).
    function toggle() {
        if (host) host.toggleTray(ctx.window, "volume", root)
    }
}
