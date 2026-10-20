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
import "../../config" as Config
import "../../engine" as Engine
import "../../services" as Services
import "lib/island.mjs" as Isl

Item {
    id: sceneRoot

    property var host: null
    property var instances: bars.instances

    // Concave fillet joining the island to the screen edge. Drawn for the
    // LEFT side of a top bar; mirrored by transforms for the other cases.
    component Fillet: Shape {
        id: fil
        property real r: 10
        property color fill: "black"
        width: r; height: r
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: fil.fill
            strokeColor: "transparent"
            startX: 0; startY: 0
            PathLine { x: fil.r; y: 0 }
            PathLine { x: fil.r; y: fil.r }
            // quarter circle centred at (0, r): (r, r) → (0, 0)
            PathCubic {
                control1X: fil.r;                 control1Y: fil.r - 0.55228475 * fil.r
                control2X: 0.55228475 * fil.r;    control2Y: 0
                x: 0;                             y: 0
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

            // Live activity: OsdService feedback (volume, mute, layout,
            // workspace) blooms the island on the focused output instead of
            // the floating OSD card (Osd.qml stands down while an island is
            // registered).
            readonly property bool activityLive: Services.OsdService.active
                && (Services.HyprlandService.focusedMonitor === ""
                    || (win.screen !== null && Services.HyprlandService.focusedMonitor === win.screen.name))
            onActivityLiveChanged: _event(activityLive ? "activity" : "activityEnd")

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
            // SWITCHER — Calendar · Wi-Fi · Bluetooth · Volume. While one of
            // them is open in the island, a strip on the flat-edge side
            // switches in place (the island morphs between their sizes).
            // =================================================================
            readonly property string calendarPlugin: "nikos.clock"
            readonly property var dockItems: [
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
                    if (t === "network" || t === "bluetooth" || t === "volume") return t
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
                win._finishLeaving()
                // A live client's Popover sees embedHost go null and restores.
            }

            // =================================================================
            // QD-OLED BURN-IN GUARD — one 30s tick: idle clock + orbit step
            // =================================================================
            property real idleMs: 0
            property int orbitTick: 0
            property int _guardTicks: 0
            function _touch() { win.idleMs = 0 }
            Timer {
                interval: 30000; repeat: true
                running: win.visible && win.burnGuard
                onTriggered: {
                    if (win.islandState === Isl.REST) win.idleMs += interval
                    win._guardTicks++
                    if (win._guardTicks % 6 === 0) win.orbitTick++   // one step / 3 min
                }
            }
            readonly property var orbit: Isl.orbitOffset(orbitTick, burnGuard ? 2 : 0)
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
            // Glance keeps the clock dead-centre with the wings hugging it
            // (equal sectionGap each way), and the island packs to the REAL
            // content width: pad · left — clock — right · pad. Both clusters
            // sit equidistant from the clock, so the bloom reads as a mirror
            // image, not a lopsided row with dead space on the narrow side.
            // A missing wing falls back to the wider-side slot so the clock
            // stays centred even with one section empty.
            readonly property real wingW: Math.max(leftRow.implicitWidth, rightRail.implicitWidth)
            readonly property real glanceW: {
                if (leftRow.implicitWidth <= 0 || rightRail.implicitWidth <= 0)
                    return centerRow.implicitWidth + (wingW > 0 ? 2 * (wingW + sectionGap) : 0)
                return centerRow.implicitWidth + leftRow.implicitWidth
                     + rightRail.implicitWidth + 2 * sectionGap
            }

            readonly property var target: Isl.targetSize(islandState, {
                barH: barH, padX: padX, panelPad: panelPad, margin: margin,
                restW: centerRow.implicitWidth,
                glanceW: glanceW,
                activityW: activityRow.implicitWidth,
                activityH: barH,
                panelW: client ? client.embedW : 0,
                panelH: client ? client.embedH + dockOffset : 0,
                screenW: win.width,
                screenH: win.screen ? win.screen.height : 0
            })
            readonly property real targetR: Isl.cornerRadius(islandState, target.h, barH)
            // Direction is captured when the target moves, not per frame — an
            // overshoot past the target must not flip the spring mid-flight.
            property bool growing: false

            // Window height: grow at the start of a morph (with overshoot
            // headroom), trim once the spring settles.
            property real frameH: barH
            onTargetChanged: {
                // area, not per-axis: a wide-but-shorter panel still "grows"
                growing = target.w * target.h > island.width * island.height + 0.5
                var want = Math.ceil(target.h * (1 + Isl.OVERSHOOT_PAD)) + 2
                if (want > frameH) frameH = want
                frameTrim.restart()
            }
            // Trim only after the spring has been quiet for a moment — an
            // underdamped spring crosses its target before it settles.
            Timer {
                id: frameTrim
                interval: 220
                onTriggered: win.frameH = Math.ceil(win.target.h) + 2
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
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region { item: island }

            // =================================================================
            // THE ISLAND
            // =================================================================
            Item {
                id: island
                width: win.target.w
                height: win.target.h
                x: Math.round((win.width - width) / 2) + ox
                y: win.atBottom ? win.height - height : 0

                property real r: win.targetR

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
                Behavior on r {
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
                property real ox: win.orbit.x
                Behavior on ox {
                    enabled: !win.reduceMotion
                    NumberAnimation { duration: 2400; easing.type: Easing.InOutSine }   // motion-ok: burn-in glide, not UI motion
                }
                onHeightChanged: frameTrim.restart()

                HoverHandler {
                    onHoveredChanged: win._setRawHover(hovered)
                }

                // Empty-island click closes the tray card this bar opened.
                MouseArea {
                    anchors.fill: parent
                    enabled: !!sceneRoot.host && sceneRoot.host.trayOwner === win
                             && sceneRoot.host.activeTray !== ""
                    onClicked: sceneRoot.host.closeTray()
                }

                // ── shell: flat edge on the screen, round far corners ──────
                Rectangle {
                    anchors.fill: parent
                    color: win.fill
                    antialiasing: true
                    topLeftRadius: win.atBottom ? island.r : 0
                    topRightRadius: win.atBottom ? island.r : 0
                    bottomLeftRadius: win.atBottom ? 0 : island.r
                    bottomRightRadius: win.atBottom ? 0 : island.r
                }
                Fillet {
                    r: win.fillet; fill: win.fill
                    x: -r
                    y: win.atBottom ? island.height - r : 0
                    transform: Scale { origin.x: win.fillet / 2; origin.y: win.fillet / 2
                                       xScale: 1; yScale: win.atBottom ? -1 : 1 }
                }
                Fillet {
                    r: win.fillet; fill: win.fill
                    x: island.width
                    y: win.atBottom ? island.height - r : 0
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

                        // Live activity readout (OsdService): glyph · track · value.
                        Row {
                            id: activityRow
                            readonly property bool shown: win.islandState === Isl.ACTIVITY
                            anchors.centerIn: parent
                            spacing: Math.round(win.barH * 0.4)
                            opacity: shown ? 1 : 0
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
                                text: Services.OsdService.icon
                                font.family: Config.BarConfig.fontNerd
                                font.pixelSize: Config.BarConfig.fontSizeIcon
                                color: Config.BarConfig.colorText
                            }
                            Rectangle {
                                visible: Services.OsdService.hasProgress
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(win.barH * 4.6)
                                height: Math.max(3, Math.round(win.barH * 0.14))
                                radius: height / 2
                                color: Config.ThemeConfig.hairlineSoft
                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    width: parent.width * Math.max(0, Math.min(100, Services.OsdService.value)) / 100
                                    color: Config.BarConfig.colorText
                                    Behavior on width {
                                        enabled: !win.reduceMotion
                                        NumberAnimation { duration: Config.MotionConfig.flap; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Services.OsdService.message
                                font.family: Config.BarConfig.fontFamily
                                font.pixelSize: Config.BarConfig.fontSizeLabel
                                font.bold: true
                                color: Services.OsdService.hasProgress ? Config.BarConfig.colorTextDim
                                                                       : Config.BarConfig.colorAccent
                            }
                        }

                        Engine.BarSection {
                            id: leftRow
                            height: win.barH
                            x: centerRow.x - win.sectionGap - implicitWidth
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
                            x: centerRow.x + centerRow.implicitWidth + win.sectionGap
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
                        readonly property real span: Math.max(0, island.width - 2 * island.r)
                        x: island.r
                        y: win.atBottom ? 0 : island.height - height
                        height: 2
                        width: span * Math.max(0, Math.min(100, Services.OsdService.value)) / 100
                        color: Config.BarConfig.colorAccent
                        opacity: activityRow.shown && Services.OsdService.hasProgress ? 0.55 : 0
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
                                readonly property bool available: modelData.key === "calendar"
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
                                    readonly property color a: Config.BarConfig.colorAccent
                                    readonly property color t: Config.BarConfig.colorText
                                    color: seg.current ? Qt.rgba(a.r, a.g, a.b, 0.16)
                                         : segHover.hovered ? Qt.rgba(t.r, t.g, t.b, 0.06)
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
