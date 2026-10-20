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
import "engine" as Engine
import "services" as Services

ShellRoot {
    id: shellRoot

    // =========================================================================
    // PLUGIN ENGINE — the host's side of the contract: hand the engine the
    // bar surfaces it may expose to plugins (the engine imports nothing from
    // the bar), and react to plugin popovers/overlays opening.
    // =========================================================================
    Binding {
        target: Engine.PluginRegistry
        property: "hostApi"
        value: ({
            theme: Config.ThemeConfig,
            bar: Config.BarConfig,
            osd: Services.OsdService,
            hypr: Services.HyprlandService,
            focusedMonitor: function() { return Services.HyprlandService.focusedMonitor },
            shell: shellRoot,
            legacyBarConfigPath: Config.BarConfig.configFilePath
        })
    }

    // Service + overlay plugins and the `plugins` IPC. Bar widgets are
    // mounted by the style scenes (Engine.BarSection).
    Engine.PluginHost { }

    // One bar popup at a time across tray card, notification center, plugin
    // panels and plugin overlays: each claims Engine.PopupCoordinator with a
    // closer, and the coordinator closes the previous holder.

    // Border re-sync on compositor reload: any `hyprctl reload` reverts
    // Hyprland borders to the login-time Lua values (Tier-1 T1 experiment);
    // socket2 emits `configreloaded` when that happens, and the theme's
    // borders are re-evalled live from the current palette.
    // Every line is also re-emitted to plugins (ctx.events) — the bar keeps
    // the ONE socket2 consumer.
    Connections {
        target: Services.HyprlandService
        function onSocketEvent(line) {
            if (String(line).indexOf("configreloaded") === 0)
                Config.ThemeConfig.applyHyprlandBorders()
            Engine.PluginRegistry.events.hyprEvent(line)
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
        // Style init (also flows through onRequestedStyleChanged on config
        // changes; this covers the first load).
        effectiveStyle = requestedStyle
        // Member access (not a bare reference — those never evaluate) to
        // force EventService construction: QML singletons build lazily and
        // nothing else references the collector until a panel binds it.
        console.log("[shell] EventService online:", Services.EventService.events.count, "events")
    }

    // TRAY STATE — one tray card for all outputs. trayOwner = the bar window
    // that opened it (the card follows its screen; kept after close so the
    // fade-out stays put), trayAnchor = the icon it centers under. Driven by
    // the velocity.* tray built-ins through ctx.host.
    property var trayOwner: null
    property Item trayAnchor: null
    property string activeTray: ""   // "network" | "bluetooth" | "volume" | "privacy" | ""

    function trayOpenOn(window, name) {
        return shellRoot.activeTray === name && shellRoot.trayOwner === window
    }
    function toggleTray(window, name, anchor) {
        if (shellRoot.trayOpenOn(window, name)) { shellRoot.closeTray(); return }
        shellRoot.trayOwner = window
        shellRoot.trayAnchor = anchor || null
        shellRoot.activeTray = name
        Engine.PopupCoordinator.request("tray", shellRoot.closeTray)
    }
    function closeTray() {
        if (shellRoot.activeTray === "") return
        shellRoot.activeTray = ""
        Engine.PopupCoordinator.release("tray")
    }

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
    // Plain property (NO binding to requestedStyle): the fallback assigns it,
    // and a binding made the Loader's source ↔ Error-handler assignment a
    // binding loop — QML's detector then killed the source binding and the
    // bar rendered EMPTY. Changes flow through the two handlers only, and
    // the fallback defers via callLater out of the evaluation cascade.
    property string effectiveStyle: "vector"
    onRequestedStyleChanged: effectiveStyle = requestedStyle
    // A style swap tears the scene down with any open popover mounted inside
    // it (plugin panels live in plugin subtrees the scene owns) — their
    // popClosed never fires, so the popup slot and the notch carve state
    // would go stale; the tray owner window dies too. Covers the
    // Error→vector rollback: effectiveStyle changes on both paths.
    onEffectiveStyleChanged: {
        Engine.PopupCoordinator.clear()
        shellRoot.trayOwner = null
        shellRoot.trayAnchor = null
    }

    Loader {
        id: styleLoader
        source: "styles/" + shellRoot.effectiveStyle + "/Scene.qml"
        onLoaded: item.host = shellRoot
        onStatusChanged: {
            if (status === Loader.Error && shellRoot.effectiveStyle !== "vector") {
                console.error("[Bar] style '" + shellRoot.effectiveStyle
                              + "' failed to load — falling back to vector")
                Qt.callLater(function() { shellRoot.effectiveStyle = "vector" })
            }
        }
    }


    // =========================================================================
    // SHARED TRAY CARD — dropdown for Network/Bluetooth/Volume/Power.
    // Follows the tray OWNER (the bar that opened the card): state AND screen.
    // =========================================================================
    Components.TrayCard {
        activeTray: shellRoot.activeTray
        anchorItem: shellRoot.trayAnchor
        onCloseRequested: shellRoot.closeTray()
        screen: shellRoot.trayOwner ? shellRoot.trayOwner.screen : null
        embedHost: shellRoot.trayOwner && shellRoot.trayOwner.screen
            ? (Engine.PopupCoordinator.islands[shellRoot.trayOwner.screen.name] || null) : null
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

    // The notification center claims the popup slot while shown. (target
    // null-safe: no connection until the center has loaded)
    Connections {
        target: ncLoader.item
        function onShownChanged() {
            if (ncLoader.item && ncLoader.item.shown)
                Engine.PopupCoordinator.request("nc", shellRoot.closeNotificationCenter)
            else
                Engine.PopupCoordinator.release("nc")
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

    // (The `plugins` IPC lives in engine/PluginHost.qml.)

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

    // TRANSITIONAL — delete once SUPER+SHIFT+SPACE in ~/.omni-nix/configs/
    // hypr/keybindings.lua calls the plugin directly:
    //   qs -c bar ipc call plugins call nikos.keyboard next ""
    // Until then the old `keyboard.*` targets just forward to the plugin's
    // declared verbs (manifest.ipc), so the bind keeps working.
    IpcHandler {
        id: keyboardIpc
        target: "keyboard"

        function next(): string { return Engine.PluginRegistry.call("nikos.keyboard", "next", "") }
        function prev(): string { return Engine.PluginRegistry.call("nikos.keyboard", "prev", "") }
        function set(argument: string): string { return Engine.PluginRegistry.call("nikos.keyboard", "set", argument) }
        function status(): string { return Engine.PluginRegistry.call("nikos.keyboard", "status", "") }
        function open(): string { return Engine.PluginRegistry.call("nikos.keyboard", "toggle", "") }
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
