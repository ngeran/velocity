// =============================================================================
// styles/notch/Scene.qml — THE NOTCH BAR (Shibumi V2 "active bar" port)
// =============================================================================
// A content-width lobe hanging flush off the top screen edge with smooth
// cubic shoulders (one continuous cubic per shoulder, Shibumi RunChrome).
// The screen-facing side is OPEN — no shadow, no top border; a 1px hairline
// strokes only the shoulders + desktop-facing edge.
//
// ACTIVE NOTCH: when a popover opens under the bar (PluginPopup or TrayCard),
// the lobe's bottom edge carves an animated caret bite at the card's center
// x, and an opaque card-colored wedge fills the bite — the lobe and the card
// read as one connected shape (Shibumi's connectedPanel contract, ported:
// geometry lives in Engine.PopupCoordinator.connected because panels are
// mounted inside scene-owned plugin subtrees and die on style swap).
//
// Contract with the host (injected as `host`): IDENTICAL to vector (see
// vector/Scene.qml) — tray close on lobe click, three Engine.BarSections,
// sceneRoot.instances.
// Fallback: a style whose Scene.qml fails to load rolls the host back to
// vector, so the bar never renders empty.
//
// QD-OLED: the lobe fill is the #000000-clamped background token at 0.94
// (dark, not bright); the stroke is ThemeConfig.hairline (0.07 alpha); the
// caret bite is NEGATIVE SPACE (removes fill — burns nothing); the wedge is
// the same background token opaque. Rounding is the one deliberate doctrine
// waiver for this style (user-approved).
//
// Single file on purpose: the runtime Loader does not resolve bare sibling
// types without a qmldir (see styles/ryoku/qmldir) — no siblings, no qmldir.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
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

            // Plain modelData (NEVER `required property` — breaks re-attach
            // after DPMS off/on on JS-array models; see vector).
            property var modelData: null
            screen: modelData

            readonly property bool validScreen: screen !== null && screen.name !== "" && screen.width > 0
            property bool userHidden: false
            visible: validScreen && !userHidden

            // ── NOTCH GEOMETRY (tunables; Shibumi baseline barH=33) ────────────
            readonly property int barH: Config.BarConfig.barHeight
            readonly property int breathing: 3            // window = barH+3, lobe = barH (Shibumi 33/36)
            readonly property real sc: barH / 33.0
            readonly property int wing: Math.round(14 * sc)                    // shoulder horizontal span
            readonly property int shoulderR: Math.max(10, Math.min(16, Math.round(barH * 0.45)))
            readonly property int inset: wing + shoulderR // bottom-edge inset per side
            readonly property real kappa: 0.55228475      // circle-approximation constant
            readonly property int contentInset: wing + 3

            // Lobe fill: the QD-OLED-clamped background token at Shibumi's
            // 0.94 alpha (withAlpha is hex-string-only — Qt.rgba on the color).
            readonly property color bg: Config.BarConfig.colorBackground
            readonly property color lobeFill: Qt.rgba(bg.r, bg.g, bg.b, 0.94)

            // ── ACTIVE NOTCH state (per output) ─────────────────────────────
            // fed by PopupCoordinator.connected {owner, screen, caretX}
            property bool cutOpening: true
            property real cutReveal: 0
            property real lastCaretX: -1                  // frozen while retracting
            // bite (absolute px, NOT scaled — must match the wedge's world)
            readonly property real biteHalfW: 7 * cutReveal
            readonly property real biteDepth: 5 * cutReveal
            readonly property real biteCtlH: 4.25 * cutReveal
            readonly property real biteCtlV: 2 * cutReveal
            // wedge rides 0.8px inside the bite → hairline reveal on each flank
            readonly property real wedgeHalfW: 6.2 * cutReveal
            readonly property real wedgeDepth: 4.6 * cutReveal
            readonly property real wedgeCtlH: 3.76 * cutReveal
            readonly property real wedgeCtlV: 1.77 * cutReveal

            Connections {
                target: Engine.PopupCoordinator
                function onConnectedChanged() {
                    var c = Engine.PopupCoordinator.connected
                    if (c && c.screen === panelWindow.screen.name) {
                        panelWindow.cutOpening = true
                        panelWindow.lastCaretX = c.caretX
                        panelWindow.cutReveal = 1
                    } else {
                        panelWindow.cutOpening = false
                        panelWindow.cutReveal = 0
                    }
                }
            }
            Behavior on cutReveal {
                NumberAnimation {
                    duration: panelWindow.cutOpening ? Config.MotionConfig.move   // 170 OutCubic open
                                                     : Config.MotionConfig.flap   // 110 InCubic close
                    easing.type: panelWindow.cutOpening ? Config.MotionConfig.ease : Easing.InCubic
                }
            }

            // Caret x, lobe-local. The clamp grows with the bite so the bite's
            // feet never walk under the shoulder curves (a bare 13px clamp
            // self-intersects the path when inset > 13).
            readonly property real cxPad: Math.max(13, inset + 2) + 9 * cutReveal
            readonly property real cx: Math.max(cxPad,
                    Math.min(lobe.width - cxPad,
                             (lastCaretX >= 0 ? lastCaretX : lobe.width / 2) - lobe.x))

            // Content-fitted lobe, screen-centered (Shibumi compactShell math).
            readonly property real lobeW: Math.min(panelWindow.width - 10,
                    Math.max(80, leftRow.implicitWidth + centerRow.implicitWidth
                                 + rightRail.implicitWidth + 2 * contentInset + 24))
            readonly property real shellX: Math.round((panelWindow.width - lobeW) / 2)

            // =========================================================================
            // WINDOW — full-width strip reservation, transparent; the lobe is
            // painted by the Shape below. The extra 3px are breathing only —
            // popovers anchor at margins.top = barH, the wedge tip overlaps 1px.
            // =========================================================================
            anchors { top: true; left: true; right: true }
            implicitHeight: barH + breathing
            color: "transparent"
            // Input confined to the lobe bbox — the transparent side bands and
            // the breathing slit pass clicks through to the desktop.
            mask: Region { item: lobe }

            // Click on the lobe (outside content) closes the tray card this
            // bar opened.
            MouseArea {
                anchors.fill: parent
                enabled: !!host && host.trayOwner === panelWindow && host.activeTray !== ""
                onClicked: host.closeTray()
            }

            // =========================================================================
            // THE LOBE — silhouette + hairline + caret wedge, content on top
            // =========================================================================
            Item {
                id: lobe
                x: shellX
                y: 0
                width: lobeW
                height: barH

                Behavior on x { NumberAnimation { duration: Config.MotionConfig.move; easing.type: Config.MotionConfig.ease } }
                Behavior on width { NumberAnimation { duration: Config.MotionConfig.move; easing.type: Config.MotionConfig.ease } }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    // Path heights reach barH+1 (wedge seam) — inside the window's
                    // breathing band; the Shape itself clips nothing (no clip).

                    // 1 — SILHOUETTE. Top edge flush at y=0 (screen edge, open),
                    // one continuous cubic per shoulder, bottom edge with the
                    // caret bite. At cutReveal 0 the bite cubics collapse onto
                    // the bottom line — ONE path, never swapped.
                    ShapePath {
                        fillColor: panelWindow.lobeFill
                        strokeColor: "transparent"
                        startX: 0; startY: 0

                        PathLine { x: lobe.width; y: 0 }
                        // right shoulder — ONE continuous cubic, no neck
                        PathCubic {
                            control1X: lobe.width;                       control1Y: panelWindow.kappa * panelWindow.barH
                            control2X: lobe.width - panelWindow.inset + panelWindow.kappa * panelWindow.inset
                                                                         control2Y: panelWindow.barH
                            x: lobe.width - panelWindow.inset;           y: panelWindow.barH
                        }
                        // bottom edge → bite right foot
                        PathLine { x: panelWindow.cx + panelWindow.biteHalfW; y: panelWindow.barH }
                        // bite right flank, rising to the apex
                        PathCubic {
                            control1X: panelWindow.cx + panelWindow.biteCtlH; control1Y: panelWindow.barH
                            control2X: panelWindow.cx;                        control2Y: panelWindow.barH - panelWindow.biteCtlV
                            x: panelWindow.cx;                                y: panelWindow.barH - panelWindow.biteDepth
                        }
                        // bite left flank, falling back to the edge
                        PathCubic {
                            control1X: panelWindow.cx;                        control1Y: panelWindow.barH - panelWindow.biteCtlV
                            control2X: panelWindow.cx - panelWindow.biteCtlH; control2Y: panelWindow.barH
                            x: panelWindow.cx - panelWindow.biteHalfW;        y: panelWindow.barH
                        }
                        // bottom edge → left shoulder foot
                        PathLine { x: panelWindow.inset; y: panelWindow.barH }
                        // left shoulder — mirrored cubic, closes at the start
                        PathCubic {
                            control1X: panelWindow.inset - panelWindow.kappa * panelWindow.inset
                                                                       control1Y: panelWindow.barH
                            control2X: 0;                              control2Y: panelWindow.kappa * panelWindow.barH
                            x: 0;                                      y: 0
                        }
                    }

                    // 2 — HAIRLINE. Open contour: shoulders + bottom edge only
                    // (the screen-edge side stays unstroked — Shibumi's open
                    // edge). 1px at ThemeConfig.hairline (0.07 alpha).
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Config.ThemeConfig.hairline
                        strokeWidth: 1
                        startX: 0; startY: 0

                        PathCubic {
                            control1X: 0;                              control1Y: panelWindow.kappa * panelWindow.barH
                            control2X: panelWindow.inset - panelWindow.kappa * panelWindow.inset
                                                                       control2Y: panelWindow.barH
                            x: panelWindow.inset;                      y: panelWindow.barH
                        }
                        PathLine { x: panelWindow.cx - panelWindow.biteHalfW; y: panelWindow.barH }
                        PathCubic {
                            control1X: panelWindow.cx - panelWindow.biteCtlH; control1Y: panelWindow.barH
                            control2X: panelWindow.cx;                        control2Y: panelWindow.barH - panelWindow.biteCtlV
                            x: panelWindow.cx;                                y: panelWindow.barH - panelWindow.biteDepth
                        }
                        PathCubic {
                            control1X: panelWindow.cx;                        control1Y: panelWindow.barH - panelWindow.biteCtlV
                            control2X: panelWindow.cx + panelWindow.biteCtlH; control2Y: panelWindow.barH
                            x: panelWindow.cx + panelWindow.biteHalfW;        y: panelWindow.barH
                        }
                        PathLine { x: lobe.width - panelWindow.inset; y: panelWindow.barH }
                        PathCubic {
                            control1X: lobe.width - panelWindow.inset + panelWindow.kappa * panelWindow.inset
                                                                       control1Y: panelWindow.barH
                            control2X: lobe.width;                     control2Y: panelWindow.kappa * panelWindow.barH
                            x: lobe.width;                             y: 0
                        }
                    }

                    // 3 — CARET WEDGE. Card-colored plug inside the bite — the
                    // popover windows start BELOW the bar (margins.top = barH),
                    // so (unlike Shibumi) the caret is drawn bar-side. Opaque
                    // background token = identical to the Popover card fill →
                    // seamless junction; 1px overlap into the card (barH+1) seals
                    // the seam.
                    ShapePath {
                        fillColor: Config.BarConfig.colorBackground
                        strokeColor: "transparent"
                        startX: panelWindow.cx - panelWindow.wedgeHalfW; startY: panelWindow.barH + 1

                        PathCubic {
                            control1X: panelWindow.cx - panelWindow.wedgeCtlH; control1Y: panelWindow.barH + 1
                            control2X: panelWindow.cx;                         control2Y: panelWindow.barH + 1 - panelWindow.wedgeCtlV
                            x: panelWindow.cx;                                 y: panelWindow.barH - panelWindow.wedgeDepth
                        }
                        PathCubic {
                            control1X: panelWindow.cx;                         control1Y: panelWindow.barH + 1 - panelWindow.wedgeCtlV
                            control2X: panelWindow.cx + panelWindow.wedgeCtlH; control2Y: panelWindow.barH + 1
                            x: panelWindow.cx + panelWindow.wedgeHalfW;        y: panelWindow.barH + 1
                        }
                    }
                }

                // ── SECTIONS — from plugins-state.json `layout` (built-ins
                // included). Positioned absolutely inside the lobe; the lobe
                // width fits their implicit widths. ──────────────────────────
                Engine.BarSection {
                    id: leftRow
                    x: panelWindow.contentInset
                    y: 0
                    height: panelWindow.barH
                    name: "left"
                    window: panelWindow
                    gap: Config.BarConfig.iconSpacing
                }

                Engine.BarSection {
                    id: rightRail
                    y: 0
                    height: panelWindow.barH
                    x: lobe.width - panelWindow.contentInset - width
                    name: "right"
                    window: panelWindow
                    gap: Config.BarConfig.slotMargin
                }

                // Center: screen-centered, clamped between the rails
                // (Shibumi centerTargetX).
                Engine.BarSection {
                    id: centerRow
                    y: 0
                    height: panelWindow.barH
                    name: "center"
                    window: panelWindow
                    gap: 14
                    x: Math.max(panelWindow.contentInset + leftRow.implicitWidth + 12,
                            Math.min(lobe.width - panelWindow.contentInset
                                     - rightRail.implicitWidth - 12 - implicitWidth,
                                     panelWindow.width / 2 - lobe.x - implicitWidth / 2))
                }
            }
        }
    }   // Variants (per-output bars)
}
