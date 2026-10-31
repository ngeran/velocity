// =============================================================================
// PluginManagerService.qml — settings-side driver for the bar's plugin engine
// =============================================================================
// The BAR process owns plugin loading (bar/engine/PluginRegistry) and is the
// single writer of plugins-state.json and of every plugin's settings file.
// This service is the management bridge:
//   • list/rescan/enable/disable/place/move/settings → PluginRegistry DIRECT
//     (P2.2: same process now — reached through HostBridge.engine; the old
//     `qs -c bar ipc` round-trips are gone)
//   • new / install / remove (→ trash) / restore     → bin/velocity-plugin
// sectionVisible gates the 5s refresh (popup-gated poll idiom).
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/cmdqueue.mjs" as CmdQueue

Item {
    id: root
    visible: false

    readonly property string cli: decodeURIComponent(String(Qt.resolvedUrl("../../bin/velocity-plugin")).replace(/^file:\/\//, ""))
    readonly property string userDir: (Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")) + "/velocity/plugins"

    // Validated list straight from the bar host (id, name, version, kinds,
    // enabled, status, error, commands, source, section, position, settings…)
    property var plugins: []
    // Trashed plugins: [{ entry, id, origin }], newest first.
    property var trash: []
    property bool busy: false
    property string lastError: ""
    property bool sectionVisible: false

    onSectionVisibleChanged: if (sectionVisible) { refresh(); refreshTrash() }

    Timer {
        interval: 5000
        running: root.sectionVisible
        repeat: true
        onTriggered: root.refresh()
    }

    // ── single-flight process runner over a FIFO queue ────────────────────────
    // The old runner kept ONE pending slot: the latest busy-time request
    // replaced the queued one, silently swallowing commands (enable(A) then
    // enable(B) → A never ran). Policy lives in lib/cmdqueue.mjs (tested):
    // plain FIFO; refreshes coalesce to ≤1 queued (replaced in position).
    property var _queue: CmdQueue.create()
    BoundedProcess {   // bounded: one-shot CLI op (P8.1; FIFO policy stays in cmdqueue.mjs)
        id: opProc
        command: []
        property var cb: null
        onDone: function (out) {
            var f = opProc.cb
            opProc.cb = null
            root.busy = false
            if (f) f(out)
            var nxt = CmdQueue.dequeue(root._queue)
            if (nxt) root._start(nxt.cmd, nxt.cb)
        }
    }

    function run(cmd, cb) {
        if (opProc.running) { CmdQueue.push(root._queue, cmd, cb); return }
        root._start(cmd, cb)
    }
    // refresh()-shaped calls coalesce: ≤1 queued refresh, replaced in position.
    function runCoalesced(cmd, cb) {
        if (opProc.running) { CmdQueue.pushRefresh(root._queue, cmd, cb); return }
        root._start(cmd, cb)
    }
    function _start(cmd, cb) {
        root.busy = true
        opProc.cb = cb
        opProc.command = cmd
        opProc.run()
    }

    // ── engine bridge (in-process; HostBridge.engine until attach is null) ──
    function _eng() {
        var e = HostBridge.engine
        if (!e) root.lastError = "plugin engine not ready (bar shell not attached)"
        return e
    }

    property string _lastListJson: ""
    function refresh() {
        var e = _eng(); if (!e) return
        // Same row shape the bar `plugins list` IPC served (Primitives only —
        // no QObject reaches a delegate).
        var out = []
        var ps = e.plugins || []
        for (var i = 0; i < ps.length; i++)
            out.push({ id: ps[i].id, name: ps[i].name, version: ps[i].version,
                       kinds: ps[i].kinds, enabled: ps[i].enabled,
                       status: ps[i].status, error: ps[i].error,
                       commands: ps[i].commands, ipc: ps[i].ipc,
                       source: ps[i].source, overrides: ps[i].overrides,
                       section: e.sectionOf(ps[i].id),
                       position: e.positionOf(ps[i].id),
                       defaultSection: ps[i].defaultSection,
                       description: ps[i].description,
                       settings: ps[i].settings,
                       dir: ps[i].dir })
        var j = JSON.stringify(out)
        if (j === root._lastListJson) return   // no churn — keep row hover states
        root._lastListJson = j
        root.plugins = out
    }

    function rescan() {
        var e = _eng(); if (!e) return
        e.rescan()
        root.refresh()
    }
    function setEnabled(id, on) {
        var e = _eng(); if (!e) return
        e.setEnabled(id, on)
        root.refresh()
    }
    // Shift within its bar section; the engine (single writer of the state
    // file) clamps at the edges. Direct call: delta is numeric (neg = up).
    function move(id, delta) {
        var e = _eng(); if (!e) return
        e.move(id, delta)
        root.refresh()
    }

    // ── file operations → bin/velocity-plugin ───────────────────────────────
    // The CLI validates ids/urls/manifests itself; its stderr is folded into
    // stdout and the exit code appended, so failures surface as lastError.
    function _cli(args, cb) {
        run(["sh", "-c", '"$0" "$@" 2>&1; echo "@EXIT $?"', root.cli].concat(args), function(out) {
            var lines = String(out || "").trim().split("\n")
            var code = -1
            if (lines.length && lines[lines.length - 1].indexOf("@EXIT ") === 0)
                code = parseInt(lines.pop().slice(6), 10)
            var text = lines.join("\n")
            root.lastError = code === 0 ? "" : (lines.pop() || "velocity-plugin failed").replace(/^velocity-plugin: /, "")
            if (cb) cb(code === 0, text)
        })
    }

    // `new` also asks the bar to enable it: a plugin you just scaffolded is
    // meant to run.
    function scaffold(id, kind) {
        _cli(["new", String(id || ""), "--kind", kind || "bar-widget"], function() { root.refresh() })
    }
    // Installs land disabled (opt-in); Quattro plugins are detected and
    // converted by the CLI (force with installQuattro).
    function installGit(url) { _cli(["install", String(url || "").trim()], function() { root.refresh() }) }
    function installQuattro(url) { _cli(["install", String(url || "").trim(), "--quattro"], function() { root.refresh() }) }

    // Moves the folder to the trash (undo: restore). Built-in and system
    // plugins are refused by the CLI.
    function remove(id) {
        _cli(["remove", String(id)], function() { root.refresh(); root.refreshTrash() })
    }
    function restore(entry) {
        _cli(["restore", String(entry)], function() { root.refresh(); root.refreshTrash() })
    }
    function refreshTrash() {
        _cli(["trash", "--json"], function(ok, text) {
            if (!ok) return
            try { root.trash = JSON.parse(text || "[]") } catch (e) { root.trash = [] }
        })
    }

    // ── placement + per-plugin settings (direct engine calls) ────────────────
    function place(id, section) {
        var e = _eng(); if (!e) return
        e.place(id, section, -1)
        root.refresh()
    }
    // cb({ schema, values }) — read through the engine's SettingsStore.
    function loadSettings(id, cb) {
        var e = _eng(); if (!e) return
        var j = null
        try { j = JSON.parse(e.settingsJson(id)) } catch (err) { j = null }
        if (!j || j.error) { root.lastError = j && j.error ? j.error : "bad settings output"; return }
        if (cb) cb(j)
    }
    function setSetting(id, key, value, cb) {
        var e = _eng(); if (!e) return
        var r = e.setSetting(id, key, JSON.stringify(value))
        root.lastError = r === "ok" ? "" : (key + ": " + r)
        if (cb) cb(r === "ok")
    }
}
