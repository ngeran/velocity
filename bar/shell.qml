// =============================================================================
// shell.qml — Quickshell bar entry point
// =============================================================================
//
// This is the main entry point for Quickshell. It creates a panel window
// and arranges all UI components.
//
// LAYOUT
//   Left & Right: Handled inside the RowLayout flow.
//   Center: Clock is absolute-positioned relative to the window parent,
//           guaranteeing perfect mathematical centering on your screen.
//
// CUSTOMIZATION
//   All colors and sizes are configured in config/BarConfig.qml
// =============================================================================

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "components" as Components
import "config" as Config
import "services" as Services

ShellRoot {
    id: shellRoot

    // Loaded plugin bar-widget roots, keyed by manifest id — the plugins IPC
    // routes summon/hide through the plugin's own open/close/toggle.
    property var pluginItems: ({})

    // One bar popover at a time, across classes: a plugin panel registering
    // itself open closes the tray card and the notification center. (The
    // reverse directions live in the bar's onActiveTrayChanged and the NC's
    // onShownChanged — all three funnel through the two registries:
    // trayOwner.activeTray and PluginHostService.openPanel.)
    Connections {
        target: Services.PluginHostService
        function onOpenPanelChanged() {
            if (Services.PluginHostService.openPanel === "") return
            if (shellRoot.trayOwner && shellRoot.trayOwner.activeTray !== "")
                shellRoot.trayOwner.activeTray = ""
            if (ncLoader.item && ncLoader.item.shown)
                ncLoader.item.close()
        }
    }

    // Border re-sync on compositor reload: any `hyprctl reload` reverts
    // Hyprland borders to the login-time Lua values (Tier-1 T1 experiment);
    // socket2 emits `configreloaded` when that happens, and the theme's
    // borders are re-evalled live from the current palette.
    Connections {
        target: Services.HyprlandService
        function onSocketEvent(line) {
            if (String(line).indexOf("configreloaded") === 0)
                Config.ThemeConfig.applyHyprlandBorders()
        }
    }

    // Cross-plugin panel bus: route toggle/refresh requests to the plugin
    // whose root registered the matching id (e.g. clock sun → weather panel).
    Connections {
        target: Services.PluginHostService
        function onTogglePanelRequested(id) {
            var it = shellRoot.pluginItems[id]
            if (it && it.toggle) it.toggle()
        }
        function onRefreshPanelRequested(id) {
            var it = shellRoot.pluginItems[id]
            if (it && it.refresh) it.refresh()
        }
    }

    // =========================================================================
    // LAZY OVERLAYS — load-on-first-use, keep-warm afterwards.
    // -------------------------------------------------------------------------
    // The five overlay windows (NotificationCenter, Fastfetch, Keybinds, Logs,
    // ZaiUsage) used to be constructed at bar launch — ~2400 lines of subtree
    // built before anything was ever opened. Each now loads on its first
    // toggle and stays warm (unload-on-close was rejected: between onLoaded
    // setting wanted=false and item.toggle() setting shown=true, the active
    // binding can re-evaluate to false and unload mid-open).
    // =========================================================================
    property bool ncWanted: false
    property bool fastfetchWanted: false
    property bool keybindsWanted: false
    property bool logsWanted: false
    property bool zaiWanted: false

    function toggleNotificationCenter() {
        if (ncLoader.item) ncLoader.item.toggle()
        else shellRoot.ncWanted = true        // load; onLoaded completes the open
    }
    function toggleFastfetch() {
        if (fastfetchLoader.item) fastfetchLoader.item.toggle()
        else shellRoot.fastfetchWanted = true
    }
    function toggleKeybinds() {
        if (keybindsLoader.item) keybindsLoader.item.toggle()
        else shellRoot.keybindsWanted = true
    }
    function toggleLogs() {
        if (logsLoader.item) logsLoader.item.toggle()
        else shellRoot.logsWanted = true
    }
    function toggleZaiUsage() {
        if (zaiLoader.item) zaiLoader.item.toggle()
        else shellRoot.zaiWanted = true
    }

    // EventService must be EAGER: QML singletons construct lazily on first
    // DEREFERENCE — and a never-read property binding may never evaluate.
    // Touching it imperatively at shell start guarantees construction (the
    // collector's journal tail + generation watcher depend on it).
    Component.onCompleted: {
        // Member access (not a bare reference — those never evaluate) to
        // force EventService construction: QML singletons build lazily and
        // nothing else references the collector until a panel binds it.
        console.log("[shell] EventService online:", Services.EventService.events.count, "events")
    }

    // The bar window that most recently hosted a tray card — TrayCard follows
    // it (screen + state). Per-output ownership WITHOUT the full popover
    // system: each bar variant owns its activeTray; the ShellRoot tracks which
    // one is showing so the single TrayCard renders on the right output.
    property var trayOwner: null

    // Overlay-state feedback for the style scene (isActive on icons).
    readonly property bool ncShown: ncLoader.item ? ncLoader.item.shown : false
    readonly property bool logsShown: logsLoader.item ? logsLoader.item.shown : false

    function closeNotificationCenter() {
        if (ncLoader.item && ncLoader.item.shown) ncLoader.item.close()
    }

    // =========================================================================
    // BAR STYLE — swappable strip scene (styles/<name>/Scene.qml, ryoko's
    // barStyle pattern). The style OWNS its windows; the host keeps IPC,
    // services, and shared overlays. effectiveStyle follows BarConfig.barStyle
    // (hot-swappable via bar-config.json) but rolls back to vector on
    // Loader.Error — a broken style never renders an empty bar.
    // =========================================================================
    readonly property string requestedStyle: Config.BarConfig.barStyle
    property string effectiveStyle: requestedStyle
    onRequestedStyleChanged: effectiveStyle = requestedStyle

    Loader {
        id: styleLoader
        source: "styles/" + shellRoot.effectiveStyle + "/Scene.qml"
        onLoaded: item.host = shellRoot
        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("[Bar] style '" + shellRoot.effectiveStyle
                              + "' failed to load — falling back to vector")
                shellRoot.effectiveStyle = "vector"
            }
        }
    }


    // =========================================================================
    // SHARED TRAY CARD — dropdown for Network/Bluetooth/Volume/Power.
    // Follows the tray OWNER (the bar that opened the card): state AND screen.
    // =========================================================================
    Components.TrayCard {
        activeTray: shellRoot.trayOwner ? shellRoot.trayOwner.activeTray : ""
        anchorItem: shellRoot.trayOwner ? shellRoot.trayOwner.trayAnchor : null
        onCloseRequested: if (shellRoot.trayOwner) shellRoot.trayOwner.activeTray = ""
        screen: shellRoot.trayOwner ? shellRoot.trayOwner.screen : null
    }

    // ── USER PLUGINS (service kind) — headless: timers/processes only. ──────
    Item {
        visible: false
        Repeater {
            model: Services.PluginHostService.servicePlugins
            Loader {
                source: "file://" + modelData.dir + modelData.entryPoints.service
                onLoaded: {
                    item.pluginId = modelData.id
                    item.api = Services.PluginHostService.api
                }
                onStatusChanged: {
                    if (status === Loader.Error)
                        Services.PluginHostService.reportError(modelData.id, "Service failed to load (see journal)")
                }
            }
        }
    }

    // =========================================================================
    // NOTIFICATION CENTER — slide-in panel (lazy; toggled by NotificationButton)
    // =========================================================================
    Loader {
        id: ncLoader
        active: shellRoot.ncWanted
        sourceComponent: ncComponent
        onLoaded: item.toggle()   // complete the open that triggered the load
    }
    Component {
        id: ncComponent
        Components.NotificationCenter { }
    }

    // ...and opening the notification center closes the tray card and any
    // plugin panel. (target null-safe: no connection until the center has
    // loaded)
    Connections {
        target: ncLoader.item
        function onShownChanged() {
            if (ncLoader.item && ncLoader.item.shown) {
                if (shellRoot.trayOwner && shellRoot.trayOwner.activeTray !== "")
                    shellRoot.trayOwner.activeTray = ""
                if (Services.PluginHostService.openPanel !== "")
                    Services.PluginHostService.openPanel = ""
            }
        }
    }

    // =========================================================================
    // FASTFETCH OVERLAY — system info (lazy; toggled by the ArchLogo icon)
    // =========================================================================
    Loader {
        id: fastfetchLoader
        active: shellRoot.fastfetchWanted
        sourceComponent: fastfetchComponent
        onLoaded: item.toggle()
    }
    Component {
        id: fastfetchComponent
        Components.FastfetchOverlay { }
    }

    // =========================================================================
    // KEYBINDS OVERLAY — mod+K cheat-sheet (lazy; toggled via IPC)
    // =========================================================================
    Loader {
        id: keybindsLoader
        active: shellRoot.keybindsWanted
        sourceComponent: keybindsComponent
        onLoaded: item.toggle()
    }
    Component {
        id: keybindsComponent
        Components.KeybindsOverlay { }
    }

    // =========================================================================
    // LOGS OVERLAY — system journal viewer (lazy; bar icon / SUPER+T / IPC)
    // =========================================================================
    Loader {
        id: logsLoader
        active: shellRoot.logsWanted
        sourceComponent: logsComponent
        onLoaded: item.toggle()
    }
    Component {
        id: logsComponent
        Components.LogsOverlay { }
    }

    // =========================================================================
    // Z.AI USAGE OVERLAY — quota HUD (lazy; toggled via IPC)
    // =========================================================================
    Loader {
        id: zaiLoader
        active: shellRoot.zaiWanted
        sourceComponent: zaiComponent
        onLoaded: item.toggle()
    }
    Component {
        id: zaiComponent
        Components.ZaiUsageOverlay { }
    }

    // =========================================================================
    // OSD — volume / mute feedback card (renders OsdService state)
    // =========================================================================
    Components.Osd { }

    // OSD IPC hook — lives here (not in the singleton) because IpcHandler
    // doesn't resolve inside qmldir-declared singletons in this Quickshell
    // build. Lets Hyprland keybinds / scripts drive the OSD.
    IpcHandler {
        target: "osd"
        function volume(value: int, muted: bool): string {
            Services.OsdService.showVolume(value, muted)
            return "ok"
        }
        function mute(muted: bool): string {
            Services.OsdService.showMute(muted)
            return "ok"
        }
        function ping(): string { return "ok" }
    }

    // =========================================================================
    // IPC HANDLER — plugin host: rescan / inspect / enable / disable.
    // Lives in shell.qml, NOT in the singleton (IpcHandler doesn't resolve in
    // qmldir-declared singletons on this build — same reason as the osd one).
    // =========================================================================
    IpcHandler {
        target: "plugins"
        function rescan(): string {
            Services.PluginHostService.rescan()
            return "ok"
        }
        function list(): string {
            var out = []
            var ps = Services.PluginHostService.plugins
            for (var i = 0; i < ps.length; i++)
                out.push({ id: ps[i].id, name: ps[i].name, version: ps[i].version,
                           kinds: ps[i].kinds, enabled: ps[i].enabled,
                           status: ps[i].status, error: ps[i].error,
                           commands: ps[i].commands, dir: ps[i].dir })
            return JSON.stringify(out, null, 1)
        }
        function enable(id: string): string {
            Services.PluginHostService.setEnabled(id, true)
            return "ok"
        }
        function disable(id: string): string {
            Services.PluginHostService.setEnabled(id, false)
            return "ok"
        }
        function order(json: string): string {
            try { Services.PluginHostService.setOrder(JSON.parse(json)) } catch (e) { return "bad json" }
            return "ok"
        }
        // Phase 3 lifecycle: route through the plugin's own open/close/toggle.
        function summon(id: string): string {
            var it = shellRoot.pluginItems[id]
            if (!it) return "not loaded"
            if (it.open) { it.open(); return "ok" }
            return "no open()"
        }
        function hide(id: string): string {
            var it = shellRoot.pluginItems[id]
            if (!it) return "not loaded"
            if (it.close) { it.close(); return "ok" }
            return "no close()"
        }
    }

    // =========================================================================
    // IPC HANDLERS — External Control
    // =========================================================================

    // Theme push nudge — settings ThemeService fires this right after its
    // atomic colors.json write so the bar follows theme swaps in ~0ms instead
    // of waiting out the FileView watch / 2s poll fallback. Registered here
    // (not in a singleton) for the same qmldir-resolution reason as the
    // other handlers.
    IpcHandler {
        target: "theme"
        function reload(): string {
            Config.ThemeConfig.reloadFromDisk()
            return "ok"
        }
    }

    // Bar visibility toggle (for Hyprland keybind)
    IpcHandler {
        id: barToggleIpc
        target: "barToggle"

        function toggle() {
            // All bars together (per-output variants). Flip userHidden so the
            // validScreen binding stays intact.
            const insts = (styleLoader.item && styleLoader.item.instances) || []
            let anyVisible = false
            for (let i = 0; i < insts.length; i++)
                if (insts[i].visible) { anyVisible = true; break }
            for (let i = 0; i < insts.length; i++)
                insts[i].userHidden = anyVisible
            console.log("[Bar] Visibility toggled:", !anyVisible)
        }
    }

    // Keyboard layout cycle (for SUPER+SHIFT+SPACE — see configs/hypr/keybindings.lua)
    IpcHandler {
        id: keyboardIpc
        target: "keyboard"

        function next() {
            // Layout cycling lives in the nikos.keyboard plugin now.
            var it = shellRoot.pluginItems["nikos.keyboard"]
            if (it && it.cycle) it.cycle()
            else console.log("[keyboard] plugin not loaded — enable nikos.keyboard")
        }
    }

    // Timezone tray card toggle (IPC-verifiable; bindable to a key if wanted)
    IpcHandler {
        id: timezoneIpc
        target: "timezone"

        function toggle() {
            if (shellRoot.trayOwner)
                shellRoot.trayOwner.activeTray = shellRoot.trayOwner.activeTray === "timezone" ? "" : "timezone"
        }
    }

    // Keybinds overlay toggle (for SUPER+K — see configs/hypr/keybindings.lua)
    IpcHandler {
        id: keybindsIpc
        target: "keybinds"

        function toggle() {
            shellRoot.toggleKeybinds()
        }
    }

    // Z.ai usage overlay toggle (for SUPER+Z — see configs/hypr/keybindings.lua)
    IpcHandler {
        id: zaiUsageIpc
        target: "zaiUsage"

        function toggle() {
            shellRoot.toggleZaiUsage()
        }
    }

    // Logs overlay toggle (for SUPER+T — see configs/hypr/keybindings.lua)
    IpcHandler {
        id: logsIpc
        target: "logs"

        function toggle() {
            shellRoot.toggleLogs()
        }
    }

    // Bridge Z.ai quota threshold alerts into the in-app NotificationService.
    // No notify-send/mako on this box — NotificationService is the single sink.
    // Referencing the service here also forces its lazy instantiation so the
    // polling Timer starts at bar launch.
    Connections {
        target: Services.ZaiUsageService
        ignoreUnknownSignals: true
        function onThresholdAlert(info) {
            Services.NotificationService.add(
                "Z.ai Usage",
                info.windowName + " at " + Math.round(info.pct) + "%",
                "Quota window used. Resets in " + info.resetLabel + ".",
                info.urgency,
                0)
        }
    }
}
