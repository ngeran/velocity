// =============================================================================
// PluginManagerService.qml — settings-side driver for the bar's plugin engine
// =============================================================================
// The BAR process owns plugin loading (bar/engine/PluginRegistry) and is the
// single writer of plugins-state.json and of every plugin's settings file.
// This service is the management bridge:
//   • list/rescan/enable/disable/place/move/settings → bar `plugins` IPC
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
    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: opProc
        command: []; running: false
        property var onDone: null
        property string buffer: ""
        // SplitParser is per-line — rejoin WITH newlines (codebase trap).
        stdout: SplitParser { onRead: function(d) { opProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            var cb = opProc.onDone
            var out = opProc.buffer
            opProc.buffer = ""
            opProc.onDone = null
            root.busy = false
            if (cb) cb(out)
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
        opProc.onDone = cb
        opProc.command = cmd
        opProc.running = true
    }

    // ── bar IPC ──────────────────────────────────────────────────────────────
    property string _lastListJson: ""
    function refresh() {
        runCoalesced(["qs", "-c", "bar", "ipc", "call", "plugins", "list"], function(out) {
            var trimmed = (out || "").trim()
            if (trimmed === root._lastListJson) return   // no churn — keep row hover states
            root._lastListJson = trimmed
            try { root.plugins = JSON.parse(trimmed || "[]") }
            catch (e) { root.lastError = "bad list output" }
        })
    }

    // ── deep links: settings surfaces → bar overlay plugins ─────────────────
    // "Inspect this process" from the Core GPU pane: summons an overlay
    // plugin (xray) in the BAR process with a query payload
    // ({"query":"pid:4242"}). hasPlugin() reads the last bar list; the Core
    // tab never loads it, so inspectExternal refreshes first and retries once
    // the answer lands — then reports instead of silently doing nothing.
    function hasPlugin(id) {
        for (var i = 0; i < root.plugins.length; i++) {
            var p = root.plugins[i]
            if (p.id === id && p.status === "ready" && p.enabled) return true
        }
        return false
    }
    function inspectExternal(id, payload) {
        if (root.plugins.length === 0) refresh()
        if (!hasPlugin(id)) {
            run(["true"], function() {
                if (hasPlugin(id))
                    run(["qs", "-c", "bar", "ipc", "call", "plugins", "summon", id, payload])
                else
                    root.lastError = "inspect: " + id + " is not installed or not enabled"
            })
            return
        }
        run(["qs", "-c", "bar", "ipc", "call", "plugins", "summon", id, payload])
    }
    function rescan() {
        run(["qs", "-c", "bar", "ipc", "call", "plugins", "rescan"], function() { root.refresh() })
    }
    function setEnabled(id, on) {
        run(["qs", "-c", "bar", "ipc", "call", "plugins", on ? "enable" : "disable", id],
            function() { root.refresh() })
    }
    // Shift within its bar section; the bar (single writer of the state
    // file) clamps at the edges.
    function move(id, delta) {
        run(["qs", "-c", "bar", "ipc", "call", "plugins", "move", id, delta < 0 ? "up" : "down"],
            function() { root.refresh() })
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

    // ── placement + per-plugin settings (bar IPC) ────────────────────────────
    function place(id, section) {
        run(["qs", "-c", "bar", "ipc", "call", "plugins", "place", id, section, "end"],
            function() { root.refresh() })
    }
    // cb({ schema, values }) — read through the bar's SettingsStore.
    function loadSettings(id, cb) {
        run(["qs", "-c", "bar", "ipc", "call", "plugins", "settings", id], function(out) {
            var j = null
            try { j = JSON.parse(String(out || "").trim()) } catch (e) { j = null }
            if (!j || j.error) { root.lastError = j && j.error ? j.error : "bad settings output"; return }
            if (cb) cb(j)
        })
    }
    function setSetting(id, key, value, cb) {
        run(["qs", "-c", "bar", "ipc", "call", "plugins", "setSetting", id, key, JSON.stringify(value)], function(out) {
            var r = String(out || "").trim()
            root.lastError = r === "ok" ? "" : (key + ": " + r)
            if (cb) cb(r === "ok")
        })
    }
}
