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
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    id: root

    property string current: ""
    property var connected: null
    property var _closer: null

    function request(key, closer) {
        key = String(key || "")
        if (key === "") return
        var prev = root._closer
        var changed = root.current !== key
        root.current = key
        root._closer = typeof closer === "function" ? closer : null
        if (changed && prev) prev()
    }

    function release(key) {
        if (root.current !== String(key)) return
        root.current = ""
        root._closer = null
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
        if (prev) prev()
    }
}
