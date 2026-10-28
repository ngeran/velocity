// wallpaper.test.mjs — pure WallpaperService logic (I8 split)
import * as M from "./wallpaper.mjs"

let n = 0
function ok(cond, label) {
    n++
    if (!cond) { console.error("FAIL: " + label); process.exitCode = 1 }
}

// ── backend classification ──────────────────────────────────────────────────
ok(M.isVideo("/x/a.mp4") && M.isVideo("/x/a.WEBM") && M.isVideo("/x/a.mkv") && M.isVideo("/x/a.MOV"),
   "video exts (case-insensitive)")
ok(!M.isVideo("/x/a.gif") && !M.isVideo("/x/a.webp") && !M.isVideo("") && !M.isVideo(undefined),
   "non-video / null-safe")
ok(M.isLive("/x/a.gif") && M.isLive("/x/a.APNG"), "awww-animated exts")
ok(!M.isLive("/x/a.webp") && !M.isLive("/x/a.mp4"), "webp/video are not awww-live")
ok(M.isEngined("/h/Live/a.mp4", "/h/Live/"), "exact liveDir prefix")
ok(M.isEngined("/h/Live/a.gif", "/h/Live"), "unslashed liveDir normalized")
ok(!M.isEngined("/h/Live-old/a.mp4", "/h/Live"), "sibling folder NOT claimed")
ok(!M.isEngined("/h/Pictures/Wallpapers/a.png", "/h/Live/"), "still dir not claimed")
ok(!M.isEngined("/anywhere/a.mp4", "") && !M.isEngined("/anywhere/a.mp4", undefined),
   "empty liveDir claims nothing")
ok(!M.isEngined("", "/h/Live/") && !M.isEngined(undefined, "/h/Live/"), "empty path not engined")

// ── preview resolver ────────────────────────────────────────────────────────
ok(M.previewSource("/x/a.png", {}, "/h/Live/") === "file:///x/a.png", "still → file itself")
ok(M.previewSource("/h/Live/a.mp4", { "/h/Live/a.mp4": "/c/a-k1.png" }, "/h/Live/")
   === "file:///c/a-k1.png", "engined → cached poster")
ok(M.previewSource("/h/Live/a.mp4", {}, "/h/Live/") === "", "engined without poster → empty")
ok(M.previewSource("", {}, "") === "", "empty path → empty")

// ── filtered library view ───────────────────────────────────────────────────
const STILL = ["/w/a.png", "/w/b.jpg"]
const LIVEV = ["/l/a.mp4", "/l/b.gif", "/l/c.webp"]
ok(JSON.stringify(M.filterLibrary(STILL, LIVEV, true, "all")) === JSON.stringify([...STILL, ...LIVEV]),
   "all + engine: stills then live")
ok(JSON.stringify(M.filterLibrary(STILL, LIVEV, true, "still")) === JSON.stringify(STILL), "still mode")
ok(JSON.stringify(M.filterLibrary(STILL, LIVEV, true, "live")) === JSON.stringify(LIVEV), "live mode")
ok(JSON.stringify(M.filterLibrary(STILL, LIVEV, false, "live")) === JSON.stringify(["/l/b.gif", "/l/c.webp"]),
   "no engine: videos hidden, gif/webp stay")
ok(JSON.stringify(M.filterLibrary(STILL, LIVEV, false, "all")) === JSON.stringify([...STILL, "/l/b.gif", "/l/c.webp"]),
   "no engine, all mode: videos hidden too")
ok(JSON.stringify(M.filterLibrary(null, null, false, "all")) === "[]", "null lists tolerated")

// ── scan output ─────────────────────────────────────────────────────────────
ok(JSON.stringify(M.parseFileList("/w/b.jpg\n/w/a.png\n", 0)) === JSON.stringify(["/w/a.png", "/w/b.jpg"]),
   "scan sorts, drops blank lines")
ok(JSON.stringify(M.parseFileList("", 0)) === JSON.stringify([]), "empty output → [] (blank filter)")
ok(JSON.stringify(M.parseFileList("whatever", 1)) === JSON.stringify([]), "failed scan → []")

// ── thumbnail map ───────────────────────────────────────────────────────────
// empty-value line sits mid-buffer: trim() would eat a trailing "\t\n"
const tm = M.parseThumbMap("/l/a.mp4\t/c/a-k1.png\n/l/c.mkv\t\n/l/b.webm\t/c/b-k2.png\njunk\n")
ok(tm["/l/a.mp4"] === "/c/a-k1.png" && tm["/l/b.webm"] === "/c/b-k2.png", "thumb pairs parsed")
ok(tm["/l/c.mkv"] === "", "empty value kept (key must be non-empty)")
ok(tm["junk"] === undefined && Object.keys(tm).length === 3, "junk line skipped")
ok(Object.keys(M.parseThumbMap("")).length === 0, "empty buffer → {}")

// ── engine status ───────────────────────────────────────────────────────────
const es = M.parseEngineStatus('{"running": true, "paused": false, "instances": 2}')
ok(es !== null && es.running === true && es.paused === false && es.instances === 2, "status fields")
ok(es.raw === '{"running": true, "paused": false, "instances": 2}', "raw echoed")
ok(M.parseEngineStatus('{"running": 1, "instances": 2.7}').running === false, "running is === true")
ok(M.parseEngineStatus('{"instances": 2.7}').instances === 2, "instances int-coerced")
ok(M.parseEngineStatus("{}").running === false && M.parseEngineStatus("{}").instances === 0,
   "missing fields default off")
ok(M.parseEngineStatus("daemon dead") === null, "garbage → null (keep previous raw)")

// ── random pick ─────────────────────────────────────────────────────────────
ok(M.pickRandom(["only"], 0, Math.random) === 0, "single entry → index 0")
ok(M.pickRandom([], 0, Math.random) === -1, "empty list → -1 (caller re-scans)")
// rng always landing on index 1: must still return 1 (attempts cap), len>1
ok(M.pickRandom(["a", "b"], 1, () => 0.5 + 1e-9) === 1, "repeat-avoid gives up after cap")
// rng landing on 0 first, then 1: first try ≠ lastIndex wins immediately
let calls = 0
const idx = M.pickRandom(["a", "b"], 1, () => (calls++ === 0 ? 0.2 : 0.9))
ok(idx === 0 && calls === 1, "non-repeating first try accepted")
// len 2 → maxAttempts 2: two tries both landing on lastIndex accept it
let c2 = 0
ok(M.pickRandom(["a", "b"], 1, () => (c2++ < 2 ? 0.9 : 0.2)) === 1 && c2 === 2,
   "attempts capped at min(10, len)")

// ── awww argv ───────────────────────────────────────────────────────────────
ok(JSON.stringify(M.buildAwwwCmd("/w/a.png", "fade", 60, 90, "")) ===
   JSON.stringify(["awww", "img", "/w/a.png", "--transition-type", "fade",
                   "--transition-fps", "60", "--transition-step", "90"]),
   "awww argv order + stringified fps/step")
ok(JSON.stringify(M.buildAwwwCmd("/w/a.png", "wipe", 60, 90, "DP-1")) ===
   JSON.stringify(["awww", "img", "/w/a.png", "--transition-type", "wipe",
                   "--transition-fps", "60", "--transition-step", "90", "--outputs", "DP-1"]),
   "monitor appends --outputs")

// ── config round-trip ───────────────────────────────────────────────────────
ok(M.normalizeDir("/h/Live") === "/h/Live/" && M.normalizeDir("/h/Live/") === "/h/Live/"
   && M.normalizeDir("") === "", "normalizeDir")
const st = { cycleInterval: 300000, cyclingEnabled: true, transitionType: "fade",
             animationPaused: false, wallpaperDir: "/w/", currentWallpaper: "/w/a.png",
             liveDir: "/l/", libraryMode: "all" }
const payload = M.configPayload(st)
ok(payload.cycleInterval === 300 && payload.libraryMode === "all", "payload ms→s")
ok(payload.wallpaperDir === "/w/" && payload.currentWallpaper === "/w/a.png", "payload passthrough")
const patch = M.loadedConfigPatch(payload)
ok(patch.cycleInterval === 300000 && patch.cyclingEnabled === true, "patch s→ms round-trip")
ok(patch.wallpaperDir === "/w/" && patch.currentWallpaper === "/w/a.png", "patch passthrough")
const partial = M.loadedConfigPatch({ transitionType: "wipe" })
ok(partial.transitionType === "wipe" && partial.cycleInterval === undefined
   && partial.liveDir === undefined, "absent keys stay absent")
ok(Object.keys(M.loadedConfigPatch(null)).length === 0, "null data → empty patch")

console.log(`wallpaper.test: ${n} asserts`)
