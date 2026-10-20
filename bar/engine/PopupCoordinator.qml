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
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    id: root

    property string current: ""
    property var connected: null
    property var _closer: null
    // Reassigned (never mutated) so bindings on islands[...] re-evaluate.
    property var islands: ({})

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
