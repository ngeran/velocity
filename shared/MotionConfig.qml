// =============================================================================
// shared/MotionConfig.qml — Motion token singleton (canonical, synced copy)
// =============================================================================
//
// CANONICAL SOURCE: this file is the source of truth; bar/config/ and
// settings/config/ hold byte-identical copies (tools/sync-shared). The two
// shells are separate `-c` roots and Quickshell's VFS blocks imports that
// escape the root, so the file is SYNCED, not imported across — editing a
// root copy directly will fail tools/check-shared.
//
// Port of ryoku-arch's ui/Singletons/Tokens.qml motion section (trimmed to
// what a shell needs). Four durations, two curves, one global scale — nothing
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
// "reduceMotion" (bool) and "motionScale" (0..2) are read from the ROOT's
// config json (bar-config.json in the bar shell, settings-config.json in the
// settings shell) through the same zero-fork FileView intake the configs use.
//
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

    // ── which root's config json to watch ───────────────────────────────────
    // Derived from where THIS copy lives ("…/quickshell/<root>/config/"), so
    // every synced copy is byte-identical yet watches its own shell's file.
    // Falls back to "bar" for exotic layouts.
    readonly property string _rootName: {
        var here = Qt.resolvedUrl("MotionConfig.qml").toString()
        var cut = here.indexOf("/config/")
        var start = cut > 0 ? here.lastIndexOf("/", cut - 1) : -1
        return (cut > 0 && start > 0) ? here.substring(start + 1, cut) : "bar"
    }
    readonly property string configPath: (StandardPaths.writableLocation(StandardPaths.HomeLocation).toString() + "/.config/quickshell/" + root._rootName + "-config.json").replace("file://", "")
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
