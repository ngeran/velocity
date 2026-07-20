// =============================================================================
// AudioControlService.qml — WirePlumber control via wpctl
// =============================================================================
// PipeWire-native. `pactl` is NOT installed on this machine (services.pulseaudio
// is disabled in favour of pipewire-pulse), so everything goes through `wpctl`.
//
// POLL (3s):
//   statusProc  → `wpctl status`           lists sinks/sources/streams + vol + default (*)
//   muteProc    → `wpctl get-volume <id>`  per node (status omits mute state)
//
// ACTIONS (all take the numeric node id, bare — no @ prefix):
//   wpctl set-default <id>
//   wpctl set-volume -l 1.0 <id> 0.NN      (-l 1.0 caps at 100%)
//   wpctl set-mute <id> toggle
//
// Entry shapes (kept compatible with SinkListView/SinkRow/SourceRow/SinkInputRow):
//   sinks/sources:  { id, name, desc, isDefault, volume(0-100), mute }
//   sinkInputs:     { id, app, volume(0-100), mute }
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io
import "../config" as Config

Item {
    id: root
    visible: false

    property string defaultSink: ""
    property var sinks: []
    property var sinkInputs: []
    property string defaultSource: ""
    property var sources: []

    // -------------------------------------------------------------------------
    // STATUS POLL — wpctl status (sinks + sources + streams + default marker)
    // -------------------------------------------------------------------------
    Process {
        id: statusProc
        command: ["wpctl", "status"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { statusProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                var parsed = root._parseWpctlStatus(statusProc.buffer)
                root.sinks = parsed.sinks
                root.sources = parsed.sources
                root.sinkInputs = parsed.streams
                for (var i = 0; i < parsed.sinks.length; i++) {
                    if (parsed.sinks[i].isDefault) { root.defaultSink = parsed.sinks[i].id; break }
                }
                for (var j = 0; j < parsed.sources.length; j++) {
                    if (parsed.sources[j].isDefault) { root.defaultSource = parsed.sources[j].id; break }
                }
                root._pollNodeInfo(parsed.sinks, parsed.sources, parsed.streams)
                statusProc.buffer = ""
            }
        }
    }

    // -------------------------------------------------------------------------
    // NODE-INFO POLL — wpctl get-volume <id> for every node (status omits mute)
    // Output per line: "<id>=Volume: 0.40" (+ " [MUTED]" when muted)
    // -------------------------------------------------------------------------
    Process {
        id: nodeInfoProc
        command: []
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { nodeInfoProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                root._applyNodeInfo(nodeInfoProc.buffer)
                nodeInfoProc.buffer = ""
            }
        }
    }

    function _pollNodeInfo(sinks, sources, streams) {
        var ids = []
        var i
        for (i = 0; i < sinks.length; i++) ids.push(sinks[i].id)
        for (i = 0; i < sources.length; i++) ids.push(sources[i].id)
        for (i = 0; i < streams.length; i++) ids.push(streams[i].id)
        if (ids.length === 0) return
        // for n in 53 54 55; do printf '%s=' "$n"; wpctl get-volume "$n"; done
        var loop = "for n in " + ids.join(" ") + "; do printf '%s=' \"$n\"; wpctl get-volume \"$n\"; done"
        nodeInfoProc.command = ["sh", "-c", loop]
        nodeInfoProc.running = true
    }

    function _applyNodeInfo(raw) {
        // Build id → { volume, mute } from "53=Volume: 0.40 [MUTED]" lines
        var info = {}
        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^(\d+)=Volume:\s*([\d.]+)\s*(\[MUTED\])?/)
            if (m) info[m[1]] = { volume: Math.round(parseFloat(m[2]) * 100), mute: !!m[3] }
        }
        if (Object.keys(info).length === 0) return

        // Rebuild arrays so bindings re-fire; sinks/sources keep status vol (mute
        // from here), streams take both vol + mute from here.
        var s2 = []
        for (var a = 0; a < root.sinks.length; a++) {
            var s = root.sinks[a]
            var si = info[s.id]
            s2.push({ id: s.id, name: s.name, desc: s.desc, isDefault: s.isDefault,
                      volume: s.volume, mute: si ? si.mute : s.mute })
        }
        root.sinks = s2

        var src2 = []
        for (var b = 0; b < root.sources.length; b++) {
            var sr = root.sources[b]
            var sri = info[sr.id]
            src2.push({ id: sr.id, name: sr.name, desc: sr.desc, isDefault: sr.isDefault,
                        volume: sr.volume, mute: sri ? sri.mute : sr.mute })
        }
        root.sources = src2

        var st2 = []
        for (var c = 0; c < root.sinkInputs.length; c++) {
            var st = root.sinkInputs[c]
            var sti = info[st.id]
            st2.push({ id: st.id, app: st.app,
                       volume: sti ? sti.volume : st.volume,
                       mute: sti ? sti.mute : st.mute })
        }
        root.sinkInputs = st2
    }

    // -------------------------------------------------------------------------
    // POLLING
    // -------------------------------------------------------------------------
    Timer {
        interval: 3000
        running: Config.SharedState.dashboardVisible  // only when the dashboard is open
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!statusProc.running) statusProc.running = true }
    }

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    // -------------------------------------------------------------------------
    // ACTIONS — all take the numeric node id (bare, no @)
    // -------------------------------------------------------------------------
    Process {
        id: actionProc
        property string label: ""
        onExited: function(code) {
            if (code !== 0) CommandService.pushLog("[audio] " + actionProc.label + " failed (exit " + code + ")", "error")
            root.refresh()
        }
    }

    function _run(cmd, label) {
        actionProc.label = label
        actionProc.command = cmd
        actionProc.running = true
    }

    function _volArg(pct) {
        // Accept number (50) or "50%" string from the UI sliders
        var n = typeof pct === "string" ? parseFloat(pct.replace("%", "")) : Number(pct)
        if (isNaN(n)) n = 0
        var v = Math.max(0, Math.min(100, Math.round(n)))
        return (v / 100).toFixed(2)
    }

    function setDefaultSink(id) {
        if (!id) return
        _run(["wpctl", "set-default", String(id)], "set default sink " + id)
        CommandService.pushLog("[audio] default sink → " + id, "output")
    }

    function setSinkVolume(id, pct) {
        if (id === undefined || id === "" || pct === undefined) return
        _run(["wpctl", "set-volume", "-l", "1.0", String(id), _volArg(pct)], "sink vol " + id + " " + pct)
    }

    function toggleSinkMute(id) {
        if (!id) return
        _run(["wpctl", "set-mute", String(id), "toggle"], "sink mute " + id)
    }

    function setSinkInputVolume(id, pct) {
        if (id === undefined || id === "" || pct === undefined) return
        _run(["wpctl", "set-volume", "-l", "1.0", String(id), _volArg(pct)], "stream vol " + id + " " + pct)
    }

    function toggleSinkInputMute(id) {
        if (!id) return
        _run(["wpctl", "set-mute", String(id), "toggle"], "stream mute " + id)
    }

    function setDefaultSource(id) {
        if (!id) return
        _run(["wpctl", "set-default", String(id)], "set default source " + id)
        CommandService.pushLog("[audio] default source → " + id, "output")
    }

    function setSourceVolume(id, pct) {
        if (id === undefined || id === "" || pct === undefined) return
        _run(["wpctl", "set-volume", "-l", "1.0", String(id), _volArg(pct)], "source vol " + id + " " + pct)
    }

    function toggleSourceMute(id) {
        if (!id) return
        _run(["wpctl", "set-mute", String(id), "toggle"], "source mute " + id)
    }

    // Default-sink parity with the bar AudioService.
    function _find(id, arr) {
        for (var i = 0; i < arr.length; i++) if (arr[i].id === id) return arr[i]
        return null
    }
    function volumeUp()   { var d = root.defaultSink; var s = d ? _find(d, root.sinks) : null; if (d) setSinkVolume(d, (s ? s.volume : 50) + 5) }
    function volumeDown() { var d = root.defaultSink; var s = d ? _find(d, root.sinks) : null; if (d) setSinkVolume(d, (s ? s.volume : 50) - 5) }
    function toggleMute()    { if (root.defaultSink) toggleSinkMute(root.defaultSink) }
    function toggleMicMute() { if (root.defaultSource) toggleSourceMute(root.defaultSource) }

    // -------------------------------------------------------------------------
    // PARSER — wpctl status tree
    //   Lines are prefixed with Unicode box-drawing chars (│ ├ └ ─) + spaces,
    //   so the regex consumes any leading non-digit/non-asterisk chars first.
    //   Only the Audio section is parsed — wpctl also emits a Video section
    //   with its own Sinks/Sources that we must NOT collect.
    //     Sinks:    53. Name [vol: 0.40]    (leading "*" = default)
    //     Sources:  55. Name [vol: 1.00]
    //     Streams:  103. AppName            (nested device line has [vol:] — skipped)
    // -------------------------------------------------------------------------
    function _parseWpctlStatus(text) {
        var sinks = [], sources = [], streams = [], section = null, inAudio = false
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            // Top-level section headers are bare words ("Audio", "Video"). Match
            // the trimmed line exactly — sink names contain "Audio" substring.
            var trimmed = line.trim()
            if (trimmed === "Audio")  { inAudio = true;  section = null; continue }
            if (trimmed === "Video")  { inAudio = false; section = null; continue }
            if (trimmed === "Settings") { inAudio = false; section = null; continue }
            if (!inAudio) continue

            if (line.indexOf("Sinks:") !== -1)        { section = "sink";   continue }
            if (line.indexOf("Sources:") !== -1)      { section = "source"; continue }
            if (line.indexOf("Streams:") !== -1)      { section = "stream"; continue }
            if (line.indexOf("Filters:") !== -1
                || line.indexOf("Devices:") !== -1
                || line.indexOf("Profile") !== -1)    { section = null; continue }
            if (!section) continue

            if (section === "stream") {
                // Top-level stream line: "  103. Chromium" (no [vol:]). Nested
                // device lines ("       54. Ryzen ... [vol: 0.50]") have [vol:] → skip.
                if (line.indexOf("[vol:") !== -1) continue
                var sm = line.match(/^[^0-9]*(\d+)\.\s+(.+)$/)
                if (sm) streams.push({ id: sm[1], app: sm[2].trim(), volume: 0, mute: false })
                continue
            }

            // Sink / source: consume box-drawing prefix + spaces, optional "*",
            // then "NN. Name [vol: 0.XX]"
            var m = line.match(/^[^0-9*]*(\*)?\s*(\d+)\.\s+(.+?)\s+\[vol:\s*([\d.]+)\]/)
            if (!m) continue
            var entry = {
                id: m[2],
                name: m[3].trim(),
                desc: m[3].trim(),
                volume: Math.round(parseFloat(m[4]) * 100),
                mute: false,
                isDefault: m[1] === "*"
            }
            if (section === "sink") sinks.push(entry)
            else sources.push(entry)
        }
        return { sinks: sinks, sources: sources, streams: streams }
    }
}
