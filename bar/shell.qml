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
import bar.config as Config
import bar.engine as Engine
import bar.services as Services

ShellRoot {
    id: shellRoot

    // NotificationService OWNERSHIP PIN (J2): this singleton is instantiated
    // under TWO import URIs (this file's "services" and components'
    // "../services" — a Quickshell quirk: the specifier string, not the
    // resolved directory, keys the instance). Whichever copy constructs
    // first wins the boot-time org.freedesktop.Notifications probe AND the
    // IPC registration — and only THIS file's copy can deliver peeks into
    // the PopupCoordinator every renderer reads (see the peek Connections
    // below). Dereferencing it here, in a root property (evaluated before
    // any child constructs), pins the bus + IPC to the delivering copy.
    // The other copies still exist but always stand down: mirrors, harmless.
    // MEMBER read — a bare `property var x: Services.Svc` reference is inert
    // in this build (singletons construct on first dereference; a stored
    // reference never dereferences).
    property bool _notificationSvcPin: Services.NotificationService.peekKey !== ""

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
    // NotificationCenter loads on its first toggle and stays warm. Fastfetch,
    // Keybinds, the log viewer and Z.ai usage are overlay built-ins
    // (builtins/velocity.*, same lazy wrapper) — enable/disable them in
    // Settings ▸ Plugins; toggleOverlay/overlayShown are their host verbs.
    // =========================================================================
    property bool ncWanted: false

    function toggleNotificationCenter() {
        if (ncLoader.item) ncLoader.item.toggle()
        else shellRoot.ncWanted = true        // load; onLoaded completes the open
    }
    function toggleOverlay(id) { return Engine.PluginRegistry.call(id, "toggle", "") }
    function overlayShown(id) {
        var ov = Engine.PluginRegistry.instance(id, "overlay")
        return !!ov && ov.shown === true
    }

    // =========================================================================
    // SETTINGS HOST (P2.1) — the dashboard runs in THIS process. Two file://
    // loaders into the settings tree (cross-root loads are legal; URI imports
    // are not — the import-split law). The bootstrap loads at boot (singleton
    // pins + DisplayIpc/NetworkIpc + the bar-config write verbs); the window
    // loads on first use and then stays mounted (close only hides it, like
    // ncLoader). IPC target names are unchanged — handlers below forward.
    // =========================================================================
    property bool settingsWanted: false
    property var _pendingSettingsCall: null

    readonly property string _settingsBootstrapUrl:
        "file://" + Engine.PluginRegistry.repoDir + "/settings/components/SettingsBootstrap.qml"
    readonly property string _settingsHostUrl:
        "file://" + Engine.PluginRegistry.repoDir + "/settings/components/SettingsHostWindow.qml"

    // Route a call at the host window, loading it first if needed (the queued
    // call flushes in the loader's onLoaded). Returns the function's value.
    // Two optional args — setBurnGuard(scope, val) needs both.
    function settingsCall(fn, arg1, arg2) {
        if (!settingsHostLoader.active) {
            settingsHostLoader.active = true
            _pendingSettingsCall = { fn: fn, arg1: arg1, arg2: arg2 }
            return "ok"
        }
        return _settingsInvoke(settingsHostLoader.item, fn, arg1, arg2)
    }

    // The always-on bootstrap (write verbs + PluginManager surface). Loaded
    // during shell init, so a null here means "called during boot" — say so
    // instead of silently no-oping.
    function settingsBootstrapFn(fn, arg1, arg2) {
        var b = settingsBootstrapLoader.item
        if (!b) return "error: settings bootstrap not ready"
        return _settingsInvoke(b, fn, arg1, arg2)
    }

    function _settingsInvoke(it, fn, arg1, arg2) {
        if (arg1 === undefined) return it[fn]()
        if (arg2 === undefined) return it[fn](arg1)
        return it[fn](arg1, arg2)
    }

    // Direct verb for in-process callers (velocity.settings gear right-click).
    function settingsToggle() {
        settingsCall("toggle")
    }

    // KernelEventRecorder must be EAGER: QML singletons construct lazily on first
    // DEREFERENCE — and a never-read property binding may never evaluate.
    // Touching it imperatively at shell start guarantees construction (the
    // collector's journal tail + generation watcher depend on it).
    Component.onCompleted: {
        // Style init (also flows through onRequestedStyleChanged on config
        // changes; this covers the first load).
        effectiveStyle = requestedStyle
        // Member access (not a bare reference — those never evaluate) to
        // force KernelEventRecorder construction: QML singletons build lazily and
        // nothing else references the collector until a panel binds it.
        console.log("[shell] KernelEventRecorder online:", Services.KernelEventRecorder.events.count, "events")
        // Same lazy-pin for the metrics engine: the deepcool LCD feed runs
        // window-independent, so its consumer (lcdPresent) must exist before
        // any overlay/Core tab ever opens. Reading a member forces it.
        console.log("[shell] MetricsService online:", Services.MetricsService.metricsPath)
    }

    // TRAY STATE — one tray card for all outputs. trayOwner = the bar window
    // that opened it (the card follows its screen; kept after close so the
    // fade-out stays put), trayAnchor = the icon it centers under. Driven by
    // the velocity.* tray built-ins through ctx.host.
    property var trayOwner: null
    property Item trayAnchor: null
    property string activeTray: ""   // "network" | "bluetooth" | "volume" | "privacy" | "control" | ""

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
    // Control Center (UX U1): the floating ControlCenterOverlay panel — no
    // longer a TrayCard body (user call 2026-10-31: the tray popup "sucks").
    // Keybind / IPC / gear left-click land here; the settings dashboard keeps
    // the gear's right click only.
    property bool ccWanted: false
    function toggleControlCenter() {
        if (ccLoader.item) ccLoader.item.toggle()
        else shellRoot.ccWanted = true       // load; onLoaded completes the open
    }
    function closeControlCenter() {
        if (ccLoader.item && ccLoader.item.shown) ccLoader.item.close()
    }
    // P4.7: force-open the Control Center on one of its in-body pages
    // (controlCenter.page IPC — SUPER+COMMA → "bar").
    function openControlCenterPage(name) {
        if (ccLoader.item) { ccLoader.item.openPage(name); return }
        shellRoot._ccParkedPage = name
        shellRoot.ccWanted = true
    }
    property string _ccParkedPage: ""
    readonly property bool ccShown: ccLoader.item ? ccLoader.item.shown : false

    // Open one tray card body by name (CC tile drills: network / bluetooth /
    // volume). The focused output's bar window anchors the card, exactly like
    // clicking the pill — never toggles a matching open card closed.
    function openTrayBody(name) {
        var insts = (styleLoader.item && styleLoader.item.instances) || []
        var mon = Services.HyprlandService.focusedMonitor
        var win = null
        for (var i = 0; i < insts.length; i++)
            if (insts[i].screen && insts[i].screen.name === mon) { win = insts[i]; break }
        if (!win && insts.length > 0) win = insts[0]
        if (!win) { console.warn("[shell] openTrayBody: no bar instance"); return }
        if (!shellRoot.trayOpenOn(win, name)) shellRoot.toggleTray(win, name, null)
    }
    function closeTray() {
        if (shellRoot.activeTray === "") return
        shellRoot.activeTray = ""
        Engine.PopupCoordinator.release("tray")
    }

    // Overlay-state feedback for the style scene (isActive on icons).
    readonly property bool ncShown: ncLoader.item ? ncLoader.item.shown : false

    // Height of the tallest live style window (island chrome is 32 while
    // barHeight stays 26) — what top-right banners must clear. Toast eats this.
    readonly property int topClearance: {
        var h = Config.BarConfig.barHeight
        var insts = (styleLoader.item && styleLoader.item.instances) || []
        for (var i = 0; i < insts.length; i++)
            if (insts[i] && insts[i].height > h) h = insts[i].height
        return h
    }

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
        id: trayCard
        activeTray: shellRoot.activeTray
        anchorItem: shellRoot.trayAnchor
        shellApi: shellRoot
        onCloseRequested: shellRoot.closeTray()
        screen: shellRoot.trayOwner ? shellRoot.trayOwner.screen : null
        embedHost: shellRoot.trayOwner && shellRoot.trayOwner.screen
            ? (Engine.PopupCoordinator.islands[shellRoot.trayOwner.screen.name] || null) : null
    }

    // =========================================================================
    // SETTINGS LOADERS — file:// into the settings tree (see settings host
    // note above). barServices hands the merged-domain services to
    // HostBridge; extended as P2.2/P2.3 merge each domain.
    // =========================================================================
    Loader {
        id: settingsBootstrapLoader
        active: true
        source: shellRoot._settingsBootstrapUrl
        onLoaded: item.barServices = ({
            engine: Engine.PluginRegistry,
            log: Services.LogService,
            bluetooth: Services.BluetoothService,
            audio: Services.AudioService,
            network: Services.NetworkService,
            metrics: Services.MetricsService,
            notifications: Services.NotificationService,
            configWriter: Config.BarConfigWriter,
            // P5.6: socket2 re-emitter — settings-side wallpaper auto-pause
            // reads fullscreen>> lines through HostBridge (ONE socket consumer).
            hypr: Services.HyprlandService
        })
    }

    Loader {
        id: settingsHostLoader
        active: shellRoot.settingsWanted
        source: shellRoot._settingsHostUrl
        onLoaded: {
            var p = shellRoot._pendingSettingsCall
            shellRoot._pendingSettingsCall = null
            if (p) shellRoot._settingsInvoke(item, p.fn, p.arg1, p.arg2)
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

    // =========================================================================
    // CONTROL CENTER — floating panel (lazy; gear left-click, SUPER+A/N, IPC)
    // =========================================================================
    Loader {
        id: ccLoader
        active: shellRoot.ccWanted
        sourceComponent: ccComponent
        onLoaded: {
            item.toggle()   // complete the open that triggered the load
            if (shellRoot._ccParkedPage !== "") {
                item.openPage(shellRoot._ccParkedPage)
                shellRoot._ccParkedPage = ""
            }
        }
    }
    Component {
        id: ccComponent
        Components.ControlCenterOverlay { shellApi: shellRoot }
    }

    // The CC claims the popup slot while shown — one popup at a time with the
    // tray card, the notification center and the overlay plugins.
    Connections {
        target: ccLoader.item
        function onShownChanged() {
            if (ccLoader.item && ccLoader.item.shown)
                Engine.PopupCoordinator.request("cc", shellRoot.closeControlCenter)
            else
                Engine.PopupCoordinator.release("cc")
        }
    }

    // The notification center claims the popup slot while shown. (target
    // null-safe: no connection until the center has loaded) While it holds
    // the slot the activity queue's arbitration hides any live peek (J0
    // panel-wins) — no separate banner-dismissal needed.
    Connections {
        target: ncLoader.item
        function onShownChanged() {
            var shown = ncLoader.item && ncLoader.item.shown
            // panel-wins is ALSO policy on the publisher copy: nc's own
            // panelOpen write lands on the "../services" instance, not the
            // peek publisher pinned above — this file re-states it.
            Services.NotificationService.panelOpen = shown
            if (shown)
                Engine.PopupCoordinator.request("nc", shellRoot.closeNotificationCenter)
            else
                Engine.PopupCoordinator.release("nc")
        }
    }

    // Now-playing delivery (P6.7): MprisService owns the announce POLICY; the
    // dual-instance law routes delivery through this file's coordinator (the
    // service's own ../engine would be a second, unseen instance).
    Connections {
        target: Services.MprisService
        function onMediaActivityRevChanged() {
            var s = Services.MprisService.mediaActivitySpec
            if (s) Engine.PopupCoordinator.activity(s)
            else Engine.PopupCoordinator.endActivity("media")
        }
    }

    // =========================================================================
    // OSD — volume / mute feedback card (renders OsdService state)
    // =========================================================================
    Components.Osd { }

// Notification toasts (UX U3): the ryoku-port toast surface. Data comes from
// NotificationService.popups (U4); the window self-manages its mapped state
// and follows the focused monitor — no shell plumbing.
Components.NotificationToasts { }

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

    // Live activities (J0) — scripts/Hyprland push island feedback without a
    // plugin: `qs -c bar ipc call island activity '{"key":"dl","icon":"↓",
    // "label":"42%","progress":42}'` (ttlMs required unless progress is
    // present; 10-min hard cap; priorities osd>recording>peek>progress>timer,
    // unknown → timer). `island end <key>` retracts. Keys are prefixed
    // "ipc:" so scripts can never end a plugin's or the OSD's activity.
    IpcHandler {
        target: "island"
        function activity(json: string): string {
            var spec
            try { spec = JSON.parse(json) } catch (e) { return "bad json: " + e }
            if (!spec || typeof spec !== "object" || !spec.key)
                return "refused: need key + ttlMs (or progress)"
            // Namespace on PUBLISH, not just on end — scripts must never
            // collide with a plugin's "<pluginId>:<key>" or the OSD's "osd"
            // (the prefix is what makes `island end <key>` reach only their
            // own entries).
            spec.key = "ipc:" + spec.key
            return Engine.PopupCoordinator.activity(spec)
                ? "ok" : "refused: need key + ttlMs (or progress)"
        }
        function end(key: string): string {
            Engine.PopupCoordinator.endActivity("ipc:" + key)
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

    // bar-config.json nudge — settings fires it after its atomic write.
    IpcHandler {
        target: "config"
        function reload(): string {
            Config.BarConfig.reloadFromDisk()
            Config.MotionConfig.reloadFromDisk()
            return "ok"
        }
    }

    // network speedtest — settings' RUN IN BAR (H1) + scripts: run the bar's
    // XHR ladder headless. The completed result lands in
    // $XDG_STATE_HOME/velocity/speedtest.json for the settings view.
    IpcHandler {
        target: "network"
        function latency(): string { return shellRoot.settingsBootstrapFn("networkLatency") }
        function engineer(): string { return shellRoot.settingsBootstrapFn("networkEngineer") }
        function speedtest(): string {
            Services.NetworkService.runSpeedTest()
            return "ok"
        }
    }

    // metrics lease — H7: scripting surface; settings (Core tab, dashboard
    // System Pulse) now call MetricsService.extendLease() directly (one
    // process, P2.3). Clamp ≤ 30s lives in lib/lease.mjs.
    IpcHandler {
        target: "metrics"
        function lease(seconds: int): string {
            Services.MetricsService.extendLease(seconds)
            return "ok"
        }
    }

    // notifications ingest/control — moved here from NotificationService.qml
    // (P2): IpcHandlers live in shell.qml (the qmldir-singleton placement
    // double-registers under the J2 import split — the losing mirror logged a
    // WARN on every boot). Same surface; it lands on the pinned instance via
    // this file's import either way. Ingest docs on NotificationService.
    IpcHandler {
        target: "notifications"
        // args = single JSON string: {appName, summary, body, urgency}
        function add(json: string) {
            var d = null
            try { d = JSON.parse(json) } catch (e) {
                console.warn("[shell] notifications add: bad json:", json)
                return
            }
            Services.NotificationService.add(d.appName, d.summary, d.body, d.urgency, d.clickId, d.appIcon)
        }
        function clear() { Services.NotificationService.clearAll() }   // soft: undo with restore()
        function restore() { Services.NotificationService.restoreCleared() }
        function dnd(on: bool) { Services.NotificationService.setDnd(on) }
        // P6.5 DND schedule: json = {enabled, start, end} ("HH:MM", wraps midnight)
        function schedule(json: string) {
            var d = null
            try { d = JSON.parse(json) } catch (e) {
                console.warn("[shell] notifications schedule: bad json:", json)
                return
            }
            Services.NotificationService.setSchedule(d.enabled, d.start, d.end)
        }
        // Keybind form (SUPER+SHIFT+N): typed IPC params are required, so the
        // toggle variant is its own no-arg verb.
        function dndToggle() { Services.NotificationService.setDnd(!Services.NotificationService.dnd) }
        function readAll() { Services.NotificationService.markAllRead() }
        function list(): string {
            var rows = []
            var m = Services.NotificationService.model
            for (var i = 0; i < m.count; i++) rows.push(m.get(i))
            return JSON.stringify(rows)
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

    // The CANONICAL keyboard bind path (D3): SUPER+SHIFT+SPACE renders as
    //   qs -c bar ipc call keyboard next
    // and these `keyboard.*` targets forward to the plugin's declared verbs
    // (manifest.ipc) — the bar-level alias plugins and humans both use.
    IpcHandler {
        id: keyboardIpc
        target: "keyboard"

        function next(): string { return Engine.PluginRegistry.call("nikos.keyboard", "next", "") }
        function prev(): string { return Engine.PluginRegistry.call("nikos.keyboard", "prev", "") }
        function set(argument: string): string { return Engine.PluginRegistry.call("nikos.keyboard", "set", argument) }
        function status(): string { return Engine.PluginRegistry.call("nikos.keyboard", "status", "") }
        function open(): string { return Engine.PluginRegistry.call("nikos.keyboard", "toggle", "") }
    }

    // Clipboard picker (J8, same pattern as the keyboard target): thin forwarder to the
    // velocity.clipboard overlay plugin — `qs -c bar ipc call clipboard
    // toggle|open|close`. No-ops (with a mount-time journal line) while
    // cliphist/wl-copy are absent.
    IpcHandler {
        target: "clipboard"

        function toggle(): string { return Engine.PluginRegistry.call("velocity.clipboard", "toggle", "") }
        function open(): string { return Engine.PluginRegistry.call("velocity.clipboard", "open", "") }
        function close(): string { return Engine.PluginRegistry.call("velocity.clipboard", "close", "") }
    }

    // Screen recorder (J9, same pattern): thin forwarder to the velocity.record
    // service — `qs -c bar ipc call record start [region|output]|stop|toggle|status`.
    // Answers "unavailable: …" while wf-recorder is absent.
    IpcHandler {
        target: "record"

        // bare start/toggle = region mode; typed IPC params are required, so
        // the mode variant is its own verb
        function start(): string { return Engine.PluginRegistry.call("velocity.record", "start", "") }
        function startMode(argument: string): string { return Engine.PluginRegistry.call("velocity.record", "start", argument) }
        function stop(): string { return Engine.PluginRegistry.call("velocity.record", "stop", "") }
        function toggle(): string { return Engine.PluginRegistry.call("velocity.record", "toggle", "") }
        function status(): string { return Engine.PluginRegistry.call("velocity.record", "status", "") }
    }

    // Screenshots (P7 G2, same pattern): thin forwarder to the velocity.shot
    // service — `qs -c bar ipc call screenshot region|output|window|status`.
    // Every capture rides wl-copy + ~/Pictures/Screenshots; answers
    // "unavailable: …" while grim/slurp/wl-copy are absent.
    IpcHandler {
        target: "screenshot"
        function region(): string { return Engine.PluginRegistry.call("velocity.shot", "region", "") }
        function output(): string { return Engine.PluginRegistry.call("velocity.shot", "output", "") }
        function window(): string { return Engine.PluginRegistry.call("velocity.shot", "window", "") }
        function status(): string { return Engine.PluginRegistry.call("velocity.shot", "status", "") }
    }

    IpcHandler {
        target: "controlCenter"
        function toggle() { shellRoot.toggleControlCenter() }
        // P3.8 page <name>: deep page entry from the keybinds table
        // (SUPER+COMMA → "bar"). P4.8: "bar" is the Control Center's own
        // in-body BAR page (BarSettingsBody) — the bar-settings overlay is
        // deleted.
        function page(name: string) {
            if (name === "bar") { shellRoot.openControlCenterPage("bar"); return "ok" }
            console.warn("[shell] controlCenter.page: unknown page:", name)
            return ""
        }
    }

    // Launcher (P3.8): thin forwarder to the velocity.launcher overlay
    // plugin — `qs -c bar ipc call launcher toggle|open|close`. SUPER+SPACE
    // (D3) replaces the old rofi exec bind.
    IpcHandler {
        target: "launcher"

        // void, NOT string: PluginRegistry.call's "ok" return leaking through a
        // typed handler makes Qt log its coerce-to-void error on every call.
        function toggle(): void { Engine.PluginRegistry.call("velocity.launcher", "toggle", "") }
        function open(): void { Engine.PluginRegistry.call("velocity.launcher", "open", "") }
        function close(): void { Engine.PluginRegistry.call("velocity.launcher", "close", "") }
    }

    // Keybinds overlay toggle (for SUPER+K — see ~/.config/hypr/velocity-binds.lua)
    IpcHandler {
        id: keybindsIpc
        target: "keybinds"

        function toggle() {
            shellRoot.toggleOverlay("velocity.keybinds")
        }
    }

    // Z.ai usage overlay toggle (for SUPER+Z — see ~/.config/hypr/velocity-binds.lua)
    IpcHandler {
        id: zaiUsageIpc
        target: "zaiUsage"

        function toggle() {
            shellRoot.toggleOverlay("velocity.zai-usage")
        }
    }

    // Logs overlay toggle (for SUPER+T — see ~/.config/hypr/velocity-binds.lua)
    IpcHandler {
        id: logsIpc
        target: "logs"

        function toggle() {
            shellRoot.toggleOverlay("velocity.logs-viewer")
        }
    }

    // =========================================================================
    // SETTINGS IPC (P2.1) — target names unchanged from the old settings
    // process; every verb forwards into the hosted window (toggle/deep links)
    // or the bootstrap (silent config writes, PluginManager).
    // =========================================================================
    IpcHandler {
        target: "SettingsWindow"

        function toggle() { return shellRoot.settingsCall("toggle") }
        function show() { return shellRoot.settingsCall("show") }
        function hide() { return shellRoot.settingsCall("hide") }

        // Read-only probe: key of the visible top-level tab. First-ever call
        // loads the window and returns "" — the probe means "generic open";
        // a second call reads the real tab.
        function activeTab(): string {
            if (!settingsHostLoader.active) {
                shellRoot.settingsCall("activeTab")
                return ""
            }
            return settingsHostLoader.item.activeTab()
        }

        function openControlNetwork() { return shellRoot.settingsCall("openControlNetwork") }
        function openControlBluetooth() { return shellRoot.settingsCall("openControlBluetooth") }
        function openControlAudio() { return shellRoot.settingsCall("openControlAudio") }
        function openControlDisplay() { return shellRoot.settingsCall("openControlDisplay") }
        function openControlPlugins() { return shellRoot.settingsCall("openControlPlugins") }
        function openSettings() { return shellRoot.settingsCall("openSettings") }
        function openThemeTab() { return shellRoot.settingsCall("openThemeTab") }
        function openWallpapers() { return shellRoot.settingsCall("openWallpapers") }
        function openCore(section: string) { return shellRoot.settingsCall("openCore", section) }

        // C4: bar-owned keys written FROM the bar — silent funnel through the
        // bootstrap (no window opened).
        function setBarStyle(name: string): string { return shellRoot.settingsBootstrapFn("setBarStyle", name) }
        function setBarPosition(pos: string): string { return shellRoot.settingsBootstrapFn("setBarPosition", pos) }
        function setOsdStyle(style: string): string { return shellRoot.settingsBootstrapFn("setOsdStyle", style) }
        function setBarHeight(h: string): string { return shellRoot.settingsBootstrapFn("setBarHeight", h) }
        function setWorkspaceCount(n: string): string { return shellRoot.settingsBootstrapFn("setWorkspaceCount", n) }
        function setBurnGuard(scope: string, val: string): string { return shellRoot.settingsBootstrapFn("setBurnGuard", scope, val) }
    }

    // Plugin pipeline (install/convert from the CLI and tests)
    IpcHandler {
        target: "PluginManager"
        function installFromGit(url: string): string { return shellRoot.settingsBootstrapFn("pluginInstallFromGit", url) }
        function refresh(): string { return shellRoot.settingsBootstrapFn("pluginRefresh") }
    }

    // Power menu overlay (bar PowerIcon / SUPER+P)
    IpcHandler {
        target: "powerMenu"
        function toggle() { shellRoot.settingsCall("powerToggle") }
    }

    // Dashboard search (scripting / truth probes / deep-link)
    IpcHandler {
        target: "search"
        function query(q: string): string { return shellRoot.settingsCall("searchQuery", q) }
        function open(q: string) { shellRoot.settingsCall("searchOpen", q) }
        function activateFirst(q: string) { return shellRoot.settingsCall("searchActivateFirst", q) }
        function list(): string { return shellRoot.settingsCall("searchList") }
    }
}
