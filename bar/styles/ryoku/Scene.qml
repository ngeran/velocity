// =============================================================================
// styles/ryoku/Scene.qml — THE RYOKU BAR (v1: frame-strip identity)
// =============================================================================
// Same host contract and machinery as vector (windows, tray ownership, engine
// sections) — a different VISUAL LANGUAGE, ryoku's "paper and ink"
// grammar expressed through our live theme tokens:
//   • workspaces = mono tracked numbers, INVERTED-PLATE emphasis (selected
//     state flips to a bone plate — emphasis by inversion, not color)
//   • 1px hairline frame edge under the bar (ink at ~4.5% — near-invisible,
//     edge definition only). Ornament chrome (glyphs/marginalia/reg marks)
//     was REMOVED per user rule: nothing stays that isn't clickable or
//     doing a job (also the strictest QD-OLED posture)
// Deeper divergence (own glyph set, marginalia, frame edges on 4 sides) is
// later-phase work; v1 deliberately reuses the theme-driven tray icons and
// plugin pills.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config" as Config
import "../../engine" as Engine
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


            // Placeholder/zero-sized screens (connector hotplug churn) must
            // not spawn ghost bars (Shibumi BarPanel.validScreen pattern).
            // userHidden keeps the IPC toggle out of the binding (assignment
            // would break it).
            readonly property bool validScreen: screen !== null && screen.name !== "" && screen.width > 0
            // QD-OLED: the active-workspace plate stays bright only this
            // long after a switch (feedback), then dims to a faint tint.
            property bool wsPlateBright: false

            property bool userHidden: false
            visible: validScreen && !userHidden

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

            // Sections come from plugins-state.json `layout`; ryoku swaps in
            // its own workspaces (overrides) and keeps every other widget.
            Engine.BarSection {
                name: "left"
                window: panelWindow
                gap: 10
                overrides: ({ "velocity.workspaces": ryokuWorkspaces })
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

        // ── RYOKU WORKSPACES — inverted-plate emphasis (replaces the
        // velocity.workspaces built-in in this style) ──────────────────────
        Component {
            id: ryokuWorkspaces
            Row {
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
                            font.pixelSize: Math.max(8, Math.round(10 * Config.BarConfig.contentScale))
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
