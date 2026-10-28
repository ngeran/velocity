// =============================================================================
// LockConfig.qml — the lock root's read-only config sample (singleton)
// =============================================================================
// The lock is a SEPARATE config root: it cannot import the bar's singletons
// (imports escaping a `-c` root fail in the qrc VFS), so it samples the two
// shared files it needs, READ-ONLY, once per process:
//   bar-config.json              → reduceMotion / motionScale (the same root
//                                  keys MotionConfig reads — one contract)
//   ~/.cache/theme/colors.json   → accent / text / textDim / error (the theme
//                                  cache ThemeService writes)
// No watchers, no writes, no forks after the two intake reads — the lock is
// short-lived and idle-zero by construction.
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── motion (same contract as the bar's MotionConfig) ────────────────────
    property bool reduceMotion: false
    property real motionScale: 1.0
    function dur(ms) {
        if (root.reduceMotion) return 0
        var s = root.motionScale
        if (!isFinite(s) || s < 0) s = 1.0
        return Math.max(0, Math.round(ms * s))
    }

    // ── theme sample (defaults = the current palette; replaced by the read) ──
    property color bg: "#000000"          // doctrine: pure black lock surface
    property color text: "#E0E0E0"
    property color textDim: "#73A6CB"
    property color accent: "#DE6145"
    property color errorCol: "#B56758"    // not "error" — QML Item already has one

    // ── one-shot intakes (Process `cat`, the proven zero-fork pattern; the
    //    QtObject root has no default property, so these are property-hosted) ─
    function _parse(json, apply) {
        try { var d = JSON.parse(json); if (d && typeof d === "object") apply(d) } catch (e) {}
    }

    property Process _cfgReader: Process {   // unbounded-ok: one-shot, exits at EOF
        command: ["sh", "-c", 'cat "$1" 2>/dev/null || true', "sh",
                  Quickshell.env("HOME") + "/.config/quickshell/bar-config.json"]
        stdout: SplitParser {
            onRead: function(data) {
                root._parse(data, function(d) {
                    if (d.reduceMotion !== undefined) root.reduceMotion = d.reduceMotion === true
                    if (d.motionScale !== undefined) {
                        var s = Number(d.motionScale)
                        if (isFinite(s) && s >= 0 && s <= 2) root.motionScale = s
                    }
                })
            }
        }
    }

    property Process _themeReader: Process {   // unbounded-ok: one-shot, exits at EOF
        command: ["sh", "-c", 'cat "$1" 2>/dev/null || true', "sh",
                  Quickshell.env("HOME") + "/.cache/theme/colors.json"]
        stdout: SplitParser {
            onRead: function(data) {
                root._parse(data, function(d) {
                    var c = d.colors
                    if (!c) return
                    if (typeof c.text === "string") root.text = c.text
                    if (typeof c.textDim === "string") root.textDim = c.textDim
                    if (typeof c.accent === "string") root.accent = c.accent
                    if (typeof c.error === "string") root.errorCol = c.error
                })
            }
        }
    }

    Component.onCompleted: {
        _cfgReader.running = true
        _themeReader.running = true
    }
}
