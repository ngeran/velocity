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
// open/close exclusivity (PluginHostService.openPanel or the tray's
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

Item {
    id: pop

    // ── API ────────────────────────────────────────────────────────────────
    property Item anchorItem: null          // trigger (pill/icon) — optional
    property string anchorFallback: "right" // "right" | "center"
    property real cardWidth: 320
    property real edgeMargin: 5
    property real gap: 8                    // drop below the host's top edge
    property real padding: 10               // card inner padding
    property real offX: 0                   // drag offsets (applied post-clamp)
    property real offY: 0
    property bool opened: false
    property bool hoverClose: false

    default property alias content: cardBody.data

    signal popOpened()
    signal popClosed()

    // For host windows' fade-out tail: keep the window mapped while the card
    // is still fading (visible: opened || cardOpacity > 0).
    readonly property real cardOpacity: card.opacity

    width: cardWidth
    height: card.implicitHeight

    // Trigger center in SCREEN x (bar window origin == screen origin; the
    // overlay spans the screen below the bar, so x coords are interchangeable).
    readonly property real anchorCenterX: {
        if (anchorItem)
            return anchorItem.mapToItem(null, anchorItem.width / 2, 0).x
        if (anchorFallback === "center") return parent ? parent.width / 2 : 0
        return parent ? parent.width : 0   // "right"
    }

    function open() { if (!opened) { opened = true; popOpened() } }
    function close() { if (opened) { opened = false; popClosed() } }
    function toggle() { opened ? close() : open() }

    // ── backdrop: click-outside dismiss (misses only — card is above) ───────
    MouseArea {
        parent: pop.parent      // fill the HOST overlay content item
        anchors.fill: parent
        z: pop.z - 1            // strictly behind the popover card
        enabled: pop.opened
        onClicked: pop.close()
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
        y: pop.gap + pop.offY - (pop.opened ? 0 : 6)   // settle-lift from -6
        implicitHeight: cardBody.implicitHeight + 2 * pop.padding
        color: Config.BarConfig.colorBackground
        radius: 10
        border.width: 1
        border.color: Config.ThemeConfig.colors.border
        opacity: pop.opened ? 1 : 0
        visible: pop.opened || opacity > 0

        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.flap } }
        Behavior on y { NumberAnimation { duration: Config.MotionConfig.move; easing.type: Config.MotionConfig.ease } }

        MouseArea { anchors.fill: parent }   // swallow in-card clicks

        HoverHandler {
            enabled: pop.hoverClose
            onHoveredChanged: {
                if (hovered) hoverCloseTimer.stop()
                else if (pop.opened) hoverCloseTimer.restart()
            }
        }
        Timer {
            id: hoverCloseTimer
            interval: 450
            onTriggered: if (pop.opened) pop.close()
        }

        ColumnLayout {
            id: cardBody
            x: pop.padding
            y: pop.padding
            width: parent.width - 2 * pop.padding
            spacing: 0
        }
    }
}
