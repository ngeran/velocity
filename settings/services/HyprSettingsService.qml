// =============================================================================
// HyprSettingsService.qml — DESKTOP tab: Hyprland look-and-feel controller
// =============================================================================
// Owns the blur/shadow/gaps/border/rounding/opacity settings (the catalog and
// all pure logic live in ../lib/hyprsettings.mjs — testable outside QML).
//
// WRITE MODEL (the omasettings invariants, on velocity's terms):
//   Read before write — the first write of a key records the live value in
//   `originals`; "changed" means the override now differs from that original,
//   so flip-and-flip-back leaves no mark. Reset deletes the override and evals
//   the original back, so your own config answers again with no reload.
//
// PERSISTENCE — overrides render into ~/.config/hypr/velocity-settings.lua
//   (generated wholly by us, created on the FIRST write — never at startup).
//   hyprland.lua gets one appended require line, backed up once first
//   (.velocity.bak, exclusive create). Loading after omasettings.lua means a
//   key we both set resolves per-property in our favour, like a hand edit at
//   the foot of the file would.
//
// APPLY — `hyprctl eval "hl.config({...})"`, the form MonitorService and the
//   bar's theme-border sync already prove live. `hyprctl keyword` is refused
//   by the Lua parser (stderr, exit 0 — looks applied, does nothing).
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io
import "../lib/hyprsettings.mjs" as Hypr

Item {
    id: root

    // ── state ───────────────────────────────────────────────────────────
    // overrides: { key: value } we have written (renders to the managed file)
    // originals: { key: value } found live before our first write of that key
    // live:      { key: value } read back from Hyprland just now
    property var overrides: ({})
    property var originals: ({})
    property var live: ({})

    // True once one successful read landed — rows show "…" until then rather
    // than the catalog fallbacks (round numbers that were never real).
    readonly property bool loaded: Object.keys(live).length > 0

    // Surfaces apply/read failures in the pane footer; cleared on next success.
    property string lastError: ""

    // Poll gate — the DESKTOP pane sets this while it is on screen.
    property bool watching: false

    readonly property int changedCount: Hypr.changedKeys(overrides, originals).length

    function effective(key) {
        if (overrides[key] !== undefined) return overrides[key]
        return live[key]
    }

    function isChanged(key) {
        return Hypr.isChanged(overrides, originals, key)
    }

    // Catalog entry for a key — the pane renders rows straight from it.
    function def(key) {
        return Hypr.settingFor(key)
    }

    // ── paths ───────────────────────────────────────────────────────────
    readonly property string homeDir: ("" + StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "")
    readonly property string configDir: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "")
    readonly property string storePath: configDir + "/quickshell/hypr-settings.json"
    readonly property string hyprDir: homeDir + "/.config/hypr"
    readonly property string managedPath: hyprDir + "/velocity-settings.lua"
    readonly property string hyprlandPath: hyprDir + "/hyprland.lua"
    readonly property string requireLine: "require(\"hypr.velocity-settings\")"

    // ── live read — one batched call for the whole catalog ──────────────
    // Each answer arrives as its own JSON line; a failed getoption (keyword
    // gone in some future Hyprland) prints a non-JSON line and is skipped,
    // leaving that key undefined ("…" in the UI) instead of a fake value.
    Process {   // unbounded-ok: one-shot local IPC query — answers in ms; timeout migration queued
        id: readProc
        command: ["hyprctl", "-j", "--batch", Hypr.batchArg(Hypr.CATALOG.map(function(d) { return d.keyword }))]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { readProc.buffer += data + "\n" }
        }
        onStarted: buffer = ""
        onRunningChanged: {
            if (running) return
            var answers = {}
            var lines = buffer.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (line.length === 0 || line.charAt(0) !== "{") continue
                try {
                    var doc = JSON.parse(line)
                    if (doc.option !== undefined) answers[doc.option] = doc
                } catch (e) { /* non-JSON answer line — skip */ }
            }
            var next = {}
            for (var j = 0; j < Hypr.CATALOG.length; j++) {
                var def = Hypr.CATALOG[j]
                var v = Hypr.valueFromAnswer(answers[def.keyword], def.type)
                if (v !== undefined) next[def.key] = v
            }
            if (Object.keys(next).length > 0) {
                root.live = next
                root.lastError = ""
            } else {
                root.lastError = "Hyprland answered nothing — is it running?"
            }
            buffer = ""
        }
    }

    function refresh() {
        if (!readProc.running) readProc.running = true
    }

    Timer {
        interval: 15000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ── writes ──────────────────────────────────────────────────────────
    function set(key, value) {
        var def = Hypr.settingFor(key)
        if (!def) return
        if (def.type === "bool" && typeof value !== "boolean") return
        if (def.choices && def.choices.indexOf(value) === -1) return

        // Read the original BEFORE the write — recorded after, it would be
        // the value this write just created.
        var nextOriginals = shallowCopy(originals)
        if (nextOriginals[key] === undefined && live[key] !== undefined)
            nextOriginals[key] = live[key]
        var nextOverrides = shallowCopy(overrides)
        nextOverrides[key] = value

        originals = nextOriginals
        overrides = nextOverrides
        persist()
        renderManaged()
        applyLive([{ keyword: def.keyword, value: value }])
        refresh()
    }

    function reset(key) {
        var def = Hypr.settingFor(key)
        if (!def || overrides[key] === undefined) return
        var nextOverrides = shallowCopy(overrides)
        delete nextOverrides[key]
        overrides = nextOverrides
        persist()
        renderManaged()
        // Hand the original back live so the screen matches the files again.
        if (originals[key] !== undefined)
            applyLive([{ keyword: def.keyword, value: originals[key] }])
        refresh()
    }

    function resetAll() {
        // One eval restores every original at once — no cascade of writes.
        var pairs = []
        for (var key in originals) {
            if (!Object.prototype.hasOwnProperty.call(originals, key)) continue
            var def = Hypr.settingFor(key)
            if (def) pairs.push({ keyword: def.keyword, value: originals[key] })
        }
        overrides = {}
        persist()
        renderManaged()
        if (pairs.length > 0) applyLive(pairs)
        refresh()
    }

    // ── live apply ──────────────────────────────────────────────────────
    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: applyProc
        command: []
        property string buffer: ""
        // Two pills inside one eval's lifetime would drop the second write —
        // hold it and send when the process frees up.
        property var queued: null
        stdout: SplitParser {
            onRead: function(data) { applyProc.buffer += data + "\n" }
        }
        onStarted: buffer = ""
        onRunningChanged: {
            if (running) return
            // hyprctl eval answers "ok" or "error: …" on stdout.
            if (buffer.indexOf("error") !== -1)
                root.lastError = "Hyprland refused the change: " + buffer.trim()
            else
                root.lastError = ""
            buffer = ""
            if (queued) {
                var next = queued
                queued = null
                _send(next)
            }
        }
    }

    function applyLive(pairs) {
        if (applyProc.running) {
            applyProc.queued = pairs
            return
        }
        _send(pairs)
    }

    function _send(pairs) {
        applyProc.command = ["hyprctl", "eval", Hypr.evalCall(pairs)]
        applyProc.running = true
    }

    // ── persistence ─────────────────────────────────────────────────────
    function persist() {
        ThemeService._atomicWrite(storePath, JSON.stringify({
            schemaVersion: 1,
            overrides: overrides,
            originals: originals
        }, null, 2))
    }

    // Rendered from the store on every write — cheap, and the file can never
    // drift from what the window believes.
    function renderManaged() {
        ensureRequireLine(function() {
            ThemeService._atomicWrite(managedPath, Hypr.renderManagedLua(overrides))
        })
    }

    // Append the require line to hyprland.lua once. Runs on the FIRST managed
    // write, not at startup — a user who never touches the DESKTOP pane keeps
    // a byte-identical hyprland.lua. The backup is an exclusive create: the
    // pristine pre-velocity copy is never overwritten by later writes.
    function ensureRequireLine(onReady) {
        var script =
            "H=" + JSON.stringify(hyprlandPath) + "\n" +
            "grep -qF " + JSON.stringify(requireLine) + " \"$H\" 2>/dev/null && exit 0\n" +
            "[ -f \"$H\" ] || exit 1\n" +
            "[ -e \"$H.velocity.bak\" ] || ln \"$H\" \"$H.velocity.bak\" 2>/dev/null\n" +
            "printf '\\n-- Velocity settings (velocity-settings:managed) — values from the velocity settings window.\\n' >> \"$H\"\n" +
            "printf '%s\\n' " + JSON.stringify(requireLine) + " >> \"$H\"\n"
        ensureProc.pendingReady = onReady
        ensureProc.command = ["sh", "-c", script]
        ensureProc.running = true
    }

    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: ensureProc
        command: []
        property var pendingReady: null
        onRunningChanged: {
            if (!running && pendingReady) {
                var cb = pendingReady
                pendingReady = null
                cb()
            }
        }
    }

    // ── store load ──────────────────────────────────────────────────────
    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: loadProc
        command: []
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { loadProc.buffer += data + "\n" }
        }
        onStarted: buffer = ""
        onRunningChanged: {
            if (running || buffer.trim().length === 0) return
            try {
                var valid = Hypr.validStore(JSON.parse(buffer))
                root.overrides = valid.overrides
                root.originals = valid.originals
            } catch (e) {
                console.log("[HyprSettingsService] store unreadable, starting clean:", e)
            }
            buffer = ""
        }
    }

    function shallowCopy(obj) {
        var out = {}
        for (var k in obj)
            if (Object.prototype.hasOwnProperty.call(obj, k)) out[k] = obj[k]
        return out
    }

    Component.onCompleted: {
        loadProc.command = ["cat", storePath]
        loadProc.running = true
        refresh()
    }
}
