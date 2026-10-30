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
// PROPERTIES
//   volume / muted / hasAudio          default sink (as before)
//   micMuted / hasMic                  default source
//   hwLabel                            short node id for the popup header
//   defaultSink / defaultSource        string ids of the default nodes
//   sinks / sources / sinkInputs       device rows for the settings views:
//                                      { id, name, desc, isDefault, volume(0-100), mute }
//                                      sinkInputs rows: { id, app, volume, mute }
// METHODS: setVolume, toggleMute, volumeUp/Down, toggleMicMute (default nodes)
//          setDefaultSink/Source, setSinkVolume, toggleSinkMute,
//          setSinkInputVolume, toggleSinkInputMute, setSourceVolume,
//          toggleSourceMute (per-id; the settings rows)
// =============================================================================

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../config" as Config

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

    // ── DEVICE ROWS (settings dashboard views) ──────────────────────────────
    // Flag semantics (verified live): audio nodes carry Audio + Sink/Source.
    // e.g. t=17 = Audio|Sink (a sink), t=9 = Audio|Source (a source).
    readonly property var sinks: {
        const rows = []
        const nodes = Pipewire.nodes.values || []
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (!n.isSink) continue
            rows.push({
                id: String(n.id),
                name: n.description || n.nickname || n.name,
                desc: n.description || n.nickname || n.name,
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
            if (!(n.type & PwNodeType.Source)) continue
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
            if (!n.isStream || !(n.type & PwNodeType.Audio)) continue
            rows.push({
                id: String(n.id),
                app: n.nickname || n.name,
                volume: Math.round(Math.min(n.audio.volume, 1.0) * 100),
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

    // ── DEFAULT-NODE ACTIONS (bar popup) ──
    function setVolume(val) {
        if (!root.sink) return
        root.sink.audio.volume = Math.max(0, Math.min(100, Math.round(val))) / 100
    }

    function toggleMute() {
        if (!root.sink) return
        root.sink.audio.muted = !root.sink.audio.muted
    }

    function volumeUp()   { setVolume(root.volume + 5) }
    function volumeDown() { setVolume(root.volume - 5) }

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

    function _volFloat(pct) {
        // Accept number (50) or "50%" string from the UI sliders
        var n = typeof pct === "string" ? parseFloat(pct.replace("%", "")) : Number(pct)
        if (isNaN(n)) n = 0
        return Math.max(0, Math.min(100, Math.round(n))) / 100
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
        const n = _node(id); if (n) n.audio.volume = _volFloat(pct)
    }
    function toggleSinkMute(id) {
        const n = _node(id); if (n) n.audio.muted = !n.audio.muted
    }
    function setSinkInputVolume(id, pct) {
        const n = _node(id); if (n) n.audio.volume = _volFloat(pct)
    }
    function toggleSinkInputMute(id) {
        const n = _node(id); if (n) n.audio.muted = !n.audio.muted
    }
    function setSourceVolume(id, pct) {
        const n = _node(id); if (n) n.audio.volume = _volFloat(pct)
    }
    function toggleSourceMute(id) {
        const n = _node(id); if (n) n.audio.muted = !n.audio.muted
    }
}
