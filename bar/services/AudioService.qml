// =============================================================================
// AudioService.qml — native PipeWire audio: default sink/source volume + mute,
// plus the SINK LIST for the volume popup's output picker (P2.2: this is the
// ONE audio service — the settings dashboard's device rows read the same
// instance through HostBridge).
// =============================================================================
// Quickshell.Services.Pipewire over the session's PipeWire: zero processes,
// zero timers for state (volume/mute arrive as PipeWire events — external
// changes like media keys update the bar instantly).
//
// TRACKING (memory: quickshell-native-client-traps #1/#2): ALL nodes are
// tracked and filtered AFTER tracking — filtering untracked nodes
// self-excludes everything; and `objects:` must be assigned imperatively
// (Connections + onCompleted) or the declarative binding evaluates once at
// boot against an empty registry and never re-fires.
//
// WRITES (memory: quickshell-pw-bluez-volume-writes): volume WRITES go
// through `wpctl set-volume`, NOT native `node.audio.volume` — on bluez5
// nodes (Eris 3.5BT, PipeWire 1.6.6) the native write is silently dropped:
// local echo only, never reaches PipeWire (verified: same write lands via
// wpctl; ALSA nodes accept the native write; mute writes land natively on
// both). Reads/mutes stay native (events + mute proven working). When a
// quickshell release fixes pipewire volume writes, revert to native.
//
// PROPERTIES
//   volume / muted / hasAudio          default sink (as before)
//   micVolume / micMuted / hasMic      default source (P4.3: input slider)
//   hwLabel                            short node id for the popup header
//   defaultSink / defaultSource        string ids of the default nodes
//   sinks / sources / sinkInputs       device rows for the settings views:
//                                      { id, name, desc, glyph, isDefault, volume(0-100), mute }
//                                      sinkInputs rows: { id, app, volume, mute }
// METHODS: setVolume, toggleMute, volumeUp/Down, setMicVolume, toggleMicMute
//          (default nodes)
//          setDefaultSink/Source, setSinkVolume, toggleSinkMute,
//          setSinkInputVolume, toggleSinkInputMute, setSourceVolume,
//          toggleSourceMute (per-id; the settings rows)
// =============================================================================

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../config" as Config
import "../lib/audio-classify.mjs" as AudioClassify

Scope {
    id: root

    // The default sink/source, followed automatically when the user switches.
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // String ids (the settings views pass them verbatim; "" if none).
    readonly property string defaultSink: root.sink ? String(root.sink.id) : ""
    readonly property string defaultSource: root.source ? String(root.source.id) : ""

    // PipeWire only populates node properties for tracked objects — track ALL
    // of them; the views filter. The registry signal is `valuesChanged` ON THE
    // NODES MODEL — Pipewire.onNodesChanged does not exist, and the mismatch
    // left the tracker empty forever (volume stuck at 0%). The default sink
    // is ALSO tracked declaratively (re-fires on every output switch — the
    // old, proven pattern) so its volume reads work the moment it appears.
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    PwObjectTracker {
        id: tracker
        objects: []
    }
    // ONE onCompleted handler (two = "Property value set multiple times"):
    // seed the tracker AND the startup log.
    Component.onCompleted: {
        tracker.objects = Pipewire.nodes.values
        console.log("[AudioService] native PipeWire: sink=" +
            (root.sink ? root.sink.description : "none") +
            " vol=" + volume + " muted=" + muted +
            " sinks=" + sinks.length + " sources=" + sources.length)
    }
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { tracker.objects = Pipewire.nodes.values }
    }

    property bool hasAudio: root.sink != null
    property int volume: root.sink
        ? Math.round(Math.min(root.sink.audio.volume, 1.0) * 100) : 0
    property bool muted: root.sink ? root.sink.audio.muted : false

    // Header label — the raw node name is the most honest "device id" we have.
    readonly property string hwLabel: root.sink ? (root.sink.name || "") : ""

    // ── INPUT SOURCE (microphone) ──
    property bool hasMic: root.source != null
    property bool micMuted: root.source ? root.source.audio.muted : false
    property int micVolume: root.source
        ? Math.round(Math.min(root.source.audio.volume, 1.0) * 100) : 0

    // ── DEVICE ROWS (settings dashboard views) ──────────────────────────────
    // Classification (V1, live-verified): playback streams ALSO publish
    // isSink:true and capture streams carry the Source type bit — so the
    // isSink/type-bit filters of the pre-V1 service filed playing apps under
    // OUTPUT and recording apps under INPUT/APPS. Filters now go through
    // classifyNode (node-tested): "sink" = device outputs, "source" = device
    // inputs (audio-bearing, non-stream), "playback" = playback streams only.
    // Descriptor hasAudio passes `n.audio != null`; omarchy's warning about
    // reading .properties before bind applies to CLASSIFICATION only — the
    // classifier here never touches properties.
    readonly property var sinks: {
        const rows = []
        const nodes = Pipewire.nodes.values || []
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (AudioClassify.classifyNode({ isSink: n.isSink, isStream: n.isStream,
                                              hasAudio: n.audio != null }) !== "sink") continue
            rows.push({
                id: String(n.id),
                name: n.description || n.nickname || n.name,
                desc: n.description || n.nickname || n.name,
                // Device glyph for the popup picker (headphones/bluetooth/
                // hdmi/generic) — pure pick in the node-tested lib.
                glyph: AudioClassify.sinkGlyph({
                    name: n.name,
                    description: n.description,
                    nickname: n.nickname,
                    deviceApi: n.properties ? n.properties["device.api"] : "",
                    iconName: n.properties ? n.properties["device.icon-name"] : "",
                    productName: n.properties ? n.properties["device.product.name"] : ""
                }),
                isDefault: root.sink !== null && n.id === root.sink.id,
                volume: Math.round(Math.min(n.audio.volume, 1.0) * 100),
                mute: n.audio.muted
            })
        }
        return rows
    }

    readonly property var sources: {
        const rows = []
        const nodes = Pipewire.nodes.values || []
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (AudioClassify.classifyNode({ isSink: n.isSink, isStream: n.isStream,
                                              hasAudio: n.audio != null }) !== "source") continue
            const name = n.description || n.nickname || n.name
            rows.push({
                id: String(n.id),
                name: name,
                desc: name,
                isDefault: root.source !== null && n.id === root.source.id,
                volume: Math.round(Math.min(n.audio.volume, 1.0) * 100),
                mute: n.audio.muted
            })
        }
        return rows
    }

    readonly property var sinkInputs: {
        const rows = []
        const nodes = Pipewire.nodes.values || []
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (AudioClassify.classifyNode({ isSink: n.isSink, isStream: n.isStream,
                                              hasAudio: n.audio != null }) !== "playback") continue
            rows.push({
                id: String(n.id),
                // application.name is the real app id — Chromium's nickname is
                // the useless literal "Playback" (streamLabel: first non-empty
                // of appName/nickname/name, trimmed).
                app: AudioClassify.streamLabel({
                    appName: n.properties ? n.properties["application.name"] : "",
                    nickname: n.nickname,
                    name: n.name
                }),
                // No 1.0 read clamp: per-app streams may exceed 100% (150%
                // slider max, omarchy parity) — the readout must stay truthful.
                volume: Math.round(n.audio.volume * 100),
                mute: n.audio.muted
            })
        }
        return rows
    }

    onSinkChanged: console.log("[AudioService] default sink: " +
                               (sink ? sink.description : "none") +
                               (sink ? " vol=" + Math.round(Math.min(sink.audio.volume, 1.0) * 100) : ""))

    onVolumeChanged: if (Config.DebugConfig.debugService)
        console.log("[AudioService] volume " + volume)
    onMutedChanged: if (Config.DebugConfig.debugService)
        console.log("[AudioService] muted " + muted)

    // ── VOLUME WRITE PATH (wpctl — see WRITES note in the header) ──────────
    // Later writes for the same node replace the pending one (latest-wins,
    // keyed by node id) — the same queue shape as BluetoothService's
    // actionProc. Spawns are ALSO gap-throttled (_flushGapMs): a drag fires
    // onMoved at ~60Hz, and each spawn's PipeWire event re-evaluates every
    // tracked model (sink rows, streams) — spawning at drag rate stalls the
    // render loop and the handle renders behind the cursor. One wpctl in
    // flight at a time; the trailing flush guarantees the LAST value (the
    // release commit) always lands.
    BoundedProcess {   // bounded: coalesced one-shot volume writes
        id: wpProc
        timeoutMs: 2000
        property string label: ""
        // A timeout/overflow kill suppresses onDone — reschedule here too or
        // the remaining pending writes would sit in the map forever.
        onLimit: function (reason) {
            console.log("[AudioService] " + wpProc.label + " aborted (" + reason + ")")
            root._scheduleFlush()
        }
        onDone: function (out, err, code) {
            if (code !== 0)
                console.log("[AudioService] " + wpProc.label +
                    " failed (exit " + code + "): " + (out + err).trim())
            root._scheduleFlush()
        }
    }

    // Trailing edge of the flush gap: fires while writes are pending but the
    // gap/wpProc isn't ready yet; retries until both clear.
    Timer {
        id: flushGap
        interval: root._flushGapMs
        onTriggered: root._scheduleFlush()
    }

    property var _pendingVol: ({})   // node-id string → float, latest-wins
    readonly property int _flushGapMs: 150
    property real _lastFlushAt: 0

    function _writeVolume(id, fl) {
        root._pendingVol[id] = fl
        root._scheduleFlush()
    }

    // Single flush entry point: flushes now only when idle AND outside the
    // gap, else defers to the trailing timer (restarted, never stacked).
    // A failed spawn (non-zero exit / timeout) DROPS that value: re-queueing
    // would retry-loop a dead node every 2s — the next user interaction
    // rewrites it anyway (and the slider's resync cap re-arms the handle).
    function _scheduleFlush() {
        if (Object.keys(root._pendingVol).length === 0) return
        if (!wpProc.running && Date.now() - root._lastFlushAt >= root._flushGapMs) {
            const ids = Object.keys(root._pendingVol)
            const id = ids[0]
            const fl = root._pendingVol[id]
            delete root._pendingVol[id]
            root._lastFlushAt = Date.now()
            wpProc.label = "set-volume " + id
            wpProc.command = ["wpctl", "set-volume", id, fl.toFixed(3)]
            wpProc.run()
            return
        }
        if (!flushGap.running) flushGap.restart()
    }

    // ── DEFAULT-NODE ACTIONS (bar popup) ──
    function setVolume(val) {
        if (!root.sink) return
        _writeVolume(String(root.sink.id),
            Math.max(0, Math.min(100, Math.round(val))) / 100)
    }

    function toggleMute() {
        if (!root.sink) return
        root.sink.audio.muted = !root.sink.audio.muted
    }

    function volumeUp()   { setVolume(root.volume + 5) }
    function volumeDown() { setVolume(root.volume - 5) }

    function setMicVolume(val) {
        if (!root.source) return
        _writeVolume(String(root.source.id),
            Math.max(0, Math.min(100, Math.round(val))) / 100)
    }

    function toggleMicMute() {
        if (!root.source) return
        root.source.audio.muted = !root.source.audio.muted
    }

    // ── PER-ID ACTIONS (settings device rows) ───────────────────────────────
    function _node(id) {
        const all = Pipewire.nodes.values || []
        for (let i = 0; i < all.length; i++)
            if (String(all[i].id) === String(id)) return all[i]
        return null
    }

    function _volFloat(pct, maxPct) {
        // Accept number (50) or "50%" string from the UI sliders. Devices cap
        // at 100%; per-app streams pass maxPct 150 (omarchy parity).
        var n = typeof pct === "string" ? parseFloat(pct.replace("%", "")) : Number(pct)
        if (isNaN(n)) n = 0
        const max = (typeof maxPct === "number" && maxPct > 0) ? maxPct : 100
        return Math.max(0, Math.min(max, Math.round(n))) / 100
    }

    // Event-driven state — kept for consumer compatibility.
    function refresh() {}

    function setDefaultSink(id) {
        const n = _node(id)
        if (!n) return
        Pipewire.preferredDefaultAudioSink = n
        console.log("[AudioService] default sink → " + n.description)
    }

    function setDefaultSource(id) {
        const n = _node(id)
        if (!n) return
        Pipewire.preferredDefaultAudioSource = n
        console.log("[AudioService] default source → " + n.description)
    }

    function setSinkVolume(id, pct) {
        const n = _node(id); if (n) _writeVolume(String(id), _volFloat(pct))
    }
    function toggleSinkMute(id) {
        const n = _node(id); if (n) n.audio.muted = !n.audio.muted
    }
    function setSinkInputVolume(id, pct) {
        const n = _node(id); if (n) _writeVolume(String(id), _volFloat(pct, 150))
    }
    function toggleSinkInputMute(id) {
        const n = _node(id); if (n) n.audio.muted = !n.audio.muted
    }
    function setSourceVolume(id, pct) {
        const n = _node(id); if (n) _writeVolume(String(id), _volFloat(pct))
    }
    function toggleSourceMute(id) {
        const n = _node(id); if (n) n.audio.muted = !n.audio.muted
    }
}
