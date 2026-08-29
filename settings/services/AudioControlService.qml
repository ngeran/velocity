// =============================================================================
// AudioControlService.qml — WirePlumber control via native PipeWire
// =============================================================================
// Event-driven replacement for the wpctl poll pair (`wpctl status` every 3s +
// a per-node `wpctl get-volume` loop): node state arrives as PipeWire events,
// volume/mute/default changes are property writes confirmed by the events
// they trigger. Zero forks while the dashboard is open.
//
// The public API is byte-compatible with the wpctl version — ids are STRINGS
// (the old regex ids were strings; consumers compare/pass them verbatim):
//   sinks/sources:  { id, name, desc, isDefault, volume(0-100), mute }
//   sinkInputs:     { id, app, volume(0-100), mute }
//   defaultSink/defaultSource: string id of the default node ("" if none)
//
// Node classes: isSink → sinks; AudioDuplex/AudioSource flags → sources
// (duplex devices appear in both, as in wpctl's tree); isStream+Audio →
// sinkInputs (video streams excluded).
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../config" as Config

Item {
    id: root
    visible: false

    property string defaultSink: Pipewire.defaultAudioSink
        ? String(Pipewire.defaultAudioSink.id) : ""
    property string defaultSource: Pipewire.defaultAudioSource
        ? String(Pipewire.defaultAudioSource.id) : ""

    // -------------------------------------------------------------------------
    // NATIVE STATE — ALL nodes tracked, THEN filtered
    // -------------------------------------------------------------------------
    // TRACKER ORDERING (the deadlock trap, twice over): node props (isSink/
    // type/volume) only populate once tracked, and a DECLARATIVE objects
    // binding over nodes.values evaluates once at boot (empty) and never
    // re-fires — the tracker stays empty forever on a fresh start. Assign
    // imperatively: once at construction, then on every values change.
    PwObjectTracker {
        id: nodeTracker
        objects: []
    }
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() {
            nodeTracker.objects = Pipewire.nodes.values || []
        }
    }
    // (tracker's boot assignment lives in the single onCompleted at the bottom)

    // Flag semantics (verified live): audio nodes carry Audio + Sink/Source.
    // e.g. t=17 = Audio|Sink (a sink), t=9 = Audio|Source (a source).
    readonly property var _audioNodes: {
        const all = Pipewire.nodes.values || []
        const out = []
        for (let i = 0; i < all.length; i++) {
            const n = all[i]
            if (n.isSink || n.isStream || (n.type & PwNodeType.Source))
                out.push(n)
        }
        return out
    }

    readonly property var sinks: {
        const dflt = Pipewire.defaultAudioSink
        const rows = []
        const nodes = root._audioNodes
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (!n.isSink) continue
            rows.push({
                id: String(n.id),
                name: n.description || n.nickname || n.name,
                desc: n.description || n.nickname || n.name,
                isDefault: dflt !== null && n.id === dflt.id,
                volume: Math.round(Math.min(n.audio.volume, 1.0) * 100),
                mute: n.audio.muted
            })
        }
        return rows
    }

    readonly property var sources: {
        const dflt = Pipewire.defaultAudioSource
        const rows = []
        const nodes = root._audioNodes
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (!(n.type & PwNodeType.Source)) continue
            const name = n.description || n.nickname || n.name
            rows.push({
                id: String(n.id),
                name: name,
                desc: name,
                isDefault: dflt !== null && n.id === dflt.id,
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

    Component.onCompleted: {
        nodeTracker.objects = Pipewire.nodes.values || []
        console.log("[AudioControl] native PipeWire: sinks=" +
            sinks.length + " sources=" + sources.length + " streams=" + sinkInputs.length)
    }

    // Registry enumeration is async — log the settled counts (hotplug visible).
    onSinksChanged: console.log("[AudioControl] sinks now " + sinks.length +
        " default=" + defaultSink)
    onSourcesChanged: console.log("[AudioControl] sources now " + sources.length)
    onSinkInputsChanged: console.log("[AudioControl] streams now " + sinkInputs.length)

    // -------------------------------------------------------------------------
    // NODE LOOKUP + VOLUME MATH
    // -------------------------------------------------------------------------
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

    // Event-driven — kept for consumer compatibility (was: re-run statusProc).
    function refresh() {}

    // -------------------------------------------------------------------------
    // ACTIONS — property writes, confirmed by the events they trigger
    // -------------------------------------------------------------------------
    function setDefaultSink(id) {
        const n = _node(id)
        if (!n) return
        Pipewire.preferredDefaultAudioSink = n
        CommandService.pushLog("[audio] default sink → " + n.description, "output")
    }

    function setDefaultSource(id) {
        const n = _node(id)
        if (!n) return
        Pipewire.preferredDefaultAudioSource = n
        CommandService.pushLog("[audio] default source → " + n.description, "output")
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

    // Default-node convenience (bar AudioService parity)
    function _find(id, arr) {
        for (let i = 0; i < arr.length; i++) if (arr[i].id === id) return arr[i]
        return null
    }
    function volumeUp() {
        const s = _find(root.defaultSink, root.sinks)
        if (root.defaultSink) setSinkVolume(root.defaultSink, (s ? s.volume : 50) + 5)
    }
    function volumeDown() {
        const s = _find(root.defaultSink, root.sinks)
        if (root.defaultSink) setSinkVolume(root.defaultSink, (s ? s.volume : 50) - 5)
    }
    function toggleMute()    { if (root.defaultSink) toggleSinkMute(root.defaultSink) }
    function toggleMicMute() { if (root.defaultSource) toggleSourceMute(root.defaultSource) }
}
