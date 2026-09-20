// =============================================================================
// styles/vector/Scene.qml — THE VECTOR BAR (default style)
// =============================================================================
// Moved verbatim from shell.qml's bar strip (Phase-1 style architecture): this
// style owns its windows (one PanelWindow per output via Variants) and the
// whole rail layout — workspaces, layout slots, tray icons, plugin pills.
// The HOST (shell.qml) owns IPC handlers, shared overlays (TrayCard,
// notification center, logs/keybinds/zai/fastfetch, OSD), and services.
//
// Contract with the host (injected as `host`):
//   host.trayOwner                — set to this window when a tray opens
//   host.closeNotificationCenter()/toggleLogs()/toggleFastfetch()/toggleNotificationCenter()
//   host.ncShown / host.logsShown — overlay state for isActive feedback
//   host.pluginItems              — plugin registry (summon/hide IPC routing)
//   sceneRoot.instances           — per-output windows (barToggle IPC)
// Fallback: a style whose Scene.qml fails to load rolls the host back to
// vector, so the bar never renders empty.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components" as Components
import "../../config" as Config
import "../../services" as Services

Item {
    id: sceneRoot

    property var host: null
    // The host's barToggle IPC iterates the per-output windows.
    property var instances: bars.instances

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
            // hosts the TrayCard until closed). Opening a tray also closes
            // any open plugin panel — one bar popover at a time, all classes.
            onActiveTrayChanged: {
                if (activeTray !== "") {
                    host.trayOwner = panelWindow
                    host.closeNotificationCenter()
                    if (Services.PluginHostService.openPanel !== "")
                        Services.PluginHostService.openPanel = ""
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
                onTriggered: host.toggleFastfetch()
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
                            var reg = host.pluginItems
                            reg[modelData.id] = item
                            host.pluginItems = reg
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
                isActive: host.logsShown
                onTriggered: host.toggleLogs()
            }
        }
        Component {
            id: notificationsSlot
            Components.NotificationButton {
                Layout.alignment: Qt.AlignVCenter
                isActive: host.ncShown
                onCenterRequested: host.toggleNotificationCenter()
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
                        var reg = host.pluginItems
                        reg[modelData.id] = item
                        host.pluginItems = reg
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
}
