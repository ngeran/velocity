// =============================================================================
// PrivacyService.qml — what is watching or listening right now
// =============================================================================
// Mic / camera / screen-share detection from the PipeWire link graph, polled
// through `pw-dump` (bounded read, 3s cadence). Classification lives in
// bar/lib/privacy.mjs (unit-tested): an ACTIVE capture stream fed by a source
// decides the bucket —
//   capture ← mic-like source            → mic
//   capture ← monitor/virtual source     → screen (system audio)
//   video capture ← camera-ish source    → camera
//   video capture ← anything else        → screen (portal screencast)
// Playback streams are nobody's business and never count.
//
// WHY PW-DUMP AND NOT THE NATIVE REGISTRY — verified 2026-09-29 on
// quickshell 0.3.1: Pipewire.nodes/linkGroups populate at connect but never
// live-update (a stream node started AFTER launch never appears; link group
// states stay -1/Unlinked while capture is running). AudioService only works
// around this because sinks persist. The pill needs the transient truth, so
// it polls the source of truth. xray's device domain does the same.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io
import "../lib/privacy.mjs" as Privacy

Item {
    id: root

    // kind → [{ app, pid }] — only kinds with active uses are non-empty
    property var active: ({ mic: [], camera: [], screen: [] })
    readonly property int totalActive: Privacy.activeCount(active)
    readonly property bool hasActive: totalActive > 0

    function appsFor(kind) { return active[kind] || [] }

    // ── sleep inhibitors — who is keeping the machine awake ─────────────
    // Same pill, second detector: systemd-inhibit, filtered to sleep. Runs
    // on a slow cadence (15s — inhibitors change rarely) through the
    // bounded contract like every other shell-out here.
    property var inhibitors: []     // [{ who, why }]
    readonly property bool hasInhibitors: inhibitors.length > 0

    BoundedProcess {
        id: inhProc
        command: ["sh", "-c", "systemd-inhibit --list --json=short 2>/dev/null"]
        timeoutMs: 4000
        maxBytes: 131072
        onDone: function(out) {
            var next = []
            try {
                var arr = JSON.parse(out)
                for (var i = 0; i < arr.length; i++) {
                    var it = arr[i]
                    var what = String(it.What || it.what || "")
                    var mode = String(it.Mode || it.mode || "")
                    // "delay" inhibitors (NetworkManager et al.) are routine
                    // noise — only "block" mode actually keeps the machine up.
                    if (what.indexOf("sleep") === -1 || mode !== "block") continue
                    next.push({
                        who: String(it.Who || it.who || "unknown"),
                        why: String(it.Why || it.why || "")
                    })
                }
            } catch (e) { /* keep previous */ }
            if (JSON.stringify(next) !== JSON.stringify(root.inhibitors))
                root.inhibitors = next
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: inhProc.run()
    }

    // ── pw-dump poll ────────────────────────────────────────────────────
    Process {   // unbounded-ok: one-shot local command — timeout migration queued
        id: dumpProc
        command: ["sh", "-c", "pw-dump 2>/dev/null | head -c 4000000"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { dumpProc.buffer += data + "\n" }
        }
        onStarted: buffer = ""
        onRunningChanged: {
            if (running) return
            var buf = buffer
            buffer = ""
            try { root._ingest(JSON.parse(buf)) }
            catch (e) { /* a torn or empty dump keeps the previous survey */ }
        }
    }

    function _ingest(objs) {
        if (!Array.isArray(objs)) return
        var nodes = {}, links = []
        for (var i = 0; i < objs.length; i++) {
            var o = objs[i]
            if (!o || typeof o !== "object") continue
            var info = o.info || {}
            var props = info.props || {}
            if (o.type === "PipeWire:Interface:Node") {
                nodes[o.id] = {
                    mediaClass: String(props["media.class"] || ""),
                    name: String(props["node.name"] || ""),
                    description: String(props["node.description"] || ""),
                    props: props
                }
            } else if (o.type === "PipeWire:Interface:Link") {
                // Real dump shape (verified): ids sit in INFO as kebab-case
                // "output-node-id"/"input-node-id"; state is the STRING
                // "active" (pw_link_state as text). The props map's
                // "link.output.node" is the fallback spelling.
                var outId = parseInt(info["output-node-id"] !== undefined
                                      ? info["output-node-id"] : props["link.output.node"], 10)
                var inId = parseInt(info["input-node-id"] !== undefined
                                    ? info["input-node-id"] : props["link.input.node"], 10)
                var state = String(info["state"] || "").toLowerCase()
                if (!isNaN(outId) && !isNaN(inId) && (state === "" || state === "active"))
                    links.push({ sourceId: outId, targetId: inId })
            }
        }
        var next = Privacy.surveyPrivacy(nodes, links)
        // New object identity only on real change — the rail binding for the
        // pill's visibility re-fires on every assignment otherwise.
        if (JSON.stringify(next) !== JSON.stringify(root.active))
            root.active = next
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!dumpProc.running) dumpProc.running = true
        }
    }
}
