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
    // Scene teardown (style swap) destroys plugin items — drop their registry
    // entries so the host's summon/hide IPC never routes to dead objects.
    function unregisterPlugin(id) {
        if (!host || !host.pluginItems[id]) return
        let reg = host.pluginItems
        delete reg[id]
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
            // Marginalia index: 1-based position among real outputs (computed
            // rather than trusting a delegate index that Variants may not
            // provide).
            // QD-OLED: the active-workspace plate stays bright only this
            // long after a switch (feedback), then dims to a faint tint.
            property bool wsPlateBright: false

            // ── MARGINALIA index: 1-based position among real outputs (computed
            // rather than trusting a delegate index that Variants may not
            // provide).
            readonly property int screenIndex: {
                var ss = Quickshell.screens
                for (var i = 0; i < ss.length; i++)
                    if (ss[i] === panelWindow.screen) return i + 1
                return 1
            }
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

            Timer {
                id: wsPlateDim
                interval: 45000
                running: panelWindow.wsPlateBright
                repeat: false
                onTriggered: panelWindow.wsPlateBright = false
            }
            Connections {
                target: Services.HyprlandService
                function onActiveWorkspaceChanged() {
                    panelWindow.wsPlateBright = true   // bright = feedback only
                    wsPlateDim.restart()
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
                opacity: 0.4
            }

            Components.ArchLogo {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 6
                onTriggered: host.toggleFastfetch()
            }

            // ── RYOKU PIXEL GLYPH — 1-bit asanoha star (print separator) ─────
            RyokuPixel {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 10
                glyph: [
                    "00011000",
                    "00011000",
                    "11011011",
                    "11100111",
                    "11011011",
                    "00011000",
                    "00011000",
                    "00000000"
                ]
                ink: Config.ThemeConfig.colors.textDim
                inkOpacity: 0.4
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
                        implicitWidth: wsNum.implicitWidth + (active ? 12 : 6)
                        implicitHeight: 17
                        radius: 0   // QD-OLED: no anti-aliased corner subpixels
                        // Ryoku press grammar: hover = ink @0.08, pressed
                        // @0.16, snap-timed. The active plate inverts BRIGHT
                        // only as switch feedback (wsPlateBright), then
                        // settles to a faint @0.10 tint — no static bright
                        // fill (QD-OLED burn-in rule).
                        color: wsCell.active
                               ? (panelWindow.wsPlateBright
                                   ? Config.ThemeConfig.colors.text
                                   : Config.ThemeConfig.withAlpha(Config.ThemeConfig.colors.text, 0.10))
                               : wsMa.pressed
                                 ? Config.ThemeConfig.withAlpha(Config.ThemeConfig.colors.text, 0.16)
                                 : wsMa.containsMouse
                                   ? Config.ThemeConfig.withAlpha(Config.ThemeConfig.colors.text, 0.08)
                                   : "transparent"
                        Behavior on color { ColorAnimation { duration: Config.MotionConfig.move } }

                        Text {
                            id: wsNum
                            anchors.centerIn: parent
                            text: wsCell.ws < 10 ? "0" + wsCell.ws : "" + wsCell.ws
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1.2
                            color: wsCell.active
                                   ? (panelWindow.wsPlateBright
                                       ? Config.ThemeConfig.colors.background
                                       : Config.ThemeConfig.colors.text)
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

            // ── RYOKU MARGINALIA — katakana gloss + screen index. Text-only,
            // no border box: a static 1px rectangle outline is exactly the
            // shape QD-OLED burn-in hates. Very dim (0.45). ────────────────
            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 6
                text: "リョク  R·" + (panelWindow.screenIndex < 10
                                     ? "0" + panelWindow.screenIndex
                                     : panelWindow.screenIndex)
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: 8
                font.letterSpacing: 1.0
                color: Config.ThemeConfig.colors.textDim
                opacity: 0.45
            }
            Item {
                width: Config.BarConfig.barPadding
                Layout.fillHeight: true
            }
        }

        // ── RYOKU FRAME EDGE — 1px under the bar. Static full-width line, so
        // the alpha is deliberately BELOW the theme hairline token (~4.5% ink
        // ≈ a couple of nits on QD-OLED — dimmer than the rounding-AA it
        // replaces). ────────────────────────────────────────────────────────
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Config.ThemeConfig.withAlpha(Config.ThemeConfig.colors.text, 0.045)
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
                        Component.onDestruction: sceneRoot.unregisterPlugin(modelData.id)
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
