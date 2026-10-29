// =============================================================================
// PluginHost.qml — mounts service + overlay plugins, owns the `plugins` IPC
// =============================================================================
// Placed once in shell.qml (NOT in a style scene) so headless services and
// full-screen overlays survive bar style swaps. Bar widgets are mounted by
// the scenes through PluginSlot + PluginRegistry.mount. A bar-widget or
// overlay may ALSO declare entryPoints.service — a headless root mounted
// here once per plugin (not per output) and exposed to its views as
// ctx.service (the service/view split).
//
// IPC (qs -c bar ipc call plugins <fn> …) — Quickshell IPC has no optional
// params, so pass "" / "{}" where an argument is unused:
//   rescan · reload <id> · list · layout · enable <id> · disable <id>
//   place <id> <left|center|right> <index|end> · move <id> <up|down|upN|downN>
// (no negative numbers: the qs CLI would read "-1" as a flag)
//   summon <id> <payloadJson> · hide <id> · call <id> <verb> <arg>
//   settings <id> → {schema, values} · setSetting <id> <key> <valueJson>
// IpcHandler lives here, not in the registry singleton: it doesn't resolve
// inside qmldir-declared singletons on this Quickshell build.
// =============================================================================

import QtQuick
import Quickshell
import Quickshell.Io

// Zero-size, NOT visible:false — Quickshell windows created in an invisible
// subtree stay unmapped, which hid overlay windows entirely.
Item {
    id: host
    width: 0
    height: 0

    // ── service plugins: headless (timers/processes only) ───────────────────
    Repeater {
        model: PluginRegistry.servicePlugins
        Loader {
            id: serviceLoader
            required property var modelData
            source: PluginRegistry.entryUrl(modelData, "service")
            // Hot reload swaps the item; the Loader itself survives, so its
            // Component.onDestruction never fires for the swap. Without this
            // guard the OUTGOING root lingers in PluginRegistry.instances and
            // instance()/call() serve a destroyed object (J6: reload left
            // every entryPoints.service plugin answering "not loaded").
            property var _mountedItem: null
            onItemChanged: {
                if (_mountedItem && _mountedItem !== item)
                    PluginRegistry.unmount(modelData.id, _mountedItem)
                _mountedItem = item
            }
            onLoaded: PluginRegistry.mount(item, modelData, "service", null)
            onStatusChanged: {
                if (status === Loader.Error)
                    PluginRegistry.reportError(modelData.id, "service failed to load (see journal)")
            }
            Component.onDestruction: PluginRegistry.unmount(modelData.id, item)
        }
    }

    // ── overlay plugins: keepLoaded — hidden until summoned ─────────────────
    Repeater {
        model: PluginRegistry.overlayPlugins

        // Item wrapper: the Loader carries the overlay window; Connections
        // watches its `shown` and claims/releases the popup slot on the flip.
        Item {
            id: overlaySlot
            required property var modelData

            Loader {
                id: overlayLoader
                source: PluginRegistry.entryUrl(overlaySlot.modelData, "overlay")
                // Same swap-guard as the service Loader above: a hot reload
                // replaces the item without destroying the Loader, so the
                // outgoing overlay root must be unmounted here.
                property var _mountedItem: null
                onItemChanged: {
                    if (_mountedItem && _mountedItem !== item)
                        PluginRegistry.unmount(overlaySlot.modelData.id, _mountedItem)
                    _mountedItem = item
                }
                onLoaded: PluginRegistry.mount(item, overlaySlot.modelData, "overlay", null)
                onStatusChanged: {
                    if (status === Loader.Error)
                        PluginRegistry.reportError(overlaySlot.modelData.id, "overlay failed to load (see journal)")
                }
            }
            Component.onDestruction: {
                PluginRegistry.unmount(overlaySlot.modelData.id, overlayLoader.item)
                PopupCoordinator.release("overlay:" + overlaySlot.modelData.id)
            }

            Connections {
                target: overlayLoader.item
                ignoreUnknownSignals: true
                function onShownChanged() {
                    var it = overlayLoader.item
                    var key = "overlay:" + overlaySlot.modelData.id
                    if (it && it.shown)
                        PopupCoordinator.request(key, function() { if (it && it.shown && typeof it.close === "function") it.close() })
                    else
                        PopupCoordinator.release(key)
                }
            }
        }
    }

    IpcHandler {
        target: "plugins"

        function rescan(): string {
            PluginRegistry.rescan()
            return "ok"
        }
        // Remount one plugin's roots from disk (hot reload).
        function reload(id: string): string {
            return PluginRegistry.reload(id)
        }
        function list(): string {
            var out = []
            var ps = PluginRegistry.plugins
            for (var i = 0; i < ps.length; i++)
                out.push({ id: ps[i].id, name: ps[i].name, version: ps[i].version,
                           kinds: ps[i].kinds, enabled: ps[i].enabled,
                           status: ps[i].status, error: ps[i].error,
                           commands: ps[i].commands, ipc: ps[i].ipc,
                           source: ps[i].source, overrides: ps[i].overrides,
                           section: PluginRegistry.sectionOf(ps[i].id),
                           position: PluginRegistry.positionOf(ps[i].id),
                           defaultSection: ps[i].defaultSection,
                           description: ps[i].description,
                           settings: ps[i].settings,
                           dir: ps[i].dir })
            return JSON.stringify(out, null, 1)
        }
        function enable(id: string): string {
            PluginRegistry.setEnabled(id, true)
            return "ok"
        }
        function disable(id: string): string {
            PluginRegistry.setEnabled(id, false)
            return "ok"
        }
        function layout(): string {
            return JSON.stringify(PluginRegistry.layout)
        }
        function place(id: string, section: string, index: string): string {
            if (index === "" || index === "end") return PluginRegistry.place(id, section, -1)
            if (!/^[0-9]+$/.test(index)) return "index must be a number or 'end'"
            return PluginRegistry.place(id, section, parseInt(index, 10))
        }
        function move(id: string, steps: string): string {
            var m = /^(up|down)([0-9]*)$/.exec(steps)
            if (!m) return "steps must be up, down, upN or downN"
            var n = m[2] === "" ? 1 : parseInt(m[2], 10)
            return PluginRegistry.move(id, m[1] === "up" ? -n : n)
        }
        function settings(id: string): string {
            return PluginRegistry.settingsJson(id)
        }
        function setSetting(id: string, key: string, valueJson: string): string {
            return PluginRegistry.setSetting(id, key, valueJson)
        }
        // Overlays take a JSON payload ({"query":"pid:4242"}-style deep
        // links); widget plugins ignore it.
        function summon(id: string, payload: string): string {
            return PluginRegistry.summon(id, payload || "{}")
        }
        function hide(id: string): string {
            return PluginRegistry.hide(id)
        }
        // Plugin-declared verbs (manifest.ipc), e.g.
        //   qs -c bar ipc call plugins call nikos.keyboard next ""
        function call(id: string, verb: string, arg: string): string {
            return PluginRegistry.call(id, verb, arg)
        }
    }
}
