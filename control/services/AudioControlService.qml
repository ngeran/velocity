// =============================================================================
// AudioControlService.qml — pactl control (sinks/sources + per-stream vol)
// =============================================================================
//
// PROBES:
//   defaultSinkProc (3s) pactl get-default-sink
//   sinksProc       (3s) pactl -f json list sinks
//   sinkInputsProc  (2s) pactl -f json list sink-inputs
//
// Matches the existing bar AudioService (pactl, not wpctl). Prefers `-f json`
// (verified on pipewire-pulse 17) and auto-falls-back to text-regex parsing if
// the build ignores -f json. Format is detected by the first non-ws char
// ("[" / "{" → JSON, else text).
//
// sinks entry:      { index, name, desc, isDefault, volume(0-100), mute }
// sinkInputs entry: { id, app, sink(index str), volume(0-100), mute }
//
// On any set-*, the relevant list is refreshed immediately (responsive UI).
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property string defaultSink: ""
    property var sinks: []
    property var sinkInputs: []

    // -------------------------------------------------------------------------
    // DEFAULT SINK
    // -------------------------------------------------------------------------

    Process {
        id: defaultSinkProc
        command: ["pactl", "get-default-sink"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { defaultSinkProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var s = defaultSinkProc.buffer.trim()
                if (s.length > 0) {
                    root.defaultSink = s
                    // re-stamp isDefault flags if the list already exists
                    root._restampDefault(s)
                }
                defaultSinkProc.buffer = ""
            }
        }
    }

    // -------------------------------------------------------------------------
    // SINKS
    // -------------------------------------------------------------------------

    Process {
        id: sinksProc
        command: ["sh", "-c", "pactl -f json list sinks 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { sinksProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var raw = sinksProc.buffer.trim()
                if (raw.length > 0) {
                    var parsed = root._looksJson(raw)
                        ? root._parseSinksJson(raw)
                        : root._parseSinksText(raw)
                    if (parsed) {
                        root.sinks = parsed
                        root._restampDefault(root.defaultSink)
                    }
                }
                sinksProc.buffer = ""
            }
        }
    }

    // -------------------------------------------------------------------------
    // SINK INPUTS (active streams)
    // -------------------------------------------------------------------------

    Process {
        id: sinkInputsProc
        command: ["sh", "-c", "pactl -f json list sink-inputs 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { sinkInputsProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var raw = sinkInputsProc.buffer.trim()
                if (raw.length > 0) {
                    var parsed = root._looksJson(raw)
                        ? root._parseSinkInputsJson(raw)
                        : root._parseSinkInputsText(raw)
                    if (parsed) root.sinkInputs = parsed
                }
                sinkInputsProc.buffer = ""
            }
        }
    }

    // -------------------------------------------------------------------------
    // POLLING
    // -------------------------------------------------------------------------

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!defaultSinkProc.running) defaultSinkProc.running = true
            if (!sinksProc.running) sinksProc.running = true
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!sinkInputsProc.running) sinkInputsProc.running = true }
    }

    function refresh() {
        if (!defaultSinkProc.running) defaultSinkProc.running = true
        if (!sinksProc.running) sinksProc.running = true
        if (!sinkInputsProc.running) sinkInputsProc.running = true
    }

    // -------------------------------------------------------------------------
    // ACTIONS
    // -------------------------------------------------------------------------

    Process {
        id: actionProc
        property string label: ""
        property string lastVolume: ""
        onExited: function(code) {
            if (code !== 0) CommandService.pushLog("[audio] " + actionProc.label + " failed (exit " + code + ")", "error")
            root.refresh()
        }
    }

    function _run(verb, args, label) {
        actionProc.label = label
        actionProc.command = ["pactl", verb].concat(args)
        actionProc.running = true
    }

    function setDefaultSink(name) {
        if (!name) return
        _run("set-default-sink", [name], "set default " + name)
        CommandService.pushLog("[audio] default sink → " + name, "output")
    }

    function setSinkVolume(name, pct) {
        if (!name || !pct) return
        _run("set-sink-volume", [name, pct], "vol " + name + " " + pct)
    }

    function toggleSinkMute(name) {
        if (!name) return
        _run("set-sink-mute", [name, "toggle"], "mute " + name)
    }

    function setSinkInputVolume(id, pct) {
        if (!id || !pct) return
        _run("set-sink-input-volume", [id, pct], "stream vol " + id + " " + pct)
    }

    function toggleSinkInputMute(id) {
        if (!id) return
        _run("set-sink-input-mute", [id, "toggle"], "stream mute " + id)
    }

    // Default-sink parity with the bar AudioService.
    function volumeUp()   { setSinkVolume(root.defaultSink, "+5%") }
    function volumeDown() { setSinkVolume(root.defaultSink, "-5%") }
    function toggleMute() { toggleSinkMute(root.defaultSink) }

    // -------------------------------------------------------------------------
    // HELPERS / PARSERS
    // -------------------------------------------------------------------------

    function _looksJson(s) {
        var t = (s || "").trim()
        return t.length > 0 && (t.charAt(0) === "[" || t.charAt(0) === "{")
    }

    function _volPct(vol) {
        if (!vol) return 0
        for (var k in vol) {
            if (Object.prototype.hasOwnProperty.call(vol, k) && vol[k] && vol[k].value_percent) {
                return parseInt(vol[k].value_percent) || 0
            }
        }
        for (var k2 in vol) {
            if (Object.prototype.hasOwnProperty.call(vol, k2) && vol[k2] && typeof vol[k2].value === "number") {
                return Math.round(vol[k2].value / 65536 * 100)
            }
        }
        return 0
    }

    function _parseSinksJson(raw) {
        try {
            var arr = JSON.parse(raw)
            var out = []
            for (var i = 0; i < arr.length; i++) {
                var s = arr[i]
                out.push({
                    index: s.index,
                    name: s.name || "",
                    desc: s.description || s.name || "",
                    isDefault: (s.name === root.defaultSink),
                    volume: root._volPct(s.volume),
                    mute: !!s.mute
                })
            }
            return out
        } catch (e) {
            CommandService.pushLog("[audio] sinks json parse failed: " + e, "warning")
            return null
        }
    }

    function _parseSinkInputsJson(raw) {
        try {
            var arr = JSON.parse(raw)
            if (!arr) return []
            var out = []
            for (var i = 0; i < arr.length; i++) {
                var si = arr[i]
                var app = ""
                try { app = (si.properties && (si.properties["application.name"] || si.properties["media.name"])) || ("stream " + si.index) } catch (e2) { app = "stream " + si.index }
                out.push({
                    id: String(si.index),
                    app: app,
                    sink: String(si.sink),
                    volume: root._volPct(si.volume),
                    mute: !!si.mute
                })
            }
            return out
        } catch (e) {
            CommandService.pushLog("[audio] sink-inputs json parse failed: " + e, "warning")
            return null
        }
    }

    // --- text fallback (for builds that ignore -f json) ---
    function _parseSinksText(raw) {
        var lines = raw.split("\n")
        var out = []
        var cur = null
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i].trim()
            if (ln.indexOf("Sink #") === 0) {
                if (cur) out.push(cur)
                cur = { index: parseInt(ln.replace("Sink #", "")) || -1, name: "", desc: "", isDefault: false, volume: 0, mute: false }
            } else if (cur) {
                if (ln.indexOf("Name:") === 0) { cur.name = ln.substring(5).trim(); cur.isDefault = (cur.name === root.defaultSink) }
                else if (ln.indexOf("Description:") === 0) cur.desc = ln.substring(12).trim()
                else if (ln.indexOf("Mute:") === 0) cur.mute = (ln.substring(5).trim() === "yes")
                else if (ln.indexOf("Volume:") === 0) { var m = ln.match(/(\d+)%/); if (m) cur.volume = parseInt(m[1]) }
            }
        }
        if (cur) out.push(cur)
        return out
    }

    function _parseSinkInputsText(raw) {
        var lines = raw.split("\n")
        var out = []
        var cur = null
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i].trim()
            if (ln.indexOf("Sink Input #") === 0) {
                if (cur) out.push(cur)
                cur = { id: ln.replace("Sink Input #", "").trim(), app: "", sink: "", volume: 0, mute: false }
            } else if (cur) {
                if (ln.indexOf("Sink:") === 0) cur.sink = ln.substring(5).trim()
                else if (ln.indexOf("Mute:") === 0) cur.mute = (ln.substring(5).trim() === "yes")
                else if (ln.indexOf("Volume:") === 0) { var m = ln.match(/(\d+)%/); if (m) cur.volume = parseInt(m[1]) }
                else if (ln.indexOf("application.name") === 0) cur.app = ln.split("=")[1].trim().replace(/"/g, "")
            }
        }
        if (cur) out.push(cur)
        return out
    }

    // Re-stamp isDefault after defaultSink or sinks change.
    function _restampDefault(name) {
        if (!name || root.sinks.length === 0) return
        var changed = false
        var out = []
        for (var i = 0; i < root.sinks.length; i++) {
            var s = root.sinks[i]
            var def = (s.name === name)
            if (s.isDefault !== def) changed = true
            out.push({ index: s.index, name: s.name, desc: s.desc, isDefault: def, volume: s.volume, mute: s.mute })
        }
        if (changed) root.sinks = out
    }
}
