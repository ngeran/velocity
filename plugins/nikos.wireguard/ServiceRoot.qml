// =============================================================================
// nikos.wireguard — headless service root (entryPoints.service)
// =============================================================================
// Mounts ONCE per bar process (nikos.storage pattern): pushes settings into
// both qmldir singletons and kicks their first poll, so the bar pill's
// shield/lock is honest whether or not the panel has ever been opened.
// Views never configure or fetch.
// =============================================================================
import QtQuick
import "." as WG

Item {
    id: svcRoot

    // ctx lands after mount (post-Component.onCompleted) — the host's
    // PluginRegistry.mount assigns it; declare it or the bindings throw.
    property var ctx: null

    readonly property var _settings: ctx ? ctx.settings.values : null

    on_SettingsChanged: {
        WG.WireGuardService.configure(_settings)
        WG.TailscaleService.configure(_settings)
    }

    Component.onCompleted: {
        WG.WireGuardService.configure(_settings)
        WG.TailscaleService.configure(_settings)
        WG.WireGuardService.refresh()
        WG.TailscaleService.refresh()
        console.log("[nikos.wireguard] service mounted — tunnel/tailscale state warming")
    }
}
