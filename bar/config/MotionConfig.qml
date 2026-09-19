// =============================================================================
// bar/config/MotionConfig.qml — Motion token singleton
// =============================================================================
//
// Port of ryoku-arch's ui/Singletons/Tokens.qml motion section (trimmed to
// what a bar needs). Four durations, two curves, one global scale — nothing
// else. Rule (ryoku docs/ui-ux.md): read the token, never write a literal,
// never wrap a token in dur() again (double-scaling).
//
//   snap  90ms  hover / press / state flip
//   flap 110ms  a value changing
//   move 170ms  a selector travelling
//   swap 210ms  content exchanging (also the palette cross-fade duration)
//
// dur(ms) applies motionScale and collapses to 0 under reduceMotion, so every
// adopter gets global speed control + accessibility for free. Optional keys
// "reduceMotion" (bool) and "motionScale" (0..2) are read from bar-config.json
// through the same zero-fork FileView intake BarConfig uses.
//
// SYNC WITH: settings/config/MotionConfig.qml — token values, dur(), and the
// intake mechanism MUST stay identical (separate processes; only the watched
// file name differs: bar-config.json vs settings-config.json).
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

Item {
    id: root
    visible: false

    property bool reduceMotion: false
    property real motionScale: 1.0

    readonly property int snap: root.dur(90)
    readonly property int flap: root.dur(110)
    readonly property int move: root.dur(170)
    readonly property int swap: root.dur(210)

    // ease = OutCubic for everything; easeSnap = OutQuad for micro-interactions
    // (hover fills, knob slides) where the OutCubic tail feels late.
    readonly property int ease: Easing.OutCubic
    readonly property int easeSnap: Easing.OutQuad

    function dur(ms) {
        if (root.reduceMotion) return 0
        var s = root.motionScale
        if (!isFinite(s) || s < 0) s = 1.0
        return Math.max(0, Math.round(ms * s))
    }

    // ── optional user keys from bar-config.json (zero-fork intake) ──────────
    readonly property string configPath: (StandardPaths.writableLocation(StandardPaths.HomeLocation).toString() + "/.config/quickshell/bar-config.json").replace("file://", "")
    property string _lastRaw: ""

    function ingestMotionText(raw) {
        var text = (raw || "").trim()
        if (text.length === 0 || text === root._lastRaw) return
        root._lastRaw = text
        try {
            var data = JSON.parse(text)
            if (data.reduceMotion !== undefined)
                root.reduceMotion = (data.reduceMotion === true)
            if (data.motionScale !== undefined) {
                var s = Number(data.motionScale)
                if (isFinite(s) && s >= 0 && s <= 2) root.motionScale = s
            }
        } catch (e) {
            // mid-write or foreign JSON — keep current values
        }
    }

    FileView {
        id: motionFile
        path: root.configPath
        watchChanges: true
        printErrors: false
        onFileChanged: root.ingestMotionText(motionFile.text())
        onTextChanged: root.ingestMotionText(text())
        Component.onCompleted: root.ingestMotionText(motionFile.text())
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            motionFile.reload()
            root.ingestMotionText(motionFile.text())
        }
    }
}
