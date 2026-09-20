// =============================================================================
// styles/ryoku/Scene.qml — THE RYOKU BAR (v1: frame-strip identity)
// =============================================================================
// Same host contract and machinery as vector (windows, tray ownership, rail
// slots, plugin pills) — a different VISUAL LANGUAGE, ryoku's "paper and ink"
// grammar expressed through our live theme tokens:
//   • workspaces = mono tracked numbers, INVERTED-PLATE emphasis (selected
//     state flips to a bone plate — emphasis by inversion, not color)
//   • 1px hairline frame edge under the bar (ink at low alpha over text)
//   • registration marks (+) in the dead zones at both ends — print chrome
// Deeper divergence (own glyph set, marginalia, frame edges on 4 sides) is
// later-phase work; v1 deliberately reuses the theme-driven tray icons and
// plugin pills.
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
    // Registry helper with live-swap race guard: plugin delegates construct
    // DURING scene build, before the host injection lands (Loader.onLoaded) —
    // on a live style swap that order inverts (plugins list already warm).
    // callLater defers the write one frame, by which time host is set.
    function registerPlugin(id, item) {
        if (!host) { Qt.callLater(function() { sceneRoot.registerPlugin(id, item) }); return }
        var reg = host.pluginItems
        reg[id] = item
        host.pluginItems = reg
    }
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

            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Config.BarConfig.barPadding
                text: "+"
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: 9
                color: Config.ThemeConfig.colors.textDim
                opacity: 0.55
            }

            Components.ArchLogo {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 6
                onTriggered: host.toggleFastfetch()
            }

            // ── RYOKU WORKSPACES — inverted-plate emphasis ────────────────────
            Row {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 10
                spacing: 10

                Repeater {
                    model: Config.BarConfig.workspaceCount

                    Rectangle {
                        id: wsCell
                        readonly property int ws: index + 1
                        readonly property bool active: Services.HyprlandService.activeWorkspace === ws
                        implicitWidth: wsNum.implicitWidth + (active ? 12 : 0)
                        implicitHeight: 17
                        radius: 2
                        color: active ? Config.ThemeConfig.colors.text : "transparent"

                        Text {
                            id: wsNum
                            anchors.centerIn: parent
                            text: wsCell.ws < 10 ? "0" + wsCell.ws : "" + wsCell.ws
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1.2
                            color: wsCell.active ? Config.ThemeConfig.colors.background
                                                 : Config.ThemeConfig.colors.textDim
                            opacity: wsCell.active ? 1.0 : (wsMa.containsMouse ? 0.95 : 0.62)
                            Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.snap } }
                        }

                        MouseArea {
                            id: wsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.HyprlandService.switchTo(wsCell.ws)
                        }
                    }
                }
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

            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 6
                text: "+"
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: 9
                color: Config.ThemeConfig.colors.textDim
                opacity: 0.55
            }
            Item {
                width: Config.BarConfig.barPadding
                Layout.fillHeight: true
            }
        }

        // ── RYOKU FRAME EDGE — 1px hairline under the bar ────────────────────
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Config.ThemeConfig.hairline
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
                            sceneRoot.registerPlugin(modelData.id, item)
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
                        sceneRoot.registerPlugin(modelData.id, item)
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
