// =============================================================================
// BoundedProcess.qml — the ONE way services shell out (xray config.py +
// omasettings capture(), distilled to velocity's QML-native form).
// =============================================================================
// Every one-shot command gets, by construction:
//   • a TIMEOUT (timeoutMs, default 5s) — a hung tool is killed, not waited on
//   • a BYTE CAP (maxBytes, default 1MB, stderr counted too) — a flooded tool
//     cannot wedge the shell or balloon the buffer
//   • stdout/stderr captured SEPARATELY and rejoined WITH newlines — the
//     SplitParser per-line trap (the TX/RX incident) is structurally
//     impossible: handlers receive finished strings, never chunk soup
//   • latest-wins queuing — run() while busy holds the newest command and
//     starts it on completion; a dropped write can never happen silently
//   • limit callbacks — onLimit("timeout"|"overflow") instead of silence
//
// Usage:
//   BoundedProcess {
//       id: gwProc
//       command: ["sh", "-c", "ip -4 route show default"]
//       onDone: function(out, err, code) { ... }   // out has real newlines
//       onLimit: function(reason) { ... }          // optional
//   }
//   gwProc.run()   // no-ops into the queue while busy — never drops a call
//
// ROOT NOTE: an Item wrapper, not a Process root — Quickshell's Process has
// no default property that accepts the Timer child (discovered by the bar
// failing to load). Everything callers touch is aliased.
//
// Long-lived streams (journal tails, socket2) are a DIFFERENT pattern and
// stay plain `Process` with their own supervision — mark them with a
// `// unbounded-ok:` waiver for tools/check-bounded.
// =============================================================================

import QtQuick
import Quickshell.Io

Item {
    id: bp

    property alias command: proc.command
    property alias running: proc.running   // writable: false = kill (house kill idiom)
    property int timeoutMs: 5000
    property int maxBytes: 1048576
    property var onDone: null        // function(out, err, exitCode)
    property var onLimit: null       // function(reason: "timeout"|"overflow")

    property string _out: ""
    property string _err: ""
    property int _bytes: 0
    property bool _limited: false
    property var _pending: null      // latest-wins: newest command while busy

    Process {
        id: proc
        stdout: SplitParser {
            onRead: function(data) {
                bp._bytes += data.length + 1
                if (bp._bytes > bp.maxBytes) { bp._limit("overflow"); return }
                bp._out += data + "\n"
            }
        }
        stderr: SplitParser {
            onRead: function(data) {
                bp._bytes += data.length + 1
                if (bp._bytes > bp.maxBytes) { bp._limit("overflow"); return }
                bp._err += data + "\n"
            }
        }

        onStarted: {
            bp._out = ""
            bp._err = ""
            bp._bytes = 0
            bp._limited = false
            killTimer.interval = bp.timeoutMs
            killTimer.restart()
        }

        onExited: function(code) {
            killTimer.stop()
            var out = bp._out
            var err = bp._err
            bp._out = ""
            bp._err = ""
            bp._bytes = 0
            if (bp._limited) {
                bp._limited = false
            } else if (bp.onDone) {
                bp.onDone(out, err, code)
            }
            if (bp._pending) {
                var cmd = bp._pending
                bp._pending = null
                bp.command = cmd
                bp.running = true
            }
        }
    }

    Timer {
        id: killTimer
        running: false
        repeat: false
        onTriggered: bp._limit("timeout")
    }

    // Start, or hold the newest command and start it when this proc frees up.
    // Callers never need their own !running guards or pending slots.
    function run() {
        if (bp.running) { bp._pending = bp.command; return }
        bp.running = true
    }

    function _limit(reason) {
        bp._pending = null           // a timed-out probe never chains
        if (!bp._limited) {
            bp._limited = true
            if (bp.running) bp.running = false
            if (bp.onLimit) bp.onLimit(reason)
        }
    }
}
