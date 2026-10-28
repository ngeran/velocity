// =============================================================================
// PopupCoordinator.qml — one bar popup at a time, across every surface
// =============================================================================
// Surfaces claim the single slot by key:
//   "<pluginId>" / "<pluginId>.<sub>"   plugin panels (ctx.popup)
//   "tray"                              the host's tray card
//   "nc"                                the notification center
//   "overlay:<pluginId>"                overlay plugins (PluginHost)
// Plugin ids can't contain ":" and the fixed keys aren't valid ids, so the
// classes never collide.
//
// request(key, closer) takes the slot and calls the PREVIOUS holder's closer
// (after `current` has moved, so its release() is a no-op). Plugin panels
// pass no closer: they watch `current` and close themselves.
//
// `connected` is the notch-lobe carve geometry { owner, screen, caretX }
// published by whichever card is open. It lives here, not in a scene: a style
// swap destroys panels mid-open and their close handlers never fire.
//
// `islands` maps a screen name to the island host a style registered for that
// output (styles/island). A popover whose screen has one presents its content
// inside the island instead of opening its own window; the host object is
// opaque here (the engine never calls into it).
//
// `activities` is the live-activity registry (J0): OSD, plugins (ctx.island)
// and the `island` IPC publish transient status; `visibleActivity` is the ONE
// that renders (lib/activity-queue.mjs arbitration). An open panel wins —
// every claim/release/clear recomputes it. Both maps are REASSIGNED, never
// mutated, so bindings re-evaluate.
// =============================================================================

pragma Singleton

import QtQuick
import "lib/activity-queue.mjs" as Aq

QtObject {
    id: root

    property string current: ""
    property var connected: null
    property var _closer: null
    // Reassigned (never mutated) so bindings on islands[...] re-evaluate.
    property var islands: ({})

    // ── live activities (J0) ────────────────────────────────────────────────
    // key → entry {key, priority, icon, label, accent, progress, focusedOnly,
    // expiresAt, seq}. Writers: OsdService (key "osd"), ctx.island
    // ("<pluginId>:<key>"), the `island` IPC ("<key>" under owner "ipc:").
    property var activities: ({})
    // The arbitrated winner (or null) — what scenes render.
    property var visibleActivity: null
    property int _actSeq: 0
    // Expiry sweep — 1 Hz ONLY while something is registered; the map is
    // empty at rest, so the timer sits stopped (no idle cost). Property-
    // hosted: QtObject has no default property, so a bare child Timer
    // doesn't parse ("Cannot assign to non-existent default property").
    property Timer sweepTimer: Timer {
        interval: 1000
        running: Object.keys(root.activities).length > 0
        repeat: true
        onTriggered: {
            var r = Aq.sweep(root.activities, Date.now())
            if (r.changed) { root.activities = r.map; root._recomputeVisible() }
        }
    }

    // Publish/update one activity. `spec` is the raw caller object; invalid
    // specs (no key, no ttl and no progress) are refused with false.
    function activity(spec) {
        var act = Aq.normalize(spec, Date.now())
        if (act === null) return false
        root._actSeq += 1
        root.activities = Aq.upsert(root.activities, act, root._actSeq)
        root._recomputeVisible()
        return true
    }

    function endActivity(key) {
        var m = Aq.remove(root.activities, String(key || ""))
        if (m === root.activities) return
        root.activities = m
        root._recomputeVisible()
    }

    function _recomputeVisible() {
        root.visibleActivity = Aq.arbitrate(root.activities, root.current !== "")
    }

    function registerIsland(screenName, host) {
        var name = String(screenName || "")
        if (name === "" || !host) return
        var m = Object.assign({}, root.islands)
        m[name] = host
        root.islands = m
    }

    // Owner-checked: a successor window that registered first is kept.
    function unregisterIsland(screenName, host) {
        var name = String(screenName || "")
        if (root.islands[name] !== host) return
        var m = Object.assign({}, root.islands)
        delete m[name]
        root.islands = m
    }

    function islandFor(screenName) {
        return root.islands[String(screenName || "")] || null
    }

    function request(key, closer) {
        key = String(key || "")
        if (key === "") return
        var prev = root._closer
        var prevKey = root.current
        var changed = root.current !== key
        root.current = key
        root._closer = typeof closer === "function" ? closer : null
        root._recomputeVisible()
        if (changed) {
            // The replaced holder's carve geometry is dead the moment it
            // loses the slot: a holder destroyed before it could publish
            // null (hot-reloaded plugin panel, style swap mid-open) would
            // otherwise leave the notch carve stuck until the next
            // successful open. Owner-checked, so a successor that already
            // published is never wiped.
            if (root.connected && root.connected.owner === prevKey) root.connected = null
            if (prev) {
                // A closer bound to a destroyed object throws. Clear the
                // claim anyway — the successor's claim is already in place;
                // the stale closer must not poison the swap.
                try { prev() } catch (e) {
                    console.warn("[PopupCoordinator] stale closer for '" + prevKey + "':", e)
                }
            }
        }
    }

    function release(key) {
        if (root.current !== String(key)) return
        root.current = ""
        root._closer = null
        root._recomputeVisible()
    }

    // Owner-checked: never wipes a successor's publish.
    function publish(owner, geom) {
        if (geom) root.connected = { owner: owner, screen: geom.screen || "", caretX: geom.caretX }
        else if (root.connected && root.connected.owner === owner) root.connected = null
    }

    // Style swap: close whatever is open and drop stale carve geometry.
    function clear() {
        var prev = root._closer
        root.current = ""
        root._closer = null
        root.connected = null
        root._recomputeVisible()
        if (prev) {
            try { prev() } catch (e) {
                console.warn("[PopupCoordinator] stale closer during clear:", e)
            }
        }
    }
}
