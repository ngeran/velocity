// LauncherFrecency.qml — launch-frequency store for the native launcher.
// Port of ryoku's launcher Frecency singleton: a flat {id: count} map, bumped
// on every launch and read by launcher-search.mjs as the ranking tiebreak
// (and the empty-query "most used" list). State lives in the session state
// dir, next to the plugins' own settings files.
//
// FileView contract note (see ThemeConfig for the full saga): blockLoading
// makes the boot read synchronous, atomicWrites keeps crash-writes clean.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string file: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/velocity/launcher-usage.json"
    property var usage: ({})

    function get(id) {
        var c = id ? root.usage[id] : 0
        return typeof c === "number" ? c : 0
    }

    function bump(id) {
        if (!id)
            return
        var m = Object.assign({}, root.usage) // reassign: bindings on usage re-evaluate
        m[id] = ((typeof m[id] === "number") ? m[id] : 0) + 1
        root.usage = m
        store.setText(JSON.stringify(m))
    }

    FileView {
        id: store
        path: root.file
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        var raw = store.text()
        try {
            root.usage = raw && raw.length ? JSON.parse(raw) : ({})
        } catch (e) {
            root.usage = ({})
        }
    }
}
