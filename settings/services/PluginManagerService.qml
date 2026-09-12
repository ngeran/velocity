// =============================================================================
// PluginManagerService.qml — settings-side driver for the bar's plugin host
// =============================================================================
// The BAR process owns plugin loading (PluginHostService) and is the single
// writer of plugins-state.json. This service is the management bridge:
//   • list/rescan/enable/disable/order  → bar `plugins` IPC (cross-process)
//   • scaffold / installGit / remove    → direct file ops in the plugins dir
// sectionVisible gates the 5s refresh (popup-gated poll idiom).
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    readonly property string homeDir: (Quickshell.env("HOME") || "")
    readonly property string pluginsDir: homeDir + "/.config/quickshell/plugins"

    // Validated list straight from the bar host (id, name, version, kinds,
    // enabled, status, error, commands, dir…)
    property var plugins: []
    property bool busy: false
    property string lastError: ""
    property bool sectionVisible: false

    onSectionVisibleChanged: if (sectionVisible) refresh()

    Timer {
        interval: 5000
        running: root.sectionVisible
        repeat: true
        onTriggered: root.refresh()
    }

    // ── single-flight process runner with a one-slot pending queue ───────────
    // A dropped request silently swallowed installs (the runner was often
    // busy with the 5s refresh) — so the latest request waits and runs next.
    property var _pendingCmd: null
    property var _pendingCb: null
    Process {
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
            if (root._pendingCmd) {
                var c = root._pendingCmd, w = root._pendingCb
                root._pendingCmd = null; root._pendingCb = null
                run(c, w)
            }
        }
    }

    function run(cmd, cb) {
        if (opProc.running) {
            root._pendingCmd = cmd
            root._pendingCb = cb
            return
        }
        root.busy = true
        opProc.onDone = cb
        opProc.command = cmd
        opProc.running = true
    }

    // ── bar IPC ──────────────────────────────────────────────────────────────
    property string _lastListJson: ""
    function refresh() {
        run(["qs", "-c", "bar", "ipc", "call", "plugins", "list"], function(out) {
            var trimmed = (out || "").trim()
            if (trimmed === root._lastListJson) return   // no churn — keep row hover states
            root._lastListJson = trimmed
            try { root.plugins = JSON.parse(trimmed || "[]") }
            catch (e) { root.lastError = "bad list output" }
        })
    }
    function rescan() {
        run(["qs", "-c", "bar", "ipc", "call", "plugins", "rescan"], function() { root.refresh() })
    }
    function setEnabled(id, on) {
        run(["qs", "-c", "bar", "ipc", "call", "plugins", on ? "enable" : "disable", id],
            function() { root.refresh() })
    }
    function move(id, delta) {
        // Reorder within the current bar-widget ordering, then hand the new
        // id array to the bar (single writer of the state file).
        var ids = []
        var ps = root.plugins
        var idx = -1
        for (var i = 0; i < ps.length; i++) {
            if (ps[i].kinds.indexOf("bar-widget") !== -1) ids.push(ps[i].id)
            if (ps[i].id === id) idx = ids.length - 1
        }
        if (idx < 0) return
        var to = idx + delta
        if (to < 0 || to >= ids.length) return
        var tmp = ids[idx]; ids[idx] = ids[to]; ids[to] = tmp
        run(["qs", "-c", "bar", "ipc", "call", "plugins", "order", JSON.stringify(ids)],
            function() { root.refresh() })
    }

    // ── file operations ──────────────────────────────────────────────────────
    // Multi-segment ids are valid (io.github.sspaeti.timezones) — same rule
    // the bar's host applies. Only the omarchy.* namespace is reserved.
    function _safeId(id) {
        return /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_-]+)+$/.test(String(id || "")) &&
               String(id).indexOf("omarchy.") !== 0
    }

    // Scaffold a new plugin folder from the api-1 template.
    function scaffold(id) {
        if (!_safeId(id)) { root.lastError = "id must be namespaced like author.name"; return }
        var dir = root.pluginsDir + "/" + id
        run(["sh", "-c",
             "mkdir -p '" + dir + "' && printf '%s' '" +
             JSON.stringify({
                 schemaVersion: 1, api: 1, id: id,
                 name: id.split(".")[1].charAt(0).toUpperCase() + id.split(".")[1].slice(1),
                 version: "0.1.0",
                 description: "Scaffolded plugin — edit BarWidget.qml.",
                 author: id.split(".")[0],
                 kinds: ["bar-widget"],
                 entryPoints: { barWidget: "BarWidget.qml" },
                 commands: []
             }).replace(/'/g, "'\\''") + "' > '" + dir + "/manifest.json' && printf '%s' '" +
             _template().replace(/'/g, "'\\''") + "' > '" + dir + "/BarWidget.qml'"],
             function() { root.lastError = ""; root.rescan() })
    }

    // Clone a git repo into the plugins dir; the repo's manifest.json is
    // validated by the host on rescan. AUTO-DETECT: a clone without our
    // schemaVersion (i.e. a raw Quattro plugin) is converted in place first.
    function installGit(url) {
        var u = String(url || "").trim()
        // Only https/ssh git URLs — no shell metacharacters survive the argv split.
        if (!/(^[a-z]+:\/\/|^git@|^\/)[^\s';&|]+$/.test(u)) { root.lastError = "invalid git url"; return }
        var name = u.split("/").pop().replace(/\.git$/, "")
        if (name === "") { root.lastError = "cannot derive folder from url"; return }
        var dir = root.pluginsDir + "/" + name
        run(["sh", "-c", "rm -rf '" + dir + "'; git clone --depth 1 '" + u + "' '" + dir + "' 2>&1"],
            function(out) {
                if (out.indexOf("fatal") !== -1 || out.indexOf("error") !== -1) {
                    root.lastError = out.trim().split("\n").pop()
                    return
                }
                run(["sh", "-c", "node -e 'try{const m=JSON.parse(require(\"fs\").readFileSync(\"" + dir + "/manifest.json\",\"utf8\"));process.exit(m.compat===\"quattro\"?1:0)}catch(e){process.exit(0)}'"],
                    function(needsConvert) {
                        if (needsConvert.trim() === "0") convertQuattroInPlace(dir)
                        root.lastError = ""
                        root.rescan()
                    })
            })
    }

    // ── QUATTRO PIPELINE — clone an Omarchy/Quattro plugin and convert it ────
    // Clone → copy the compat qs.* modules into the folder → rewrite their
    // qs.Commons / qs.Ui imports to the vendored copies → regenerate our
    // manifest (theirs preserved as manifest.quattro.json). Non-mechanical
    // spots (panel internals referencing Omarchy-only APIs) surface as
    // runtime errors in the manager rather than silent breakage.
    function installQuattro(url) {
        var u = String(url || "").trim()
        if (!/^([a-z]+:\/\/|git@|\/)[^\s';&|]+$/.test(u) && !/^\/[^\s']+$/.test(u)) {
            root.lastError = "invalid source url or path"; return
        }
        var name = u.split("/").filter(Boolean).pop().replace(/\.git$/, "")
        if (name === "") { root.lastError = "cannot derive folder from url"; return }
        busy = true
        run(["sh", "-c", "rm -rf '" + root.pluginsDir + "/" + name + "'; git clone --depth 1 '" + u + "' '" + root.pluginsDir + "/" + name + "' 2>&1"],
            function(out) {
                if (out.indexOf("fatal") !== -1) { root.lastError = "clone failed"; busy = false; return }
                convertQuattroInPlace(root.pluginsDir + "/" + name)
                root.rescan()
            })
    }

    // In-place conversion of an already-cloned Quattro plugin folder:
    // manifest regen (ours from theirs) + root-type rewrites (BarWidget →
    // QsBarWidget, Panel → QsPanel) so the derived roots resolve to the
    // compat bases instead of recursively to their own filenames.
    function convertQuattroInPlace(dir) {
        run(["sh", "-c",
             "cd '" + dir + "' && " +
             "sed -i 's|^BarWidget {$|QsBarWidget {|' BarWidget.qml && " +
             "sed -i 's|^Panel {$|QsPanel {|' Panel.qml 2>/dev/null; " +
             "mv manifest.json manifest.quattro.json 2>/dev/null; " +
             "node -e '"
             + "const fs=require(\"fs\");"
             + "try { const m=JSON.parse(fs.readFileSync(\"manifest.quattro.json\",\"utf8\"));"
             + "const out={schemaVersion:1,api:2,id:m.id,name:m.name||m.id,version:String(m.version||\"0.1.0\"),"
             + "description:(m.description||\"\").slice(0,200),author:m.author||\"quattro\","
             + "kinds:[\"bar-widget\"],entryPoints:{barWidget:(m.entryPoints&&m.entryPoints.barWidget)||\"BarWidget.qml\"},"
             + "commands:[],compat:\"quattro\"};"
             + "fs.writeFileSync(\"manifest.json\",JSON.stringify(out,null,2)); } catch(e) { process.exit(1) }' "
             + "&& echo CONVERTED"],
            function(out) {
                root.lastError = out.indexOf("CONVERTED") !== -1 ? "" : "quattro conversion failed: " + out.trim().split("\n").pop()
                root.rescan()
            })
    }

    // Two-step confirm lives in the UI; this nukes the folder + state refs.
    // The folder name is NOT always the id (converted plugins live in e.g.
    // omarchy-timezones-plugin/) — resolve the real dir from the host list.
    function remove(id) {
        if (!_safeId(id)) { root.lastError = "invalid id"; return }
        var dir = ""
        for (var i = 0; i < root.plugins.length; i++)
            if (root.plugins[i].id === id) { dir = root.plugins[i].dir || ""; break }
        var target = (dir !== "") ? dir : root.pluginsDir + "/" + id
        // Paranoia: only ever delete INSIDE the plugins dir.
        if (target.indexOf(root.pluginsDir + "/") !== 0) {
            root.lastError = "refusing to delete outside plugins dir"
            return
        }
        run(["sh", "-c", "rm -rf '" + target + "'"],
            function() { root.rescan() })
    }

    function _template() {
        return [
            "// Scaffolded by the plugin manager — plugin api 1.",
            "import QtQuick",
            "",
            "Item {",
            "    id: root",
            "    property string pluginId: \"\"",
            "    property var api: null",
            "",
            "    implicitWidth: label.implicitWidth + 12",
            "    height: api ? api.bar.barHeight : 30",
            "",
            "    Text {",
            "        id: label",
            "        anchors.centerIn: parent",
            "        text: \"7 NEW\"",
            "        font.family: api ? api.bar.fontNerd : \"monospace\"",
            "        font.pixelSize: api ? api.bar.fontSizeIcon : 13",
            "        color: api ? api.theme.colors.success : \"#888\"",
            "    }",
            "}"
        ].join("\n")
    }
}
