// =============================================================================
// nikos.vnc — headless service root (entryPoints.service)
// =============================================================================
// Mounts ONCE per bar process (nikos.storage/wireguard pattern): pushes
// settings into the VncService singleton, kicks its first poll, and owns
// the ONLY ctx-touching action — the detached viewer launch. The plugin
// contract routes process launches through ctx.run (argv[0] must be in
// manifest.commands; "vncviewer" is), and the service singleton itself
// never sees ctx, so it stays headless-testable. Views never configure
// or fetch.
// =============================================================================
import QtQuick
import "." as VNC

Item {
    id: svcRoot

    // ctx lands after mount (post-Component.onCompleted) — the host's
    // PluginRegistry.mount assigns it; declare it or the bindings throw.
    property var ctx: null

    readonly property var _settings: ctx ? ctx.settings.values : null

    on_SettingsChanged: VNC.VncService.configure(_settings)

    Component.onCompleted: {
        VNC.VncService.configure(_settings)
        VNC.VncService.refresh()
        console.log("[nikos.vnc] service mounted — probe state warming")
    }

    // Viewer launch: the service emits a ready-to-run argv (host::port +
    // optional -PasswordFile/-FullScreen); ctx.run detaches it so the GUI
    // outlives the poll cycle. Fire-and-forget by design — liveness is the
    // pgrep probe's job, not the launcher's.
    Connections {
        target: VNC.VncService
        function onRequestConnect(argv) {
            if (!svcRoot.ctx || !argv || argv.length < 2) return
            svcRoot.ctx.run(argv)
        }
    }
}
