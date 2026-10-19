// =============================================================================
// styles/vector/Scene.qml — THE VECTOR BAR (default style)
// =============================================================================
// Moved verbatim from shell.qml's bar strip (Phase-1 style architecture): this
// style owns its windows (one PanelWindow per output via Variants) and the
// window chrome; WHAT renders in its left/center/right comes from the engine
// layout (Engine.BarSection — built-ins and plugins alike).
// The HOST (shell.qml) owns IPC handlers, shared overlays (TrayCard,
// notification center, logs/keybinds/zai/fastfetch, OSD), and services.
//
// Contract with the host (injected as `host`):
//   host.trayOwner / activeTray / closeTray() — empty-bar click closes the
//                                   tray card this window opened
//   Engine.BarSection ×3          — left/center/right; widgets reach the host
//                                   through ctx (built-ins: ctx.host)
//   sceneRoot.instances           — per-output windows (barToggle IPC)
// Fallback: a style whose Scene.qml fails to load rolls the host back to
// vector, so the bar never renders empty.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config" as Config
import "../../engine" as Engine

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


            // Placeholder/zero-sized screens (connector hotplug churn) must
            // not spawn ghost bars (Shibumi BarPanel.validScreen pattern).
            // userHidden keeps the IPC toggle out of the binding (assignment
            // would break it).
            readonly property bool validScreen: screen !== null && screen.name !== "" && screen.width > 0
            property bool userHidden: false
            visible: validScreen && !userHidden

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
        // MAIN LAYOUT — three engine sections
        // =========================================================================

        // Click on empty bar area closes the tray card this bar opened.
        MouseArea {
            anchors.fill: parent
            enabled: !!host && host.trayOwner === panelWindow && host.activeTray !== ""
            onClicked: host.closeTray()
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Item { width: Config.BarConfig.barPadding; Layout.fillHeight: true }

            // Sections come from plugins-state.json `layout` (built-ins
            // included: logo, workspaces, tray icons are velocity.* plugins).
            Engine.BarSection {
                name: "left"
                window: panelWindow
                gap: Config.BarConfig.iconSpacing
                Layout.fillHeight: true
            }

            Item { Layout.fillWidth: true; Layout.fillHeight: true }

            Engine.BarSection {
                name: "right"
                window: panelWindow
                gap: Config.BarConfig.slotMargin
                Layout.fillHeight: true
            }

            Item { width: Config.BarConfig.barPadding; Layout.fillHeight: true }
        }

        // Center section: anchored to the window, so it stays dead-center
        // regardless of the rails. Empty center = nothing drawn.
        Engine.BarSection {
            anchors.centerIn: parent
            height: parent.height
            name: "center"
            window: panelWindow
            gap: 14
        }
    }
    }   // Variants (per-output bars)
}
