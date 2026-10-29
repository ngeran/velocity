// =============================================================================
// velocity.record — headless screen-recording service (J9, kinds ["service"])
// =============================================================================
// ONE root per session (service/view split; nothing renders on the bar).
// wf-recorder + slurp, J8-style tool probe: absent → verbs answer honestly
// ("unavailable: …") + one journal line at mount.
//
// Flow: `record start` → slurp region pick (interactive — the process lives
// until the user draws the box; Esc aborts silently) → mkdir -p ~/Videos →
// wf-recorder -g <geom> -f <file> [--audio] → island activity
// `{key:"rec", priority:"recording", activate:stop}` renewed at 1 Hz
// (ttl 3 s per tick; the J0 recording rank was reserved for exactly this).
// The island's `activate` click IS the stop button (Scene.qml already calls
// it) — zero new UI. Stop sends SIGINT — the only signal wf-recorder
// finalizes cleanly on; Quickshell's running=false would SIGTERM and
// truncate the mp4. On exit: activity ended + notification through the bar
// `notifications add` IPC (notify-send absent — J6 pattern).
//
// QD-OLED: label-only card (no progress track — a growing red bar would be
// a permanent fill); dims after 3 s per the J0 static doctrine while the
// per-second label keeps it non-static.
//
// Known edge: a bar restart kills the recorder child mid-take (the take is
// lost, file truncated). Accepted for J9 — recording through a shell restart
// is not a real workflow.
// =============================================================================

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var ctx: null

    // ── state ────────────────────────────────────────────────────────────────
    property bool supported: false
    property bool recording: false
    property string outFile: ""
    property int elapsedSec: 0

    readonly property string videosDir: Quickshell.env("HOME") + "/Videos"
    readonly property string elapsedLabel: {
        var m = Math.floor(elapsedSec / 60)
        var s = elapsedSec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    Component.onCompleted: probe.running = true

    // ── verbs (manifest.ipc, via PluginRegistry.call) ────────────────────────
    function start(argument) {
        if (!root.supported) return "unavailable: wf-recorder/slurp missing (omni-nix)"
        if (root.recording) return "already recording"
        if (!root.ctx) return "not ready"
        var mode = String(argument || "region")
        if (mode === "region") { slurpProc.running = true; return "ok" }
        if (mode === "output") { mkdirProc.running = true; return "ok" }   // full output, no slurp
        return "error: mode must be region|output"
    }

    function stop() {
        if (!root.recording) return "idle"
        if (recorder.pid <= 0) return "not started yet"
        stopProc.command = ["sh", "-c", 'kill -INT "$1"', "stop", String(recorder.pid)]
        stopProc.running = true
        return "ok"
    }

    function toggle(argument) { return root.recording ? root.stop() : root.start(argument) }

    function status() {
        return JSON.stringify({ recording: root.recording,
                                elapsed: root.elapsedLabel, file: root.outFile })
    }

    // ── tool probe (one-shot at mount) ───────────────────────────────────────
    Process {   // unbounded-ok: one-shot tool probe at mount
        id: probe
        command: ["sh", "-c", "wf-recorder --help >/dev/null 2>&1 && slurp --help >/dev/null 2>&1"]
        running: false
        onExited: function(code, status) {
            root.supported = (code === 0)
            if (code !== 0)
                console.log("[velocity.record] wf-recorder/slurp not found — record verbs unavailable " +
                            "(add wf-recorder in omni-nix)")
        }
    }

    // ── region pick (interactive; Esc = code 1 = quiet abort) ────────────────
    // slurp prints one line "x,y WxH" — SplitParser is exact here (per-line,
    // newline stripped; single line in, single line out).
    property string _geometry: ""
    Process {   // unbounded-ok: interactive region pick, lives until the user draws
        id: slurpProc
        running: false
        command: ["slurp", "-b", "#00000055", "-c", "#00dce5", "-w", "2"]
        stdout: SplitParser {
            onRead: function(data) { root._geometry = data.trim() }
        }
        onExited: function(code, status) {
            if (code !== 0) {
                if (code !== 1) console.log("[velocity.record] slurp aborted: code " + code)
                root._geometry = ""
                return   // Esc-cancelled pick — silent
            }
            if (root._geometry.length === 0) return
            mkdirProc.running = true
        }
    }

    // ── output dir, then launch ──────────────────────────────────────────────
    Process {   // unbounded-ok: one-shot mkdir before every recording
        id: mkdirProc
        running: false
        command: ["sh", "-c", 'mkdir -p "$1"', "mkdir", root.videosDir]
        onExited: function(code, status) {
            if (code !== 0) { console.warn("[velocity.record] mkdir failed"); return }
            root._launch()
        }
    }

    function _launch() {
        var stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19)
        root.outFile = videosDir + "/velocity-rec-" + stamp + ".mp4"
        root.elapsedSec = 0
        var argv = ["wf-recorder"]
        if (root._geometry !== "") argv.push("-g", root._geometry)
        if (root.ctx && root.ctx.settings.values.audio === true) argv.push("--audio")
        argv.push("-f", root.outFile)
        recorder.command = argv
        recorder.running = true
        root.recording = true
        root._publish()
        tick.restart()
    }

    Process {   // unbounded-ok: the recording itself — runs until the user stops it
        id: recorder
        running: false
        onExited: function(code, status) {
            tick.stop()
            var file = root.outFile
            root.recording = false
            root._geometry = ""
            if (root.ctx) root.ctx.island.end("rec")
            if (code === 0) root._notify("RECORDING SAVED", file)
            else root._notify("RECORDING FAILED", "exit " + code + " — " + file)
        }
    }

    // 1 Hz elapsed tick — also renews the island activity (ttl 3 s per tick)
    Timer {
        id: tick
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root.elapsedSec += 1
            root._publish()
        }
    }

    function _publish() {
        if (!root.ctx) return
        root.ctx.island.activity({
            key: "rec", priority: "recording", icon: "󰍩",
            label: "REC " + root.elapsedLabel, ttlMs: 3000,
            focusedOnly: false,
            activate: function() { root.stop() }   // the island click = stop button
        })
    }

    Process {   // unbounded-ok: one-shot kill -INT on stop
        id: stopProc
        running: false
        onExited: function(code, status) {
            if (code !== 0) console.warn("[velocity.record] kill -INT failed")
        }
    }

    // ── notification (J6 pattern: sh → the bar's notifications IPC) ──────────
    Process {   // unbounded-ok: one-shot desktop notification on stop
        id: notifyProc
        running: false
    }

    function _notify(summary, body) {
        notifyProc.command = ["sh", "-c", 'qs -c bar ipc call notifications add "$1"',
                              "notify", JSON.stringify({
                                  appName: "velocity.record",
                                  summary: summary,
                                  body: body,
                                  urgency: "normal" })]
        notifyProc.running = true
    }
}
