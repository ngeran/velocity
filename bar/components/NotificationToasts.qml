// =============================================================================
// NotificationToasts.qml — the toast surface (UX U3)
// =============================================================================
// Port of ryoku's NotificationPopups (GPL-3 — github.com/ryoku-shell,
// modules/notifications/NotificationPopups.qml), re-tokenised for this rice.
// A top-right overlay layer surface sized to its content (the toast column),
// reserving nothing and never taking keyboard focus. Newest-first at a fixed
// content width, floating px(16) off the corner. Each card arrives from off
// the right edge (slide + fade + small scale settle) and, on close, is flicked
// back out while the cards below hold their slot until it clears, then rise.
// The surface holds its height for a card that is still leaving (exitFloor)
// and unmaps shortly after the list empties, so the last exit is neither
// clipped nor cut short; a popup arriving in that wait cancels the unmap.
//
// Services.NotificationService.popups is reassigned as a whole array on every
// change (UX U4), which resets a plain view (no per-item animation). A local
// `cards` ListModel is reconciled against it incrementally so the ListView's
// add/remove/displaced transitions actually fire per card.
//
// The window follows the FOCUSED monitor: the screen is set imperatively just
// before the first map (the Osd's P1.11 lesson — a `screen` binding read by
// `visible` closes into a binding loop).
// =============================================================================

import QtQuick
import Quickshell
import Quickshell.Wayland
import bar.services as Services
import bar.config as Config

PanelWindow {
    id: win

    // Base logical px: content width 400, inter-card spacing 12, corner float 16
    // — all through PopupMetrics (the interface-scale read the popups share).
    readonly property real inset: Config.PopupMetrics.px(16)

    // How far off the right edge a card starts and leaves.
    readonly property real slideFrom: win.implicitWidth

    readonly property var popups: Services.NotificationService.popups
    property bool mapped: false

    visible: win.mapped
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    // Keyboard-inert (H1 doctrine — no tray/toast body takes input).
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "velocity-toasts"

    anchors { top: true; right: true }
    margins.top: win.inset
    margins.right: win.inset

    implicitWidth: Config.PopupMetrics.px(400)
    // As tall as its cards, but never shorter than a card that is still
    // leaving: the window clips, so collapsing under the last toast wiped its
    // exit slide instead of letting it glide off the edge (ryoku's exitFloor).
    implicitHeight: Math.max(1, list.contentHeight, win.exitFloor)
    // Height held for a leaving card, released once its exit has finished. This
    // must outlast the whole dismiss: the flicked card slides out over the
    // exit, then the cards below wait that long and rise.
    property real exitFloor: 0
    Timer {
        id: exitHold
        interval: Config.MotionConfig.animDurationSlower + Config.MotionConfig.snap + 60
        onTriggered: win.exitFloor = 0
    }
    // Only follow the height once cards are already up: growing from nothing
    // wiped the first toast open top-down, which read as the card unrolling
    // rather than arriving (ryoku finding).
    Behavior on implicitHeight {
        enabled: cards.count > 1
        NumberAnimation { duration: Config.MotionConfig.animDurationNormal; easing.type: Config.MotionConfig.ease }
    }

    // Newest-first card view, reconciled from NotificationService.popups by id.
    ListModel { id: cards }

    function indexOfId(id) {
        for (var i = 0; i < cards.count; i++)
            if (cards.get(i).nid === id) return i
        return -1
    }
    function sync() {
        var incoming = win.popups
        // Drop cards whose notification is gone (triggers the remove slide).
        for (var i = cards.count - 1; i >= 0; i--) {
            var id = cards.get(i).nid
            var keep = false
            for (var k = 0; k < incoming.length; k++)
                if (incoming[k].id === id) { keep = true; break }
            if (!keep) {
                // Pin the surface at its current height for the exit's
                // duration, then let it settle; otherwise the last card leaves
                // a 1 px window that clips the slide it is mid-way through.
                win.exitFloor = Math.max(win.exitFloor, list.contentHeight)
                exitHold.restart()
                cards.remove(i)
            }
        }
        // Insert new cards and reorder to match the newest-first order.
        for (var j = 0; j < incoming.length; j++) {
            var p = incoming[j]
            var cur = win.indexOfId(p.id)
            if (cur < 0)
                cards.insert(j, { nid: p.id, entry: p,
                                  ttl: Services.NotificationService.popupTtl(p) })
            else if (cur !== j)
                cards.move(cur, j, 1)
        }
    }

    // Map before the first card lands: a ListView does not animate its initial
    // population, so syncing in the same frame the surface maps would skip the
    // arrival entirely (ryoku finding). Unmap shortly after the list empties,
    // re-checking emptiness so a popup arriving during the wait cancels it.
    onPopupsChanged: {
        if (win.popups.length > 0) {
            win.screen = Services.HyprlandService.focusedMonitor === ""
                ? win.screen : _screenByName(Services.HyprlandService.focusedMonitor)
            unmapTimer.stop()
            if (!win.mapped) {
                win.mapped = true
                Qt.callLater(win.sync)
                return
            }
        } else {
            unmapTimer.restart()
        }
        win.sync()
    }
    Component.onCompleted: {
        win.sync()
        win.mapped = win.popups.length > 0
    }
    function _screenByName(name) {
        var scr = Quickshell.screens
        for (var i = 0; i < scr.length; i++)
            if (scr[i].name === name) return scr[i]
        return win.screen
    }

    Timer {
        id: unmapTimer
        interval: Config.MotionConfig.swap
        onTriggered: if (win.popups.length === 0) win.mapped = false
    }

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: contentHeight
        spacing: Config.PopupMetrics.px(12)
        interactive: false
        model: cards

        // A toast is flicked off its edge rather than fading in place, and the
        // stack settles up behind it instead of teleporting (ryoku's physical
        // dismiss): add = arrive from off-edge with a small scale settle;
        // remove = slide out while shrinking and fading in parallel;
        // removeDisplaced = the cards below hold their slot until the flicked
        // card has cleared (a PauseAnimation the length of the exit), then
        // rise. displaced restores a card caught mid-arrival so an interrupted
        // card never sticks half-flicked.
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Config.MotionConfig.swap }
            NumberAnimation { property: "x"; from: win.slideFrom; to: 0; duration: Config.MotionConfig.swap; easing.type: Config.MotionConfig.ease }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Config.MotionConfig.swap; easing.type: Config.MotionConfig.ease }
        }
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: Config.MotionConfig.animDurationNormal; easing.type: Config.MotionConfig.ease }
            NumberAnimation { properties: "opacity"; to: 1; duration: Config.MotionConfig.animDurationNormal }
            NumberAnimation { property: "x"; to: 0; duration: Config.MotionConfig.animDurationNormal }
            NumberAnimation { property: "scale"; to: 1; duration: Config.MotionConfig.animDurationNormal }
        }
        remove: Transition {
            NumberAnimation { property: "x"; to: win.slideFrom; duration: Config.MotionConfig.animDurationSlower; easing.type: Config.MotionConfig.ease }
            NumberAnimation { property: "scale"; to: 0.8; duration: Config.MotionConfig.animDurationSlower }
            NumberAnimation { properties: "opacity"; to: 0; duration: Config.MotionConfig.animDurationSlower }
        }
        removeDisplaced: Transition {
            SequentialAnimation {
                PauseAnimation { duration: Config.MotionConfig.animDurationSlower }
                NumberAnimation { properties: "y"; duration: Config.MotionConfig.animDurationNormal; easing.type: Config.MotionConfig.ease }
            }
            NumberAnimation { properties: "opacity"; to: 1; duration: Config.MotionConfig.animDurationNormal }
            NumberAnimation { property: "x"; to: 0; duration: Config.MotionConfig.animDurationNormal }
            NumberAnimation { property: "scale"; to: 1; duration: Config.MotionConfig.animDurationNormal }
        }

        delegate: Item {
            id: popupDelegate

            // plain property (NOT `required`): a JS-object ListModel role +
            // required property reads as undefined on this build (known trap).
            property var entry: model.entry
            // Sticky criticals pass -1 → the card draws no countdown.
            readonly property int lifespanMs: model.ttl < 0 ? 0 : model.ttl

            width: ListView.view ? ListView.view.width : 0
            height: toastCard.implicitHeight
            transformOrigin: Item.TopRight

            NotificationToastCard {
                id: toastCard
                width: popupDelegate.width
                notif: popupDelegate.entry
                compact: true
                lifespanMs: popupDelegate.lifespanMs
            }
        }
    }
}
