// =============================================================================
// nikos.artcraft — headless service root (entryPoints.service)
// =============================================================================
// ONE instance per bar process. It owns the ArtCraft state:
//   * runs `artcraft-check` when the bar starts (and on a timer)
//   * watches $XDG_STATE_HOME/artcraft/status.json
//   * starts `artcraft-upgrade [app]` as a detached systemd user unit
//   * watches $XDG_STATE_HOME/artcraft/progress.json while an upgrade runs
//   * publishes the live progress through ctx.island
//
// The upgrade is deliberately detached: `nixos-rebuild switch` can restart
// quickshell-bar, and a direct child would die with the bar. The script writes
// progress.json, so the next bar process picks the upgrade back up.
// =============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.platform
import "lib/artcraft.mjs" as A

Item {
    id: root

    width: 0
    height: 0

    property var ctx: null

    readonly property string stateDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/artcraft"
    readonly property string statusPath: stateDir + "/status.json"
    readonly property string progressPath: stateDir + "/progress.json"

    // StandardPaths returns a QUrl ("file:///run/..."), not a plain path.
    // An unresolved executable is a truthy invalid QUrl, so `|| fallback`
    // never fires — normalize to a path and test that instead.
    function execPath(name) {
        var u = StandardPaths.findExecutable(name)
        var s = u ? String(u) : ""
        if (s.indexOf("file://") === 0) s = s.substring(7)
        return s
    }

    // Process takes a path; ctx.run matches argv[0] against manifest.commands,
    // so the detached upgrade must use the bare declared names.
    readonly property string checkBin: execPath("artcraft-check") || "artcraft-check"
    readonly property bool hasSystemdRun: execPath("systemd-run") !== ""

    property var status: A.normalizeStatus({})
    property var progress: A.normalizeProgress({})
    property bool checking: false
    property string checkError: ""
    property int checkIntervalMs: 6 * 60 * 60 * 1000

    readonly property bool upgrading: progress.running === true
    readonly property int count: status.count || 0
    readonly property var apps: status.apps || []
    readonly property var outdated: status.outdated || []
    readonly property string lastCheckedText:
        A.relativeTime(status.checked, Math.floor(new Date().getTime() / 1000))

    readonly property var _settings: ctx ? ctx.settings.values : null

    // ── lifecycle ────────────────────────────────────────────────────────────
    onCtxChanged: {
        applySettings()
        if (ctx && !bootChecked) {
            bootChecked = true
            if (ctx.settings.get("checkOnBoot", true)) check()
        }
    }
    on_SettingsChanged: applySettings()

    property bool bootChecked: false

    function applySettings() {
        if (!ctx) return
        var hours = Number(ctx.settings.get("checkIntervalHours", 6))
        if (!isFinite(hours) || hours < 1) hours = 6
        checkIntervalMs = Math.round(hours * 60 * 60 * 1000)
    }

    Component.onCompleted: {
        // ctx is injected after mount; onCtxChanged runs the boot check then.
        statusFile.reload()
        progressFile.reload()
    }

    // ── checks ───────────────────────────────────────────────────────────────
    function check() {
        if (checkProc.running) return "check already running"
        checking = true
        checkError = ""
        checkProc.running = true
        return "ok"
    }

    function shouldCheck() {
        var now = Math.floor(new Date().getTime() / 1000)
        return !status.checked || (now - status.checked) > 15 * 60
    }

    function update(app) {
        if (upgrading) return "upgrade already running"
        var target = app ? String(app) : ""
        var argv = []
        if (hasSystemdRun) {
            argv = ["systemd-run", "--user", "--unit=artcraft-upgrade",
                    "--collect", "--property=Type=oneshot", "--", "artcraft-upgrade"]
        } else {
            argv = ["artcraft-upgrade"]
        }
        if (target !== "") argv.push(target)
        if (!ctx || !ctx.run(argv)) {
            checkError = "could not start artcraft-upgrade"
            return "error"
        }
        checkError = ""
        startedAt = Math.floor(new Date().getTime() / 1000)
        progress = A.normalizeProgress({
            running: true,
            active: target,
            overall: 0,
            message: "starting…",
            apps: target ? { [target]: { phase: "pending", percent: 0 } } : {}
        })
        publishActivity(progress)
        return "ok"
    }

    function updateAll() { return update("") }

    function refresh() { return check() }

    // ── activity (island / floating OSD) ─────────────────────────────────────
    function publishActivity(p) {
        if (!ctx) return
        if (!p.running) {
            ctx.island.end("upgrade")
            return
        }
        var label = (p.active ? p.active + " " : "") + A.formatPercent(p.overall)
        ctx.island.activity({
            key: "upgrade",
            icon: "▲",
            label: label,
            progress: p.overall,
            priority: "progress"
        })
    }

    // ── status.json ──────────────────────────────────────────────────────────
    FileView {
        id: statusFile
        path: root.statusPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.readStatus()
        onFileChanged: reload()
    }

    function readStatus() {
        try {
            var raw = statusFile.text()
            root.status = A.normalizeStatus(raw && raw.length ? JSON.parse(raw) : {})
        } catch (e) {
            root.checkError = "status.json is not valid JSON"
        }
    }

    // ── progress.json ────────────────────────────────────────────────────────
    FileView {
        id: progressFile
        path: root.progressPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.readProgress()
        onFileChanged: reload()
    }

    property bool _wasRunning: false
    property double startedAt: 0

    function readProgress() {
        var wasRunning = root._wasRunning
        var next
        try {
            var raw = progressFile.text()
            next = A.normalizeProgress(raw && raw.length ? JSON.parse(raw) : {})
        } catch (e) {
            return
        }
        // The poll timer starts the instant update() sets the in-memory
        // "starting" state; ignore the previous run's file until the detached
        // upgrade has written a newer one.
        if (root.upgrading && next.updated < root.startedAt) return
        root.progress = next
        root._wasRunning = next.running
        root.publishActivity(next)
        if (wasRunning && !next.running)
            statusFile.reload()
    }

    // ── processes / timers ───────────────────────────────────────────────────
    Process {
        id: checkProc
        command: [root.checkBin]
        onRunningChanged: root.checking = running
        onExited: (exitCode, exitStatus) => {
            root.checking = false
            if (exitCode !== 0)
                root.checkError = "artcraft-check failed (exit " + exitCode + ")"
            else
                root.checkError = ""
            statusFile.reload()
        }
    }

    Timer {
        interval: root.checkIntervalMs
        repeat: true
        running: root.ctx !== null
        onTriggered: root.check()
    }

    Timer {
        id: poll
        interval: 1000
        repeat: true
        running: root.upgrading
        onTriggered: progressFile.reload()
    }

    Timer {
        id: startGuard
        interval: 15000
        repeat: false
        running: root.upgrading && root.progress.updated === 0
        onTriggered: {
            root.checkError = "upgrade did not start — check the systemd journal"
            root.progress = A.normalizeProgress({
                running: false,
                error: root.checkError,
                message: root.checkError
            })
            root.publishActivity(root.progress)
        }
    }
}
