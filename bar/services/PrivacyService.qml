// =============================================================================
// PrivacyService.qml — what is watching or listening right now
// =============================================================================
// Mic / camera / screen-share detection from the PipeWire link graph,
// EVENT-DRIVEN (T1.1): a long-lived `pw-mon` watcher (one process for the
// service's lifetime) marks the graph dirty on every event line; a 250 ms
// debounce collapses a burst into ONE bounded `pw-dump` survey. Classification
// lives in bar/lib/privacy.mjs (unit-tested): an ACTIVE capture stream fed by
// a source decides the bucket —
//   capture ← mic-like source            → mic
//   capture ← monitor/virtual source     → screen (system audio)
//   video capture ← camera-ish source    → camera
//   video capture ← anything else        → screen (portal screencast)
// Playback streams are nobody's business and never count.
//
// WHY NOT THE NATIVE REGISTRY — verified 2026-09-29 on quickshell 0.3.1:
// Pipewire.nodes/linkGroups populate at connect but never live-update (a
// stream node started AFTER launch never appears; link group states stay
// -1/Unlinked while capture is running). AudioService only works around this
// because sinks persist. The pill needs the transient truth.
// WHY NOT A FIXED pw-dump POLL — the old 3 s cadence forked 20×/min while the
// graph sat still; now the survey only runs when something actually changed
// (zero forks at idle, and sub-second reaction when it isn't).
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

    // ── DEMAND GATE — zero forks while nobody is listening ─────────────
    // The watcher + surveyors only run while a consumer exists: the
    // velocity.privacy pill increments iconDemandCount while MOUNTED (not
    // while visible — an idle pill must still catch the first stream or it
    // could never light up; refcounted so several mounts can share one
    // demand), the tray privacy body sets bodyDemanded while open. Plugin
    // disabled + body closed → this service idles.
    property int iconDemandCount: 0
    property bool bodyDemanded: false
    readonly property bool demanded: iconDemandCount > 0 || bodyDemanded
    onDemandedChanged: {
        pwRespawn.stop()
        if (demanded) {
            _pwFailCount = 0
            pwWatch.running = true
        } else {
            pwWatch.running = false
        }
    }

    // ── sleep inhibitors — who is keeping the machine awake ─────────────
    // Same pill, second detector: systemd-inhibit, filtered to sleep. The
    // pill RENDERS inhibitors (hasInhibitors feeds its visibility), so this
    // keeps polling while demanded — on a slow 60 s cadence (inhibitors
    // change rarely) through the bounded contract like every other shell-out
    // here.
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
        interval: 60000
        running: root.demanded
        repeat: true
        triggeredOnStart: true
        onTriggered: inhProc.run()
    }

    // ── graph watcher + debounced survey ────────────────────────────────
    // Every pw-mon line marks the survey dirty and resets the respawn
    // ladder (a line means the pipe is alive). The 250 ms debounce turns a
    // burst of events into a single pw-dump.
    property int _pwFailCount: 0
    property string _pwPending: ""      // pw-mon marker awaiting its type line
    function _pwDelay() { return [250, 1000, 5000, 30000][Math.min(_pwFailCount - 1, 3)] }
    function _graphDirty() {
        _pwFailCount = 0
        dumpDebounce.restart()
    }

    Process {   // unbounded-ok: long-lived pw-mon graph watcher (T1.1); stdout
                // is consumed line-by-line and discarded — nothing buffers
        id: pwWatch
        command: ["pw-mon", "-N"]
        stdout: SplitParser {
            onRead: function(line) {
                // pw-mon block shape (verified live): a marker line first
                // (added:/removed:/changed:), then "id:", then — EXCEPT for
                // removed: — a "type: PipeWire:Interface:<T>" header. Only
                // Node/Link/Port events mark the survey dirty: every pw-dump
                // we run registers itself as a graph CLIENT, so reacting to
                // Client churn would survey in an endless loop (observed:
                // dump → "added: Client" → dump, 50% core). A removed: block
                // never finds its type line, so it stays inert until the next
                // marker — removals are picked up via the follow-up Port/Node
                // churn they cause.
                var s = "" + line
                var t = s.trim()
                if (t === "added:" || t === "removed:" || t === "changed:") {
                    root._pwPending = t
                    return
                }
                if (root._pwPending === ""
                        || s.indexOf("type: PipeWire:Interface:") < 0) return
                root._pwPending = ""
                // Anchor the cut at indexOf — lines are tab-indented, so a
                // bare substring(prefix.length) lands one char early.
                var at = s.indexOf("type: PipeWire:Interface:")
                var kind = s.substring(at + "type: PipeWire:Interface:".length)
                                .split(" ")[0]
                if (kind === "Node" || kind === "Link" || kind === "Port")
                    root._graphDirty()
            }
        }
        onExited: {
            if (!root.demanded) return   // intentional stop, not a failure
            _pwFailCount++
            console.warn("[PrivacyService] pw-mon exited — retrying in",
                         root._pwDelay(), "ms (fail", _pwFailCount + ")")
            pwRespawn.interval = root._pwDelay()
            pwRespawn.restart()
        }
    }

    Timer {
        id: pwRespawn
        running: false
        repeat: false
        onTriggered: if (root.demanded) pwWatch.running = true
    }

    Timer {
        id: dumpDebounce
        interval: 250
        running: false
        repeat: false
        onTriggered: dumpProc.run()
    }

    BoundedProcess {   // bounded: one-shot pw-dump survey (P8.1)
        id: dumpProc
        timeoutMs: 8000              // pw-dump on a loaded graph can take seconds
        maxBytes: 4194304            // the old head -c 4000000 cap, preserved
        command: ["sh", "-c", "pw-dump 2>/dev/null"]
        onDone: function (out) {
            try { root._ingest(JSON.parse(out)) }
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

    // Belt-and-braces for exotic hot-reload orders (body open while this
    // singleton is swapped): make sure the watcher reflects current demand.
    Component.onCompleted: pwWatch.running = root.demanded
}
