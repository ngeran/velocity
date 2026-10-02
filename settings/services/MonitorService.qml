// =============================================================================
// MonitorService.qml — monitor topology + LIVE display controller
// =============================================================================
// Polls `hyprctl monitors -j` and exposes a structured `monitors[]`, and applies
// live output changes for the Display section.
//
// APPLY MECHANISM (verified 2026-08-29 by trial, see git history):
//   `hyprctl eval "hl.monitor({ ... })"` with a FULL rule — mode / scale /
//   bitdepth / vrr / cm / sdr* all apply live (cm hdr ⇄ srgb, 8 ⇄ 10-bit,
//   60 ⇄ 119.88 Hz, sdrbrightness all proven by readback). Two dead ends:
//   `hyprctl keyword` is refused by the Lua parser and `hyprctl output` is a
//   no-op echo (accepts bogus props with "ok"). A full rule must always be
//   sent — a partial hl.monitor would reset the omitted attrs.
//
// CABLE-PROOF RULES (verified 2026-09-30 live: desc-keyed eval → ok + readback):
//   Every rule is keyed `output = 'desc:<EDID description>'`, not by connector
//   name — the name (HDMI-A-1) changes when the cable moves ports; the desc
//   follows the physical display. EXCEPTION (twin-EDID guard): two live units
//   sharing one desc would both be driven by the same rule — those fall back
//   to port-name keys (unique but cable-fragile) and the UI warns.
//   Reload reverts eval'd values to the config
//   file → persistence goes through stageToNix(): it splices a velocity-managed
//   block into ~/.config/hypr/monitors.lua (omarchy's file — everything outside
//   the markers is untouched), one FULL desc-keyed rule per display. Rules for
//   currently-absent displays are PRESERVED on re-stage (remember-absent): the
//   file accumulates one rule per display ever staged, and Hyprland — which
//   auto-reloads on save — re-applies a rule whenever that display reappears
//   on any port. Stage pipeline: first-touch backup (monitors.lua.velocity-bak,
//   never overwritten) → atomic write → `hyprctl configerrors` validation →
//   restore on failure.
//
// monitors[] entry:
//   { name, desc, make, model, w, h, refreshHz, scale, vrr, dpms, transform,
//     format, colorPreset, sdrBrightness, sdrSaturation, sdrMinLuminance,
//     sdrMaxLuminance, x, y, physW, physH, modes: [{w,h,hz}] }
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io
import "../config" as Config

Item {
    id: root
    visible: false

    property var monitors: []
    // The monitor poll is async — recompute the persist state whenever live
    // values land (the seed-time call runs before `primary` exists).
    onMonitorsChanged: _recomputePersistState()

    // The focused monitor (fallback: the first). Drives the control cards.
    readonly property var primary: {
        var ms = root.monitors
        for (var i = 0; i < ms.length; i++) if (ms[i].focused) return ms[i]
        return ms.length > 0 ? ms[0] : null
    }

    // Selection — which monitor the Display controls target ("" = focused).
    // The arrangement canvas sets this by clicking a tile.
    property string selectedName: ""
    readonly property var target: {
        var ms = root.monitors
        if (root.selectedName !== "")
            for (var i = 0; i < ms.length; i++)
                if (ms[i].name === root.selectedName) return ms[i]
        return root.primary
    }

    // IDENTIFY — flash every monitor's name via a batched hyprctl notify
    // (omarchy-screens pattern, minus its python driver).
    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: identifyProc
        command: []; running: false
    }

    function identify() {
        var parts = []
        var ms = root.monitors
        for (var i = 0; i < ms.length; i++) {
            var label = ((ms[i].make + " " + ms[i].model).trim() || ms[i].desc || "Display")
            parts.push("notify -1 4000 \"rgb(bb9af7)\" " + ms[i].name + " · " + label)
        }
        if (parts.length === 0) return
        identifyProc.command = ["hyprctl", "--batch", parts.join("; ")]
        identifyProc.running = true
    }

    // ── capability (proven on this box: MPG321UX QD-OLED) ──────────────────
    readonly property bool hdrCapable: true   // cm hdr ⇄ srgb flips live
    readonly property bool vrrCapable: true   // EDID HDMI-Forum VSDB present

    // ── config-state not visible in monitors -j ────────────────────────────
    // vrr active-bool reads false on the desktop when vrr=2 (fullscreen), so
    // the CONFIGURED mode is tracked here, seeded from the nix source.
    property int vrrMode: 2
    property int cmAutoHdr: 0        // render.cm_auto_hdr global (HDR "Auto")

    // ── Keep/Revert window for risky changes (mode/scale) ──────────────────
    // { rule: string, deadline: ms, label: string } | null
    property var pendingRevert: null
    readonly property bool revertPending: pendingRevert !== null
    readonly property real revertSecondsLeft: pendingRevert
        ? Math.max(0, Math.ceil((pendingRevert.deadline - Date.now()) / 1000)) : 0

    // ── persistence state: live values vs the staged desc-keyed rules ──────
    // "dirty" = some live display has no staged rule, or its staged
    //           mode/scale/bitdepth/vrr differ (a reload would drop them —
    //           stage!). See the STORE section for the block format.
    property string persistState: "clean"

    // -------------------------------------------------------------------------
    // POLL — hyprctl monitors -j (JSON). 10s while the dashboard is open; also
    // refreshed after every applied rule (readback verification).
    // -------------------------------------------------------------------------
    Process {   // unbounded-ok: one-shot local IPC query — answers in ms; timeout migration queued
        id: monProc
        command: ["hyprctl", "monitors", "-j"]
        property string buffer: ""
        property bool stale: false   // an apply landed while this poll was in flight
        stdout: SplitParser { onRead: function(data) { monProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                // Stale-poll guard (hyprmoncfg pattern): a poll that started
                // BEFORE a rule applied carries pre-apply readback — discarding
                // it and re-reading beats letting persistState/transiently lie.
                if (monProc.stale) {
                    monProc.stale = false
                    monProc.buffer = ""   // discard wholesale — leftover JSON would concatenate into the next read
                    root.refresh()
                    return
                }
                var arr = root._parseMonitors(monProc.buffer)
                monProc.buffer = ""
                // Topology signature: an identical readback (the common 10s
                // case) must not churn the model + every binding attached to it.
                var sig = JSON.stringify(arr)
                if (sig !== root._monSig) {
                    root._monSig = sig
                    root.monitors = arr
                }
                root._recomputeDescCollisions(arr)
            }
        }
    }

    // JSON of the last parsed topology — the churn guard above.
    property string _monSig: ""

    Timer {
        interval: 10000
        running: Config.SharedState.dashboardVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!monProc.running) monProc.running = true }
    }

    // Counts down the Keep/Revert window even if the UI misses a tick.
    Timer {
        interval: 250
        running: root.revertPending
        repeat: true
        onTriggered: {
            if (!root.revertPending) return
            if (Date.now() >= root.pendingRevert.deadline) root.revertNow()
        }
    }

    function refresh() {
        if (monProc.running) {
            monProc.stale = true   // in-flight poll predates whatever just changed
            return
        }
        monProc.running = true
    }

    // ── TWIN-EDID GUARD ─────────────────────────────────────────────────────
    // Two identical displays share one EDID desc — a desc-keyed rule would
    // drive BOTH units. Those fall back to the port name (unique, but
    // cable-fragile); the UI warns. Unique descs stay desc-keyed.
    property var _descCollision: ({})
    readonly property bool identityCollided: Object.keys(_descCollision).length > 0

    function _recomputeDescCollisions(arr) {
        var counts = {}, dup = {}
        for (var i = 0; i < arr.length; i++)
            counts[arr[i].desc] = (counts[arr[i].desc] || 0) + 1
        for (var d in counts) if (counts[d] > 1) dup[d] = true
        root._descCollision = dup
    }

    // The store key a display is addressed by.
    function _outputKeyFor(p) {
        return root._descCollision[p.desc] ? p.name : "desc:" + p.desc
    }

    // Synthetic-data proof of the wiring (no dual-monitor hardware needed):
    // display.selftest IPC asserts collision detection, keying, rule output
    // and stored-rule matching against a fake topology.
    function selfTest() {
        var fails = []
        var base = { scale: 1, format: "XRGB8888", refreshHz: 60, w: 1920, h: 1080,
                     x: 0, y: 0, transform: 0, colorPreset: "", sdrBrightness: 1,
                     sdrSaturation: 1, sdrMinLuminance: 0.2, sdrMaxLuminance: 80 }
        var twin = function(name) {
            var o = JSON.parse(JSON.stringify(base)); o.name = name
            o.desc = "Same Corp SameScreen 111"; return o
        }
        var fake = [twin("DP-1"), twin("DP-2"),
                    JSON.parse(JSON.stringify(base))]
        fake[2].name = "HDMI-A-1"; fake[2].desc = "Other Corp OtherScreen 222"

        root._recomputeDescCollisions(fake)
        if (!root._descCollision["Same Corp SameScreen 111"]) fails.push("collision not detected")
        if (root._descCollision["Other Corp OtherScreen 222"]) fails.push("false collision")
        if (root._outputKeyFor(fake[0]) !== "DP-1") fails.push("twin not name-keyed")
        if (root._outputKeyFor(fake[2]) !== "desc:Other Corp OtherScreen 222") fails.push("unique not desc-keyed")
        if (root.ruleFor(fake[0], {}).indexOf("output = 'DP-1'") === -1) fails.push("twin rule not name-keyed")
        if (root.ruleFor(fake[2], {}).indexOf("output = 'desc:Other Corp OtherScreen 222'") === -1) fails.push("unique rule not desc-keyed")
        if (root._ruleOut(root.ruleFor(fake[0], {})) !== "DP-1") fails.push("_ruleOut name")
        if (root._ruleOut(root.ruleFor(fake[2], {})) !== "desc:Other Corp OtherScreen 222") fails.push("_ruleOut desc")
        // a stored twin rule must match its unit by NAME, not by desc
        var storedLine = "hl.monitor({ output = 'DP-2', mode = '1920x1080@60', position = '0x0', scale = 1, bitdepth = 8, vrr = 2 })"
        if (root._ruleOut(storedLine) !== "DP-2") fails.push("stored name rule unparsed")
        if (root._ruleDesc(storedLine) !== "") fails.push("name rule misread as desc-keyed")

        root._recomputeDescCollisions(root.monitors)   // restore the live topology
        return fails.length === 0 ? "PASS" : "FAIL: " + fails.join("; ")
    }

    // -------------------------------------------------------------------------
    // RULE BUILDER — full hl.monitor rule from live state + overrides
    // -------------------------------------------------------------------------
    // over: { mode, scale, bitdepth, vrr, cm, sdrbrightness, sdrsaturation,
    //         sdr_min_luminance, sdr_max_luminance }  (undefined = keep live)
    // Keyed by `desc:` — see the header. ruleFor() builds for any monitor;
    // ruleString() targets the selection.
    function currentModeStringFor(p) {
        if (!p) return "preferred"
        // Trim trailing zeros: 119.88 stays, 60.00 → 60
        var hz = String(parseFloat(p.refreshHz.toFixed(2)))
        return p.w + "x" + p.h + "@" + hz
    }

    function currentModeString() { return currentModeStringFor(target) }

    function _bitdepthOf(p) {
        if (!p) return 10
        // XBGR2101010/ARGB2101010 → 10-bit; XRGB8888/ARGB8888 → 8-bit
        return (p.format.indexOf("2101010") !== -1 || p.format.indexOf("101010") !== -1) ? 10 : 8
    }

    function liveBitdepth() { return _bitdepthOf(target) }

    function ruleFor(p, over) {
        if (!p) return ""
        var o = over || {}
        var mode = o.mode !== undefined ? o.mode : currentModeStringFor(p)
        var scale = o.scale !== undefined ? o.scale : p.scale
        var bd = o.bitdepth !== undefined ? o.bitdepth : _bitdepthOf(p)
        var vrr = o.vrr !== undefined ? o.vrr : vrrMode
        var pos = p.x + "x" + p.y
        var s = "hl.monitor({ output = '" + root._outputKeyFor(p) + "', mode = '" + mode
              + "', position = '" + pos + "', scale = " + scale
              + ", bitdepth = " + bd + ", vrr = " + vrr
        // transform only when rotated (or explicitly requested) — never emit
        // a zero transform that could surprise an untested attr path.
        var tf = o.transform !== undefined ? o.transform : p.transform
        if (tf !== 0) s += ", transform = " + tf
        // cm + SDR tune attrs only when HDR is live (or explicitly requested) —
        // matches the plugin's emission rules and keeps SDR minimal.
        var cm = o.cm !== undefined ? o.cm : p.colorPreset
        if (cm && cm !== "" && cm !== "srgb") s += ", cm = '" + cm + "'"
        var sb = o.sdrbrightness !== undefined ? o.sdrbrightness : (p.sdrBrightness || 1)
        var ss = o.sdrsaturation !== undefined ? o.sdrsaturation : (p.sdrSaturation || 1)
        var smin = o.sdr_min_luminance !== undefined ? o.sdr_min_luminance : (p.sdrMinLuminance || 0.2)
        var smax = o.sdr_max_luminance !== undefined ? o.sdr_max_luminance : (p.sdrMaxLuminance || 80)
        if (cm && cm !== "" && cm !== "srgb") {
            s += ", sdrbrightness = " + sb + ", sdrsaturation = " + ss
              + ", sdr_min_luminance = " + smin + ", sdr_max_luminance = " + smax
        }
        return s + " })"
    }

    // -------------------------------------------------------------------------
    // APPLY — single-flight rule Process with a trailing-write queue (sliders
    // can outpace hyprctl; the last requested rule always lands).
    // -------------------------------------------------------------------------
    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: ruleProc
        command: []; running: false
        property string queued: ""
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { ruleProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                if (ruleProc.buffer.indexOf("ok") === -1)
                    CommandService.pushLog("[display] rule apply failed: " + ruleProc.buffer, "error")
                ruleProc.buffer = ""
                if (ruleProc.queued !== "") {
                    var next = ruleProc.queued
                    ruleProc.queued = ""
                    root._runRule(next)
                } else {
                    root.refresh()
                    root._recomputePersistState()
                }
            }
        }
    }

    function _runRule(rule) {
        ruleProc.command = ["hyprctl", "eval", rule]
        ruleProc.running = true
    }

    function applyRule(over) {
        var rule = ruleString(over)
        if (rule === "") return
        if (ruleProc.running) { ruleProc.queued = rule; return }
        _runRule(rule)
    }

    // Global (non-monitor) config, e.g. render.cm_auto_hdr for HDR "Auto".
    // Same eval mechanism; not queued behind ruleProc (independent target).
    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: globalProc
        command: []; running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { globalProc.buffer += data + "\n" } }
        onRunningChanged: if (!running) {
            if (globalProc.buffer.indexOf("ok") === -1)
                CommandService.pushLog("[display] global apply failed: " + globalProc.buffer, "error")
            globalProc.buffer = ""
        }
    }

    function applyGlobalConfig(expr) {
        globalProc.command = ["hyprctl", "eval", expr]
        globalProc.running = true
    }

    // Risky change (mode/scale): snapshot the CURRENT rule first, apply, then
    // open the 10s Keep/Revert window. confirmKeep() closes it; revertNow()
    // re-issues the snapshot.
    function applyWithRevert(label, over) {
        var before = ruleString({})
        applyRule(over)
        pendingRevert = { rule: before, deadline: Date.now() + 10000, label: label }
    }

    function confirmKeep() { pendingRevert = null }

    function revertNow() {
        var pr = pendingRevert
        pendingRevert = null
        if (!pr) return
        _runRule(pr.rule)
    }

    // -------------------------------------------------------------------------
    // DPMS — proven verb pair from HypridleService (hl.dsp.dpms enable/disable)
    // -------------------------------------------------------------------------
    Process {   // unbounded-ok: one-shot local IPC query — answers in ms; timeout migration queued
        id: dpmsProc
        command: []; running: false
        onRunningChanged: if (!running) Qt.callLater(root.refresh)
    }

    function setDpms(on) {
        dpmsProc.command = ["hyprctl", "dispatch",
            "hl.dsp.dpms({ action = \"" + (on ? "enable" : "disable") + "\" })"]
        dpmsProc.running = true
    }

    // -------------------------------------------------------------------------
    // STORE — ~/.config/hypr/monitors.lua (omarchy's file, required by
    // hyprland.lua; Hyprland auto-reloads it on save). Velocity owns ONLY the
    // marked block: one FULL desc-keyed rule per display ever staged — rules
    // for currently-absent displays stay put (remember-absent), so a replug
    // on any port re-applies automatically. Everything outside the markers is
    // never read or rewritten.
    // -------------------------------------------------------------------------
    readonly property string hyprDir: ("" + StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "") + "/.config/hypr"
    readonly property string storePath: hyprDir + "/monitors.lua"
    readonly property string blockBegin: "-- BEGIN velocity-managed (desc-keyed display rules; the velocity Display panel re-stages this block)"
    readonly property string blockEnd: "-- END velocity-managed"

    // The whole file text (FileView) — persist state parses the block out of it.
    property string storeText: ""

    FileView {
        id: storeFile
        path: root.storePath
        watchChanges: true
        printErrors: false

        // The ThemeConfig colors.json pattern (proven against the async-reload
        // staleness — a synchronous text() right after reload() returns the
        // stale cache): instant ingest on same-inode changes, ingest from
        // textChanged for async reload completions, blocking read at startup.
        onFileChanged: root._ingestStore(storeFile.text())
        onTextChanged: root._ingestStore(text())

        Component.onCompleted: root._ingestStore(storeFile.text())
    }

    // Safety poll for tmp+mv inode swaps (our own stage writes replace the
    // file) — reload() re-reads by path in C++. Zero forks, cheap text.
    Timer {
        id: storePoller
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            storeFile.reload()
            root._ingestStore(storeFile.text())
        }
    }

    function _ingestStore(t) {
        var s = String(t || "")
        if (s === storeText) return   // idempotent for the poller
        storeText = s
        _seedFromStore()
    }

    // cmAutoHdr lives in the look-and-feel render block, not monitors.lua.
    FileView {
        id: lookFile
        path: root.hyprDir + "/looknfeel.lua"
        watchChanges: false
        onLoaded: {
            var m = /cm_auto_hdr\s*=\s*(\d)/.exec(text())
            if (m) root.cmAutoHdr = parseInt(m[1], 10)
        }
    }

    Component.onCompleted: lookFile.reload()   // storeFile reads itself at startup

    function _managedInner(text) {
        var b = text.indexOf(root.blockBegin)
        if (b === -1) return ""
        var e = text.indexOf(root.blockEnd, b)
        if (e === -1) return ""
        return text.substring(b + root.blockBegin.length, e)
    }

    // Staged rules: one hl.monitor({...}) line per desc, in stage order.
    function _storedRules(inner) {
        var lines = inner.split("\n"), out = []
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (l.indexOf("hl.monitor({") === 0 && l.indexOf("desc:") !== -1)
                out.push(l)
        }
        return out
    }

    function _ruleDesc(ruleLine) {
        var m = /output = 'desc:([^']*)'/.exec(ruleLine)
        return m ? m[1] : ""
    }

    // The full output token a stored rule addresses: 'desc:…' or a port name
    // (twin-EDID fallback). Matching is by token, never by desc alone.
    function _ruleOut(ruleLine) {
        var m = /output = '([^']*)'/.exec(ruleLine)
        return m ? m[1] : ""
    }

    function _storedAttr(ruleLine, name) {
        // attr values come in both quote styles (mode/cm single-quoted, the
        // omarchy template uses double quotes) — strip either.
        var re = new RegExp("\\b" + name + "\\s*=\\s*['\"]?([^'\",}]*)['\"]?")
        var m = re.exec(ruleLine)
        return m ? String(m[1]).trim() : ""
    }

    // Seeds vrrMode (the configured value) from the target's staged rule.
    function _seedFromStore() {
        var inner = _managedInner(storeText)
        var stored = _storedRules(inner)
        var p = primary
        var want = p ? root._outputKeyFor(p) : ""
        for (var i = 0; i < stored.length; i++) {
            if (want !== "" && _ruleOut(stored[i]) !== want) continue
            var m = /vrr\s*=\s*(\d)/.exec(stored[i])
            if (m) { vrrMode = parseInt(m[1], 10); break }
        }
        _recomputePersistState()
    }

    // "dirty" when any LIVE display's rule is missing from the block or its
    // mode/scale/bitdepth/vrr differ from live. (cm/sdr* intentionally
    // ignored: SDR defaults differ per display and staging keeps them too.)
    function _recomputePersistState() {
        var ms = root.monitors
        if (ms.length === 0) return
        var stored = _storedRules(_managedInner(storeText))
        for (var i = 0; i < ms.length; i++) {
            var m = ms[i]
            var rule = ""
            for (var j = 0; j < stored.length; j++)
                if (_ruleOut(stored[j]) === root._outputKeyFor(m)) { rule = stored[j]; break }
            if (rule === "" || _storedAttr(rule, "mode") !== _trimModeHz(currentModeStringFor(m)) ||
                _storedAttr(rule, "scale") !== String(m.scale) ||
                _storedAttr(rule, "bitdepth") !== String(_bitdepthOf(m)) ||
                _storedAttr(rule, "vrr") !== String(vrrMode)) {
                persistState = "dirty"
                return
            }
        }
        persistState = "clean"
    }

    // "3840x2160@240" vs live "3840x2160@119.88" — compare via parseFloat so
    // 60.00 == 60.
    function _trimModeHz(mode) {
        var m = /^(\d+x\d+)@([\d.]+)$/.exec(mode)
        if (!m) return mode
        return m[1] + "@" + String(parseFloat(m[2]))
    }

    // -------------------------------------------------------------------------
    // STAGE — splice the managed block (fresh rule per live display, preserved
    // rules for absent ones) into monitors.lua. Pipeline: backup-once → atomic
    // write → Hyprland auto-reload → configerrors validation → restore on
    // failure. (The stage button's "apply" half is Hyprland's reload itself.)
    // -------------------------------------------------------------------------
    property string _preStageText: ""   // file text before the splice, for restore

    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: stageProc
        command: []; running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { stageProc.buffer += data + "\n" } }
        onRunningChanged: if (!running) {
            var out = stageProc.buffer.trim()
            stageProc.buffer = ""
            if (out === "WROTE") root._validateStage()
            else CommandService.pushLog("[display] stage write failed: " + out, "error")
        }
    }

    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: validateProc
        command: []; running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { validateProc.buffer += data + "\n" } }
        onRunningChanged: if (!running) {
            var out = validateProc.buffer.trim()
            validateProc.buffer = ""
            if (out === "ok" || out === "")
                root._stageDone()
            else
                root._stageRestore("[display] configerrors after stage — restored: " + out)
        }
    }

    // Hyprland reloads the file asynchronously; give it a beat before asking.
    Timer { id: validateDelay; interval: 600; onTriggered: validateProc.running = true }

    function _validateStage() { validateDelay.restart() }

    function _stageDone() {
        _preStageText = ""
        storeFile.reload()   // poller settles the inode swap within 2s
        CommandService.pushLog("[display] staged " + root.monitors.length +
                               " display rule(s) → monitors.lua (desc-keyed: survives cable moves and reloads)", "info")
    }

    function _stageRestore(why) {
        var esc = _preStageText.replace(/\\/g, "\\\\").replace(/'/g, "'\\''")
        restoreProc.command = ["sh", "-c",
            "printf '%s' '" + esc + "' > " + storePath + ".tmp.$$ && mv -f " + storePath + ".tmp.$$ " + storePath]
        restoreProc.running = true
        CommandService.pushLog(why, "error")
    }

    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: restoreProc
        command: []; running: false
        onRunningChanged: if (!running) {
            _preStageText = ""
            storeFile.reload()   // poller settles the inode swap within 2s
        }
    }

    function stageToNix() {
        var ms = root.monitors
        if (ms.length === 0) return
        var fileText = storeText
        var inner = _managedInner(fileText)
        var stored = _storedRules(inner)

        // Fresh rules for every live display; keep stored rules for displays
        // that are absent right now (remember-absent — both desc-keyed and
        // twin-fallback name-keyed rules preserve).
        var liveKeys = {}
        var lines = []
        for (var i = 0; i < ms.length; i++) {
            liveKeys[root._outputKeyFor(ms[i])] = true
            lines.push("    " + ruleFor(ms[i], {}))
        }
        for (var j = 0; j < stored.length; j++)
            if (!liveKeys[_ruleOut(stored[j])]) lines.push("    " + stored[j])

        var block = root.blockBegin + "\n" + lines.join("\n") + "\n" + root.blockEnd
        var newText
        if (inner !== "") {
            newText = fileText.substring(0, fileText.indexOf(root.blockBegin)) + block +
                      fileText.substring(fileText.indexOf(root.blockEnd) + root.blockEnd.length)
        } else if (fileText !== "") {
            newText = fileText.replace(/\s*$/, "\n\n") + block + "\n"
        } else {
            newText = "-- Display rules staged by the velocity settings panel.\n" + block + "\n"
        }
        if (newText === fileText) { _recomputePersistState(); return }

        _preStageText = fileText
        var esc = newText.replace(/\\/g, "\\\\").replace(/'/g, "'\\''")
        stageProc.command = ["sh", "-c",
            "F=" + storePath + "\n" +
            // first-touch backup, never overwritten (ln fails when it exists)
            "[ -e \"$F\" ] && ln \"$F\" \"$F.velocity-bak\" 2>/dev/null\n" +
            "printf '%s' '" + esc + "' > \"$F.tmp.$$\" && mv -f \"$F.tmp.$$\" \"$F\" && echo WROTE"]
        stageProc.running = true
    }

    // -------------------------------------------------------------------------
    // PARSERS
    // -------------------------------------------------------------------------

    function _parseMonitors(raw) {
        var arr = []
        try {
            var data = JSON.parse(raw || "[]")
            for (var i = 0; i < data.length; i++) {
                var m = data[i]
                arr.push({
                    name:        m.name || "",
                    desc:        m.description || "",
                    make:        m.make || "",
                    model:       m.model || "",
                    w:           m.width || 0,
                    h:           m.height || 0,
                    refreshHz:   m.refreshRate || 0,
                    scale:       m.scale || 1,
                    vrr:         !!m.vrr,
                    dpms:        !!m.dpmsStatus,
                    transform:   m.transform || 0,
                    format:      m.currentFormat || "",
                    colorPreset: m.colorManagementPreset || "",
                    sdrBrightness:    m.sdrBrightness || 1,
                    sdrSaturation:    m.sdrSaturation || 1,
                    sdrMinLuminance:  m.sdrMinLuminance || 0.2,
                    sdrMaxLuminance:  m.sdrMaxLuminance || 80,
                    x:           m.x || 0,
                    y:           m.y || 0,
                    physW:       m.physicalWidth || 0,
                    physH:       m.physicalHeight || 0,
                    focused:     !!m.focused,
                    activeWs:    m.activeWorkspace ? (m.activeWorkspace.id || 0) : 0,
                    modes:       root._parseModes(m.availableModes || "")
                })
            }
        } catch (e) {
            CommandService.pushLog("[display] monitors parse error: " + e, "error")
        }
        return arr
    }

    // "3840x2160@60.00Hz 3840x2160@119.88Hz 2560x1440@120.00Hz …" → [{w,h,hz}]
    function _parseModes(s) {
        var modes = []
        var re = /(\d+)x(\d+)@([\d.]+)/g
        var match
        while ((match = re.exec(s)) !== null) {
            modes.push({ w: parseInt(match[1]), h: parseInt(match[2]), hz: parseFloat(match[3]) })
        }
        // De-dup (hyprctl can repeat) + sort by pixels desc then hz desc.
        var seen = {}, uniq = []
        for (var i = 0; i < modes.length; i++) {
            var k = modes[i].w + "x" + modes[i].h + "@" + modes[i].hz
            if (!seen[k]) { seen[k] = true; uniq.push(modes[i]) }
        }
        uniq.sort(function(a, b) {
            var pa = a.w * a.h, pb = b.w * b.h
            if (pa !== pb) return pb - pa
            return b.hz - a.hz
        })
        return uniq
    }
}
