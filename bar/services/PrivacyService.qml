// =============================================================================
// PrivacyService.qml — what is watching or listening right now
// =============================================================================
// Mic / camera / screen-share detection from the NATIVE PipeWire registry
// (zero forks — same service AudioService uses). A privacy use is an ACTIVE
// link group feeding a CAPTURE stream; what is being captured decides the
// bucket (see bar/lib/privacy.mjs for the rules + tests).
//
//   capture stream ← mic-like source            → mic
//   capture stream ← monitor/virtual source     → screen (system audio)
//   video capture ← camera-ish source           → camera
//   video capture ← anything else (portal)      → screen (screencast)
//
// Playback streams are nobody's business and never count.
//
// REFRESH — event-driven where the registry allows (valuesChanged on both
// models) plus a 2s reconcile: link state flips (Paused → Active) and the
// async property population gap AudioService documents don't fire registry
// signals. Cost is a walk of a few dozen objects — nothing.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../lib/privacy.mjs" as Privacy

Item {
    id: root

    // kind → [{ app, pid }] — only kinds with active uses are non-empty
    property var active: ({ mic: [], camera: [], screen: [] })
    readonly property int totalActive: Privacy.activeCount(active)
    readonly property bool hasActive: totalActive > 0

    function appsFor(kind) { return active[kind] || [] }

    // ── recompute ───────────────────────────────────────────────────────
    function recompute() {
        var nodes = {}
        var nvals = Pipewire.nodes.values
        for (var i = 0; i < nvals.length; i++) {
            var n = nvals[i]
            if (!n || !n.ready) continue
            nodes[n.id] = {
                mediaClass: String(n.properties["media.class"] || ""),
                name: String(n.name || ""),
                description: String(n.description || ""),
                props: n.properties || {}
            }
        }
        var links = []
        var gvals = Pipewire.linkGroups.values
        for (var j = 0; j < gvals.length; j++) {
            var g = gvals[j]
            // PwLinkState.Active (integer in case the singleton enum fails
            // to resolve: Error0 Unlinked1 Init2 Negotiating3 Allocating4
            // Paused5 Active6)
            if (!g || g.state !== PwLinkState.Active) continue
            if (!g.source || !g.target) continue
            links.push({ sourceId: g.source.id, targetId: g.target.id })
        }
        var next = Privacy.surveyPrivacy(nodes, links)
        // New object identity only on real change — the rail binding for the
        // pill's visibility re-fires on every assignment otherwise.
        if (JSON.stringify(next) !== JSON.stringify(root.active))
            root.active = next
    }

    Connections {
        target: Pipewire.nodes
        // The registry signal lives on the MODEL (AudioService's finding):
        // Pipewire.onNodesChanged does not exist.
        function onValuesChanged() { root.recompute() }
    }
    Connections {
        target: Pipewire.linkGroups
        function onValuesChanged() { root.recompute() }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.recompute()
    }

    Component.onCompleted: recompute()
}
