// =============================================================================
// PluginRegistry.qml — the plugin engine: discovery, state, instances, routing
// =============================================================================
// Standalone: imports nothing from bar/config, bar/services or
// bar/components. The host (shell.qml) injects `hostApi` once at startup.
//
// Search path, highest precedence first (an id found twice: the higher one
// wins and records `overrides`; the lower one is listed as "shadowed"):
//   user     $XDG_CONFIG_HOME/velocity/plugins      (symlinks rejected)
//   system   $VELOCITY_PLUGIN_PATH (colon list), then
//            $XDG_DATA_DIRS/*/velocity/plugins      (read-only; symlinks OK — Nix)
//   bundled  <repo>/plugins                         (symlinks rejected)
//   builtin  <repo>/bar/builtins                    (first-party bar widgets)
//
// State lives in <repo>/plugins-state.json (schema 2, lib/layout.mjs):
//   { schemaVersion: 2, enabled: { id: bool }, layout: { left, center, right } }
// The bar process is its ONLY writer — the settings manager and the CLI go
// through the `plugins` IPC (PluginHost.qml). Plugins are opt-in: an id with
// no state entry starts disabled, except built-ins (on unless set false).
// A schema-1 file ({enabled, order}) is migrated on the first scan, folding
// in bar-config.json's legacy `rightLayout`.
//
// Instances: every mounted plugin root registers here per output (a bar
// widget exists once per screen). summon/hide/call pick the instance on the
// focused monitor, else the first live one.
// =============================================================================

pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import "lib/discovery.mjs" as Discovery
import "lib/layout.mjs" as Layout
import "lib/fit.mjs" as Fit

Item {
    id: root
    visible: false

    // The api version plugins must declare (manifest `api`).
    readonly property int apiVersion: 2

    // Injected by the host — the engine's ONLY window into the bar:
    //   { theme, bar, osd, hypr, focusedMonitor: function() → string,
    //     shell (built-ins only: ctx.host), legacyBarConfigPath (migration) }
    property var hostApi: ({})

    // ── paths ────────────────────────────────────────────────────────────────
    function _envOr(name, fallback) {
        var v = Quickshell.env(name)
        return v && String(v) !== "" ? String(v) : fallback
    }
    function _localPath(url) {
        return decodeURIComponent(String(url).replace(/^file:\/\//, "")).replace(/\/$/, "")
    }
    readonly property string homeDir: _envOr("HOME", "")
    readonly property string configHome: _envOr("XDG_CONFIG_HOME", homeDir + "/.config")
    readonly property string dataHome: _envOr("XDG_DATA_HOME", homeDir + "/.local/share")
    readonly property string stateHome: _envOr("XDG_STATE_HOME", homeDir + "/.local/state")
    // Resolved from this file, not from $HOME: the repo can live anywhere.
    // Quickshell 0.3 loads configs out of an internal VFS (Qt.resolvedUrl then
    // yields "qrc:/qs-<id>", not a file:// path) — under it every repo-relative
    // path (state file, builtins, bundled plugins) silently points into an
    // empty virtual root and the scan finds nothing. A file:// URL still means
    // a real checkout (dev -p mode); anything else resolves to the deployed
    // repo (~/.config/quickshell, the deploy-link contract) or VELOCITY_REPO_DIR.
    readonly property string _rawRootUrl: Qt.resolvedUrl("../..")
    readonly property string repoDir: {
        var u = String(_rawRootUrl)
        if (u.indexOf("file://") === 0) return _localPath(u)
        var viaEnv = _envOr("VELOCITY_REPO_DIR", "")
        if (viaEnv !== "") return viaEnv.replace(/\/$/, "")
        return (configHome + "/quickshell").replace(/\/$/, "")
    }
    readonly property string userDir: configHome + "/velocity/plugins"
    readonly property string bundledDir: repoDir + "/plugins"
    readonly property string builtinDir: repoDir + "/bar/builtins"
    readonly property string statePath: repoDir + "/plugins-state.json"
    // VELOCITY_PLUGIN_PATH lists plugin dirs directly (the home-manager
    // module points it at its symlinked plugin tree).
    readonly property var systemDirs: _envOr("VELOCITY_PLUGIN_PATH", "").split(":")
        .filter(function(d) { return d !== "" })
        .map(function(d) { return d.replace(/\/$/, "") })
        .concat(_envOr("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
        .split(":").filter(function(d) { return d !== "" })
        .map(function(d) { return d.replace(/\/$/, "") + "/velocity/plugins" }))
    // Scan order = precedence order. links: whether symlinks are allowed.
    readonly property var searchPath: [{ source: "user", path: userDir, links: false }]
        .concat(systemDirs.map(function(p) { return { source: "system", path: p, links: true } }))
        .concat([{ source: "bundled", path: bundledDir, links: false },
                 { source: "builtin", path: builtinDir, links: false }])

    // ── plugin list ──────────────────────────────────────────────────────────
    // Normalized manifests (lib/manifest.mjs) + { dir, source, overrides[],
    // enabled, status: ready|disabled|invalid|error|shadowed, error }
    property var plugins: []

    // What each bar section renders: { left: [plugin], center, right }.
    readonly property var sections: Layout.resolve(root.layout, root.plugins)
    // Headless roots mounted ONCE in the host (PluginHost): kind-"service"
    // plugins, plus any plugin with an extra entryPoints.service root — the
    // service/view split (one live service per plugin across hosts and
    // outputs; views stay per-window and disposable).
    readonly property var servicePlugins: root.plugins.filter(function(p) {
        return p.enabled && p.status === "ready"
            && (p.kinds.indexOf("service") !== -1 || !!p.entryPoints.service)
    })
    readonly property var overlayPlugins: root._byKind("overlay")

    function plugin(id) {
        for (var i = 0; i < root.plugins.length; i++)
            if (root.plugins[i].id === id && root.plugins[i].status !== "shadowed") return root.plugins[i]
        return null
    }

    function _byKind(kind) {
        return root.plugins.filter(function(p) {
            return p.enabled && p.status === "ready" && p.kinds.indexOf(kind) !== -1
        })
    }

    // Event bus handed to plugins (ctx.events) — the host re-emits the bar's
    // one socket2 stream here, so plugins never open their own.
    readonly property QtObject events: QtObject {
        signal hyprEvent(string line)
    }

    // ── state ────────────────────────────────────────────────────────────────
    property var enabledMap: ({})
    property var layout: Layout.empty()
    property bool _stateReady: false
    property bool _scanned: false
    // Schema-1 `order`, kept only until the first scan migrates it.
    property var _legacyOrder: null

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: false
        printErrors: false
        onLoaded: {
            var j = null
            try { j = JSON.parse(text() || "{}") } catch (e) { j = null }
            j = j && typeof j === "object" ? j : {}
            root.enabledMap = Object.assign({}, (j.enabled && typeof j.enabled === "object") ? j.enabled : {}, root._pending)
            if (j.schemaVersion === 2 && j.layout) {
                root.layout = Layout.normalize(j.layout)
                root._legacyOrder = null
            } else if (!root._scanned) {
                // Migrate on the first scan only: a re-read racing our own
                // schema-2 write must not migrate (and reset) twice.
                root._legacyOrder = Array.isArray(j.order) ? j.order : []
            }
            root._applyEnabledFlags()
            root._markStateReady()
        }
        // First run: no state file yet — readiness must still land.
        onLoadFailed: {
            if (!root._scanned) root._legacyOrder = []
            root._markStateReady()
        }
    }

    // Read once, only when migrating (blockLoading: text() is synchronous).
    FileView {
        id: legacyConfig
        path: root._legacyOrder !== null ? String(root.hostApi.legacyBarConfigPath || "") : ""
        blockLoading: true
        printErrors: false
    }

    function _migrate(list) {
        var cfg = {}
        try { cfg = JSON.parse(legacyConfig.text() || "{}") || {} } catch (e) { cfg = {} }
        var r = Layout.migrate({ rightLayout: cfg.rightLayout, order: root._legacyOrder, plugins: list })
        var m = Object.assign({}, root.enabledMap)
        for (var i = 0; i < r.disabled.length; i++) m[r.disabled[i]] = false
        root.enabledMap = m
        root.layout = r.layout
        root._legacyOrder = null
        console.log("[PluginRegistry] migrated plugins-state.json to schema 2")
    }
    // The first scan waits for the state: scanning earlier mounted disabled
    // plugins with default state and tore them down again a moment later.
    function _markStateReady() {
        if (root._stateReady) return
        root._stateReady = true
        root.rescan()
    }
    Component.onCompleted: stateFile.reload()

    Process {   // unbounded-ok: one-shot local file write (tmp + mv)
        id: stateWriter
        command: []; running: false
        onExited: function(code) {
            if (code !== 0) console.log("[PluginRegistry] state write failed exit=" + code)
        }
    }

    function _persistState() {
        // Before the first scan the list is empty: pruning then would wipe
        // the whole state.
        if (!root._scanned) return
        // Prune ids no longer on disk — removed plugins would otherwise leave
        // zombie entries forever. S4: ids still under the grace tally (missed
        // 1-2 consecutive scans) survive — the keep-list is known ∪ _misses.
        var pruned = {}
        var known = []
        for (var i = 0; i < root.plugins.length; i++) known.push(root.plugins[i].id)
        var keep = known.concat(Object.keys(root._misses))
        for (var k in root.enabledMap)
            if (keep.indexOf(k) !== -1) pruned[k] = root.enabledMap[k]
        root.layout = Layout.prune(root.layout, keep)
        stateWriter.command = ["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"',
            "sh", root.statePath, JSON.stringify({ schemaVersion: 2, enabled: pruned, layout: root.layout })]
        stateWriter.running = true
    }

    // Enabling a bar widget with no place yet puts it at the end of its
    // manifest's defaultSection. Disabling keeps its place.
    function setEnabled(id, on) {
        var m = Object.assign({}, root.enabledMap)
        m[id] = on === true
        root.enabledMap = m
        var p = root.plugin(id)
        // Not scanned yet (`new` / install racing the async rescan): persisting
        // now would prune the id. Apply after the next scan instead.
        if (!p) {
            var pend = Object.assign({}, root._pending)
            pend[id] = on === true
            root._pending = pend
            root.rescan()
            return
        }
        if (on === true && p) root.layout = Layout.ensurePlaced(root.layout, p)
        root._persistState()
        root._applyEnabledFlags()
    }

    // Placement (index < 0 or past the end = append). Returns "ok" or why not.
    function place(id, section, index) {
        var p = root.plugin(id)
        if (!p || p.kinds.indexOf("bar-widget") === -1) return "not a bar widget: " + id
        if (Layout.SECTIONS.indexOf(section) === -1) return "section must be one of " + Layout.SECTIONS.join(", ")
        root.layout = Layout.place(root.layout, id, section, index)
        root._persistState()
        return "ok"
    }
    function move(id, delta) {
        if (Layout.sectionOf(root.layout, id) === "") return "not placed: " + id
        root.layout = Layout.move(root.layout, id, delta)
        root._persistState()
        return "ok"
    }
    function sectionOf(id) { return Layout.sectionOf(root.layout, id) }
    // Pure overflow planning (lib/fit.mjs): scenes pass in the per-cell
    // widths they measured + each cell's collapsePriority and get back the
    // compact/collapse maps, effective section widths and the clamped center
    // x. Passthrough here so styles never import engine internals by path.
    function planFit(params) { return Fit.planFit(params) }
    function positionOf(id) {
        var s = Layout.sectionOf(root.layout, id)
        return s === "" ? -1 : root.layout[s].indexOf(id)
    }

    // ── discovery: one fork over every search dir ───────────────────────────
    // Dirs ride as argv ("source|links|path"), never spliced into the script.
    readonly property string _scanScript: [
        'for spec in "$@"; do',
        '  src=${spec%%|*}; rest=${spec#*|}; links=${rest%%|*}; base=${rest#*|}',
        '  [ -d "$base" ] || continue',
        '  for d in "$base"/*/; do',
        '    [ -f "${d}manifest.json" ] || continue',
        '    echo "@DIR $src ${d}"; cat "${d}manifest.json"; echo',
        '  done',
        '  [ "$links" = 0 ] && find "$base" -mindepth 1 -type l 2>/dev/null | sed "s/^/@LINK /"',
        'done',
        'true'
    ].join("\n")

    Process {   // unbounded-ok: one-shot local scan (sh + cat + find over a few dirs)
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

    // id → bool set before a scan knew the id; survives the rescan's state
    // reload, then gets placed + persisted once the scan lands.
    property var _pending: ({})
    // S4 prune grace: id → consecutive missed scans (Layout.pruneGrace owns
    // the math). Refreshed once per scan in _absorbScan; _persistState keeps
    // ids still under grace so one scan blip can't wipe their state.
    property var _misses: ({})
    property bool _rescanQueued: false

    function rescan() {
        if (!root._stateReady) return
        // A scan already in flight may predate the change that asked for this one.
        if (scanProc.running) { root._rescanQueued = true; return }
        // No stateFile.reload() here: the BAR is the single writer of
        // plugins-state.json (docs contract), so re-reading on every rescan
        // just raced the bar's own writes — a reload landing between an
        // in-memory apply and its persist resurrected the stale file over the
        // fresh state. The state loads exactly once (Component.onCompleted);
        // from then on the registry owns it. (External clobbers — e.g. a
        // deploy sync — are healed by the next _persistState(), which writes
        // the bar's authoritative in-memory state back.)
        scanProc.buffer = ""
        var args = root.searchPath.map(function(s) { return s.source + "|" + (s.links ? 1 : 0) + "|" + s.path })
        scanProc.command = ["sh", "-c", root._scanScript, "sh"].concat(args)
        scanProc.running = true
    }

    // Parsing, validation and precedence live in lib/discovery.mjs (tested).
    function _absorbScan(raw) {
        var scan = Discovery.parseScanOutput(raw)
        var list = Discovery.resolvePlugins(scan.blocks, scan.symlinks, root.apiVersion)
        for (var i = 0; i < list.length; i++)
            if (list[i].status === "invalid")
                console.log("[PluginRegistry] invalid plugin in " + list[i].dir + ": " + list[i].error)
        root._scanned = true
        var migrating = root._legacyOrder !== null
        if (migrating) root._migrate(list)
        root.plugins = root._applyStateToList(list)
        var known = []
        for (var i = 0; i < root.plugins.length; i++) known.push(root.plugins[i].id)
        var settle = Object.keys(root._pending)
        root._pending = ({})
        for (var i = 0; i < settle.length; i++) {
            var p = root.plugin(settle[i])
            if (p && root.enabledMap[p.id] === true) root.layout = Layout.ensurePlaced(root.layout, p)
        }
        // S4 prune grace: refresh the miss tally against THIS scan's ids
        // (cadence is scans, not saves). Ids that hit the grace limit drop
        // from enabled + layout here; ids still under grace stay in the maps
        // and in _misses for _persistState's keep-list.
        var g = Layout.pruneGrace(root.enabledMap, root.layout, known, root._misses)
        root._misses = g.misses
        var graceDropped = g.dropped.length > 0
        if (graceDropped) {
            root.enabledMap = g.enabled
            root.layout = g.layout
            for (var x = 0; x < g.dropped.length; x++)
                console.log("[PluginRegistry] pruned " + g.dropped[x] +
                            " after " + Layout.PRUNE_GRACE + " missed scans")
        }
        if (migrating || settle.length > 0 || graceDropped) root._persistState()
        if (root._rescanQueued) { root._rescanQueued = false; Qt.callLater(root.rescan) }
    }

    // Copy-on-write: NEW objects with enabled/status applied. In-place
    // mutation of shared items caused a binding loop.
    function _applyStateToList(list) {
        var out = []
        for (var i = 0; i < list.length; i++) {
            var p = Object.assign({}, list[i])
            // invalid/shadowed never load. An errored plugin stays errored
            // while enabled; disabling it clears the error, re-enabling retries.
            if (p.status !== "invalid" && p.status !== "shadowed") {
                var v = root.enabledMap[p.id]
                p.enabled = v === true || (p.source === "builtin" && v !== false)
                if (!p.enabled) { p.status = "disabled"; p.error = "" }
                else if (p.status === "disabled") p.status = "ready"
            }
            out.push(p)
        }
        return out
    }

    function _applyEnabledFlags() {
        root.plugins = root._applyStateToList(root.plugins)
    }

    // Loaders report back. Idempotent: re-reporting an errored plugin must
    // NOT reassign the list (new identity → Repeater reset → reload → re-report
    // loop).
    function reportError(id, message) {
        for (var i = 0; i < root.plugins.length; i++) {
            var p = root.plugins[i]
            if (p.id !== id || p.status === "shadowed") continue
            if (p.status === "error") return
            var out = root.plugins.slice(0)
            out[i] = Object.assign({}, p, { status: "error", error: message })
            root.plugins = out
            console.log("[PluginRegistry] load error " + id + ": " + message)
            return
        }
    }

    // ── hot reload ──────────────────────────────────────────────────────────
    // id → rev. A bump changes the entry URL (?rev=N), so the plugin's slots
    // and loaders remount from disk without resetting the plugin list (and
    // PluginSlot keeps the old instance until the new one builds). The query
    // defeats the component cache for the ENTRY file only; sibling types it
    // instantiates stay cached until the bar restarts.
    property var revs: ({})

    function entryUrl(plugin, key) {
        var rev = root.revs[plugin.id] || 0
        return "file://" + plugin.dir + plugin.entryPoints[key] + (rev > 0 ? "?rev=" + rev : "")
    }

    function reload(id) {
        var p = root.plugin(id)
        if (!p) return "unknown plugin " + id
        var r = Object.assign({}, root.revs)
        r[id] = (r[id] || 0) + 1
        root.revs = r
        // An errored plugin isn't rendered at all; a reload is a retry.
        if (p.status === "error") {
            root.plugins = root.plugins.map(function(x) {
                return x === p ? Object.assign({}, x, { status: "ready", error: "" }) : x
            })
        }
        console.log("[PluginRegistry] reload " + id + " rev " + r[id])
        return "ok rev " + r[id]
    }

    // Zero-fork watchers on every enabled plugin's entry files + manifest
    // (system plugins are read-only — not watched). Edits are debounced; a
    // manifest edit rescans instead (kinds/entries/settings may have changed).
    readonly property var _watchList: {
        var out = []
        for (var i = 0; i < root.plugins.length; i++) {
            var p = root.plugins[i]
            if (!p.enabled || p.source === "system" || (p.status !== "ready" && p.status !== "error")) continue
            out.push({ id: p.id, path: p.dir + "manifest.json", manifest: true })
            for (var k in p.entryPoints) out.push({ id: p.id, path: p.dir + p.entryPoints[k], manifest: false })
        }
        return out
    }
    property var _dirtyIds: ({})
    property bool _dirtyManifest: false

    Instantiator {
        model: root._watchList
        delegate: FileView {
            id: watcher
            required property var modelData
            path: modelData.path
            watchChanges: true
            printErrors: false
            onFileChanged: {
                // Re-arm: editors that save by rename replace the inode.
                watcher.reload()
                if (modelData.manifest) root._dirtyManifest = true
                else { var d = Object.assign({}, root._dirtyIds); d[modelData.id] = true; root._dirtyIds = d }
                reloadDebounce.restart()
            }
        }
    }
    Timer {
        id: reloadDebounce
        interval: 250
        onTriggered: {
            var ids = Object.keys(root._dirtyIds)
            root._dirtyIds = ({})
            for (var i = 0; i < ids.length; i++) root.reload(ids[i])
            if (root._dirtyManifest) { root._dirtyManifest = false; root.rescan() }
        }
    }

    // ── ctx + settings ───────────────────────────────────────────────────────
    Component { id: contextComponent; PluginContext { } }
    Component { id: storeComponent; SettingsStore { } }

    // One SettingsStore per plugin id, shared by all its instances.
    property var _stores: ({})
    function settingsFor(plugin) {
        var s = root._stores[plugin.id]
        if (!s) {
            s = storeComponent.createObject(root, {
                pluginId: plugin.id,
                schema: plugin.settings || {},
                path: root.stateHome + "/velocity/plugins/" + plugin.id + ".json"
            })
            var next = Object.assign({}, root._stores)
            next[plugin.id] = s
            root._stores = next
        } else {
            s.schema = plugin.settings || {}   // manifest may have changed on rescan
        }
        return s
    }

    // Settings over IPC (settings app, CLI): through the plugin's one store,
    // so the bar stays the only writer of its file.
    function settingsJson(id) {
        var p = root.plugin(id)
        if (!p) return JSON.stringify({ error: "unknown plugin " + id })
        return JSON.stringify({ schema: p.settings || {}, values: root.settingsFor(p).values })
    }
    function setSetting(id, key, valueJson) {
        var p = root.plugin(id)
        if (!p) return "unknown plugin " + id
        var v
        try { v = JSON.parse(valueJson) } catch (e) { return "value must be JSON (strings quoted)" }
        return root.settingsFor(p).set(key, v) ? "ok" : "rejected by the manifest schema (see journal)"
    }

    // A context per mounted instance, parented to it (destroyed with it).
    function _contextFor(plugin, item, window) {
        return contextComponent.createObject(item, {
            pluginId: plugin.id,
            dir: plugin.dir,
            manifest: plugin,
            window: window || null,
            theme: root.hostApi.theme || null,
            bar: root.hostApi.bar || null,
            osd: root.hostApi.osd || null,
            events: root.events,
            settings: root.settingsFor(plugin),
            host: plugin.source === "builtin" ? (root.hostApi.shell || null) : null
        })
    }

    // ── instances ────────────────────────────────────────────────────────────
    // id → [{ item, kind, window }] — one entry per mounted root per output.
    property var instances: ({})

    // Mount point contract: every Loader/PluginSlot hands the loaded root
    // here. Injection is guarded (`in`): assigning an undeclared property
    // throws, and plugin roots declare only what they use.
    function mount(item, plugin, kind, window) {
        if (!item || !plugin) return
        if ("pluginId" in item) item.pluginId = plugin.id
        if ("manifest" in item) item.manifest = plugin
        if ("ctx" in item) item.ctx = root._contextFor(plugin, item, window)
        var list = (root.instances[plugin.id] || []).filter(function(e) { return e.item && e.item !== item })
        list.push({ item: item, kind: kind, window: window || null })
        var reg = root.instances
        reg[plugin.id] = list
        root.instances = reg
    }

    function unmount(id, item) {
        var reg = root.instances
        if (!reg[id]) return
        // Destroyed objects read as null — prune those along with this one.
        var list = reg[id].filter(function(e) { return e.item && e.item !== item })
        if (list.length > 0) reg[id] = list
        else delete reg[id]
        root.instances = reg
    }

    // The live instance of `kind` ("" = any) on the focused monitor, else
    // the first one.
    function instance(id, kind) {
        var list = (root.instances[id] || []).filter(function(e) {
            return !!e.item && (!kind || e.kind === kind)
        })
        if (list.length === 0) return null
        var focused = typeof root.hostApi.focusedMonitor === "function" ? root.hostApi.focusedMonitor() : ""
        for (var i = 0; i < list.length; i++) {
            var w = list[i].window
            if (focused !== "" && w && w.screen && w.screen.name === focused) return list[i].item
        }
        return list[0].item
    }

    // The plugin's one headless service root (entryPoints.service or kind
    // "service"), or null until it mounts. Reads `instances`, so bindings
    // on it re-evaluate when the root appears/disappears (ctx.service).
    function serviceFor(id) {
        var list = root.instances[id] || []
        for (var i = 0; i < list.length; i++)
            if (list[i].kind === "service" && list[i].item) return list[i].item
        return null
    }

    // One verb for widget panels AND overlays. Dual-kind plugins (xray:
    // overlay + bar-widget) register both — a widget without open() must not
    // shadow the overlay.
    function summon(id, payloadJson) {
        var w = root.instance(id, "bar-widget")
        if (w && typeof w.open === "function") { w.open(); return "ok" }
        var ov = root.instance(id, "overlay")
        if (ov) {
            if (typeof ov.open === "function") { ov.open(payloadJson || "{}"); return "ok" }
            if (typeof ov.toggle === "function") { ov.toggle(payloadJson || "{}"); return "ok" }
            return "no open()"
        }
        return "not loaded"
    }

    function hide(id) {
        var w = root.instance(id, "bar-widget")
        if (w && typeof w.close === "function") { w.close(); return "ok" }
        var ov = root.instance(id, "overlay")
        if (ov) {
            if (typeof ov.close === "function") { ov.close(); return "ok" }
            return "no close()"
        }
        return "not loaded"
    }

    // Plugin-declared IPC: `verb` must be listed in manifest.ipc and be a
    // function on one of the plugin's roots (widget, then service, then
    // overlay). `arg` is passed through as a string.
    function call(id, verb, arg) {
        var p = root.plugin(id)
        if (!p) return "unknown plugin " + id
        if (p.ipc.indexOf(verb) === -1) return "verb '" + verb + "' not declared in " + id + " manifest.ipc"
        var kinds = ["bar-widget", "service", "overlay"]
        for (var k = 0; k < kinds.length; k++) {
            var it = root.instance(id, kinds[k])
            if (it && typeof it[verb] === "function") {
                var res = it[verb](arg === undefined ? "" : String(arg))
                return res === undefined || res === null ? "ok" : String(res)
            }
        }
        return "not loaded"
    }
}
