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

    PanelWindow {
        id: panelWindow

        property string activeTray: ""   // "network" | "bluetooth" | "volume" | "power" | "" (closed)

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

        // One-popup-at-a-time (Omarchy requestPopout pattern): opening a tray
        // card closes the notification center...
        onActiveTrayChanged: {
            if (activeTray !== "" && ncLoader.item && ncLoader.item.shown)
                ncLoader.item.close()
        }

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

            // --- RIGHT SIDE ---

            Components.KeyboardWidget {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Config.BarConfig.iconSpacing
            }

            Components.WeatherWidget {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 12    // +10 keeps the keyboard US label clear of the sun glyph
                Layout.rightMargin: 44   // breathing room before the wifi icon
            }

            Components.NetworkIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: -4
                isActive: panelWindow.activeTray === "network"
                onTrayRequested: panelWindow.activeTray = panelWindow.activeTray === "network" ? "" : "network"
            }

            Components.BluetoothIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: -6
                isActive: panelWindow.activeTray === "bluetooth"
                onTrayRequested: panelWindow.activeTray = panelWindow.activeTray === "bluetooth" ? "" : "bluetooth"
            }

            Components.VolumeIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: -6
                isActive: panelWindow.activeTray === "volume"
                onTrayRequested: panelWindow.activeTray = panelWindow.activeTray === "volume" ? "" : "volume"
            }

            Components.BatteryIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: -6
                isActive: panelWindow.activeTray === "power"  // Changed from "battery" to "power"
                onTrayRequested: panelWindow.activeTray = panelWindow.activeTray === "power" ? "" : "power"  // Changed from "battery" to "power"
            }

            Components.LogsIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: -6
                isActive: logsLoader.item ? logsLoader.item.shown : false
                onTriggered: shellRoot.toggleLogs()
            }

            Components.NotificationButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                isActive: ncLoader.item ? ncLoader.item.shown : false
                onCenterRequested: shellRoot.toggleNotificationCenter()
            }

            Item {
                width: Config.BarConfig.barPadding
                Layout.fillHeight: true
            }
        }

        // =========================================================================
        // PERFECTLY CENTERED CLOCK
        // =========================================================================
        // Sitting outside the RowLayout, this anchors directly to the panel window.
        // It will remain dead-center even if you delete all icons on the right.

        Components.ClockWidget {
            anchors.centerIn: parent
        }
    }

    // =========================================================================
    // SHARED TRAY CARD — dropdown for Network/Bluetooth/Volume/Power
    // =========================================================================
    Components.TrayCard {
        activeTray: panelWindow.activeTray
        onCloseRequested: panelWindow.activeTray = ""
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
            if (ncLoader.item && ncLoader.item.shown && panelWindow.activeTray !== "")
                panelWindow.activeTray = ""
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
    // IPC HANDLERS — External Control
    // =========================================================================

    // Bar visibility toggle (for Hyprland keybind)
    IpcHandler {
        id: barToggleIpc
        target: "barToggle"

        function toggle() {
            panelWindow.visible = !panelWindow.visible
            console.log("[Bar] Visibility toggled:", panelWindow.visible)
        }
    }

    // Keyboard layout cycle (for SUPER+SHIFT+SPACE — see configs/hypr/keybindings.lua)
    IpcHandler {
        id: keyboardIpc
        target: "keyboard"

        function next() {
            Services.KeyboardService.switchNext()
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
