// =============================================================================
// Popover.qml — the anchored-popover primitive (Tier-3, ryoku/shibumi port)
// =============================================================================
// A positioned CARD item (not a window) that lives inside any full-screen
// overlay PanelWindow. One primitive for tray cards and plugin panels:
//
//   • Trigger-anchored — pass `anchorItem` (the pill/icon; it MAY live in a
//     different window — we only read its x via mapToItem(null), valid because
//     the bar strip and the overlay share the screen origin/width). The card
//     centers under the trigger; `anchorFallback` ("right"|"center") covers
//     hosts with no trigger item.
//   • Edge-clamped — the card never leaves [edgeMargin .. width-edgeMargin];
//     drag offsets (offX/offY) shift it after clamping.
//   • Motion — opacity + a 6px settle lift at MotionConfig tokens
//     (reduceMotion collapses to instant via dur()).
//   • Dismiss — transparent backdrop MouseArea (click-outside closes). NO
//     HyprlandFocusGrab anywhere: it self-cancels the moment the layer takes
//     focus (ryoku finding) — layershell keyboardFocus stays None.
//   • hoverClose — optional 450ms hover-out close (plugin panels want it;
//     tray cards don't).
//
// Host responsibilities: parent the Popover to the overlay window's content
// item, keep `visible: opened || card.opacity > 0` on the WINDOW, and wire
// open/close exclusivity (Engine.PopupCoordinator via ctx.popup or the tray's
// activeTray). The card surface (bg/radius/border + padding) is ours; the
// body content is the consumer's via the default slot.
//
// KNOWN LIMIT (inherited from the pre-primitive code): anchorItem on a
// secondary monitor maps into THAT monitor's bar window while the popover
// window sits on its own screen — same-monitor triggers only, like before.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../lib/popover-geometry.mjs" as PopGeo

Item {
    id: pop

    // ── API ────────────────────────────────────────────────────────────────
    property Item anchorItem: null          // trigger (pill/icon) — optional
    property string anchorFallback: "right" // "right" | "center"
    property real cardWidth: 320
    property real cardHeight: -1            // -1 = auto (content + 2*padding)
    property real edgeMargin: 5
    property real gap: 8                    // strip-side offset: drop below the host's top edge (top bar) / rise above its bottom edge (bottom bar)
    property real padding: 10               // card inner padding
    property real offX: 0                   // drag offsets (applied post-clamp)
    property real offY: 0
    property bool opened: false
    property bool hoverClose: false
    // Typing guard (C3 network card): while a password field is focused the
    // hover-out close is HELD — the cursor resting outside the card must not
    // kill a half-typed password. Flipping this on also cancels a pending
    // hover-out timer.
    property bool hoverPause: false
    // Layer-keyboard request (C3): hosts bind their window's
    // WlrLayershell.keyboardFocus to OnDemand while this is true so the
    // embedded/floating body can take text input (island embeds read it off
    // the presented client; TrayCard reads it off its body directly).
    property bool keyboardWanted: false
    // Hosts whose open state lives elsewhere (e.g. TrayCard's activeTray):
    // bind `opened`, set externalState, and handle dismissRequested — the
    // backdrop / hover-out / timers ASK instead of writing (a write would
    // break the host's binding).
    property bool externalState: false
    // TrayCard idiom: only start the hover-out timer after the cursor has
    // actually entered the card (opening with the cursor still on the bar
    // icon must not auto-close).
    property bool hoverCloseNeedsEntry: false
    // Tray-style cards are a seamless extension of the bar — no border.
    property bool showBorder: true
    // Island style: an island host for this screen (ctx.popup.island / the
    // shell's lookup). While set at open time the card CONTENT is presented
    // inside the island (host.present(pop) / host.withdraw(pop)) and the
    // host window should stay unmapped (`embedded`). null = classic card.
    property var embedHost: null
    readonly property bool embedded: _embedHost !== null
    // What the island adopts and how big it wants to be (card box incl.
    // padding; the card's own geometry keeps computing while hidden).
    readonly property Item embedItem: cardContent
    readonly property real embedW: card.width
    readonly property real embedH: card.implicitHeight
    property var _embedHost: null

    default property alias content: cardBody.data
    // Hosts with their own internal geometry (TrayCard's per-body sizing):
    // children of cardArea anchor-fill the card instead of flowing in the
    // column.
    property alias cardArea: cardAreaHost.data

    signal popOpened()
    signal popClosed()
    signal dismissRequested()

    // For host windows' fade-out tail: keep the window mapped while the card
    // is still fading (visible: opened || cardOpacity > 0).
    readonly property real cardOpacity: card.opacity
    // Card center in SCREEN x — the notch lobe reads it to place its caret
    // bite (popover windows share the bar's screen origin; see anchorCenterX).
    readonly property real cardCenterX: card.x + card.width / 2

    property bool _hoverEntered: false

    function _dismiss() {
        if (externalState) { dismissRequested(); return }
        close()
    }

    function open() {
        if (!opened) {
            _hoverEntered = false
            opened = true
            settleBurst.shots = 0
            settleBurst.restart()
            popOpened()
        }
    }
    // External-state hosts (TrayCard) flip `opened` by binding — burst for
    // them too, so the anchor re-measures through their window's settle.
    onOpenedChanged: {
        if (opened && externalState) {
            settleBurst.shots = 0
            settleBurst.restart()
        }
        _syncEmbed()
    }
    function close() { if (opened) { _hoverEntered = false; opened = false; popClosed() } }
    function toggle() { opened ? close() : open() }

    // ── island embedding ────────────────────────────────────────────────────
    // Present on open, withdraw on close; one code path for both open styles
    // (open() and external-state bindings) because it keys off `opened`.
    function _syncEmbed() {
        if (opened && embedHost && _embedHost === null) {
            _embedHost = embedHost
            _embedHost.present(pop)
        } else if ((!opened || embedHost !== _embedHost) && _embedHost !== null) {
            var h = _embedHost
            _embedHost = null
            // true = the island animates the content out and calls
            // restoreEmbed() itself when done; anything else = restore now.
            // Moving to another island while open: cancel the old one's
            // fade (it would otherwise hand the content back from under the
            // new host).
            var immediate = opened && !!embedHost
            var deferred = !!h.withdraw && h.withdraw(pop, immediate) === true
            if (!deferred) restoreEmbed()
            if (opened && embedHost) _syncEmbed()
        }
    }
    // The island hands the content back (or dies, style swap): home again.
    function restoreEmbed() {
        if (_embedHost !== null) return   // presented elsewhere since
        cardContent.parent = card
        cardContent.x = 0
        cardContent.y = 0
        cardContent.opacity = 1
        cardContent.scale = 1
    }
    onEmbedHostChanged: _syncEmbed()
    Component.onDestruction: {
        if (_embedHost !== null && _embedHost.withdraw) _embedHost.withdraw(pop, true)
    }

    // Screen-fit (UA 2.2): the card never exceeds the host window minus
    // margins (width) and its vertical budget (height). PopGeo returns the
    // request untouched until the parent reports real geometry — hosts spawn
    // at placeholder sizes and the clamp re-applies when they settle.
    // Embedded: the host window never maps (it may sit at a placeholder
    // size), so the island's budget replaces the window clamp.
    width: embedHost
           ? (embedHost.maxContentW > 0 ? Math.min(cardWidth, embedHost.maxContentW) : cardWidth)
           : PopGeo.clampCardWidth(cardWidth, parent ? parent.width : 0, edgeMargin)
    // Vertical budget: parent height minus the drop gap and margins (-1 =
    // unclamped). Host windows already exclude the bar strip (margins.top =
    // barHeight), so no bar term here — see popover-geometry.mjs.
    readonly property real maxHeight: embedHost
        ? (embedHost.maxContentH > 0 ? embedHost.maxContentH : -1)
        : PopGeo.clampMaxHeight(parent ? parent.height : 0, gap, edgeMargin)
    height: card.implicitHeight

    // Trigger center in SCREEN x (bar window origin == screen origin; the
    // overlay spans the screen below the bar, so x coords are interchangeable).
    //
    // mapToItem() is NOT reactive — window/scene transforms don't notify QML
    // bindings, so a value read mid-race sticks forever. Real race (found on
    // the notch style): panel windows spawn at a placeholder 500×500 and size
    // after layer attach, while the bar scene may still be running its lobe
    // layout — the first measure can be wrong (even negative), and nothing
    // re-measures. Fix: an explicit tick the binding depends on, bumped by
    // the anchor's own geometry signals and a bounded settle burst after
    // open (Shibumi's budgeted-recovery pattern: 5 × 60ms, no standing timer).
    property int _anchorTick: 0
    function _nudge() { _anchorTick++ }
    readonly property real anchorCenterX: {
        _anchorTick   // dependency: re-measure on every nudge
        if (anchorItem)
            return anchorItem.mapToItem(null, anchorItem.width / 2, 0).x
        if (anchorFallback === "center") return parent ? parent.width / 2 : 0
        return parent ? parent.width : 0   // "right"
    }
    onAnchorItemChanged: _nudge()
    onParentChanged: _nudge()
    Connections {
        target: pop.anchorItem
        function onXChanged() { pop._nudge() }
        function onWidthChanged() { pop._nudge() }
        function onParentChanged() { pop._nudge() }
    }
    Timer {
        id: settleBurst
        property int shots: 0
        interval: 60; repeat: true
        onTriggered: {
            pop._nudge()
            shots++
            if (shots >= 5) settleBurst.stop()
        }
    }


    // ── backdrop: click-outside dismiss (misses only — card is above) ───────
    MouseArea {
        parent: pop.parent      // fill the HOST overlay content item
        anchors.fill: parent
        z: pop.z - 1            // strictly behind the popover card
        enabled: pop.opened
        onClicked: pop._dismiss()
    }

    // ── the card ────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        width: pop.width
        x: {
            // Clamp the ANCHORED position first, then apply the drag offset —
            // offX must survive the clamp or a right-docked card could never
            // be dragged. Sign follows the historic right-dock drag semantics
            // (dragging left moves the card left; dragMa does offX -= dx).
            var lo = pop.edgeMargin
            var hi = (pop.parent ? pop.parent.width : width + 2 * pop.edgeMargin)
                     - width - pop.edgeMargin
            var base = Math.max(lo, Math.min(hi, pop.anchorCenterX - width / 2))
            return base - pop.offX
        }
        // B5: orientation follows barPosition. Top bar: the host window
        // excludes the strip via margins.top, the card drops from its top
        // edge and settle-lifts from -6. Bottom bar: margins.bottom excludes
        // the strip, the card rises from the bottom edge (gap faces the bar)
        // and settle-drops from +6 — mirrored motion, same tokens.
        y: Config.BarConfig.barAtBottom
          ? (pop.parent ? pop.parent.height - pop.height - pop.gap : pop.gap)
            + pop.offY + (pop.opened ? 0 : 6)
          : pop.gap + pop.offY - (pop.opened ? 0 : 6)
        implicitHeight: pop.cardHeight >= 0
                        ? Math.min(pop.cardHeight, pop.maxHeight < 0 ? pop.cardHeight : pop.maxHeight)
                        : pop.maxHeight < 0
                          ? cardBody.implicitHeight + 2 * pop.padding
                          : Math.min(cardBody.implicitHeight + 2 * pop.padding, pop.maxHeight)
        color: Config.BarConfig.colorBackground
        radius: 10
        border.width: pop.showBorder ? 1 : 0
        border.color: Config.ThemeConfig.colors.border
        opacity: pop.opened ? 1 : 0
        visible: pop.opened || opacity > 0

        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.flap } }
        Behavior on y { NumberAnimation { duration: Config.MotionConfig.move; easing.type: Config.MotionConfig.ease } }

        MouseArea { anchors.fill: parent }   // swallow in-card clicks

        HoverHandler {
            enabled: pop.hoverClose
            onHoveredChanged: {
                if (hovered) {
                    hoverCloseTimer.stop()
                    pop._hoverEntered = true
                } else if (pop.opened && !pop.hoverPause
                           && (!pop.hoverCloseNeedsEntry || pop._hoverEntered)) {
                    hoverCloseTimer.restart()
                }
            }
        }
        // A pause landing mid-count (cursor outside when a field gains focus)
        // must also stop the timer already running.
        Connections {
            target: pop
            function onHoverPauseChanged() { if (pop.hoverPause) hoverCloseTimer.stop() }
        }
        Timer {
            id: hoverCloseTimer
            interval: 450
            onTriggered: if (pop.opened) pop._dismiss()
        }

        // Everything inside the card surface. Sized explicitly (no anchors)
        // so the island can adopt it as-is: the body keeps the card's
        // geometry while the island's shell morphs around it.
        Item {
            id: cardContent
            width: card.width
            height: card.height

            // Body scrolls only when the content is taller than the card's
            // vertical budget (UA 2.2); an exact-fit body is inert (1px guard).
            Flickable {
                id: bodyScroll
                x: pop.padding
                y: pop.padding
                width: parent.width - 2 * pop.padding
                height: parent.height - 2 * pop.padding
                contentWidth: width
                contentHeight: cardBody.implicitHeight
                interactive: PopGeo.scrollNeeded(contentHeight, height)
                clip: true

                ColumnLayout {
                    id: cardBody
                    width: bodyScroll.width
                    spacing: 0
                }
            }

            // Fill-slot for hosts with custom internal geometry (anchor-fill).
            // Declared AFTER the column so tray content stacks above the
            // click-swallower.
            Item {
                id: cardAreaHost
                anchors.fill: parent
            }
        }
    }
}
