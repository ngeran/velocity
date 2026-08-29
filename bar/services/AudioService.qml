// =============================================================================
// AudioService.qml — default-sink volume/mute (native PipeWire, event-driven)
// =============================================================================
// Quickshell.Services.Pipewire over the session's PipeWire: zero processes,
// zero timers (replaced the 2.5 s wpctl poll + set/mute one-shot forks).
// Volume/mute arrive as PipeWire events, so the old syncLock optimistic-update
// dance is gone — writes are confirmed by the very event they trigger, and
// external changes (media keys, pactl) update the bar instantly.
//
// PROPERTIES (names unchanged — VolumeIcon/TrayCard untouched)
//   volume  : int   0-100 (audio.volume is a 0..1 float average; >1 boost is
//                   clamped for display, matching the old `wpctl -l 1.0` cap)
//   muted   : bool
//   hasAudio: bool  a default sink exists (false → icons hide, as before)
// METHODS: setVolume(int), toggleMute(), volumeUp(), volumeDown()
// =============================================================================

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../config" as Config

Scope {
    id: root

    // The default sink, followed automatically when the user switches output.
    readonly property var sink: Pipewire.defaultAudioSink

    // PipeWire only populates node properties for tracked objects.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    property bool hasAudio: root.sink != null
    property int volume: root.sink
        ? Math.round(Math.min(root.sink.audio.volume, 1.0) * 100) : 0
    property bool muted: root.sink ? root.sink.audio.muted : false

    // Fires when the registry delivers the default sink (startup) and on every
    // output switch — the journal is the only window into this timing.
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

    Component.onCompleted: console.log("[AudioService] native PipeWire: sink=" +
        (root.sink ? root.sink.description : "none") +
        " vol=" + volume + " muted=" + muted)
}
