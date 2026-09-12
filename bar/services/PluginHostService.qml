// =============================================================================
// PluginHostService.qml — discovery, validation and state for user plugins
// =============================================================================
// Scans ~/.config/quickshell/plugins/<author.name>/manifest.json (one fork per
// rescan), validates the manifest contract, and exposes the validated list the
// bar's Loader slots instantiate. Enable/disable state persists in
// plugins-state.json; undiscovered-but-enabled entries are simply dormant.
//
// Manifest contract (api 1):
//   { schemaVersion:1, api:1, id:"author.name", name, version, description,
//     author, kinds:["bar-widget"|"service"], entryPoints:{barWidget|service},
//     commands:["curl",...] }
//   — id must be namespaced; "omarchy.*" is reserved. Entry files are loaded
//     by the shell's Loaders, which report load errors back via reportError().
//
// The api object injected into plugin roots carries OBJECT REFERENCES to the
// process-wide singletons (theme/bar/osd) — deliberately NOT imports, so
// plugins share the same singleton instances instead of tripping the
// absolute-vs-relative import duplicate-instance trap, and the surface is
// versioned (api.version) so hosts can evolve it without breaking plugins.
//
// Plugins are unsandboxed user code by design (same rule as the shell): the
// declared `commands` list is shown to the user in the plugin manager.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../config" as Config

Item {
    id: root
    visible: false

    readonly property string homeDir: (Quickshell.env("HOME") || "")
    readonly property string pluginsDir: homeDir + "/.config/quickshell/plugins"
    readonly property string statePath: homeDir + "/.config/quickshell/plugins-state.json"

    // Validated manifests + runtime state: { id, name, version, description,
    // author, kinds[], entry{}, commands[], dir, enabled, status, error }
    property var plugins: []

    readonly property var barWidgetPlugins: root._byKind("bar-widget", "right")
    readonly property var centerWidgetPlugins: root._byKind("bar-widget", "center")
    readonly property var servicePlugins: root._byKind("service", "")

    // The plugin panel that is currently open (manifest id, or ""). Opening
    // one panel closes the others — same one-at-a-time contract as TrayCard.
    property string openPanel: ""

    // Cross-plugin panel bus: the clock anchor asks for the weather panel
    // toggle/refresh without knowing the weather plugin's internals.
    signal togglePanelRequested(string id)
    signal refreshPanelRequested(string id)
    function requestTogglePanel(id) { togglePanelRequested(id) }
    function requestRefreshPanel(id) { refreshPanelRequested(id) }

    // Stable API surface injected into every plugin root as `api`.
    // hypr = the bar's ONE socket2 owner — plugins subscribe to its events
    // instead of streaming their own (a second nc would fight the owner).
    readonly property var api: ({
        version: 1,
        theme: Config.ThemeConfig,
        bar: Config.BarConfig,
        osd: OsdService,
        hypr: HyprlandService,
        host: root
    })

    // ── state (enabled map + bar display order) ──────────────────────────────
    // The bar is the SINGLE WRITER of plugins-state.json; the settings plugin
    // manager drives it through the `plugins` IPC (including `order`).
    property var enabledMap: ({})
    property var order: []             // ids in requested bar order
    property bool _stateReady: false

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: false
        onLoaded: {
            try {
                var j = JSON.parse(text() || "{}")
                if (j && j.enabled) root.enabledMap = j.enabled
                if (j && Array.isArray(j.order)) root.order = j.order
            } catch (e) { root.enabledMap = {}; root.order = [] }
            // First run: the state file doesn't exist yet — onLoaded never
            // fires, so readiness must not depend on it landing.
            root._stateReady = true
            root._applyEnabledFlags()
            root.rescan()
        }
    }
    Component.onCompleted: {
        stateFile.reload()
        // Don't wait on the async state read — the missing-file case never
        // emits onLoaded. If the state lands later, onLoaded re-applies it.
        root._stateReady = true
        root.rescan()
    }

    Process {
        id: stateWriter
        command: []; running: false
        onExited: function(code) {
            if (code !== 0) console.log("[PluginHost] state write failed exit=" + code)
        }
    }

    function _persistState() {
        // Prune keys whose plugins no longer exist — removed plugins would
        // otherwise leave zombie entries in plugins-state.json forever.
        var pruned = {}
        for (var k in root.enabledMap) {
            var known = false
            for (var i = 0; i < root.plugins.length; i++)
                if (root.plugins[i].id === k) { known = true; break }
            if (known) pruned[k] = root.enabledMap[k]
        }
        var json = JSON.stringify({ enabled: pruned, order: root.order })
        var esc = json.replace(/'/g, "'\\''")
        stateWriter.command = ["sh", "-c",
            "mkdir -p '" + root.homeDir + "/.config/quickshell' && printf '%s' '" + esc + "' > '" + root.statePath + "'"]
        stateWriter.running = true
    }

    function setEnabled(id, on) {
        var m = Object.assign({}, root.enabledMap)
        m[id] = on === true
        root.enabledMap = m
        root._persistState()
        root._applyEnabledFlags()
    }

    // Reorder bar-widgets (array of ids from the plugin manager). Unknown ids
    // keep their relative order after the known ones.
    function setOrder(ids) {
        if (!Array.isArray(ids)) return
        root.order = ids.map(String)
        root._persistState()
        root._applyEnabledFlags()
    }

    // ── scan: one fork lists dirs, dumps manifests, and exposes symlinks ────
    Process {
        id: scanProc
        command: []; running: false
        property string buffer: ""
        // SplitParser emits PER LINE — rejoin with "\n" (codebase trap).
        stdout: SplitParser { onRead: function(d) { scanProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            root._absorbScan(scanProc.buffer)
            scanProc.buffer = ""
        }
    }

    function rescan() {
        if (!root._stateReady || scanProc.running) return
        // External writers (settings plugin manager) edit the state file and
        // then call rescan — re-read it so enabled/order apply.
        stateFile.reload()
        scanProc.buffer = ""
        scanProc.command = ["sh", "-c",
            "for d in " + root.pluginsDir + "/*/; do" +
            " [ -f \"${d}manifest.json\" ] && { echo \"@DIR ${d}\"; cat \"${d}manifest.json\"; echo; }; done;" +
            " echo \"@LINKS\"; find " + root.pluginsDir + " -type l 2>/dev/null; true"]
        scanProc.running = true
    }

    function _absorbScan(raw) {
        var symlinks = []
        var blocks = []
        var cur = null
        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var L = lines[i]
            if (L.indexOf("@DIR ") === 0) {
                cur = { dir: L.slice(5).trim(), json: "" }
                blocks.push(cur)
            } else if (L === "@LINKS") {
                cur = null
            } else if (cur !== null) {
                cur.json += L + "\n"
            } else if (L.trim() !== "") {
                symlinks.push(L.trim())
            }
        }

        var out = []
        for (var b = 0; b < blocks.length; b++) {
            var m = root._validate(blocks[b].dir, blocks[b].json, symlinks)
            if (m) out.push(m)
        }
        root.plugins = root._applyStateToList(out)
    }

    // Copy-on-write: returns a NEW list of NEW objects with enabled/status
    // applied + bar order sorted. In-place mutation of shared items caused a
    // binding loop (barWidgetPlugins re-evaluating against mutated inputs).
    function _applyStateToList(list) {
        var out = []
        for (var i = 0; i < list.length; i++) {
            var p = Object.assign({}, list[i])
            p.enabled = root.enabledMap[p.id] !== false
            if (p.enabled && p.status === "disabled") p.status = "ready"
            if (!p.enabled) p.status = "disabled"
            out.push(p)
        }
        var rank = {}
        for (var r = 0; r < root.order.length; r++) rank[root.order[r]] = r
        out.sort(function(a, b) {
            var ra = rank[a.id] === undefined ? 9999 : rank[a.id]
            var rb = rank[b.id] === undefined ? 9999 : rank[b.id]
            return ra - rb
        })
        return out
    }

    function _applyEnabledFlags() {
        root.plugins = root._applyStateToList(root.plugins)
    }

    // Contract validation — returns the plugin object or null (with error).
    function _validate(dir, jsonText, symlinks) {
        var m
        try { m = JSON.parse(jsonText) } catch (e) { return _bad(dir, "manifest is not valid JSON: " + e) }
        if (!m || typeof m !== "object") return _bad(dir, "manifest is not an object")

        if (m.schemaVersion !== 1) return _bad(dir, "schemaVersion must be 1")
        if (typeof m.id !== "string" || !/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_-]+)+$/.test(m.id))
            return _bad(dir, "id must be namespaced like 'author.name' or 'org.group.name'")
        if (m.id.indexOf("omarchy.") === 0) return _bad(dir, "id 'omarchy.*' is reserved")
        if (typeof m.name !== "string" || m.name === "") return _bad(dir, "name missing")
        if (typeof m.version !== "string" && typeof m.version !== "number") return _bad(dir, "version missing")
        if (!Array.isArray(m.kinds) || m.kinds.length === 0) return _bad(dir, "kinds missing")
        if (!m.entryPoints || typeof m.entryPoints !== "object") return _bad(dir, "entryPoints missing")

        var legalKinds = ["bar-widget", "service"]
        for (var k = 0; k < m.kinds.length; k++) {
            var kind = m.kinds[k]
            if (legalKinds.indexOf(kind) === -1) return _bad(dir, "unsupported kind: " + kind)
            var entry = m.entryPoints[kind === "bar-widget" ? "barWidget" : kind]
            if (typeof entry !== "string" || entry === "" || entry.indexOf("/") !== -1 || entry.indexOf("..") !== -1)
                return _bad(dir, "entryPoints." + (kind === "bar-widget" ? "barWidget" : kind) + " must be a safe relative filename")
        }
        if (m.slot !== undefined && m.slot !== "right" && m.slot !== "center")
            return _bad(dir, "slot must be 'right' or 'center'")

        for (var s = 0; s < symlinks.length; s++)
            if (symlinks[s].indexOf(dir) === 0) return _bad(dir, "plugin folder contains a symlink: " + symlinks[s])

        return {
            id: m.id,
            name: String(m.name),
            version: String(m.version),
            description: String(m.description || ""),
            author: String(m.author || m.id.split(".")[0]),
            kinds: m.kinds.slice(0),
            entryPoints: m.entryPoints,
            commands: Array.isArray(m.commands) ? m.commands.map(String) : [],
            slot: m.slot || "right",
            apiWanted: (m.api === undefined ? 1 : m.api),
            dir: dir,
            enabled: true,
            status: "ready",
            error: ""
        }
    }

    function _bad(dir, why) {
        console.log("[PluginHost] invalid plugin in " + dir + ": " + why)
        return {
            id: dir, name: dir.split("/").filter(Boolean).pop() || dir,
            version: "", description: "", author: "", kinds: [], entryPoints: {},
            commands: [], apiWanted: 1, dir: dir, enabled: false,
            status: "invalid", error: why
        }
    }

    // Loaders report back — surfaced by the plugin manager (Phase 2) + list IPC.
    // Idempotent: re-reporting an already-errored plugin must NOT reassign the
    // plugins array — a new identity here recomputes barWidgetPlugins, resets
    // the rail Repeater, recreates the failing Loader, which re-reports… the
    // binding loop the journal kept flagging.
    function reportError(id, message) {
        for (var i = 0; i < root.plugins.length; i++) {
            if (root.plugins[i].id === id) {
                var p = root.plugins[i]
                if (p.status === "error") return
                p.status = "error"
                p.error = message
                var out = root.plugins.slice(0); out[i] = Object.assign({}, p)
                root.plugins = out
                console.log("[PluginHost] load error " + id + ": " + message)
                return
            }
        }
    }

    function _byKind(kind, slot) {
        var out = []
        for (var i = 0; i < root.plugins.length; i++) {
            var p = root.plugins[i]
            if (!p.enabled || p.status !== "ready" || p.kinds.indexOf(kind) === -1) continue
            var pSlot = p.slot || "right"
            if (slot === "" || pSlot === slot) out.push(p)
        }
        return out
    }
}
