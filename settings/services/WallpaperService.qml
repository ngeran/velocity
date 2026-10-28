// =============================================================================
// WallpaperService.qml — Wallpaper Management Service
// =============================================================================
//
// Background service for wallpaper rotation via awww (swww-compatible) for
// stills, plus the wallpaper-engine (mpvpaper) backend for animated content.
// Exposes IPC interface for control from Settings UI without duplicating state.
//
// I8 SPLIT: classification, the filtered library view, scan/thumbnail/
// engine-status parsing, the repeat-avoiding random pick, the awww argv
// builder and the config round-trip live in ../lib/wallpaper.mjs
// (node-tested). This file keeps IO + state (Processes, timers, persister).
//
// LIBRARY MODEL
//   still library : wallpaperDir  (default ~/Pictures/Wallpapers/)  → awww
//   live library  : liveDir       (default ~/Pictures/Live-Wallpapers/) →
//                   wallpaper-engine (mpvpaper + mpv IPC, NVDEC on the panel's
//                   video engine). Everything in liveDir routes to the engine —
//                   gif/webp/apng included — so pause, frame extraction and
//                   thumbnails all live in one place.
//   libraryMode filters what rotation picks: all | still | live.
//
// ENGINE INTEGRATION (single owner: this service)
//   The engine daemon runs in integrated mode (WE_AUTOSTART=0): it never picks
//   media itself, it only keeps mpvpaper instances alive (crash, hotplug) for
//   whatever the last `set` requested. This service drives it through:
//     set FILE   → heal instances + loadfile replace (video→video, no restart)
//     clear      → kill instances + forget media (reveals the awww still below)
//     pause/resume → mpv pause (decode stops; only ever done when the panel is
//                    covered or DPMS-off — never on a visible static frame)
//   Handoff is flash-free both ways: awww renders UNDER mpvpaper, so
//   animated→still applies the still first, then clears the instances.
//
// IPC Commands (quickshell ipc call settings call wallpaper-service <fn>):
//   cycleNow            — Apply a random wallpaper immediately
//   refreshList         — Re-scan both wallpaper directories
//   getList             — Returns newline-separated list of wallpaper paths
//   getCurrentInfo      — Returns the active wallpaper path
//   getCount            — Returns number of discovered wallpapers
//   setWallpaperByPath  — Apply a specific path (backend auto-selected)
//   setWallpaperByIndex — Apply by 0-based index
//   setInterval         — Set cycle interval in seconds (min: 10)
//   getInterval         — Returns current interval in seconds
//   toggleCycling       — Flip auto-cycle on/off
//   getCyclingEnabled   — Returns bool
//   setCyclingEnabled   — Set cycling state explicitly
//   setTransition       — Set transition type (outer, fade, wipe, simple, wave)
//   getTransition       — Returns current transition type
//   setAnimationPaused  — Freeze/resume live playback (engine pause or awww)
//   toggleAnimationPause— Flip playback state
//   getAnimationPaused  — Returns bool (true = frozen)
//   setLibraryMode      — all | still | live (what rotation may pick)
//   getLibraryMode      — Returns current mode
//   setLiveDir          — Change the live library directory and re-scan
//   getLiveDir          — Returns the live library directory
//   getEngineStatus     — Returns engine status as a JSON string
//   enginePause / engineResume / engineTogglePause — direct engine control
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell
import Quickshell.Io
import "../config" as Config
import "../utils" as Utils
import "../services" as Services
import "../lib/wallpaper.mjs" as Wm

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

    property string wallpaperDir: ""     // still library
    property string liveDir: ""          // animated library (engine-backed)
    property string currentWallpaper: ""
    property int    lastIndex: -1
    property bool   cyclingEnabled: true
    property bool   scanInProgress: false
    property string currentMonitor: ""  // Target monitor for wallpaper (empty = all)

    /// What rotation may pick: "all" | "still" | "live"
    property string libraryMode: "all"

    /// Raw per-library lists — wallpaperList is the filtered view.
    property var    stillList: []
    property var    liveList: []

    /// True while the daemon's animation is frozen — engine pause for
    /// live-library content, awww HOLD for gif/apng in the still library.
    property bool   animationPaused: false

    /// liveDir path → cached poster frame (png) for grid thumbnails + matugen.
    property var    thumbMap: ({})

    // --- engine (wallpaper-engine CLI) state, refreshed by status polling ---
    property bool   engineAvailable: false   // CLI found on PATH
    property bool   engineRunning: false     // daemon pid alive
    property bool   enginePaused: false      // daemon-level pause flag
    property int    engineInstances: 0       // alive mpvpaper instances

    /// True for real video containers — only the engine can display these
    /// (the awww fallback cannot decode video; gif/webp/apng can stay).
    function isVideo(path: string): bool {
        return Wm.isVideo(path)
    }

    /// Filtered pick list — rotation, IPC index access and the gallery all
    /// read this, so a mode switch re-scopes everything at once.
    readonly property var wallpaperList: Wm.filterLibrary(root.stillList, root.liveList,
                                                          root.engineAvailable, root.libraryMode)

    // =========================================================================
    // CLASSIFICATION — rules in ../lib/wallpaper.mjs (I8 split, node-tested)
    // =========================================================================

    /// True for formats awww animates as a wallpaper (still library gif/apng).
    function isLive(path: string): bool {
        return Wm.isLive(path)
    }

    /// True for anything in the live library — routed to wallpaper-engine
    /// (mpvpaper), awww fallback if the engine is unavailable. Directory-based
    /// (not extension-based) so existing still-library content, including
    /// gif/apng/webp, keeps its current awww behaviour untouched. The slash-
    /// normalized prefix match (sibling folders like Live-Wallpapers-old must
    /// not be claimed) lives in ../lib/wallpaper.mjs.
    function isEngined(path: string): bool {
        return Wm.isEngined(path, root.liveDir)
    }

    /// THE preview resolver (§1 dedup): stills use the file itself, engine
    /// content uses its cached poster frame ("" until extracted — callers
    /// show a placeholder). The gallery (WallpaperModule.thumbFor) and the
    /// dashboard card (ActiveWallpaperCard.previewSource) both delegate here
    /// — the two copies had drifted into near-identical shapes.
    function previewSourceFor(path: string): string {
        return Wm.previewSource(path, root.thumbMap, root.liveDir)
    }

    // =========================================================================
    // CONFIGURATION PERSISTENCE
    // =========================================================================

    property string configFilePath: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString()
                                       .replace("file://", "") + "/quickshell/wallpaper-config.json"

    Utils.ConfigPersistence {
        id: configPersister
        configPath: root.configFilePath

        onLoaded: function(data) {
            console.log("[WallpaperService] Config loaded:", JSON.stringify(data))
            // I8: seconds→ms and the per-key guards live in
            // ../lib/wallpaper.mjs (loadedConfigPatch — absent key = keep
            // previous value, exactly the old inline guards).
            var patch = Wm.loadedConfigPatch(data)
            if (patch.cycleInterval    !== undefined) root.cycleInterval    = patch.cycleInterval
            if (patch.cyclingEnabled   !== undefined) root.cyclingEnabled   = patch.cyclingEnabled
            if (patch.transitionType   !== undefined) root.transitionType   = patch.transitionType
            if (patch.animationPaused  !== undefined) root.animationPaused  = patch.animationPaused
            if (patch.wallpaperDir     !== undefined) root.wallpaperDir     = patch.wallpaperDir
            if (patch.currentWallpaper !== undefined) root.currentWallpaper = patch.currentWallpaper
            if (patch.liveDir          !== undefined) root.liveDir          = patch.liveDir
            if (patch.libraryMode      !== undefined) root.libraryMode      = patch.libraryMode
            // Writers add the trailing slash, but a hand-edited or older
            // config may not have it — isEngined() prefix-matches with "/".
            root.wallpaperDir = Wm.normalizeDir(root.wallpaperDir)
            root.liveDir      = Wm.normalizeDir(root.liveDir)

            // Sync the loaded wallpaper into SharedState so dashboard widgets
            // (e.g. the Active Wallpaper preview) show it immediately on
            // startup — not only after a wallpaper is freshly applied.
            Config.SharedState.updateWallpaper(root.currentWallpaper)

            // STEP 2 — boot sequence, now that saved state is in place.
            if (!root._bootScansStarted) {
                root._bootScansStarted = true
                startScan()
                startLiveScan()
                probeEngine()
            }
        }

        onSaved: function(success) {
            if (success) {
                if (Config.DebugConfig.debugService) console.log("[WallpaperService] Config saved successfully")
            } else {
                console.log("[WallpaperService] Failed to save config")
            }
        }
    }

    function saveConfig() {
        // (I8: ms→seconds conversion in ../lib/wallpaper.mjs.)
        configPersister.save(Wm.configPayload(root))
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[WallpaperService] Starting — cycle interval:",
                    root.cycleInterval / 1000, "s, transition:", root.transitionType)
        initFromHome()
    }

    // =========================================================================
    // STEP 1 — Resolve $HOME defaults, then load the saved config.
    // =========================================================================
    // The scans, engine probe and daemon guard DO NOT start here: the config
    // load is async, and starting them with default dirs / an empty
    // currentWallpaper let a random pick override the saved wallpaper and
    // ignored the saved liveDir. They start from onLoaded (exactly once).

    function initFromHome() {
        var home = Quickshell.env("HOME")
        if (root.wallpaperDir.length === 0) {
            root.wallpaperDir = home + "/Pictures/Wallpapers/"
        }
        if (root.liveDir.length === 0) {
            root.liveDir = home + "/Pictures/Live-Wallpapers/"
        }
        console.log("[WallpaperService] Wallpaper dir:", root.wallpaperDir)
        console.log("[WallpaperService] Live dir:", root.liveDir)

        configPersister.load()
    }

    /// Guards the STEP-2 kick: onLoaded fires exactly once per load(), but the
    /// flag makes the boot sequence explicitly single-shot.
    property bool _bootScansStarted: false

    /// One-shot probe: is the wallpaper-engine CLI installed? (It appears once
    /// services.wallpaperEngine is enabled in the NixOS config.) Re-probed
    /// whenever the dashboard opens while still unavailable, so enabling the
    /// module never needs a shell restart. Absolute path — systemd user units
    /// have a closed PATH (same reason hypridle's hooks are absolute).
    readonly property string engineBin: "/run/current-system/sw/bin/wallpaper-engine"

    function probeEngine() {
        // argv form, no shell: exit 0 = present+executable (onDone reads the code only)
        engineProbe.command = ["test", "-x", root.engineBin]
        engineProbe.run()   // latest-wins queue while busy — never drops a probe
    }

    BoundedProcess {
        id: engineProbe
        timeoutMs: 5000
        maxBytes: 4096

        onDone: function(out, err, code) {
            var had = root.engineAvailable
            root.engineAvailable = (code === 0)
            if (root.engineAvailable && !had) {
                console.log("[WallpaperService] wallpaper-engine available — animated backend enabled")
                pollEngineStatus()
                // The live boot-restore (liveScanner) ran before this probe
                // resolved — and skipped because engineAvailable was still
                // false — and the probe never retried, so a saved video
                // wallpaper never came back after login. Retry now.
                if (!root.bootRestored && root.currentWallpaper.length > 0
                        && root.isEngined(root.currentWallpaper)) {
                    root.bootRestored = true
                    applyWallpaper(root.currentWallpaper)
                }
            } else if (!root.engineAvailable) {
                if (Config.DebugConfig.debugService) console.log("[WallpaperService] wallpaper-engine not on PATH — live library falls back to awww")
            }
        }
    }

    // =========================================================================
    // STEP 2 — Scan wallpaper directories
    // =========================================================================

    // --- still library (unchanged behaviour) ---------------------------------
    BoundedProcess {
        id: scanner
        timeoutMs: 10000
        maxBytes: 262144

        onDone: function(out, err, code) {
            root.scanInProgress = false

            if (code !== 0) {
                console.warn("[WallpaperService] Directory scan failed with exit code:", code)
                console.warn("[WallpaperService] Check directory path and permissions:", root.wallpaperDir)
            }

            // A failed scan reads as empty (previous behaviour: the exit-code
            // warn plus the "No wallpapers found" pair). Sort for deterministic
            // ordering. (I8: parse in ../lib/wallpaper.mjs.)
            var lines = Wm.parseFileList(out, code)
            root.stillList = lines

            if (lines.length === 0 && root.wallpaperDir.length > 0) {
                console.warn("[WallpaperService] No wallpapers found in:", root.wallpaperDir)
                console.warn("[WallpaperService] Check that the directory exists and contains image files")
            } else {
                if (Config.DebugConfig.debugService) console.log("[WallpaperService] Found", root.stillList.length, "still wallpaper(s)")
            }

            // First run / boot restore. A saved still is re-applied so the
            // fresh awww daemon doesn't sit on a black screen until the
            // first cycle tick.
            if (root.stillList.length > 0 && root.currentWallpaper.length === 0) {
                applyWallpaper(selectRandomWallpaper())
            } else if (root.currentWallpaper.length > 0
                       && !root.isEngined(root.currentWallpaper)
                       && !root.bootRestored) {
                root.bootRestored = true
                applyWallpaper(root.currentWallpaper)
            }
        }
    }

    // --- live library (engine content) ---------------------------------------
    BoundedProcess {
        id: liveScanner
        timeoutMs: 10000
        maxBytes: 262144

        onDone: function(out, err, code) {
            var lines = Wm.parseFileList(out, code)
            root.liveList = lines

            if (lines.length === 0) {
                if (Config.DebugConfig.debugService) console.log("[WallpaperService] Live library empty:", root.liveDir)
            } else {
                console.log("[WallpaperService] Found", root.liveList.length, "live wallpaper(s)")
                startThumbWorker()
            }

            // Boot restore for engine content (video survives reboots only
            // if something re-issues the `set` — the engine daemon starts
            // intentionally empty in integrated mode).
            if (root.currentWallpaper.length > 0
                    && root.isEngined(root.currentWallpaper)
                    && root.engineAvailable
                    && !root.bootRestored) {
                root.bootRestored = true
                applyWallpaper(root.currentWallpaper)
            }
        }
    }

    /// Scan both libraries (stills silently skip if one is already running).
    function startScan() {
        if (root.scanInProgress) {
            if (Config.DebugConfig.debugService) console.log("[WallpaperService] Scan already in progress, skipping")
            return
        }
        if (root.wallpaperDir.length === 0) {
            console.warn("[WallpaperService] Cannot scan: no wallpaper directory set")
            return
        }

        root.scanInProgress = true
        // -L: symlinked libraries/files must scan like the thumbnail worker
        // (which already used -L) — they used to silently disagree.
        scanner.command = [
            "find", "-L", root.wallpaperDir,
            "-maxdepth", "1",
            "-type",     "f",
            "(", "-iname", "*.jpg",
                 "-o", "-iname", "*.jpeg",
                 "-o", "-iname", "*.png",
                 "-o", "-iname", "*.webp",
                 "-o", "-iname", "*.gif",
                 "-o", "-iname", "*.apng",
            ")"
        ]
        scanner.run()
    }

    function startLiveScan() {
        if (root.liveDir.length === 0) return
        liveScanner.command = [
            "find", "-L", root.liveDir,
            "-maxdepth", "1",
            "-type",     "f",
            "(", "-iname", "*.mp4",
                 "-o", "-iname", "*.webm",
                 "-o", "-iname", "*.mkv",
                 "-o", "-iname", "*.mov",
                 "-o", "-iname", "*.gif",
                 "-o", "-iname", "*.webp",
                 "-o", "-iname", "*.apng",
            ")"
        ]
        liveScanner.run()
    }

    // =========================================================================
    // THUMBNAILS — poster frames for the live library
    // ---------------------------------------------------------------------------
    // Qt can't decode video (or animated webp) into an Image, so each live
    // entry gets a cached poster frame: ~/.cache/quickshell/wallpaper-thumbs/
    // The same frame feeds matugen when an animated wallpaper is applied.
    // One worker process per scan; cache keys include mtime+size like the
    // engine's transcode cache, so edits invalidate naturally.
    // =========================================================================

    readonly property string thumbCacheDir: StandardPaths.writableLocation(StandardPaths.CacheLocation).toString()
                                            .replace("file://", "") + "/quickshell/wallpaper-thumbs"

    Process {   // unbounded-ok: one ffmpeg per uncached file, error-level logs only
        id: thumbWorker

        property string buf: ""

        stdout: SplitParser {
            onRead: data => { thumbWorker.buf += data + "\n" }
        }

        onRunningChanged: {
            if (!running) {
                var map = Wm.parseThumbMap(thumbWorker.buf)
                thumbWorker.buf = ""
                root.thumbMap = map
                if (Config.DebugConfig.debugService) console.log("[WallpaperService] Thumbnails ready:", Object.keys(map).length)
            }
        }
    }

    function startThumbWorker() {
        thumbWorker.buf = ""
        thumbWorker.command = ["bash", "-c",
            'd="$1"; c="$2"; mkdir -p "$c"; find -L "$d" -maxdepth 1 -type f ' +
            '\\( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" ' +
            '-o -iname "*.gif" -o -iname "*.webp" -o -iname "*.apng" \\) -print0 | ' +
            'while IFS= read -r -d "" f; do ' +
            'key=$(printf "%s" "$f$(stat -c %Y:%s "$f")" | sha1sum | cut -c1-12); ' +
            'out="$c/$(basename "${f%.*}")-$key.png"; ' +
            '[ -s "$out" ] || ffmpeg -nostdin -loglevel error -y -ss 1 -i "$f" -frames:v 1 -vf scale=640:-2 "$out" 2>/dev/null ' +
            '|| ffmpeg -nostdin -loglevel error -y -i "$f" -frames:v 1 -vf scale=640:-2 "$out" 2>/dev/null ' +
            '|| rm -f "$out"; ' +
            '[ -f "$out" ] && printf "%s\\t%s\\n" "$f" "$out"; ' +
            'done',
            "thumb-worker", root.liveDir, root.thumbCacheDir]
        thumbWorker.running = true
    }

    // =========================================================================
    // PERIODIC LIST REFRESH
    // =========================================================================

    Timer {
        id: refreshTimer
        interval: 60000
        running: Config.SharedState.dashboardVisible  // only when the dashboard is open
        repeat: true
        onTriggered: {
            if (root.wallpaperDir.length > 0) startScan()
            startLiveScan()
        }
    }

    // =========================================================================
    // RANDOM SELECTION
    // =========================================================================

    /// Returns a random path from the filtered list, avoiding immediate repeats.
    function selectRandomWallpaper(): string {
        if (root.wallpaperList.length === 0) {
            if (Config.DebugConfig.debugService) console.log("[WallpaperService] List empty — triggering re-scan")
            startScan()
            return ""
        }

        // (I8: the repeat-avoiding pick lives in ../lib/wallpaper.mjs.)
        var newIndex = Wm.pickRandom(root.wallpaperList, root.lastIndex, Math.random)

        root.lastIndex = newIndex
        var path = root.wallpaperList[newIndex]
        if (Config.DebugConfig.debugService) console.log("[WallpaperService] Selected [" + newIndex + "]:", path)
        return path
    }

    // =========================================================================
    // WALLPAPER APPLICATION — backend routing
    // =========================================================================

    /// True while an awww apply is in flight and the engine should be cleared
    /// once it lands (animated → still handoff: reveal the still beneath).
    property bool pendingClear: false

    /// Set after the first boot restore / initial pick, so the 60 s refresh
    /// scans don't re-apply the same wallpaper forever.
    property bool bootRestored: false

    /// Legacy awww apply (stills, and gif/apng/webp fallback without engine).
    function applyAwww(path) {
        // pendingClear decided once: engine present → clear it after the still
        // lands (a no-op if nothing is running).
        root.pendingClear = root.engineAvailable

        // (I8: argv build + --outputs flag in ../lib/wallpaper.mjs.)
        awwwApply(Wm.buildAwwwCmd(path, root.transitionType,
                                  root.transitionFps, root.transitionStep,
                                  root.currentMonitor))
    }

    // --- awww daemon guard --------------------------------------------------
    // Nothing on this host starts awww-daemon (no exec-once, no unit): without
    // a guard, every awww img/pause fails with "socket not found" and the
    // still library sits black until the first cycle tick. One bounded
    // probe-and-spawn ahead of the first apply; applies that arrive while the
    // guard runs are held (latest-wins) and flushed on readiness.
    property bool _awwwDaemonUp: false
    property var   _awwwHeldCmd: null

    BoundedProcess {
        id: awwwGuard
        timeoutMs: 8000
        maxBytes: 4096
        command: ["sh", "-c",
                  "awww query >/dev/null 2>&1 && exit 0; " +
                  "nohup awww-daemon >/dev/null 2>&1 & " +
                  "for _ in $(seq 1 40); do awww query >/dev/null 2>&1 && exit 0; sleep 0.1; done; exit 1"]

        onDone: function(out, err, code) {
            root._awwwDaemonUp = (code === 0)
            if (code !== 0)
                console.warn("[WallpaperService] awww daemon unavailable — stills cannot apply until it starts")
            var held = root._awwwHeldCmd
            root._awwwHeldCmd = null
            if (held !== null) root._awwwSend(held)
        }
    }

    /// Ensure the daemon answers, then send cmd. Latest-wins on both stages:
    /// a newer apply replaces a held one while the guard probes, and
    /// _awwwSend's run() replaces a queued apply while one is in flight.
    function awwwApply(cmd) {
        if (root._awwwDaemonUp) {
            root._awwwSend(cmd)
            return
        }
        root._awwwHeldCmd = cmd
        awwwGuard.run()
    }

    function _awwwSend(cmd) {
        awwwProcess.command = cmd
        awwwProcess.run()
    }

    /// Apply a wallpaper by absolute path. Backend is selected by library:
    /// liveDir content → wallpaper-engine (mpvpaper), everything else → awww.
    function applyWallpaper(path) {
        if (!path || path.length === 0) {
            console.log("[WallpaperService] applyWallpaper: empty path, aborting")
            return
        }

        var engined = root.isEngined(path) && root.engineAvailable

        // A fresh apply resumes playback (a paused backend swallows the new
        // image's transition / starts the new file frozen). HOLD is re-armed
        // by the user afterwards. Resume the backend that was holding.
        if (root.animationPaused) {
            if (root.currentWallpaper.length > 0 && root.isEngined(root.currentWallpaper) && root.engineAvailable) {
                engineAct(["resume"])
            } else {
                pauseCtl.command = ["awww", "unpause"]
                pauseCtl.run()
            }
            root.animationPaused = false
        }

        if (root.isEngined(path)) {
            if (engined) {
                // A video supersedes any pending animated→still handoff:
                // letting the still's `clear` fire after this `set` would kill
                // the freshly loaded video.
                root.pendingClear = false
                // Video → video: loadfile replace, no process restart. The
                // engine also heals dead instances as part of `set`.
                engineAct(["set", path])
            } else {
                // Engine unavailable: legacy fallback — awww animates
                // gif/apng/webp natively; real video files will warn in the
                // journal. Nothing else changes.
                console.warn("[WallpaperService] Engine unavailable — awww fallback for", path)
                applyAwww(path)
            }
        } else {
            applyAwww(path)
        }

        root.currentWallpaper = path
        Config.SharedState.updateWallpaper(path)
        saveConfig()

        // Auto-theme from the new wallpaper via matugen (instant, no rebuild)
        // when the matugenOnWallpaperChange toggle is on. Engine content gets
        // its extracted poster frame instead of the (undecodable) video path.
        if (Services.SettingsConfigService.matugenOnWallpaperChange) {
            if (engined) {
                themeFromEngineWallpaper(path)
            } else {
                if (Config.DebugConfig.debugService) console.log("[WallpaperService] Auto-theming from wallpaper via matugen:", path)
                Services.ThemeService.applyDynamicTheme(path)
            }
        }
    }

    /// matugen from an animated wallpaper: use the cached poster frame.
    function themeFromEngineWallpaper(path) {
        var t = root.thumbMap[path]
        if (t) {
            if (Config.DebugConfig.debugService) console.log("[WallpaperService] Auto-theming from poster frame:", t)
            Services.ThemeService.applyDynamicTheme(t)
            return
        }
        // Frame not cached yet — extract it now, then theme. Positional sh
        // args ($0 = cache dir, $1 = source): no quoting traps on odd paths,
        // the cache dir is created on demand (the thumbnail worker may not
        // have run yet), and ffmpeg resolves from the service PATH.
        frameExtractor.targetPath = path
        frameExtractor.command = ["sh", "-c",
            'mkdir -p "$0" && exec ffmpeg -nostdin -loglevel error -y -ss 1 -i "$1" -frames:v 1 -vf scale=640:-2 "$0/matugen-frame.png"',
            root.thumbCacheDir, path]
        frameExtractor.run()
    }

    BoundedProcess {
        id: frameExtractor
        timeoutMs: 15000
        maxBytes: 65536

        property string targetPath: ""

        onDone: function(out, err, code) {
            if (code === 0 && Services.SettingsConfigService.matugenOnWallpaperChange) {
                Services.ThemeService.applyDynamicTheme(root.thumbCacheDir + "/matugen-frame.png")
            } else if (code !== 0) {
                console.warn("[WallpaperService] matugen frame extraction failed for", targetPath)
            }
        }
    }

    BoundedProcess {
        id: awwwProcess
        timeoutMs: 20000        // 4K transitions are slow; img itself is quick
        maxBytes: 65536

        onDone: function(out, err, code) {
            if (code !== 0) {
                console.warn("[WallpaperService] Wallpaper apply failed with exit code:", code)
                console.warn("[WallpaperService] Make sure awww is installed and the path is valid")
            } else if (root.pendingClear) {
                // Still applied under the running mpvpaper layer — reveal it.
                root.pendingClear = false
                engineAct(["clear"])
            }
        }
    }

    // =========================================================================
    // LIVE (ANIMATED) WALLPAPER CONTROL
    // --------------------------------------------------------------------------
    // RUN/HOLD routes by what is currently on screen: engine content gets
    // wallpaper-engine pause/resume (mpv decode stops), still-library
    // gif/apng keeps the legacy awww pause. One-shot Process so a HOLD toggle
    // can never stomp a pending img apply on the shared awwwProcess.
    // =========================================================================

    BoundedProcess {
        id: pauseCtl
        timeoutMs: 8000
        maxBytes: 4096

        onDone: function(out, err, code) {
            if (code !== 0)
                console.warn("[WallpaperService] awww pause/unpause failed with exit code:", code)
        }
    }

    /// Freeze (true) or resume (false) live-wallpaper playback.
    function setAnimationPaused(paused: bool) {
        root.animationPaused = paused
        saveConfig()

        if (root.currentWallpaper.length > 0 && root.isEngined(root.currentWallpaper) && root.engineAvailable) {
            engineAct([paused ? "pause" : "resume"])
        } else {
            pauseCtl.command = ["awww", paused ? "pause" : "unpause"]
            pauseCtl.run()
        }
    }

    function toggleAnimationPause() {
        root.setAnimationPaused(!root.animationPaused)
    }

    // =========================================================================
    // ENGINE CONTROL (wallpaper-engine CLI)
    // =========================================================================

    // FIFO, not a single slot: applyWallpaper sends `resume` then `set` when
    // the animation is paused — with one queued slot the `set` overwrote the
    // `resume` and the new video started frozen. Capped (oldest dropped):
    // entries are idempotent state commands, the newest wins either way.
    readonly property int _engineQueueMax: 4
    property var _engineQueue: []

    BoundedProcess {
        id: engineActProc
        timeoutMs: 8000
        maxBytes: 65536

        onDone: function(out, err, code) {
            if (code !== 0) {
                console.warn("[WallpaperService] wallpaper-engine command failed (exit " + code + ")")
            }
            pollEngineStatus()
            if (root._engineQueue.length > 0) engineAct(root._engineQueue.shift())
        }
    }

    /// Fire a wallpaper-engine subcommand; FIFO queue while busy.
    function engineAct(args) {
        if (!root.engineAvailable) {
            console.warn("[WallpaperService] engineAct ignored (engine unavailable):", args.join(" "))
            return
        }
        if (engineActProc.running) {
            if (root._engineQueue.length >= root._engineQueueMax) root._engineQueue.shift()
            root._engineQueue.push(args)
            return
        }
        engineActProc.command = [root.engineBin].concat(args)
        engineActProc.running = true
    }

    /// Latest engine status JSON (for IPC consumers), refreshed ~10 s while
    /// the dashboard is open and after every engine command.
    property string lastEngineStatus: "{}"

    property string _statusBuf: ""

    Process {   // unbounded-ok: one-line JSON from a local CLI
        id: engineStatusProc

        stdout: SplitParser {
            onRead: data => { root._statusBuf += data + "\n" }
        }

        onRunningChanged: {
            if (!running) {
                var buf = root._statusBuf
                root._statusBuf = ""
                // (I8: parse in ../lib/wallpaper.mjs — null on garbage keeps
                // the previous raw status.)
                var st = Wm.parseEngineStatus(buf)
                if (st !== null) {
                    root.engineRunning   = st.running
                    root.enginePaused    = st.paused
                    root.engineInstances = st.instances
                    root.lastEngineStatus = st.raw
                } else {
                    // Daemon down mid-poll or garbage output — treat as off.
                    root.engineRunning   = false
                    root.enginePaused    = false
                    root.engineInstances = 0
                }
            }
        }
    }

    function pollEngineStatus() {
        if (!root.engineAvailable) return
        if (engineStatusProc.running) return
        root._statusBuf = ""
        engineStatusProc.command = [root.engineBin, "status"]
        engineStatusProc.running = true
    }

    Timer {
        id: engineStatusTimer
        interval: 10000
        running: Config.SharedState.dashboardVisible && root.engineAvailable
        repeat: true
        onTriggered: pollEngineStatus()
    }

    // Re-probe when the dashboard opens — covers "module enabled after shell start".
    Connections {
        target: Config.SharedState
        function onDashboardVisibleChanged() {
            if (Config.SharedState.dashboardVisible) {
                if (!root.engineAvailable) probeEngine()
                pollEngineStatus()
            }
        }
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
        if (Config.DebugConfig.debugService) console.log("[WallpaperService] setWallpaperByPath", path)
        applyWallpaper(path)
    }

    /// Flip auto-cycling on/off.
    function toggleCycling() {
        console.log("[WallpaperService] toggleCycling")
        root.cyclingEnabled = !root.cyclingEnabled
        console.log("[WallpaperService] toggleCycling ->", root.cyclingEnabled,
                    "timer running:", cycleTimer.running)
        saveConfig()
    }

    /// Set auto-cycle interval (seconds; minimum 10).
    function setInterval(seconds: int) {
        console.log("[WallpaperService] setInterval", seconds, "s")
        if (seconds < 10) {
            console.log("[WallpaperService] Interval too small, must be >= 10 seconds")
            return
        }
        root.cycleInterval  = seconds * 1000
        // cycleTimer.interval is BOUND to root.cycleInterval — assigning the
        // timer's property directly broke that binding permanently (a later
        // config load / save round-trip would stop updating the timer).
        console.log("[WallpaperService] Interval set to", seconds,
                    "seconds (", root.cycleInterval, "ms)")
        saveConfig()
    }

    /// Set transition type (any|outer|inner|fade|wipe|simple|wave).
    function setTransition(type: string) {
        console.log("[WallpaperService] setTransition", type)
        if (type.length > 0) {
            root.transitionType = type
            saveConfig()
        }
    }

    /// Re-scan both wallpaper directories.
    function refreshList() {
        console.log("[WallpaperService] refreshList")
        startScan()
        startLiveScan()
    }

    /// Change the wallpaper directory and re-scan immediately.
    function setWallpaperDir(dir: string) {
        console.log("[WallpaperService] setWallpaperDir", dir)
        if (dir.length === 0) {
            console.log("[WallpaperService] Empty directory, ignoring")
            return
        }
        root.wallpaperDir     = dir.endsWith("/") ? dir : dir + "/"
        root.stillList        = []
        root.currentWallpaper = ""
        root.lastIndex        = -1
        console.log("[WallpaperService] Wallpaper directory set to", root.wallpaperDir)
        saveConfig()
        startScan()
    }

    /// Set what rotation may pick: "all" | "still" | "live".
    function setLibraryMode(mode: string) {
        console.log("[WallpaperService] setLibraryMode", mode)
        if (mode !== "all" && mode !== "still" && mode !== "live") {
            console.warn("[WallpaperService] Invalid library mode:", mode)
            return
        }
        root.libraryMode = mode
        root.lastIndex   = -1
        saveConfig()
    }

    /// Change the live library directory and re-scan it.
    function setLiveDir(dir: string) {
        console.log("[WallpaperService] setLiveDir", dir)
        if (dir.length === 0) {
            console.log("[WallpaperService] Empty directory, ignoring")
            return
        }
        root.liveDir   = dir.endsWith("/") ? dir : dir + "/"
        root.liveList  = []
        root.thumbMap  = ({})
        root.lastIndex = -1
        saveConfig()
        startLiveScan()
    }

    // =========================================================================
    // AUTO-CYCLE TIMER  (the single rotation owner — QML, not the engine)
    // =========================================================================

    Timer {
        id: cycleTimer
        interval:         root.cycleInterval
        running:          root.cyclingEnabled && root.wallpaperList.length > 0
        repeat:           true
        triggeredOnStart: false

        onTriggered: {
            if (!root.cyclingEnabled) return
            if (Config.DebugConfig.debugService) console.log("[WallpaperService] Auto-cycle triggered")
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
            if (Config.DebugConfig.debugService) console.log("[WallpaperService] FUNCTION CALL: cycleNow")
            applyWallpaper(selectRandomWallpaper())
        }

        /// Re-scan both wallpaper directories
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
            if (Config.DebugConfig.debugService) console.log("[WallpaperService] FUNCTION CALL: setWallpaperByIndex", index)
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
            saveConfig()   // the toggle path saves; the IPC setter used not to
            console.log("[WallpaperService] IPC: setCyclingEnabled ->", enabled)
        }

        /// Set transition type
        function setTransition(type: string) {
            root.setTransition(type)
        }

        /// Freeze/resume live (gif/apng) playback
        function setAnimationPaused(paused: bool) {
            root.setAnimationPaused(paused)
        }

        /// Flip playback state
        function toggleAnimationPause() {
            root.toggleAnimationPause()
        }

        /// Return whether playback is currently frozen
        function getAnimationPaused(): bool {
            return root.animationPaused
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

        /// Set what rotation may pick: all | still | live
        function setLibraryMode(mode: string) {
            root.setLibraryMode(mode)
        }

        /// Return the current library mode
        function getLibraryMode(): string {
            return root.libraryMode
        }

        /// Return the live library directory
        function getLiveDir(): string {
            return root.liveDir
        }

        /// Change the live library directory and re-scan
        function setLiveDir(dir: string) {
            root.setLiveDir(dir)
        }

        /// Return the last engine status JSON string
        function getEngineStatus(): string {
            return root.lastEngineStatus
        }

        /// Freeze engine playback (mpv decode stops)
        function enginePause() {
            root.setAnimationPaused(true)
        }

        /// Resume engine playback
        function engineResume() {
            root.setAnimationPaused(false)
        }

        /// Flip engine playback state
        function engineTogglePause() {
            root.toggleAnimationPause()
        }
    }
}
