// =============================================================================
// MprisService.qml — media players over native Quickshell.Services.Mpris
// =============================================================================
// P4.3: the ONE media service — the volume card's NOW PLAYING strip reads
// this (and later the Control Center tile); nothing else imports Mpris.
//
// Delegates never hold native player objects (primitive rows only — the
// documented dangling-C++-ref segfault class). Players and per-player state
// arrive as D-Bus events: zero polling.
//
// PROPERTIES
//   rows        [{ id (dbusName), identity, title, artist, album, isPlaying,
//                  canTogglePlaying, canGoNext, canGoPrevious, canRaise }]
//   hasPlayers  rows.length > 0
//   active      first PLAYING row, else rows[0], else null
// METHODS: togglePlay(id), next(id), previous(id), raise(id)
// =============================================================================

pragma Singleton
import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root
    visible: false

    // The imperative snapshot pattern (AudioService tracker law): a declarative
    // `.values` binding can latch empty when evaluated mid-init and never
    // re-fire; reassign on the model's own signal instead.
    property var _players: []

    Component.onCompleted: _resync()
    Connections {
        target: Mpris.players
        function onValuesChanged() { root._resync() }
    }

    function _resync() {
        root._players = Mpris.players.values || []
    }

    // Primitive rows for the views. Reading each player's properties inside
    // this binding wires the per-player notifies, so track/play flips
    // propagate without a timer.
    readonly property var rows: {
        const out = []
        for (let i = 0; i < root._players.length; i++) {
            const p = root._players[i]
            out.push({
                id: p.dbusName,
                identity: p.identity || p.dbusName,
                title: p.trackTitle || "",
                artist: p.trackArtist || "",
                album: p.trackAlbum || "",
                isPlaying: p.isPlaying,
                canTogglePlaying: p.canTogglePlaying,
                canGoNext: p.canGoNext,
                canGoPrevious: p.canGoPrevious,
                canRaise: p.canRaise
            })
        }
        return out
    }

    readonly property bool hasPlayers: rows.length > 0

    // The strip's player: the first PLAYING one, else the first known.
    readonly property var active: {
        for (let i = 0; i < rows.length; i++)
            if (rows[i].isPlaying) return rows[i]
        return rows.length > 0 ? rows[0] : null
    }

    // Native lookup stays inside the verb call — never stored.
    function _player(id) {
        for (let i = 0; i < root._players.length; i++)
            if (root._players[i].dbusName === id) return root._players[i]
        return null
    }

    function togglePlay(id) { const p = _player(id); if (p) p.togglePlaying() }
    function next(id)       { const p = _player(id); if (p) p.next() }
    function previous(id)   { const p = _player(id); if (p) p.previous() }
    function raise(id)      { const p = _player(id); if (p) p.raise() }

    onRowsChanged: console.log("[MprisService] players " + rows.length +
        (active ? " active=" + active.identity +
         " playing=" + active.isPlaying : ""))
}
