// =============================================================================
// WallpaperService.qml — Wallpaper Management Service
// =============================================================================
//
// Background service for wallpaper rotation via awww (swww-compatible).
// Exposes IPC interface for control from Settings UI without duplicating state.
//
// IPC Commands (quickshell ipc call settings call wallpaper-service <fn>):
//   cycleNow            — Apply a random wallpaper immediately
//   refreshList         — Re-scan the wallpaper directory
//   getList             — Returns newline-separated list of wallpaper paths
//   getCurrentInfo      — Returns the active wallpaper path
//   getCount            — Returns number of discovered wallpapers
//   setWallpaperByPath  — Apply a specific path
//   setWallpaperByIndex — Apply by 0-based index
//   setInterval         — Set cycle interval in seconds (min: 10)
//   getInterval         — Returns current interval in seconds
//   toggleCycling       — Flip auto-cycle on/off
//   getCyclingEnabled   — Returns bool
//   setCyclingEnabled   — Set cycling state explicitly
//   setTransition       — Set transition type (outer, fade, wipe, simple, wave)
//   getTransition       — Returns current transition type
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // =========================================================================
    // CONFIGURATION
    // =========================================================================

    /// Auto-cycle interval in milliseconds (default: 5 minutes)
    property int cycleInterval: 300000

    /// awww transition style: any | outer | inner | fade | wipe | simple | wave
    property string transitionType: "fade"

    /// Target FPS for the transition animation
    readonly property int transitionFps: 60

    /// Transition speed (0–255; higher = faster fade/wipe)
    readonly property int transitionStep: 90

    // =========================================================================
    // STATE
    // =========================================================================

    property string wallpaperDir: ""
    property string currentWallpaper: ""
    property var    wallpaperList: []
    property int    lastIndex: -1
    property bool   cyclingEnabled: true
    property bool   scanInProgress: false

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[WallpaperService] Starting — cycle interval:",
                    root.cycleInterval / 1000, "s, transition:", root.transitionType)
        homeGetter.running = true
    }

    // =========================================================================
    // STEP 1 — Resolve $HOME
    // =========================================================================

    Process {
        id: homeGetter
        command: ["sh", "-c", "echo $HOME"]

        property string buf: ""

        stdout: SplitParser {
            onRead: data => { homeGetter.buf += data }
        }

        onRunningChanged: {
            if (!running) {
                root.wallpaperDir = homeGetter.buf.trim() + "/Pictures/Wallpapers/"
                homeGetter.buf = ""
                console.log("[WallpaperService] Wallpaper dir:", root.wallpaperDir)
                startScan()
            }
        }
    }

    // =========================================================================
    // STEP 2 — Scan wallpaper directory for image files
    // =========================================================================

    Process {
        id: scanner

        property string buf: ""

        stdout: SplitParser {
            onRead: data => { scanner.buf += data + "\n" }
        }

        onRunningChanged: {
            if (!running) {
                root.scanInProgress = false

                var lines = scanner.buf.trim().split("\n").filter(function(l) {
                    return l.trim().length > 0
                })

                // Sort for deterministic ordering
                lines.sort()
                root.wallpaperList = lines
                scanner.buf = ""

                console.log("[WallpaperService] Found", root.wallpaperList.length, "wallpaper(s)")

                // First run: start timer and apply an initial wallpaper
                if (root.wallpaperList.length > 0) {
                    if (!cycleTimer.running && root.cyclingEnabled) {
                        cycleTimer.running = true
                    }
                    if (root.currentWallpaper.length === 0) {
                        applyWallpaper(selectRandomWallpaper())
                    }
                }
            }
        }
    }

    /// Kick off a directory scan; silently skips if one is already running.
    function startScan() {
        if (root.scanInProgress) {
            console.log("[WallpaperService] Scan already in progress, skipping")
            return
        }
        if (root.wallpaperDir.length === 0) return

        root.scanInProgress = true
        scanner.command = [
            "find", root.wallpaperDir,
            "-maxdepth", "1",
            "-type",     "f",
            "(", "-iname", "*.jpg",
                 "-o", "-iname", "*.jpeg",
                 "-o", "-iname", "*.png",
                 "-o", "-iname", "*.webp",
            ")"
        ]
        scanner.running = true
    }

    // =========================================================================
    // PERIODIC LIST REFRESH
    // =========================================================================

    Timer {
        id: refreshTimer
        interval: 60000
        running:  true
        repeat:   true
        onTriggered: {
            if (root.wallpaperDir.length > 0) startScan()
        }
    }

    // =========================================================================
    // RANDOM SELECTION
    // =========================================================================

    /// Returns a random path from wallpaperList, avoiding immediate repeats.
    function selectRandomWallpaper(): string {
        if (root.wallpaperList.length === 0) {
            console.log("[WallpaperService] List empty — triggering re-scan")
            startScan()
            return ""
        }

        var newIndex
        var attempts = 0
        var maxAttempts = Math.min(10, root.wallpaperList.length)

        do {
            newIndex = Math.floor(Math.random() * root.wallpaperList.length)
            attempts++
        } while (newIndex === root.lastIndex && attempts < maxAttempts && root.wallpaperList.length > 1)

        root.lastIndex = newIndex
        var path = root.wallpaperList[newIndex]
        console.log("[WallpaperService] Selected [" + newIndex + "]:", path)
        return path
    }

    // =========================================================================
    // WALLPAPER APPLICATION
    // =========================================================================

    Process {
        id: awwwProcess
        running: false

        onExited: function(exitCode) {
            if (exitCode !== 0)
                console.log("[WallpaperService] awww exited with code:", exitCode)
            else
                console.log("[WallpaperService] Wallpaper applied OK")
        }
    }

    /// Apply a wallpaper by absolute path.
    function applyWallpaper(path) {
        if (!path || path.length === 0) {
            console.log("[WallpaperService] applyWallpaper: empty path, aborting")
            return
        }

        awwwProcess.command = [
            "awww", "img",  path,
            "--transition-type", root.transitionType,
            "--transition-fps",  root.transitionFps.toString(),
            "--transition-step", root.transitionStep.toString()
        ]
        awwwProcess.running  = true
        root.currentWallpaper = path
    }

    // =========================================================================
    // PUBLIC CONTROL API (callable directly from in-process UI)
    // --------------------------------------------------------------------------
    // These mirror the IpcHandler interface below. The IPC handlers delegate
    // here so behavior is identical whether called from WallpaperModule (a
    // direct singleton method call) or over `quickshell ipc`.
    //
    // GOTCHA: functions declared inside an IpcHandler{} block are NOT callable
    // as methods on this singleton from other QML files — they only answer IPC
    // requests. Anything the UI must invoke has to live here on the root object.
    // =========================================================================

    /// Apply a wallpaper by absolute path.
    function setWallpaperByPath(path: string) {
        console.log("[WallpaperService] setWallpaperByPath", path)
        applyWallpaper(path)
    }

    /// Flip auto-cycling on/off.
    function toggleCycling() {
        console.log("[WallpaperService] toggleCycling")
        root.cyclingEnabled = !root.cyclingEnabled
        cycleTimer.running  = root.cyclingEnabled && root.wallpaperList.length > 0
        console.log("[WallpaperService] toggleCycling ->", root.cyclingEnabled,
                    "timer running:", cycleTimer.running)
    }

    /// Set auto-cycle interval (seconds; minimum 10).
    function setInterval(seconds: int) {
        console.log("[WallpaperService] setInterval", seconds, "s")
        if (seconds < 10) {
            console.log("[WallpaperService] Interval too small, must be >= 10 seconds")
            return
        }
        root.cycleInterval  = seconds * 1000
        cycleTimer.interval = root.cycleInterval
        console.log("[WallpaperService] Interval set to", seconds,
                    "seconds (", root.cycleInterval, "ms)")
    }

    /// Set transition type (any|outer|inner|fade|wipe|simple|wave).
    function setTransition(type: string) {
        console.log("[WallpaperService] setTransition", type)
        if (type.length > 0)
            root.transitionType = type
    }

    /// Re-scan the wallpaper directory.
    function refreshList() {
        console.log("[WallpaperService] refreshList")
        startScan()
    }

    /// Change the wallpaper directory and re-scan immediately.
    function setWallpaperDir(dir: string) {
        console.log("[WallpaperService] setWallpaperDir", dir)
        if (dir.length === 0) {
            console.log("[WallpaperService] Empty directory, ignoring")
            return
        }
        root.wallpaperDir     = dir.endsWith("/") ? dir : dir + "/"
        root.wallpaperList    = []
        root.currentWallpaper = ""
        root.lastIndex        = -1
        console.log("[WallpaperService] Wallpaper directory set to", root.wallpaperDir)
        startScan()
    }

    // =========================================================================
    // AUTO-CYCLE TIMER
    // =========================================================================

    Timer {
        id: cycleTimer
        interval:         root.cycleInterval
        running:          false
        repeat:           true
        triggeredOnStart: false

        onTriggered: {
            if (!root.cyclingEnabled) return
            console.log("[WallpaperService] Auto-cycle triggered")
            applyWallpaper(selectRandomWallpaper())
        }
    }

    // =========================================================================
    // IPC INTERFACE
    // =========================================================================

    IpcHandler {
        target: "wallpaper-service"

        /// Immediately cycle to a random wallpaper
        function cycleNow() {
            console.log("[WallpaperService] FUNCTION CALL: cycleNow")
            applyWallpaper(selectRandomWallpaper())
        }

        /// Re-scan the wallpaper directory
        function refreshList() {
            root.refreshList()
        }

        /// Return newline-separated list of all discovered wallpapers
        function getList(): string {
            return root.wallpaperList.join("\n")
        }

        /// Return the currently active wallpaper path
        function getCurrentInfo(): string {
            return root.currentWallpaper
        }

        /// Return the count of discovered wallpapers
        function getCount(): int {
            return root.wallpaperList.length
        }

        /// Apply wallpaper by absolute path
        function setWallpaperByPath(path: string) {
            root.setWallpaperByPath(path)
        }

        /// Apply wallpaper by 0-based index
        function setWallpaperByIndex(index: int) {
            console.log("[WallpaperService] FUNCTION CALL: setWallpaperByIndex", index)
            if (index >= 0 && index < root.wallpaperList.length)
                applyWallpaper(root.wallpaperList[index])
        }

        /// Set auto-cycle interval (seconds; minimum 10)
        function setInterval(seconds: int) {
            root.setInterval(seconds)
        }

        /// Return current interval in seconds
        function getInterval(): int {
            return root.cycleInterval / 1000
        }

        /// Flip auto-cycling on/off
        function toggleCycling() {
            root.toggleCycling()
        }

        /// Return whether auto-cycling is active
        function getCyclingEnabled(): bool {
            return root.cyclingEnabled
        }

        /// Set auto-cycling state explicitly
        function setCyclingEnabled(enabled: bool) {
            root.cyclingEnabled = enabled
            cycleTimer.running  = enabled && root.wallpaperList.length > 0
            console.log("[WallpaperService] IPC: setCyclingEnabled ->", enabled)
        }

        /// Set transition type
        function setTransition(type: string) {
            root.setTransition(type)
        }

        /// Return current transition type
        function getTransition(): string {
            return root.transitionType
        }

        /// Return the current wallpaper directory
        function getWallpaperDir(): string {
            return root.wallpaperDir
        }

        /// Change the wallpaper directory and re-scan immediately
        function setWallpaperDir(dir: string) {
            root.setWallpaperDir(dir)
        }
    }
}
