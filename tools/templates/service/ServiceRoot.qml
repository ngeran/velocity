// {{ID}} — headless service with a self-installing native runtime (api 2).
// On enable it runs install.sh once: the script serializes itself (flock)
// and skips an unchanged runtime via a content-hash marker, so re-enables
// and updates are cheap no-ops. Output lands in the state log; ready /
// installing / error surface through the `status` IPC verb:
//   velocity-plugin call {{ID}} status ""      (state)
//   velocity-plugin call {{ID}} setup ""       (re-run; "force" re-executes
//                                               the install steps)
// `ctx` is injected. Plugin dirs load from file://, so Qt.resolvedUrl can
// reach install.sh — and install.sh may write anywhere the user can, which
// is the whole point of a runtime bootstrap.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var ctx: null

    // ── runtime bootstrap ─────────────────────────────────────────────────────
    readonly property string installer: decodeURIComponent(String(Qt.resolvedUrl("install.sh")).replace(/^file:\/\//, ""))
    readonly property string logPath: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") || "") + "/.local/state") + "/velocity/plugins/{{ID}}/install.log"
    // Empty args run install.sh plainly (it still no-ops when unchanged);
    // the setup verb's "force" argument re-executes the install steps.
    property string setupArgs: ""
    property bool setupRan: false
    property string error: ""

    readonly property bool installing: setup.running
    readonly property bool ready: setupRan && !installing && setup.exitCode === 0
    readonly property string statusText: error !== "" ? error : (installing ? "Setting up {{NAME}}…" : "")

    Component.onCompleted: setup.running = true

    Process {   // bounded: timeout guards against a hung installer
        id: setup
        command: ["timeout", "300", "bash", "-c",
            // A copy without install.sh (standalone checkout) counts as
            // already set up — exit 0 and do nothing.
            'if [[ -f "$1" ]]; then mkdir -p "${2%/*}" && exec bash "$1" $3 >"$2" 2>&1; fi',
            "{{ID}}-setup", root.installer, root.logPath, root.setupArgs]
        onRunningChanged: {
            if (running) return
            setupRan = true
            if (exitCode === 0) {
                root.error = ""
            } else {
                root.error = "runtime setup failed (exit " + exitCode + ") — see " + root.logPath
                console.warn("{{ID}}: " + root.error)
            }
        }
    }

    // ── manifest.ipc verbs ─────────────────────────────────────────────────────
    function status(arg) {
        return JSON.stringify({ ready: root.ready, installing: root.installing,
                                error: root.error, log: root.logPath })
    }
    function setup(arg) {
        if (root.installing) return "setup already running"
        root.setupArgs = String(arg || "").trim() === "force" ? "--force" : ""
        root.setupRan = false
        root.error = ""
        setup.running = true
        return "ok"
    }
}
