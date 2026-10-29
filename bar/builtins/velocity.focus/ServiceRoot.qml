// =============================================================================
// velocity.focus — ServiceRoot (headless, entryPoints.service)
// =============================================================================
// The ONE timer owner for every output's pill (service/view split). Counts
// to a persisted wall-clock target — `endTs - Date.now()` — so display and
// completion are drift-free by construction no matter how wobbly the 1 s
// tick cadence is. State persists (atomic tmp+mv, SettingsStore idiom) at
// $XDG_STATE_HOME/velocity/plugins/velocity.focus-session.json and is
// restored on boot: a session survives a bar restart, and one that expired
// while the bar was down still fires its notification (≤ 30 min stale —
// older than that is cleared silently).
//
// Activity surfaces (J6 design note): the queue entries are TRANSIENT — a
// 10 s start card and an 8 s done-flash, both self-expiring (ttlMs). No
// per-second republish: a renewed activity would park the floating OSD
// card (vector style) on screen for the whole session — a static bright
// fill the QD-OLED doctrine forbids. The persistent countdown lives in the
// bar pill instead.
//
// Views bind ctx.service; the pill calls start/stop directly (same
// plugin). External control goes through shell.qml's "focus" target →
// PluginRegistry.call: `qs -c bar ipc call focus start <min>|stop|status`.
// =============================================================================
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    width: 0
    height: 0

    property var ctx: null

    // ── session state ────────────────────────────────────────────────────────
    property bool running: false
    property real endTs: 0            // wall-clock target, epoch ms
    property real totalMs: 0
    property string label: "FOCUS"

    // tickSeq is bumped by the 1 s tick: Date.now() inside a binding has no
    // change signal of its own, so the read below is what re-arms the
    // remainingMs → remainingLabel/progressPct cascade every second.
    property int tickSeq: 0
    readonly property real remainingMs: root.running && root.tickSeq >= 0
        ? Math.max(0, root.endTs - Date.now()) : 0
    readonly property int remainingSec: Math.ceil(root.remainingMs / 1000)
    readonly property int progressPct: root.totalMs > 0
        ? Math.round(Math.max(0, Math.min(100, root.remainingMs / root.totalMs * 100))) : 0
    // "24:59", or "1:05:30" past the hour.
    readonly property string remainingLabel: root._format(root.remainingSec)

    function _format(sec) {
        sec = Math.max(0, Math.floor(sec))
        var h = Math.floor(sec / 3600)
        var m = Math.floor((sec % 3600) / 60)
        var s = sec % 60
        return (h > 0 ? h + ":" : "") + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
    }

    // ── persistence ──────────────────────────────────────────────────────────
    // "-session" suffix keeps this clear of SettingsStore's <id>.json.
    readonly property string _statePath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "~") + "/.local/state")
        + "/velocity/plugins/velocity.focus-session.json"
    readonly property int _staleGraceMs: 30 * 60 * 1000

    FileView {
        id: stateFile
        path: root._statePath
        // The async load may not be done by Component.onCompleted (a
        // mid-session reload restored idle once); restore on the signal too.
        onLoaded: root._restore()
    }

    property bool _restored: false
    Component.onCompleted: root._restore()

    function _restore() {
        if (root._restored) return
        var txt = ""
        try { txt = stateFile.text() } catch (e) { return }
        var d = null
        try { d = JSON.parse(txt) } catch (e) { return }
        if (!d || d.running !== true || typeof d.endTs !== "number" || d.endTs <= 0) {
            root._restored = true
            return
        }
        root._restored = true
        root.label = (typeof d.label === "string" && d.label !== "") ? d.label : "FOCUS"
        var now = Date.now()
        if (d.endTs > now) {
            // Resume — the tick restarts; the start card re-surfaces on ctx.
            root.totalMs = (typeof d.totalMs === "number" && d.totalMs > 0)
                           ? d.totalMs : (d.endTs - now)
            root.endTs = d.endTs
            root.running = true
            console.log("[velocity.focus] restored session, " +
                        Math.round((d.endTs - now) / 1000) + "s left")
        } else {
            root.running = false
            root.endTs = 0
            root.totalMs = 0
            root._writeSession()
            if (now - d.endTs <= root._staleGraceMs)
                root._notify("finished while the bar was down")
        }
    }

    // ctx lands after mount — a restored session publishes its start card then.
    onCtxChanged: if (root.ctx && root.running) root._publish("start")

    // Atomic tmp+mv write (SettingsStore idiom). One-shot, no watcher.
    Process {
        id: stateWriter   // unbounded-ok: one-shot local tmp+mv file write
    }

    function _writeSession() {
        stateWriter.command = ["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"',
            "write", root._statePath,
            JSON.stringify({ schema: 1, running: root.running, endTs: root.endTs,
                             totalMs: root.totalMs, label: root.label })]
        stateWriter.running = true
    }

    // ── tick — cadence only; the countdown itself is endTs math ─────────────
    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            root.tickSeq += 1
            if (root.running && root.endTs - Date.now() <= 0) root._finish()
        }
    }

    // ── public verbs (manifest.ipc, via PluginRegistry.call) ─────────────────
    function start(argument) {
        var mins = Math.round(Number(argument))
        if (!(mins >= 1 && mins <= 180)) return "error: minutes must be 1..180"
        root.totalMs = mins * 60000
        root.endTs = Date.now() + root.totalMs
        root.running = true
        root._writeSession()
        root._publish("start")
        console.log("[velocity.focus] started " + mins + "m, ends " +
                    new Date(root.endTs).toLocaleTimeString())
        return "ok"
    }

    function stop() {
        if (!root.running) return "idle"
        root.running = false
        root.endTs = 0
        root.totalMs = 0
        root._writeSession()
        if (root.ctx) root.ctx.island.end("focus")
        console.log("[velocity.focus] cancelled")
        return "ok"
    }

    function status() {
        return JSON.stringify({ running: root.running, label: root.label,
                                remaining: root.remainingLabel, progress: root.progressPct })
    }

    // ── completion ───────────────────────────────────────────────────────────
    function _finish() {
        var mins = Math.max(1, Math.round(root.totalMs / 60000))
        root.running = false
        root.endTs = 0
        root.totalMs = 0
        root._writeSession()
        root._publish("done")
        root._notify(mins + " minute session — take a break.")
    }

    // ── activity (transient — see header) ────────────────────────────────────
    function _publish(kind) {
        if (!root.ctx) return
        if (kind === "done") {
            // ttl REQUIRED without progress; self-clears (no end() here —
            // that would kill the flash immediately).
            root.ctx.island.activity({ key: "focus", priority: "timer",
                                       icon: "󰥔", label: "FOCUS DONE", ttlMs: 8000 })
        } else {
            root.ctx.island.activity({ key: "focus", priority: "timer",
                                       icon: "󰥔", label: root.remainingLabel,
                                       progress: root.progressPct, ttlMs: 10000 })
        }
    }

    // ── desktop notification (one-shot sh → the bar's notifications IPC) ─────
    Process {
        id: notifyProc   // unbounded-ok: one-shot desktop notification on completion
    }

    function _notify(body) {
        notifyProc.command = ["sh", "-c", 'qs -c bar ipc call notifications add "$1"',
                              "notify", JSON.stringify({
                                  appName: "velocity.focus",
                                  summary: "FOCUS COMPLETE",
                                  body: body,
                                  urgency: 1 })]   // int tier (0/1/2) — "normal" fell to the low tier
        notifyProc.running = true
    }
}
