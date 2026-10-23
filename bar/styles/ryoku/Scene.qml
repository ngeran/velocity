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
            // QD-OLED: the active-workspace plate flashes on switch, then
            // decays exponentially to the faint settled tint — no binary
            // flip. Bright exposure stays strictly below the old flat 45s
            // pattern (strength crosses the 2% floor at ~24s, tau = 6s), and
            // the timer only ticks while there is anything left to decay.
            // The decay is an energy-budget pattern, not a motion token — it
            // deliberately ignores reduceMotion.
            property real plateStrength: 0
            readonly property color wsInk: Config.ThemeConfig.colors.text
            // Settled plate = ink @0.10. Built from the color object directly —
            // ThemeConfig.withAlpha takes a HEX STRING and throws on a color
            // (the tint() trap), which would kill the whole cell binding.
            readonly property color plateBase: Qt.rgba(wsInk.r, wsInk.g, wsInk.b, 0.10)
            function mixPlate(a, b, s) {
                return Qt.rgba(a.r + (b.r - a.r) * s, a.g + (b.g - a.g) * s,
                               a.b + (b.b - a.b) * s, a.a + (b.a - a.a) * s)
            }

            property bool userHidden: false
            // `visible` is bound ONCE, in the B5 block below
            // (validScreen && !userHidden && edgeApplied) — a second binding
            // here is a hard compile error ("Property value set multiple
            // times") and silently drops the whole style to vector.

            Timer {
                interval: 200
                running: panelWindow.plateStrength > 0.02
                repeat: true
                onTriggered: {
                    panelWindow.plateStrength *= Math.exp(-0.2 / 6)
                    if (panelWindow.plateStrength <= 0.02) panelWindow.plateStrength = 0
                }
            }
            Connections {
                target: Services.HyprlandService
                function onActiveWorkspaceChanged() {
                    panelWindow.plateStrength = 1   // bright = feedback only
                }
            }

            // =========================================================================
            // POSITIONING
            // =========================================================================

            // B5: layer-shell anchors only re-read on (re)map — when the
            // configured edge changes, cycle the window (brief flicker) so
            // the strip lands on the new edge live, no restart. The cycle
            // flag is written imperatively; `visible` stays a binding.
            property bool edgeApplied: true
            readonly property string edgeKey: Config.BarConfig.barPosition
            onEdgeKeyChanged: { edgeApplied = false; edgeRemap.restart() }
            Timer {
                id: edgeRemap
                interval: 150
                onTriggered: panelWindow.edgeApplied = true
            }
            visible: validScreen && !userHidden && edgeApplied

            anchors {
                top: !Config.BarConfig.barAtBottom
                bottom: Config.BarConfig.barAtBottom
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
                id: leftSection
                name: "left"
                window: panelWindow
                gap: 10
                overrides: ({ "velocity.workspaces": ryokuWorkspaces })
                fitMap: panelWindow.fitPlan.maps.left
                Layout.fillHeight: true
            }

            Item { Layout.fillWidth: true; Layout.fillHeight: true }

            Engine.BarSection {
                id: rightSection
                name: "right"
                window: panelWindow
                gap: Config.BarConfig.slotMargin
                fitMap: panelWindow.fitPlan.maps.right
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
                        // Hover intent (press grammar, #5): the hover fill
                        // lands after a short entry delay so sweeping the
                        // row doesn't shimmer; exit is instant.
                        property bool hot: false
                        implicitWidth: wsNum.implicitWidth + (active ? 12 : 6)
                        implicitHeight: 17
                        radius: 0   // QD-OLED: no anti-aliased corner subpixels
                        // Ryoku press grammar: hover = ink @0.08, pressed
                        // @0.16, snap-timed. The active plate starts INVERTED
                        // on switch and decays (plateStrength) to the faint
                        // @0.10 tint — no static bright fill (QD-OLED rule).
                        color: wsCell.active
                               ? panelWindow.mixPlate(panelWindow.plateBase,
                                                      panelWindow.wsInk,
                                                      panelWindow.plateStrength)
                               : wsMa.pressed
                                 ? Config.ThemeConfig.withAlpha(Config.ThemeConfig.colors.text, 0.16)
                                 : wsCell.hot
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
                                   ? panelWindow.mixPlate(Config.ThemeConfig.colors.text,
                                                          Config.ThemeConfig.colors.background,
                                                          panelWindow.plateStrength)
                                   : Config.ThemeConfig.colors.textDim
                            opacity: wsCell.active ? 1.0 : (wsCell.hot ? 0.95 : 0.62)
                            Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.snap } }
                        }

                        MouseArea {
                            id: wsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: {
                                if (containsMouse) wsHotDelay.restart()
                                else { wsHotDelay.stop(); wsCell.hot = false }
                            }
                            onClicked: Services.HyprlandService.switchTo(wsCell.ws)
                        }
                        Timer {
                            id: wsHotDelay
                            interval: 70
                            onTriggered: wsCell.hot = true
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
            // Edge tint line rides the desktop-facing edge — flips with the bar.
            anchors.bottom: Config.BarConfig.barAtBottom ? null : parent.bottom
            anchors.top: Config.BarConfig.barAtBottom ? parent.top : null
            width: parent.width
            height: 1
            color: Config.ThemeConfig.withAlpha(Config.ThemeConfig.colors.text, 0.045)
        }

        // Overflow plan (engine lib/fit.mjs): measured cell widths + collapse
        // priorities in; compact/collapse maps and the clamped center x out.
        readonly property var fitPlan: Engine.PluginRegistry.planFit({
            width: panelWindow.width,
            pad: Config.BarConfig.barPadding,
            gap: 10,
            slack: 8,
            left: leftSection.cellInfos,
            center: centerSection.cellInfos,
            right: rightSection.cellInfos
        })

        // Center section: x from the plan — dead-center ideal, clamped
        // between the rails (anchors.centerIn used to overlap them on narrow
        // windows). Empty center = nothing drawn.
        Engine.BarSection {
            id: centerSection
            x: panelWindow.fitPlan.centerX
            height: parent.height
            name: "center"
            window: panelWindow
            gap: 14
            fitMap: panelWindow.fitPlan.maps.center
        }
    }
    }   // Variants (per-output bars)
}
