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

    // =========================================================================
    // BARS — one PanelWindow per real output (Variants; hotplug-safe)
    // =========================================================================
    Variants {
        id: bars
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow

            // Variants REQUIRE the delegate to declare the model item slot:
            // without `modelData` (plain property — a `required property`
            // breaks on JS-array models), delegate recreation fails initial-
            // property assignment and the window NEVER re-attaches to an
            // output. Symptom: after lock/DPMS off-on the bar is gone for
            // good ("PanelWindow does not have a property called modelData").
            property var modelData: null
            screen: modelData

            property string activeTray: ""   // "network" | "bluetooth" | "volume" | "power" | "" (closed)
            // The icon that opened the tray — TrayCard's Popover centers
            // under it. Set by the icon slots' trayRequested handlers.
            property Item trayAnchor: null

            // Placeholder/zero-sized screens (connector hotplug churn) must
            // not spawn ghost bars (Shibumi BarPanel.validScreen pattern).
            // userHidden keeps the IPC toggle out of the binding (assignment
            // would break it).
            readonly property bool validScreen: screen !== null && screen.name !== "" && screen.width > 0
            property bool userHidden: false
            visible: validScreen && !userHidden

            // A bar showing a tray card becomes the tray owner (its output
            // hosts the TrayCard until closed).
            onActiveTrayChanged: {
                if (activeTray !== "") {
                    shellRoot.trayOwner = panelWindow
                    if (ncLoader.item && ncLoader.item.shown) ncLoader.item.close()
                }
            }

            // =========================================================================
            // POSITIONING
            // =========================================================================

            anchors {
                top: true
                left: true
                right: true
            }

        // =========================================================================
        // APPEARANCE (from config)
        // =========================================================================

        implicitHeight: Config.BarConfig.barHeight
        color: Config.BarConfig.colorBackground

        // =========================================================================
        // MAIN LAYOUT (Left and Right Sections)
        // =========================================================================

        // Click on empty bar area closes the open tray card.
        MouseArea {
            anchors.fill: parent
            enabled: panelWindow.activeTray !== ""
            onClicked: panelWindow.activeTray = ""
        }

        // (one-popup-at-a-time + tray-owner registration live in the
        //  onActiveTrayChanged at the top of this window)

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // --- LEFT SIDE ---

            Components.ArchLogo {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Config.BarConfig.barPadding
                onTriggered: shellRoot.toggleFastfetch()
            }

            Components.WorkspaceWidget {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Config.BarConfig.iconSpacing
            }

            // --- HUGE MIDDLE GAP ---
            // This spacer now pushes everything else all the way to the right side
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // --- RIGHT SIDE — order-driven rail (bar-config.json "rightLayout")
            // Each slot keeps its exact hand-tuned wiring; the ORDER comes from
            // config and hot-reloads with the 2s bar-config.json watcher.
            Repeater {
                model: Config.BarConfig.rightLayout

                Loader {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 0
                    Layout.rightMargin: Config.BarConfig.slotMargin
                    sourceComponent: {
                        if (modelData === "plugins")       return pluginsSlot
                        if (modelData === "network")       return networkSlot
                        if (modelData === "bluetooth")     return bluetoothSlot
                        if (modelData === "volume")        return volumeSlot
                        if (modelData === "logs")          return logsSlot
                        if (modelData === "notifications") return notificationsSlot
                        return null
                    }
                }
            }

            Item {
                width: Config.BarConfig.barPadding
                Layout.fillHeight: true
            }
        }

        // ── slot components (order-independent definitions) ──────────────────
        // keyboard converted → plugins/nikos.keyboard (lives in the plugins
        // slot); "keyboard" as a rail key is no longer legal.
        Component {
            id: pluginsSlot
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 8
                // --- USER PLUGINS (bar-widget kind) ---
                // One generation-guarded slot per enabled, validated plugin
                // (PluginSlot = ryoku PluginObjectSlot port): a broken plugin
                // keeps the previous instance mounted and reports into
                // PluginHostService instead of tearing the rail down. api/theme
                // come from the host as injected object references (never
                // imports) so plugins share the process-wide singletons.
                Repeater {
                    model: Services.PluginHostService.barWidgetPlugins

                    Components.PluginSlot {
                        Layout.alignment: Qt.AlignVCenter
                        pluginId: modelData.id
                        source: "file://" + modelData.dir + modelData.entryPoints.barWidget
                        configure: function(item) {
                            // Our nikos.* roots expose pluginId; omarchy-shaped
                            // roots (QsBarWidget) carry moduleName instead —
                            // assigning a non-existent property throws.
                            if (item.pluginId !== undefined) item.pluginId = modelData.id
                            if (item.api !== undefined) item.api = Services.PluginHostService.api
                            // Registry for the plugins IPC (summon/hide route
                            // through the plugin's own open/close/toggle).
                            var reg = shellRoot.pluginItems
                            reg[modelData.id] = item
                            shellRoot.pluginItems = reg
                        }
                    }
                }
            }
        }
        Component {
            id: networkSlot
            Components.NetworkIcon {
                Layout.alignment: Qt.AlignVCenter
                isActive: panelWindow.activeTray === "network"
                onTrayRequested: {
                    panelWindow.trayAnchor = this
                    panelWindow.activeTray = panelWindow.activeTray === "network" ? "" : "network"
                }
            }
        }
        Component {
            id: bluetoothSlot
            Components.BluetoothIcon {
                Layout.alignment: Qt.AlignVCenter
                isActive: panelWindow.activeTray === "bluetooth"
                onTrayRequested: {
                    panelWindow.trayAnchor = this
                    panelWindow.activeTray = panelWindow.activeTray === "bluetooth" ? "" : "bluetooth"
                }
            }
        }
        Component {
            id: volumeSlot
            Components.VolumeIcon {
                Layout.alignment: Qt.AlignVCenter
                isActive: panelWindow.activeTray === "volume"
                onTrayRequested: {
                    panelWindow.trayAnchor = this
                    panelWindow.activeTray = panelWindow.activeTray === "volume" ? "" : "volume"
                }
            }
        }
        Component {
            id: logsSlot
            Components.LogsIcon {
                Layout.alignment: Qt.AlignVCenter
                isActive: logsLoader.item ? logsLoader.item.shown : false
                onTriggered: shellRoot.toggleLogs()
            }
        }
        Component {
            id: notificationsSlot
            Components.NotificationButton {
                Layout.alignment: Qt.AlignVCenter
                isActive: ncLoader.item ? ncLoader.item.shown : false
                onCenterRequested: shellRoot.toggleNotificationCenter()
            }
        }

        // =========================================================================
        // PERFECTLY CENTERED — center-slot plugins
        // =========================================================================
        // Anchored to the panel window, so it stays dead-center regardless of
        // the rails. The clock is a plugin (nikos.clock) — the built-in
        // ClockWidget fallback was removed; disabling every center plugin
        // leaves the center empty by design.

        Row {
            anchors.centerIn: parent
            spacing: 14
            Repeater {
                model: Services.PluginHostService.centerWidgetPlugins

                Loader {
                    source: "file://" + modelData.dir + modelData.entryPoints.barWidget
                    onLoaded: {
                        if (item.pluginId !== undefined) item.pluginId = modelData.id
                        if (item.api !== undefined) item.api = Services.PluginHostService.api
                        var reg = shellRoot.pluginItems
                        reg[modelData.id] = item
                        shellRoot.pluginItems = reg
                    }
                    onStatusChanged: {
                        if (status === Loader.Error)
                            Services.PluginHostService.reportError(modelData.id, "Center plugin failed to load (see journal)")
                    }
                }
            }
        }
    }
    }   // Variants (per-output bars)

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

    // ...and opening the notification center closes the tray card.
    // (target null-safe: no connection until the center has loaded)
    Connections {
        target: ncLoader.item
        function onShownChanged() {
            if (ncLoader.item && ncLoader.item.shown && shellRoot.trayOwner
                && shellRoot.trayOwner.activeTray !== "")
                shellRoot.trayOwner.activeTray = ""
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
            const insts = bars.instances || []
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
