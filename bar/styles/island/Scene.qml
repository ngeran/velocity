// =============================================================================
// styles/island/Scene.qml — THE DYNAMIC ISLAND BAR
// =============================================================================
// A black island hanging from the screen edge. At rest it holds only the
// center section (the clock); hovering blooms it into a one-row glance with
// the left/right sections unmasked around the clock; opening any plugin
// panel or tray card morphs it into that panel — the card's content is
// ADOPTED into the island (Popover embedHost), no second window.
//
//   rest ──hover──▶ glance ──click widget──▶ panel ──hover-out / close──▶ …
//
// Contract with the host (injected as `host`): same as vector (tray close on
// island click, three Engine.BarSections, sceneRoot.instances). Island host
// API (each PanelWindow, registered in Engine.PopupCoordinator.islands):
//   present(pop)            adopt pop.embedItem (pop.embedW × pop.embedH)
//   withdraw(pop, now)      give it back; returns true when it will call
//                           pop.restoreEmbed() itself after the fade-out
//   maxContentW/maxContentH content budget so the island stays on screen
//
// Motion: SpringAnimation morph on width/height/radius (OPEN softer, CLOSE
// stiffer), content crossfade + scale with the in-content delayed behind the
// shell. reduceMotion → instant. Math lives in lib/island.mjs (node-tested).
//
// QD-OLED: opaque PURE-black fill (#000000 regardless of theme — pixels
// off), theme tokens only for what's drawn on it, no stroke,
// rest content dimmed (never full-white), slow sub-perceptual orbit of the
// island + its content, deeper dim after inactivity (islandBurnGuard).
//
// Window: fixed-width full-strip layer surface whose height follows the
// island (grown at the start of a morph, trimmed when it settles — never
// per frame); input mask = the island; exclusive zone = the rest height.
// Single file on purpose (no sibling types → no qmldir; see notch).
// =============================================================================

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../../components" as Bar
import "../../config" as Config
import "../../engine" as Engine
import "../../services" as Services
import "../../Ui" as Ui
import "lib/island.mjs" as Isl

Item {
    id: sceneRoot

    property var host: null
    property var instances: bars.instances

    // Concave fillet joining the island to the screen edge. Drawn for the
    // LEFT side of a top bar; mirrored by transforms for the other cases.
    component Fillet: Shape {
        id: fil
        property real cornerRadius: 10
        property color fill: "black"
        width: cornerRadius; height: cornerRadius
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: fil.fill
            strokeColor: "transparent"
            startX: 0; startY: 0
            PathLine { x: fil.cornerRadius; y: 0 }
            PathLine { x: fil.cornerRadius; y: fil.cornerRadius }
            // quarter circle centred at (0, cornerRadius)
            PathCubic {
                control1X: fil.cornerRadius;                    control1Y: fil.cornerRadius - 0.55228475 * fil.cornerRadius
                control2X: 0.55228475 * fil.cornerRadius;       control2Y: 0
                x: 0;                                           y: 0
            }
        }
    }

    Variants {
        id: bars
        model: Quickshell.screens

        PanelWindow {
            id: win

            // Plain modelData (NEVER `required property` — see vector).
            property var modelData: null
            screen: modelData

            readonly property bool validScreen: screen !== null && screen.name !== "" && screen.width > 0
            property bool userHidden: false
            // B5: layer-shell anchors only re-read on (re)map (see vector).
            property bool edgeApplied: true
            readonly property string edgeKey: Config.BarConfig.barPosition
            onEdgeKeyChanged: { edgeApplied = false; edgeRemap.restart() }
            Timer { id: edgeRemap; interval: 150; onTriggered: win.edgeApplied = true }
            visible: validScreen && !userHidden && edgeApplied
            onVisibleChanged: { if (!visible) win._dismissClient(); win._register() }

            readonly property bool atBottom: Config.BarConfig.barAtBottom
            readonly property int barH: Config.BarConfig.barHeight
            readonly property bool reduceMotion: Config.MotionConfig.reduceMotion
            readonly property bool burnGuard: Config.BarConfig.islandBurnGuard
            readonly property int padX: Math.round(barH * 0.55)
            readonly property int panelPad: 6
            readonly property int margin: 12
            readonly property int sectionGap: Math.round(barH * 0.8)
            readonly property int fillet: Isl.filletRadius(barH)
            // Always PURE black, whatever the theme (QD-OLED: pixels off) —
            // not the background token, which a non-OLED theme lifts off
            // black. Everything drawn ON the island stays theme-driven.
            readonly property color fill: "#000000"

            // =================================================================
            // STATE — rest | glance | activity | panel (lib/island.mjs)
            // =================================================================
            property string islandState: Isl.REST
            property bool hovered: false          // intent-filtered hover
            property bool _rawHover: false
            property var client: null             // the presented Popover
            property var leaving: null            // Popover fading out
            property bool _enteredPanel: false

            function _event(ev) {
                win.islandState = Isl.nextState(win.islandState, ev, {
                    hovered: win.hovered, hasPanel: win.client !== null, hasActivity: win.activityLive })
            }

            // Live activity (J0): the queue's arbitrated winner — OSD
            // feedback is its top-priority member, plugins/scripts publish
            // lower ranks (ctx.island / `island` IPC). focusedOnly entries
            // (the OSD) bloom on the focused output only.
            readonly property var activity: Engine.PopupCoordinator.visibleActivity
            readonly property bool activityLive: win.activity !== null
                && (!win.activity.focusedOnly
                    || Services.HyprlandService.focusedMonitor === ""
                    || (win.screen !== null && Services.HyprlandService.focusedMonitor === win.screen.name))
            onActivityLiveChanged: _event(activityLive ? "activity" : "activityEnd")
            // QD-OLED: an activity may hold full alpha for ≤ 3 s of stillness
            // — then it dims to the rest level until its next update (new
            // winner or in-place refresh resets the clock). The orbit keeps
            // moving the pixels underneath the whole time. Hover holds too:
            // a pointer on the island means someone is reading — the sweep
            // defers expiry (PopupCoordinator._holds) and the dim waits.
            readonly property string activityStamp: win.activity
                ? win.activity.key + ":" + win.activity.seq : ""
            property bool activityDim: false
            onActivityStampChanged: {
                activityDim = false
                win._syncHold()
            }
            onHoveredChanged: win._syncHold()
            Timer {
                interval: 3000
                running: win.activityLive && !win.activityDim && !win.hovered
                onTriggered: win.activityDim = true
            }
            readonly property real activityAlpha: win.activityDim ? 0.45 : 1
            // Hold only while this island both shows the activity AND is
            // hovered; "" releases this island's tag. Released on destruction
            // (style swap) so a dead renderer never pins a key. The tag is
            // the registered screen name (_registeredOn, "" when unregistered
            // — holdActivity ignores empty tags).
            function _syncHold() {
                var key = (win.hovered && win.activityLive) ? win.activity.key : ""
                Engine.PopupCoordinator.holdActivity("island:" + win._registeredOn, key)
            }
            // (destruction release merged into the host's single
            // Component.onDestruction below — a second handler here made the
            // whole island Scene fail to load since the J3 commit: "Property
            // value set multiple times" → silent fallback to vector.)

            Timer {
                id: hoverInTimer
                interval: Isl.HOVER_IN_MS
                onTriggered: if (win._rawHover) { win.hovered = true; win._touch(); win._event("hoverIn") }
            }
            Timer {
                id: hoverOutTimer
                interval: Isl.HOVER_OUT_MS
                onTriggered: if (!win._rawHover) { win.hovered = false; win._event("hoverOut") }
            }
            // Panels dismiss on hover-out like iOS — only once the cursor has
            // been inside the bloomed island (opening from a keybind with the
            // cursor elsewhere must not auto-close).
            Timer {
                id: panelOutTimer
                interval: Isl.PANEL_OUT_MS
                onTriggered: if (!win._rawHover && win._enteredPanel) win._dismissClient()
            }
            // Opened by keybind/IPC with the cursor elsewhere: no backdrop and
            // no keyboard focus here, so retract after a while unless entered.
            Timer {
                id: panelIdleTimer
                interval: 8000
                onTriggered: if (!win._enteredPanel) win._dismissClient()
            }
            function _setRawHover(h) {
                win._rawHover = h
                if (h) {
                    hoverOutTimer.stop(); panelOutTimer.stop(); panelIdleTimer.stop()
                    if (win.client) win._enteredPanel = true
                    if (!win.hovered) hoverInTimer.restart()
                } else {
                    hoverInTimer.stop()
                    if (win.hovered) hoverOutTimer.restart()
                    if (win.client && win._enteredPanel) panelOutTimer.restart()
                }
            }

            function _dismissClient() {
                if (win.client && win.client._dismiss) win.client._dismiss()
            }

            // =================================================================
            // SWITCHER — Control · Calendar · Wi-Fi · Bluetooth · Volume. While one of
            // them is open in the island, a strip on the flat-edge side
            // switches in place (the island morphs between their sizes).
            // =================================================================
            readonly property string calendarPlugin: "nikos.clock"
            readonly property var dockItems: [
                { key: "control",   glyph: "󰒓", plugin: "" },
                { key: "calendar",  glyph: "󰃭", plugin: calendarPlugin },
                { key: "network",   glyph: "󰖩", plugin: "velocity.network" },
                { key: "bluetooth", glyph: "󰂯", plugin: "velocity.bluetooth" },
                { key: "volume",    glyph: "󰕾", plugin: "velocity.volume" }
            ]
            readonly property bool _trayMine: !!sceneRoot.host && sceneRoot.host.trayOwner === win
            readonly property string dockKey: {
                if (win.client === null) return ""
                if (_trayMine) {
                    var t = sceneRoot.host.activeTray
                    if (t === "control" || t === "network" || t === "bluetooth" || t === "volume") return t
                    return ""
                }
                return Engine.PopupCoordinator.current === calendarPlugin ? "calendar" : ""
            }
            readonly property bool dockActive: dockKey !== ""
            // Tray → tray keeps the same Popover (TrayCard swaps its body):
            // the fitScale binding already makes the new body grow/shrink with
            // the island, so no extra choreography is needed here.
            readonly property int dockH: barH
            readonly property int dockOffset: dockActive ? dockH : 0

            function _inLayout(id) {
                var sec = Engine.PluginRegistry.sections
                return ["left", "center", "right"].some(function(k) {
                    return (sec[k] || []).indexOf(id) !== -1
                })
            }
            // This window's own instance (summon() would pick the focused
            // monitor's, which may be another island).
            function _ownInstance(id) {
                var list = Engine.PluginRegistry.instances[id] || []
                for (var i = 0; i < list.length; i++)
                    if (list[i].window === win && list[i].kind === "bar-widget" && list[i].item) return list[i].item
                return null
            }
            function dockSwitch(key) {
                if (key === win.dockKey || !sceneRoot.host) return
                win._touch()
                if (key === "calendar") {
                    var w = win._ownInstance(win.calendarPlugin)
                    if (w && typeof w.open === "function") w.open()
                } else {
                    sceneRoot.host.toggleTray(win, key, null)
                }
            }

            // =================================================================
            // ISLAND HOST API (Popover embedHost)
            // =================================================================
            readonly property var _budget: Isl.panelBudget({
                panelPad: panelPad, margin: margin,
                screenW: win.width, screenH: win.screen ? win.screen.height : 0 })
            readonly property real maxContentW: _budget.w
            readonly property real maxContentH: _budget.h > 0 ? Math.max(1, _budget.h - dockOffset) : _budget.h

            function present(pop) {
                if (!pop || !pop.embedItem) return
                if (win.leaving === pop) {               // reopened mid-fade
                    contentOut.stop()
                    win.leaving = null
                } else {
                    win._finishLeaving()
                    // Panel → panel (switcher, or any new claim): the old
                    // content fades out in place while the new one fades in;
                    // its own withdraw() later finds it in `leaving`.
                    if (win.client && win.client !== pop) {
                        var old = win.client
                        win.client = null
                        if (win.reduceMotion) win._release(old)
                        else {
                            var oi = old.embedItem
                            oi.x = oi.x; oi.y = oi.y; oi.scale = oi.scale
                            win.leaving = old
                            contentOut.target = oi
                            contentOut.restart()
                        }
                    }
                    var fresh = pop.embedItem
                    fresh.parent = stage
                    fresh.opacity = 0
                }
                // (Re)bind every time: withdraw() froze x/y for its fade-out.
                var it = pop.embedItem
                it.transformOrigin = win.atBottom ? Item.Bottom : Item.Top
                it.x = Qt.binding(function() { return Math.round((island.width - pop.embedW) / 2) })
                it.y = Qt.binding(function() {
                    return win.atBottom ? island.height - win.dockOffset - win.panelPad - pop.embedH
                                        : win.dockOffset + win.panelPad })
                // Scale-led motion: the content is sized by the island's live
                // (springing) box, so it grows/shrinks WITH the island.
                it.scale = Qt.binding(function() {
                    return win.reduceMotion ? 1
                        : Isl.fitScale(island.width, island.height, pop.embedW, pop.embedH,
                                       win.panelPad, win.dockOffset) })
                win.client = pop
                win._enteredPanel = win._rawHover
                if (win._enteredPanel) panelIdleTimer.stop(); else panelIdleTimer.restart()
                win._touch()
                win._event("present")
                contentIn.target = pop.embedItem
                contentIn.restart()
            }

            function withdraw(pop, now) {
                if (pop === win.leaving) {
                    if (now) { contentOut.stop(); win.leaving = null }
                    return !now
                }
                if (pop !== win.client) return false
                win.client = null
                panelOutTimer.stop()
                panelIdleTimer.stop()
                win._event("dismiss")
                if (now || win.reduceMotion) { contentIn.stop(); return false }
                win._finishLeaving()
                contentIn.stop()
                var it = pop.embedItem
                it.x = it.x; it.y = it.y; it.scale = it.scale   // freeze in place
                win.leaving = pop
                contentOut.target = it
                contentOut.restart()
                return true
            }

            function _release(pop) {
                if (pop && pop.restoreEmbed) pop.restoreEmbed()
            }
            // Hand the fading-out content home now (idempotent).
            function _finishLeaving() {
                contentOut.stop()
                var p = win.leaving
                win.leaving = null
                win._release(p)
            }

            // In: opacity only SNAPS on (scale comes from the fitScale binding).
            NumberAnimation {
                id: contentIn
                property: "opacity"; to: 1
                duration: Config.MotionConfig.dur(Isl.CONTENT_IN_MS); easing.type: Easing.OutQuad
            }
            ParallelAnimation {
                id: contentOut
                property Item target: null
                NumberAnimation {
                    target: contentOut.target; property: "opacity"; to: 0
                    duration: Config.MotionConfig.dur(Isl.CONTENT_OUT_MS); easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: contentOut.target; property: "scale"; to: Isl.CONTENT_OUT_SCALE
                    duration: Config.MotionConfig.dur(Isl.CONTENT_OUT_MS); easing.type: Easing.InCubic
                }
                onFinished: win._finishLeaving()
            }

            // Registry: one island host per output (owner-checked removal).
            property string _registeredOn: ""
            function _register() {
                // Only while mapped: a hidden island (barToggle, edge remap)
                // must not swallow popovers or the OSD.
                var name = win.validScreen && win.visible ? win.screen.name : ""
                if (name === win._registeredOn) return
                if (win._registeredOn !== "") Engine.PopupCoordinator.unregisterIsland(win._registeredOn, win)
                win._registeredOn = name
                if (name !== "") Engine.PopupCoordinator.registerIsland(name, win)
            }
            onValidScreenChanged: _register()
            Component.onCompleted: _register()
            Component.onDestruction: {
                if (win._registeredOn !== "") Engine.PopupCoordinator.unregisterIsland(win._registeredOn, win)
                Engine.PopupCoordinator.holdActivity("island:" + win._registeredOn, "")   // from _syncHold's merged release
                win._finishLeaving()
                // A live client's Popover sees embedHost go null and restores.
            }

            // =================================================================
            // QD-OLED BURN-IN GUARD — the shared BurnOrbit tick (T20). The
            // orbit math/table live in lib/orbit.mjs via the component; this
            // host only feeds its rest-state dim clock from the same
            // heartbeat. The dim curve stays island-specific on purpose.
            // =================================================================
            property real idleMs: 0
            function _touch() { win.idleMs = 0 }
            Bar.BurnOrbit {
                id: guardTick
                active: win.visible && win.burnGuard
                onStepped: if (win.islandState === Isl.REST) win.idleMs += 30000
            }
            readonly property var orbit: guardTick.offset
            readonly property real restAlpha: Isl.restAlpha(islandState, idleMs, { guard: burnGuard })

            // =================================================================
            // GEOMETRY
            // =================================================================
            // Before the first configure win.width is 0 — don't let the plan
            // collapse every cell for that frame; plain "full" maps instead.
            readonly property var fitPlan: win.width <= 0
                ? ({ maps: { left: ({}), center: ({}), right: ({}) } })
                : Engine.PluginRegistry.planFit({
                width: Math.max(0, win.width - 2 * win.margin - 2 * win.padX - 2 * win.sectionGap),
                pad: 0,
                gap: Config.BarConfig.iconSpacing,
                slack: 8,
                left: leftRow.cellInfos,
                center: centerRow.cellInfos,
                right: rightRail.cellInfos
            })
            readonly property var restFit: {
                var ids = Engine.PluginRegistry.sections.center || []
                var m = {}
                for (var i = 0; i < ids.length; i++) m[ids[i]] = "compact"
                return m
            }
            // Glance geometry: the clusters pin to an exact padX from their
            // outer edges (even padding both sides) and the clock stays
            // dead-centre. The island reserves a full slot (the wider wing's
            // width) per side, so a width difference between the sections
            // becomes breathing room between the clock and the NARROWER
            // cluster — never a starved outer edge (packing to real content
            // split padX ∓ Δ/2 and pinned the wide side against the edge).
            readonly property real wingW: Math.max(leftRow.implicitWidth, rightRail.implicitWidth)
            readonly property real glanceW: centerRow.implicitWidth
                + (wingW > 0 ? 2 * (wingW + sectionGap) : 0)

            // Panel sizes settle-gate: a freshly presented popover lays out
            // in steps (loaders, async probes) — committing each step would
            // spring the island in stutters, and the pre-layout 0-size first
            // read collapses to the min-width pill. Adopt the presented size
            // only after it holds still for a beat; later settles (a probe
            // returning seconds into the visit) re-gate the same way and
            // reach the island as one smooth spring.
            readonly property real rawPanelW: client ? client.embedW : 0
            readonly property real rawPanelH: client ? client.embedH + dockOffset : 0
            property real settledPanelW: 0
            property real settledPanelH: 0
            onRawPanelWChanged: panelQuiet.restart()
            onRawPanelHChanged: panelQuiet.restart()
            Timer {
                id: panelQuiet
                interval: 70
                onTriggered: {
                    win.settledPanelW = win.rawPanelW
                    win.settledPanelH = win.rawPanelH
                }
            }
            // A panel whose size has not settled yet (first 70ms) holds the
            // glance silhouette instead of collapsing to the min pill.
            readonly property string sizeState: islandState === Isl.PANEL && settledPanelH <= 0
                ? Isl.GLANCE : islandState
            readonly property var target: Isl.targetSize(sizeState, {
                barH: barH, padX: padX, panelPad: panelPad, margin: margin,
                restW: centerRow.implicitWidth,
                glanceW: glanceW,
                activityW: activityRow.implicitWidth,
                activityH: barH,
                panelW: settledPanelW,
                panelH: settledPanelH,
                screenW: win.width,
                screenH: win.screen ? win.screen.height : 0
            })
            readonly property real targetR: Isl.cornerRadius(islandState, target.h, barH)
            // Direction is captured when the target moves, not per frame — an
            // overshoot past the target must not flip the spring mid-flight.
            property bool growing: false

            // Window-height policy — the layer surface must never resize
            // while content is drawn past the new buffer's edge: a realloc
            // that clips (or blits into a fresh buffer mid-motion) reads as
            // a one-frame flicker. So the window only moves where motion
            // hides it:
            //   · base overshoot headroom from launch — rest/glance/
            //     activity are one barH row and never touch the window;
            //   · presenting reserves the full legal panel height ONCE, at
            //     motion onset (the island is still small, nothing clips).
            //     Whatever settles later — loaders, probes returning
            //     seconds into the visit — then only springs the island
            //     box, never the window;
            //   · after a dismiss the reservation drops back the moment the
            //     collapsed island fits inside base again (island's
            //     onHeightChanged) — a resize whose buffer fully contains
            //     the drawn content is invisible. The transient cost is one
            //     screen-fraction-tall buffer while a panel is open.
            readonly property real baseH: Math.ceil(barH * (1 + Isl.OVERSHOOT_PAD)) + 2
            readonly property real panelFrameH: win.screen
                ? Math.ceil(win.screen.height * Isl.PANEL_MAX_H_FRAC) + 2 : baseH
            property real frameH: baseH
            property bool _frameShrinkPending: false
            onIslandStateChanged: {
                if (islandState === Isl.PANEL) {
                    _frameShrinkPending = false
                    if (panelFrameH > frameH) frameH = panelFrameH
                } else if (frameH !== baseH) {
                    _frameShrinkPending = true
                    // reduceMotion snaps island.height in the same cascade —
                    // catch the already-small case here.
                    if (island.height <= baseH) {
                        _frameShrinkPending = false
                        frameH = baseH
                    }
                }
            }
            onTargetChanged: {
                // area, not per-axis: a wide-but-shorter panel still "grows"
                growing = target.w * target.h > island.width * island.height + 0.5
            }

            anchors {
                top: !win.atBottom
                bottom: win.atBottom
                left: true
                right: true
            }
            implicitHeight: Math.max(barH, frameH)
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: barH
            WlrLayershell.namespace: "velocity-island"
            // On-demand keys ONLY while the presented card wants text input
            // (C3: the network body's password field) — otherwise None.
            WlrLayershell.keyboardFocus: (win.client && win.client.keyboardWanted)
                ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            mask: Region { item: island }

            // =================================================================
            // THE ISLAND
            // =================================================================
            Item {
                id: island
                width: win.target.w
                height: win.target.h
                x: Math.round((win.width - width) / 2) + orbitOffsetX
                y: win.atBottom ? win.height - height : 0

                property real cornerRadius: win.targetR

                Behavior on width {
                    enabled: !win.reduceMotion
                    SpringAnimation {
                        spring: win.growing ? Isl.SPRING_OPEN.spring : Isl.SPRING_CLOSE.spring
                        damping: win.growing ? Isl.SPRING_OPEN.damping : Isl.SPRING_CLOSE.damping
                        mass: Isl.SPRING_OPEN.mass
                        epsilon: Isl.SPRING_OPEN.epsilon
                    }
                }
                Behavior on height {
                    enabled: !win.reduceMotion
                    SpringAnimation {
                        spring: win.growing ? Isl.SPRING_OPEN.spring : Isl.SPRING_CLOSE.spring
                        damping: win.growing ? Isl.SPRING_OPEN.damping : Isl.SPRING_CLOSE.damping
                        mass: Isl.SPRING_OPEN.mass
                        epsilon: Isl.SPRING_OPEN.epsilon
                    }
                }
                Behavior on cornerRadius {
                    enabled: !win.reduceMotion
                    SpringAnimation {
                        spring: win.growing ? Isl.SPRING_OPEN.spring : Isl.SPRING_CLOSE.spring
                        damping: win.growing ? Isl.SPRING_OPEN.damping : Isl.SPRING_CLOSE.damping
                        mass: Isl.SPRING_OPEN.mass
                        epsilon: 0.25
                    }
                }
                // The orbit is a 1–2px step every few minutes: glide only the
                // offset (never x itself — width/screen changes must snap).
                property real orbitOffsetX: win.orbit.x
                Behavior on orbitOffsetX {
                    enabled: !win.reduceMotion
                    NumberAnimation { duration: 2400; easing.type: Easing.InOutSine }   // motion-ok: burn-in glide, not UI motion
                }
                // Collapse follow-up: once the island fits inside the base
                // window again, drop the panel reservation (see the
                // window-height policy on win).
                onHeightChanged: if (win._frameShrinkPending && height <= win.baseH) {
                    win._frameShrinkPending = false
                    win.frameH = win.baseH
                }

                HoverHandler {
                    onHoveredChanged: win._setRawHover(hovered)
                }

                // Empty-island click: closes the tray card this bar opened,
                // otherwise opens the Control Center (widgets sit above and
                // keep their own clicks; open plugin panels swallow theirs).
                MouseArea {
                    anchors.fill: parent
                    enabled: !!sceneRoot.host
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: {
                        win._touch()
                        if (sceneRoot.host.trayOwner === win && sceneRoot.host.activeTray !== "")
                            sceneRoot.host.closeTray()
                        else if (win.client === null)
                            sceneRoot.host.toggleTray(win, "control", null)
                    }
                }

                // ── shell: flat edge on the screen, round far corners ──────
                Rectangle {
                    anchors.fill: parent
                    color: win.fill
                    antialiasing: true
                    topLeftRadius: win.atBottom ? island.cornerRadius : 0
                    topRightRadius: win.atBottom ? island.cornerRadius : 0
                    bottomLeftRadius: win.atBottom ? 0 : island.cornerRadius
                    bottomRightRadius: win.atBottom ? 0 : island.cornerRadius
                }
                Fillet {
                    cornerRadius: win.fillet; fill: win.fill
                    x: -cornerRadius
                    y: win.atBottom ? island.height - cornerRadius : 0
                    transform: Scale { origin.x: win.fillet / 2; origin.y: win.fillet / 2
                                       xScale: 1; yScale: win.atBottom ? -1 : 1 }
                }
                Fillet {
                    cornerRadius: win.fillet; fill: win.fill
                    x: island.width
                    y: win.atBottom ? island.height - cornerRadius : 0
                    transform: Scale { origin.x: win.fillet / 2; origin.y: win.fillet / 2
                                       xScale: -1; yScale: win.atBottom ? -1 : 1 }
                }

                // ── content (clipped to the shell box) ─────────────────────
                Item {
                    id: content
                    anchors.fill: parent
                    clip: true

                    // Glance / rest row: one bar-height strip on the flat
                    // edge side. Wings sit adjacent to the clock and are
                    // unmasked by the island growing, then fade in.
                    Item {
                        id: row
                        width: parent.width
                        height: win.barH
                        y: (win.atBottom ? parent.height - height : 0) + win.orbit.y
                        opacity: win.islandState === Isl.PANEL ? 0 : win.restAlpha
                        visible: opacity > 0.01
                        Behavior on opacity {
                            enabled: !win.reduceMotion
                            NumberAnimation {
                                duration: win.islandState === Isl.PANEL ? Config.MotionConfig.dur(Isl.CONTENT_OUT_MS)
                                                                         : Config.MotionConfig.swap
                                easing.type: Easing.OutCubic
                            }
                        }

                        readonly property bool wingsShown: win.islandState === Isl.GLANCE

                        Engine.BarSection {
                            id: centerRow
                            height: win.barH
                            x: Math.round((row.width - implicitWidth) / 2)
                            name: "center"
                            window: win
                            gap: 14
                            // At rest the island is "just a clock": center
                            // widgets drop to their compact form (clock →
                            // HH:MM) and bloom to full with the glance. Ids
                            // come from the layout, not cellInfos (no loop).
                            fitMap: win.islandState === Isl.GLANCE ? win.fitPlan.maps.center : win.restFit
                            opacity: win.islandState === Isl.ACTIVITY ? 0 : 1
                            Behavior on opacity {
                                enabled: !win.reduceMotion
                                NumberAnimation { duration: Config.MotionConfig.flap; easing.type: Easing.OutCubic }
                            }
                        }

                        // Live activity readout (the queue's winner): glyph · track · label.
                        // Clickable when the activity carries `activate` (the
                        // J2 notification peek) — pointer + click else inert.
                        // The wrapper Item is structural (P1.11 journal fix):
                        // a Row child may not anchors.fill, so the forgiving
                        // click target can't live inside activityRow — the
                        // wrapper carries the centering AND the MouseArea;
                        // the Row is sized by its children.
                        Item {
                            id: activityWrap
                            anchors.centerIn: parent
                            width: activityRow.width
                            height: activityRow.height

                        Row {
                            id: activityRow
                            readonly property bool shown: win.islandState === Isl.ACTIVITY
                            readonly property bool clickable: win.activity !== null
                                && win.activity.activate !== undefined
                            readonly property bool hasTrack: win.activity !== null
                                && win.activity.progress !== undefined
                            spacing: Math.round(win.barH * 0.4)
                            opacity: shown ? win.activityAlpha : 0
                            visible: opacity > 0.01
                            // scale-led like panels: grows in with the island
                            scale: shown ? 1 : Isl.CONTENT_OUT_SCALE
                            Behavior on opacity {
                                enabled: !win.reduceMotion
                                NumberAnimation { duration: Config.MotionConfig.dur(Isl.CONTENT_IN_MS); easing.type: Easing.OutQuad }
                            }
                            Behavior on scale {
                                enabled: !win.reduceMotion
                                SpringAnimation { spring: Isl.SPRING_OPEN.spring; damping: Isl.SPRING_OPEN.damping; epsilon: 0.005 }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: win.activity ? win.activity.icon : ""
                                font.family: Config.BarConfig.fontNerd
                                font.pixelSize: Config.BarConfig.fontSizeIcon
                                color: Config.BarConfig.colorText
                            }
                            // Track — style-split (J5): "bar" = continuous
                            // pill fill, "segments" = Ui.SegmentTrack with
                            // the pill radius. Same box either way.
                            Rectangle {
                                visible: activityRow.hasTrack && Config.BarConfig.osdStyle !== "segments"
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(win.barH * 4.6)
                                height: Math.max(3, Math.round(win.barH * 0.14))
                                radius: height / 2
                                color: Config.ThemeConfig.hairlineSoft
                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    width: parent.width
                                        * (activityRow.hasTrack ? Math.max(0, Math.min(100, win.activity.progress)) : 0) / 100
                                    color: Config.BarConfig.colorText
                                    Behavior on width {
                                        enabled: !win.reduceMotion
                                        NumberAnimation { duration: Config.MotionConfig.flap; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                            Ui.SegmentTrack {
                                visible: activityRow.hasTrack && Config.BarConfig.osdStyle === "segments"
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(win.barH * 4.6)
                                height: Math.max(3, Math.round(win.barH * 0.14))
                                segments: 9
                                gap: 2
                                segmentRadius: height / 2
                                accent: Config.BarConfig.colorText
                                dimAlpha: 0.3
                                value: activityRow.hasTrack ? Math.max(0, Math.min(100, win.activity.progress)) : 0
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: win.activity ? win.activity.label : ""
                                font.family: Config.BarConfig.fontFamily
                                font.pixelSize: Config.BarConfig.fontSizeLabel
                                font.bold: true
                                color: activityRow.hasTrack ? Config.BarConfig.colorTextDim
                                      : (win.activity && win.activity.accent) ? win.activity.accent
                                      : Config.BarConfig.colorAccent
                            }
                            }
                            // Lives on the wrapper (a Row child may not
                            // anchors.fill); parent = activityWrap, so the
                            // forgiving -8px target still covers the whole row.
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8   // forgiving target on a barH row
                                enabled: activityRow.clickable
                                cursorShape: activityRow.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (win.activity && win.activity.activate) win.activity.activate()
                            }
                        }

                        // Hug-then-pin: in the first frames of the bloom the
                        // island is still pill-sized, so a statically pinned
                        // wing would sit ON TOP of the clock — the whole row
                        // piles up and reads as a flicker. Each wing instead
                        // starts ADJACENT to the clock (clipped, emerging as
                        // the island grows — the unmask the old layout had)
                        // and crosses into its pinned slot once the spring
                        // makes room. The cross is continuous: when a wing
                        // is the wider one, hug and pin coincide exactly at
                        // the settled frame.
                        Engine.BarSection {
                            id: leftRow
                            height: win.barH
                            x: Math.min(win.padX, centerRow.x - win.sectionGap - implicitWidth)
                            name: "left"
                            window: win
                            gap: Config.BarConfig.iconSpacing
                            fitMap: win.fitPlan.maps.left
                            enabled: row.wingsShown
                            opacity: row.wingsShown ? 1 : 0
                            Behavior on opacity {
                                enabled: !win.reduceMotion
                                NumberAnimation {
                                    duration: row.wingsShown ? Config.MotionConfig.dur(Isl.CONTENT_IN_MS)
                                                             : Config.MotionConfig.dur(Isl.CONTENT_OUT_MS)
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Engine.BarSection {
                            id: rightRail
                            height: win.barH
                            x: Math.max(row.width - win.padX - implicitWidth,
                                        centerRow.x + centerRow.implicitWidth + win.sectionGap)
                            name: "right"
                            window: win
                            gap: Config.BarConfig.slotMargin
                            fitMap: win.fitPlan.maps.right
                            enabled: row.wingsShown
                            opacity: leftRow.opacity
                        }
                    }

                    // Edge light: the activity's value as a thin accent line on
                    // the island's far edge (transient — never at rest).
                    Rectangle {
                        readonly property real span: Math.max(0, island.width - 2 * island.cornerRadius)
                        x: island.cornerRadius
                        y: win.atBottom ? 0 : island.height - height
                        height: 2
                        width: span
                            * (activityRow.hasTrack ? Math.max(0, Math.min(100, win.activity.progress)) : 0) / 100
                        color: (win.activity && win.activity.accent) ? win.activity.accent
                                                                     : Config.BarConfig.colorAccent
                        opacity: activityRow.shown && activityRow.hasTrack
                                 ? 0.55 * win.activityAlpha : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            enabled: !win.reduceMotion
                            NumberAnimation { duration: Config.MotionConfig.flap }
                        }
                        Behavior on width {
                            enabled: !win.reduceMotion
                            NumberAnimation { duration: Config.MotionConfig.flap; easing.type: Easing.OutCubic }
                        }
                    }

                    // Switcher strip (flat-edge side, above/below the panel).
                    Row {
                        id: dock
                        readonly property bool shown: win.dockActive
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: win.atBottom ? parent.height - win.dockH : 0
                        height: win.dockH
                        spacing: Math.round(win.barH * 0.3)
                        opacity: shown ? 1 : 0
                        visible: opacity > 0.01
                        z: 2
                        Behavior on opacity {
                            enabled: !win.reduceMotion
                            NumberAnimation { duration: Config.MotionConfig.dur(Isl.CONTENT_IN_MS); easing.type: Easing.OutCubic }
                        }

                        Repeater {
                            model: win.dockItems
                            delegate: Item {
                                id: seg
                                required property var modelData
                                readonly property bool current: win.dockKey === modelData.key
                                readonly property bool available: modelData.key === "control" ? true
                                    : modelData.key === "calendar"
                                    ? win._ownInstance(modelData.plugin) !== null
                                    : win._inLayout(modelData.plugin)
                                visible: available
                                width: Math.round(win.barH * 1.6)
                                height: win.dockH

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: Math.round(win.barH * 0.72)
                                    radius: height / 2
                                    readonly property color accentColor: Config.BarConfig.colorAccent
                                    readonly property color textColor: Config.BarConfig.colorText
                                    color: seg.current ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.16)
                                         : segHover.hovered ? Qt.rgba(textColor.r, textColor.g, textColor.b, 0.06)
                                         : "transparent"
                                    Behavior on color {
                                        enabled: !win.reduceMotion
                                        ColorAnimation { duration: Config.MotionConfig.snap }
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: seg.modelData.glyph
                                    font.family: Config.BarConfig.fontNerd
                                    font.pixelSize: Config.BarConfig.fontSizeIcon
                                    color: seg.current ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
                                }
                                HoverHandler { id: segHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: win.dockSwitch(seg.modelData.key) }
                            }
                        }
                    }

                    // Panel stage: presented Popover content is reparented
                    // here (positions bound in present()).
                    Item {
                        id: stage
                        anchors.fill: parent
                        // swallow clicks on the panel background
                        MouseArea { anchors.fill: parent; enabled: win.client !== null }
                    }
                }
            }
        }
    }
}
