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
//   Reload reverts eval'd values to the nix config → persistence goes through
//   stageToNix() (rewrites ~/.omni-nix/configs/hypr/monitors.lua + git add;
//   the user's omni-apply makes it permanent).
//
// monitors[] entry:
//   { name, desc, make, model, w, h, refreshHz, scale, vrr, dpms, transform,
//     format, colorPreset, sdrBrightness, sdrSaturation, sdrMinLuminance,
//     sdrMaxLuminance, x, y, physW, physH, modes: [{w,h,hz}] }
// =============================================================================

pragma Singleton

import QtQuick
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

    // ── persistence state: live values vs the nix source of truth ──────────
    // "dirty" = live differs from ~/.omni-nix/configs/hypr/monitors.lua
    //          (a reload would lose the live tweaks — stage them!)
    property string persistState: "clean"
    property string nixRuleText: ""

    // -------------------------------------------------------------------------
    // POLL — hyprctl monitors -j (JSON). 10s while the dashboard is open; also
    // refreshed after every applied rule (readback verification).
    // -------------------------------------------------------------------------
    Process {
        id: monProc
        command: ["hyprctl", "monitors", "-j"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { monProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                root.monitors = root._parseMonitors(monProc.buffer)
                monProc.buffer = ""
            }
        }
    }

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

    function refresh() { if (!monProc.running) monProc.running = true }

    // -------------------------------------------------------------------------
    // RULE BUILDER — full hl.monitor rule from live state + overrides
    // -------------------------------------------------------------------------
    // over: { mode, scale, bitdepth, vrr, cm, sdrbrightness, sdrsaturation,
    //         sdr_min_luminance, sdr_max_luminance }  (undefined = keep live)
    function currentModeString() {
        var p = primary
        if (!p) return "preferred"
        // Trim trailing zeros: 119.88 stays, 60.00 → 60
        var hz = String(parseFloat(p.refreshHz.toFixed(2)))
        return p.w + "x" + p.h + "@" + hz
    }

    function liveBitdepth() {
        var p = primary
        if (!p) return 10
        // XBGR2101010/ARGB2101010 → 10-bit; XRGB8888/ARGB8888 → 8-bit
        return (p.format.indexOf("2101010") !== -1 || p.format.indexOf("101010") !== -1) ? 10 : 8
    }

    function ruleString(over) {
        var p = primary
        if (!p) return ""
        var o = over || {}
        var mode = o.mode !== undefined ? o.mode : currentModeString()
        var scale = o.scale !== undefined ? o.scale : p.scale
        var bd = o.bitdepth !== undefined ? o.bitdepth : liveBitdepth()
        var vrr = o.vrr !== undefined ? o.vrr : vrrMode
        var pos = p.x + "x" + p.y
        var s = "hl.monitor({ output = '" + p.name + "', mode = '" + mode
              + "', position = '" + pos + "', scale = " + scale
              + ", bitdepth = " + bd + ", vrr = " + vrr
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
    Process {
        id: ruleProc
        command: []; running: false
        property string queued: ""
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { ruleProc.buffer += data } }
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
    Process {
        id: globalProc
        command: []; running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { globalProc.buffer += data } }
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
    Process {
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
    // NIX SOURCE — the persistence target (read at startup; rewritten by stage)
    // -------------------------------------------------------------------------
    FileView {
        id: nixFile
        path: "/home/nikos/.omni-nix/configs/hypr/monitors.lua"
        watchChanges: false
        onLoaded: {
            root.nixRuleText = text()
            root._seedFromNix()
        }
    }

    // cmAutoHdr lives in look-and-feel.lua (render block), not monitors.lua.
    FileView {
        id: lookFile
        path: "/home/nikos/.omni-nix/configs/hypr/look-and-feel.lua"
        watchChanges: false
        onLoaded: {
            var m = /cm_auto_hdr\s*=\s*(\d)/.exec(text())
            if (m) root.cmAutoHdr = parseInt(m[1], 10)
        }
    }

    Component.onCompleted: { nixFile.reload(); lookFile.reload() }

    // Seeds vrrMode (config value) and computes the initial persist state.
    function _seedFromNix() {
        var m = /vrr\s*=\s*(\d)/.exec(nixRuleText)
        if (m) vrrMode = parseInt(m[1], 10)
        _recomputePersistState()
    }

    // "dirty" when the nix source's mode/scale/bitdepth/vrr differ from live.
    // (cm/sdr* are intentionally ignored: the source keeps none today, so any
    // live HDR session is by definition transient until staged.)
    function _recomputePersistState() {
        var p = primary
        if (!p || nixRuleText === "") return
        var parts = []
        var mm = /mode\s*=\s*"([^"]*)"/.exec(nixRuleText)
        var sm = /scale\s*=\s*"?([\d.]+)"?/.exec(nixRuleText)
        var bm = /bitdepth\s*=\s*(\d+)/.exec(nixRuleText)
        var vm = /vrr\s*=\s*(\d+)/.exec(nixRuleText)
        if (mm) parts.push(mm[1])
        if (sm) parts.push(sm[1])
        if (bm) parts.push(bm[1])
        if (vm) parts.push(vm[1])
        var live = [currentModeString(), String(p.scale), String(liveBitdepth()), String(vrrMode)]
        var nixMode = mm ? _trimModeHz(mm[1]) : ""
        live[0] = _trimModeHz(live[0])
        persistState = (nixMode === live[0] && parts[1] === live[1]
                        && parts[2] === live[2] && parts[3] === live[3]) ? "clean" : "dirty"
    }

    // "3840x2160@240" vs live "3840x2160@119.88" — compare res only for the
    // mode part? No: compare full but via parseFloat so 60.00 == 60.
    function _trimModeHz(mode) {
        var m = /^(\d+x\d+)@([\d.]+)$/.exec(mode)
        if (!m) return mode
        return m[1] + "@" + String(parseFloat(m[2]))
    }

    // -------------------------------------------------------------------------
    // STAGE TO NIX — rewrite the monitor attrs in the omni-nix source to the
    // current live values, then git add. The user's omni-apply persists.
    // -------------------------------------------------------------------------
    Process {
        id: stageProc
        command: []; running: false
        onExited: function(code) {
            if (code === 0) {
                nixFile.reload()
                CommandService.pushLog("[display] staged monitor settings → omni-nix (run omni-apply)", "info")
            } else {
                CommandService.pushLog("[display] stage failed exit=" + code, "error")
            }
        }
    }

    function stageToNix() {
        var p = primary
        if (!p) return
        var text = nixRuleText
        var liveMode = currentModeString()
        var liveScale = String(p.scale)
        var liveBd = String(liveBitdepth())
        var liveVrr = String(vrrMode)
        var cm = p.colorPreset
        var hdrOn = cm !== "" && cm !== "srgb"

        function setAttr(txt, name, value) {
            var re = new RegExp("(\\b" + name + '\\s*=\\s*)("[^"]*"|[\\d.]+)')
            if (re.test(txt)) return txt.replace(re, "$1" + value)
            return txt.replace(/(\}\s*\))\s*$/, ", " + name + " = " + value + " })")
        }
        // Lua number attrs unquoted; mode quoted.
        text = setAttr(text, "mode", "\"" + liveMode + "\"")
        text = setAttr(text, "scale", liveScale)
        text = setAttr(text, "bitdepth", liveBd)
        text = setAttr(text, "vrr", liveVrr)
        // HDR block: add cm + tune when live, drop when back to SDR.
        if (hdrOn) {
            text = setAttr(text, "cm", "'" + cm + "'")
            text = setAttr(text, "sdrbrightness", String(p.sdrBrightness))
            text = setAttr(text, "sdr_max_luminance", String(p.sdrMaxLuminance))
        }

        // printf to the source (single-quote-escaped), then stage in git.
        var escaped = text.replace(/'/g, "'\\''")
        stageProc.command = ["sh", "-c",
            "printf '%s' '" + escaped + "' > /home/nikos/.omni-nix/configs/hypr/monitors.lua" +
            " && git -C /home/nikos/.omni-nix add configs/hypr/monitors.lua"]
        stageProc.running = true
        _recomputePersistState()
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
