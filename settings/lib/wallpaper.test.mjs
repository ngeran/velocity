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
ok(M.previewSource("/x/a.png", {}, "/h/Live/") === "file:///x/a.png", "still, no thumb → file itself")
ok(M.previewSource("/x/a.png", { "/x/a.png": "/c/a-k1.png" }, "/h/Live/")
   === "file:///c/a-k1.png", "still with cached thumb → thumb (P5.8: never decode the 4K file)")
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

// ── thumbnail map + luma (P5.8) ─────────────────────────────────────────────
const ts = M.parseThumbStats(
    "/l/a.mp4\t/c/a-k1.png\t46.5\n/w/dark.png\t/c/dark-k2.png\t12.25\n" +
    "/w/bright.png\t/c/br-k3.png\t200\n/w/noLuma.png\t/c/nl-k4.png\t\njunk\n/l/x.mkv\t\t30\n")
ok(ts.thumbs["/l/a.mp4"] === "/c/a-k1.png" && ts.thumbs["/w/dark.png"] === "/c/dark-k2.png",
   "thumb pairs parsed")
ok(ts.luma["/l/a.mp4"] !== undefined && Math.abs(ts.luma["/l/a.mp4"] - 46.5 / 255) < 1e-9,
   "yavg → 0..1 luma")
ok(Math.abs(ts.luma["/w/dark.png"] - 12.25 / 255) < 1e-9, "dark still maps low luma")
ok(ts.luma["/w/noLuma.png"] === undefined, "empty yavg stays absent (filter keeps unknown)")
ok(ts.thumbs["/w/noLuma.png"] === "/c/nl-k4.png", "thumb kept even without luma")
ok(ts.thumbs["junk"] === undefined && ts.luma["junk"] === undefined, "junk line skipped")
ok(ts.thumbs["/l/x.mkv"] === undefined, "line without png skipped (ffmpeg failed)")
ok(Object.keys(M.parseThumbStats("").thumbs).length === 0, "empty buffer → empty maps")

// ── dark-only pick filter (P5.7) ────────────────────────────────────────────
const LUMA = { "/w/dark.png": 0.05, "/w/mid.png": 0.25, "/w/bright.png": 0.6 }
const pick = ["/w/dark.png", "/w/mid.png", "/w/bright.png", "/w/unknown.png"]
ok(JSON.stringify(M.filterDarkOnly(pick, LUMA, 0.25)) ===
   JSON.stringify(["/w/dark.png", "/w/mid.png", "/w/unknown.png"]),
   "dark-only: luma ≤ cap kept, bright dropped, unknown kept")
ok(JSON.stringify(M.filterDarkOnly(pick, LUMA, 0)) ===
   JSON.stringify(["/w/dark.png", "/w/mid.png", "/w/unknown.png"]),
   "dark-only: cap ≤ 0 falls back to default 0.25, unknown still kept")
ok(JSON.stringify(M.filterDarkOnly(pick, null, 0.25)) === JSON.stringify(pick),
   "dark-only: no luma map → full list (never blank the library)")

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
             liveDir: "/l/", libraryMode: "all", darkOnly: true }
const payload = M.configPayload(st)
ok(payload.cycleInterval === 300 && payload.libraryMode === "all", "payload ms→s")
ok(payload.wallpaperDir === "/w/" && payload.currentWallpaper === "/w/a.png", "payload passthrough")
ok(payload.darkOnly === true, "payload carries darkOnly (P5.7)")
const patch = M.loadedConfigPatch(payload)
ok(patch.cycleInterval === 300000 && patch.cyclingEnabled === true, "patch s→ms round-trip")
ok(patch.wallpaperDir === "/w/" && patch.currentWallpaper === "/w/a.png", "patch passthrough")
ok(patch.darkOnly === true && M.loadedConfigPatch({}).darkOnly === undefined,
   "patch: darkOnly present only when the file has it (seed survives)")
const partial = M.loadedConfigPatch({ transitionType: "wipe" })
ok(partial.transitionType === "wipe" && partial.cycleInterval === undefined
   && partial.liveDir === undefined, "absent keys stay absent")
ok(Object.keys(M.loadedConfigPatch(null)).length === 0, "null data → empty patch")

// ── fullscreen socket2 events (P5.6) ────────────────────────────────────────
ok(M.parseFullscreenEvent("fullscreen>>1").active === true, "fs: enter fullscreen>>1")
ok(M.parseFullscreenEvent("fullscreen>>0").active === false, "fs: exit fullscreen>>0")
ok(M.parseFullscreenEvent("fullscreen>>2").active === true, "fs: state 2 counts as active")
ok(M.parseFullscreenEvent("fullscreen>>1,DP-1").active === true, "fs: monitor suffix tolerated (enter)")
ok(M.parseFullscreenEvent("fullscreen>>0,DP-1").active === false, "fs: monitor suffix tolerated (exit)")
ok(M.parseFullscreenEvent("fullscreen<<").active === false, "fs: fullscreen<< treated as exit")
ok(M.parseFullscreenEvent("fullscreen>>x").active === false, "fs: garbage state not active")
ok(M.parseFullscreenEvent("activewindow>>x,y") === null, "fs: non-fullscreen line → null")
ok(M.parseFullscreenEvent("") === null && M.parseFullscreenEvent(null) === null, "fs: empty/null → null")

console.log(`wallpaper.test: ${n} asserts`)
