// =============================================================================
// nikos.storage — headless service root (entryPoints.service)
// =============================================================================
// Mounts ONCE per bar process (B4 split, WeatherService pattern): pushes
// settings into the singleton and keeps the drive inventory warm with one
// cold 10-min tick, so the bar pill's used-% and warn tint stay truthful
// without any per-output polling. The first inventory also lands here —
// views never configure or fetch.
// =============================================================================
import QtQuick
import "." as Storage

Item {
    id: svcRoot

    // ctx lands after mount (post-Component.onCompleted) — the host's
    // PluginRegistry.mount assigns it; declare it or the bindings throw.
    property var ctx: null

    readonly property var _settings: ctx ? ctx.settings.values : null

    on_SettingsChanged: Storage.StorageService.configure(_settings)

    Timer {
        interval: 600000   // cold tick — see StorageService's cadence note
        repeat: true
        running: svcRoot.ctx !== null
        onTriggered: Storage.StorageService.refresh()
    }

    Component.onCompleted: {
        Storage.StorageService.configure(_settings)
        Storage.StorageService.refresh()
        console.log("[nikos.storage] service mounted — drive inventory warming")
    }
}
