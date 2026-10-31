// =============================================================================
// velocity.shot — headless screenshot service (P7 G2, kinds ["service"])
// =============================================================================
// ONE root per session (service/view split). grim + slurp, J8-style tool
// probe: absent → verbs answer honestly ("unavailable: …") + one journal
// line at mount.
//
// Flow: `region` → the SHARED components/RegionPicker (the exact interaction
// velocity.record uses) → `output`/`window` → one `hyprctl -j` probe for the
// focused monitor / active window geometry → mkdir -p ~/Pictures/Screenshots
// → grim → the file is BOTH saved (<ts>.png) and copied (wl-copy). On
// success the toast card shows: thumbnail · filename · EDIT (swappy) /
// OPEN (folder) — the spec's notification surface. Esc during a pick is a
// silent abort; probe/capture failures journal once and reset.
//
// QD-OLED: the toast is transient (5 s, then fades) on pure black with a
// 1px hairline — no static fills outlive it, nothing polls while idle.
// Plugin-kit sizing law: every literal rides ctx.bar.uiScale (Math.round),
// the same math Ui/PluginPopup uses — PopupMetrics lives in the bar tree.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../components" as Components

Item {
    id: root

    property var ctx: null

    // ── state ────────────────────────────────────────────────────────────────
    property bool supported: false
    property string lastFile: ""

    readonly property string shotsDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    // plugin-kit tokens (ctx may be null for a beat at mount)
    readonly property real s: ctx && ctx.bar ? ctx.bar.uiScale : 1
    function px(n) { return Math.round(n * s) }
    readonly property var theme: ctx ? ctx.theme : null
    readonly property var bar: ctx ? ctx.bar : null

    Component.onCompleted: probe.running = true

    // ── verbs (manifest.ipc, via PluginRegistry.call) ────────────────────────
    function region() {
        if (!root.supported) return "unavailable: grim/slurp/wl-copy missing (omni-nix)"
        picker.pick()
        return "ok"
    }

    function output() {
        if (!root.supported) return "unavailable: grim/slurp/wl-copy missing (omni-nix)"
        _mode = "output"
        geoProbe.query = ["bash", "-c", "hyprctl activeworkspace -j 2>&1"]
        geoProbe.running = true
        return "ok"
    }

    function window() {
        if (!root.supported) return "unavailable: grim/slurp/wl-copy missing (omni-nix)"
        _mode = "window"
        geoProbe.query = ["bash", "-c", "hyprctl activewindow -j 2>&1"]
        geoProbe.running = true
        return "ok"
    }

    function status() {
        return JSON.stringify({ lastFile: root.lastFile, dir: root.shotsDir })
    }

    // ── capture chain: probe → mkdir → grim → wl-copy → toast ────────────────
    property string _mode: ""
    property string _geometry: ""
    property string _monitor: ""

    // The hyprctl geometry probe (output/window modes). Buffer-rejoin parse
    // on running change — the HyprlandService seed idiom (onExited ordering
    // is not guaranteed against stdout delivery).
    property string _probeOut: ""
    Process {   // unbounded-ok: one-shot local IPC query — answers in ms
        id: geoProbe
        property var query: []
        command: query
        running: false
        stdout: SplitParser { onRead: function(data) { root._probeOut += data + "\n" } }
        onRunningChanged: {
            if (running) return
            var out = root._probeOut
            root._probeOut = ""
            try {
                var obj = JSON.parse(out)
                if (root._mode === "output") {
                    root._monitor = obj.monitor || ""
                    if (root._monitor === "") throw new Error("no monitor on active workspace")
                } else {
                    var at = obj.at, size = obj.size
                    if (!Array.isArray(at) || !Array.isArray(size)) throw new Error("no geometry")
                    root._geometry = at[0] + "," + at[1] + " " + size[0] + "x" + size[1]
                }
                mkdirProc.running = true
            } catch (e) {
                root._mode = ""
                console.warn("[velocity.shot] geometry probe failed:", e.message || e)
            }
        }
    }

    Components.RegionPicker {
        id: picker
        onPicked: function(geometry) {
            root._mode = "region"
            root._geometry = geometry
            mkdirProc.running = true
        }
    }

    Process {   // unbounded-ok: one-shot mkdir before every capture
        id: mkdirProc
        running: false
        command: ["sh", "-c", 'mkdir -p "$1"', "mkdir", root.shotsDir]
        onExited: function(code, status) {
            if (code !== 0) {
                root._reset()
                console.warn("[velocity.shot] mkdir failed — " + root.shotsDir + " not writable")
                return
            }
            root._capture()
        }
    }

    function _capture() {
        var ts = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss")
        root.lastFile = root.shotsDir + "/" + ts + ".png"
        var argv = ["grim"]
        if (root._mode === "output") argv.push("-o", root._monitor)
        else argv.push("-g", root._geometry)   // region + window both ride -g
        argv.push(root.lastFile)
        grimProc.command = argv
        grimProc.running = true
    }

    Process {   // unbounded-ok: one-shot capture, exits with grim
        id: grimProc
        running: false
        onExited: function(code, status) {
            var file = root.lastFile
            root._reset()
            if (code !== 0) {
                console.warn("[velocity.shot] grim exited " + code)
                return
            }
            copyProc.command = ["sh", "-c", 'wl-copy < "$1"', "copy", file]
            copyProc.running = true
            toast.show(file)
        }
    }

    Process {   // unbounded-ok: wl-copy serves the clipboard from a detached child
        id: copyProc
        running: false
        onExited: function(code, status) {
            if (code !== 0) console.warn("[velocity.shot] wl-copy exited " + code)
        }
    }

    function _reset() {
        root._mode = ""
        root._geometry = ""
        root._monitor = ""
    }

    // ── tool probe (one-shot at mount) ───────────────────────────────────────
    Process {   // unbounded-ok: one-shot tool probe at mount
        id: probe
        // presence check (command -v) — slurp rejects --help, grim needs a target
        command: ["sh", "-c", "command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1"]
        // commands-ok: the shell builtin doing the presence probe — the
        // external tools it checks are already declared in manifest.commands.
        running: false
        onExited: function(code, status) {
            root.supported = (code === 0)
            if (code !== 0)
                console.log("[velocity.shot] grim/slurp/wl-copy not found — shot verbs unavailable " +
                            "(add grim + wl-clipboard in omni-nix)")
        }
    }

    // toast button (text-only, no fills — QD-OLED); VolumeBody MediaButton idiom
    component ToastButton: Text {
        signal activated()
        font.family: root.bar ? root.bar.fontFamily : "monospace"
        font.pixelSize: root.px(12)
        font.bold: true
        color: area.containsMouse
               ? (root.bar ? root.bar.colorAccent : "#00dce5")
               : (root.theme ? root.theme.colors.textDim : "#888888")
        opacity: toast.shown ? 1.0 : 0.0
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.activated()
        }
    }

    // ── the toast card (transient capture feedback) ──────────────────────────
    // Full-screen transparent surface with the input region clipped to the
    // card: buttons work, everything around stays click-through (the Osd
    // window's contract, plus input). Dies with the fade.
    PanelWindow {
        id: toastWindow

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "bar-shot-toast"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        // Input only over the card (+ a slop ring for the pointer). Region has
        // no margins of its own, so the ring is baked into the geometry.
        mask: Region {
            x: card.x - 8; y: card.y - 8
            width: card.width + 16; height: card.height + 16
            radius: card.radius + 8
        }

        // A layer surface has no opacity of its own — the fade lives on the
        // card, and the window closes once the fade has passed 0 (Osd idiom).
        visible: card.opacity > 0.01

        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            // Bottom-center, clear of the bar in both edge positions.
            y: parent.height - height - root.px(
                   (root.bar && root.bar.barAtBottom ? root.bar.barHeight : 0) + 24)
            width: row.implicitWidth + root.px(28)
            height: root.px(84)
            color: "#000000"
            radius: root.px(14)
            border.width: 1
            border.color: root.theme ? root.theme.colors.border : "#22ffffff"
            opacity: toast.shown ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 220 } }

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: root.px(14)

                Image {
                    Layout.preferredWidth: root.px(96)
                    Layout.preferredHeight: root.px(60)
                    source: toast.shown && toast.file !== "" ? "file://" + toast.file : ""
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    asynchronous: true
                }

                ColumnLayout {
                    spacing: root.px(6)

                    Text {
                        text: {
                            if (!toast.shown || toast.file === "") return ""
                            var parts = toast.file.split("/")
                            return parts[parts.length - 1]
                        }
                        color: root.theme ? root.theme.colors.text : "#dddddd"
                        font.family: root.bar ? root.bar.fontFamily : "monospace"
                        font.pixelSize: root.px(12)
                    }

                    RowLayout {
                        spacing: root.px(16)

                        ToastButton {
                            text: "EDIT"
                            onActivated: {
                                if (toast.shown && root.ctx && root.ctx.run(["swappy", "-f", toast.file]))
                                    toast.dismiss()
                            }
                        }
                        ToastButton {
                            text: "OPEN"
                            onActivated: {
                                if (toast.shown && root.ctx &&
                                    root.ctx.run(["xdg-open", root.shotsDir]))
                                    toast.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: toast
        property bool shown: false
        property string file: ""
        function show(file) {
            toast.file = file
            toast.shown = true
            fadeOut.restart()
        }
        function dismiss() {
            fadeOut.stop()
            toast.shown = false
            fadeAway.restart()   // let the fade-out animation finish
        }
    }

    // Auto-dismiss: 5 s of stillness, then fade — the card never parks bright.
    Timer { id: fadeOut; interval: 5000; onTriggered: toast.shown = false }
    Timer { id: fadeAway; interval: 260; onTriggered: toast.file = "" }
}
