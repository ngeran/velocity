// =============================================================================
// AudioService.qml — native PipeWire audio: default sink/source volume + mute,
// plus the SINK LIST for the volume popup's output picker.
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
//   sinks                              tracked audio sinks (default first)
//   micVolume / micMuted / hasMic      default source
//   hwLabel                            short node id for the popup header
// METHODS: setVolume, toggleMute, volumeUp/Down, setDefaultSink(node),
//          setMicVolume, toggleMicMute
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
            " vol=" + volume + " muted=" + muted)
    }
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { tracker.objects = Pipewire.nodes.values }
    }

    // Audio sinks, DEFAULT FIRST. Recomputes on registry changes; the node
    // property population gap (async) self-heals on the next nodes change.
    readonly property var sinks: {
        var out = []
        var objs = tracker.objects.values
        for (var i = 0; i < objs.length; i++) {
            var n = objs[i]
            if (n.isSink === true && !n.isStream) out.push(n)
        }
        out.sort(function(a, b) {
            if (a === root.sink) return -1
            if (b === root.sink) return 1
            return String(a.description).localeCompare(String(b.description))
        })
        return out
    }

    property bool hasAudio: root.sink != null
    property int volume: root.sink
        ? Math.round(Math.min(root.sink.audio.volume, 1.0) * 100) : 0
    property bool muted: root.sink ? root.sink.audio.muted : false

    // Header label — the raw node name is the most honest "device id" we have.
    readonly property string hwLabel: root.sink ? (root.sink.name || "") : ""

    // ── INPUT SOURCE (microphone) ──
    property bool hasMic: root.source != null
    property int micVolume: root.source
        ? Math.round(Math.min(root.source.audio.volume, 1.0) * 100) : 0
    property bool micMuted: root.source ? root.source.audio.muted : false

    function setMicVolume(val) {
        if (!root.source) return
        root.source.audio.volume = Math.max(0, Math.min(100, Math.round(val))) / 100
    }
    function toggleMicMute() {
        if (!root.source) return
        root.source.audio.muted = !root.source.audio.muted
    }

    // Switch the default output — the writable native path (memory #6),
    // wpctl set-default equivalent.
    function setDefaultSink(node) {
        if (!node) return
        Pipewire.preferredDefaultAudioSink = node
    }

    onSinkChanged: console.log("[AudioService] default sink: " +
                               (sink ? sink.description : "none") +
                               (sink ? " vol=" + Math.round(Math.min(sink.audio.volume, 1.0) * 100) : ""))

    onVolumeChanged: if (Config.DebugConfig.debugService)
        console.log("[AudioService] volume " + volume)
    onMutedChanged: if (Config.DebugConfig.debugService)
        console.log("[AudioService] muted " + muted)

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
}
