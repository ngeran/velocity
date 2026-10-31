// RegionPicker.qml — the ONE slurp region picker (shared: velocity.record +
// velocity.shot). pick() runs slurp interactively — the process lives until
// the user draws a box; Esc = exit 1 = a silent abort. Emits picked(geometry)
// with slurp's "x,y WxH" line. A pick already running is ignored (slurp is
// single-user; a second request would stack two grabs).
import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool picking: false
    signal picked(string geometry)

    function pick() {
        if (root.picking) return
        root.picking = true
        proc.running = true
    }

    // slurp prints one line "x,y WxH" — SplitParser is exact here (per-line,
    // newline stripped; single line in, single line out).
    property string _geometry: ""
    Process {   // unbounded-ok: interactive region pick, lives until the user draws
        id: proc
        running: false
        command: ["slurp", "-b", "#00000055", "-c", "#00dce5", "-w", "2"]
        stdout: SplitParser {
            onRead: function(data) { root._geometry = data.trim() }
        }
        onExited: function(code, status) {
            root.picking = false
            var geom = root._geometry
            root._geometry = ""
            if (code !== 0) {
                if (code !== 1) console.warn("[region-picker] slurp exited " + code)
                return   // Esc-cancelled pick — silent
            }
            if (geom.length === 0) return
            root.picked(geom)
        }
    }
}
