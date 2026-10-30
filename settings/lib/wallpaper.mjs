// =============================================================================
// wallpaper.mjs — pure classification + parsing for WallpaperService (I8)
// =============================================================================
// Everything the wallpaper pipeline decides without touching a process:
// the backend classification (video / awww-animated / engine-routed), the
// filtered library view, the scan + thumbnail + engine-status parsers, the
// repeat-avoiding random pick, the awww argv builder, and the config-file
// round-trip (ms↔seconds, trailing-slash normalization). The service stays
// IO + state (Processes, timers, configPersister); this file owns the rules.
// Patches carry `undefined` for "key absent" so the service can keep its
// previous value — exactly the old inline guards.
// =============================================================================

// Real video containers — only the engine can display these (the awww
// fallback cannot decode video; gif/webp/apng can stay).
export function isVideo(path) {
    var p = (path || "").toLowerCase()
    return p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv") || p.endsWith(".mov")
}

// Formats awww animates as a wallpaper (still library gif/apng).
export function isLive(path) {
    var p = (path || "").toLowerCase()
    return p.endsWith(".gif") || p.endsWith(".apng")
}

// Anything in the live library routes to wallpaper-engine (mpvpaper), awww
// fallback if the engine is unavailable. Directory-based (not extension-based)
// so existing still-library content, including gif/apng/webp, keeps its
// current awww behaviour. Prefix matches against the SLASHED dir: a liveDir
// without its trailing slash would also claim sibling folders
// (Live-Wallpapers-old).
export function isEngined(path, liveDir) {
    if (!liveDir || liveDir.length === 0) return false
    var d = liveDir.endsWith("/") ? liveDir : liveDir + "/"
    return (path || "").indexOf(d) === 0
}

// THE preview resolver (§1 dedup): stills use the file itself, engine content
// uses its cached poster frame ("" until extracted — callers show a
// placeholder).
// Grid/preview source for a library entry (P5.8): a cached thumbnail wins
// for ANY path (stills included — the grid used to decode full 4K files);
// engine content without a frame → "" (placeholder glyph); a still before
// its thumb pass → the file itself.
export function previewSource(path, thumbMap, liveDir) {
    if (!path) return ""
    var t = thumbMap ? thumbMap[path] : undefined
    if (t) return "file://" + t
    return isEngined(path, liveDir) ? "" : "file://" + path
}

// Filtered pick list — rotation, IPC index access and the gallery all read
// this, so a mode switch re-scopes everything at once. Without the engine,
// what's offered has to be limited to what a backend on this system can
// actually show: live videos are hidden (they used to be pushed to awww every
// cycle), while gif/webp/apng remain through the awww fallback.
export function filterLibrary(stillList, liveList, engineAvailable, libraryMode) {
    var live = liveList || []
    if (!engineAvailable) {
        live = live.filter(function(p) { return !isVideo(p) })
    }
    if (libraryMode === "still") return stillList || []
    if (libraryMode === "live")  return live
    return (stillList || []).concat(live)
}

// `find` scan output → sorted path list. A failed scan (code !== 0) reads as
// empty — the caller keeps its exit-code warn.
export function parseFileList(out, code) {
    var lines = code === 0
                ? (out || "").trim().split("\n").filter(function(l) { return l.trim().length > 0 })
                : []
    lines.sort()
    return lines
}

// Thumb-worker stdout → { thumbs: {path → png}, luma: {path → number} }.
// One line per file: `path\tpng\tyavg` (yavg = ffmpeg signalstats YAVG of
// the thumbnail, mean luma 0..255 — P5.7's dark-only filter reads it;
// absent/invalid stays absent). The png path embeds an mtime+size hash, so
// both caches invalidate together on edit.
export function parseThumbStats(buf) {
    var thumbs = {}, luma = {}
    var lines = (buf || "").trim().split("\n")
    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].split("\t")
        if (parts.length !== 3 || parts[0].length === 0 || parts[1].length === 0) continue
        thumbs[parts[0]] = parts[1]
        var y = parseFloat(parts[2])
        if (!isNaN(y) && y >= 0 && y <= 255) luma[parts[0]] = y / 255
    }
    return { thumbs: thumbs, luma: luma }
}

// P5.7 dark-only pick filter: keep entries with KNOWN mean luma ≤ threshold
// (0..1). Unknown luma (thumb pass hasn't reached the file) stays — the
// filter must never blank the library just because thumbs are pending.
export function filterDarkOnly(list, lumaMap, threshold) {
    var cap = threshold > 0 ? threshold : 0.25
    var out = []
    for (var i = 0; i < list.length; i++) {
        var l = lumaMap ? lumaMap[list[i]] : undefined
        if (l === undefined || l <= cap) out.push(list[i])
    }
    return out
}

// One `wallpaper-engine status` output → {running, paused, instances, raw},
// or null on garbage (daemon down mid-poll — the caller treats it as off and
// keeps the previous raw status). `| 0` is the original int coercion.
export function parseEngineStatus(buf) {
    var s = (buf || "").trim()
    try {
        var st = JSON.parse(s)
        return {
            running:   st.running === true,
            paused:    st.paused === true,
            instances: st.instances | 0,
            raw:       s
        }
    } catch (e) {
        return null
    }
}

// Random index into the filtered list, avoiding an immediate repeat. Pure:
// rng is injected (Math.random in the service) so tests are deterministic.
// Returns -1 only for an empty list (the caller re-scans instead).
export function pickRandom(list, lastIndex, rng) {
    var len = list.length
    if (len === 0) return -1
    var attempts = 0
    var maxAttempts = Math.min(10, len)
    var idx
    do {
        idx = Math.floor(rng() * len)
        attempts++
    } while (idx === lastIndex && attempts < maxAttempts && len > 1)
    return idx
}

// Legacy awww apply argv (stills, and gif/apng/webp fallback without engine).
// fps/step arrive as numbers and go out as strings; --outputs only when a
// specific monitor is selected.
export function buildAwwwCmd(path, transitionType, fps, step, monitor) {
    var cmd = [
        "awww", "img", path,
        "--transition-type", transitionType,
        "--transition-fps", String(fps),
        "--transition-step", String(step)
    ]
    if (monitor && monitor.length > 0) cmd.push("--outputs", monitor)
    return cmd
}

// One Hyprland socket2 line → { active } for fullscreen transitions, or null
// for anything that is not a fullscreen event (the caller ignores those).
// Verified live on this compositor (0.55.4): enter `fullscreen>>1`, exit
// `fullscreen>>0` — no monitor token. Newer/other builds may append one
// (",MONITOR"); the suffix is ignored. `fullscreen<<` is treated as an exit
// defensively. Any non-zero state counts as active (2 = full/maximize modes).
export function parseFullscreenEvent(line) {
    var s = String(line == null ? "" : line)
    if (s.startsWith("fullscreen<<")) return { active: false }
    if (!s.startsWith("fullscreen>>")) return null
    var state = parseInt(s.substring(12), 10)
    return { active: state !== 0 && !isNaN(state) }
}

// Config dirs are stored slashed (writers add it, isEngined prefix-matches
// with "/"); an empty dir stays empty.
export function normalizeDir(d) {
    d = d || ""
    if (d.length > 0 && !d.endsWith("/")) d += "/"
    return d
}

// wallpaper-config.json payload from live state (ms converted to seconds).
// `st` is the service root — it carries exactly these property names.
export function configPayload(st) {
    return {
        cycleInterval:    st.cycleInterval / 1000,
        cyclingEnabled:   st.cyclingEnabled,
        transitionType:   st.transitionType,
        animationPaused:  st.animationPaused,
        wallpaperDir:     st.wallpaperDir,
        currentWallpaper: st.currentWallpaper,
        liveDir:          st.liveDir,
        libraryMode:      st.libraryMode,
        darkOnly:         st.darkOnly
    }
}

// Loaded wallpaper-config.json → patch of only the keys the file carries
// (absent key = absent field = the service keeps its previous value).
// cycleInterval converts seconds → ms here. Dirs are NOT slashed here — the
// service normalizes them after applying, because the fix is unconditional
// (a HOME default set before load also needs it).
export function loadedConfigPatch(data) {
    var p = {}
    if (!data) return p
    if (data.cycleInterval   !== undefined) p.cycleInterval    = data.cycleInterval * 1000
    if (data.cyclingEnabled  !== undefined) p.cyclingEnabled   = data.cyclingEnabled
    if (data.transitionType  !== undefined) p.transitionType   = data.transitionType
    if (data.animationPaused !== undefined) p.animationPaused  = data.animationPaused
    if (data.wallpaperDir    !== undefined) p.wallpaperDir     = data.wallpaperDir
    if (data.currentWallpaper !== undefined) p.currentWallpaper = data.currentWallpaper
    if (data.liveDir         !== undefined) p.liveDir          = data.liveDir
    if (data.libraryMode     !== undefined) p.libraryMode      = data.libraryMode
    if (data.darkOnly        !== undefined) p.darkOnly         = data.darkOnly
    return p
}
