// NetworkModel.test.mjs — AP-list additions (C3): grouping, signature, glyphs
import * as M from "./NetworkModel.mjs"
import { readFile } from "node:fs/promises"

let n = 0
function ok(cond, label) {
    n++
    if (!cond) { console.error("FAIL: " + label); process.exitCode = 1 }
}

// ── secured() — open classes ────────────────────────────────────────────────
ok(M.secured("Open") === false, "Open is not secured")
ok(M.secured("Unknown") === false, "Unknown is not secured")
ok(M.secured("Owe") === false, "Owe (enhanced open) is not secured")
ok(M.secured("Wpa2Psk") === true, "Wpa2Psk is secured")
ok(M.secured("Sae") === true, "Sae is secured")
ok(M.secured("Wpa2Eap") === true, "Wpa2Eap is secured")

// ── groupAps() — best-per-SSID, sorted, connected/empty filtered ───────────
function net(name, sig, sec, known, connected) {
    return { name, signalStrength: sig, security: sec, known: !!known, connected: !!connected,
             stateChanging: false }
}
const raw = [
    net("home", 0.42, "Wpa2Psk", true),          // weaker BSS of home
    net("home", 0.81, "Wpa2Psk", true),          // strongest — must win
    net("cafe", 0.66, "Open", false),
    net("", 0.99, "Open", false),                // hidden AP — no name, dropped
    net("active", 0.95, "Wpa2Psk", true, true),  // connected — hero's job
    net("old", 0.10, "Unknown", false),
]
const g = M.groupAps(raw, "active")
ok(g.length === 3, "connected + nameless filtered: 3 rows")
ok(g[0].name === "home" && g[0].pct === 81, "strongest BSS kept, sorted first")
ok(g[1].name === "cafe" && g[1].secured === false, "open row flagged unsecured")
ok(g[2].name === "old" && g[2].known === false, "unknown-security row still listed")
ok(g[0].net === raw[1], "display record KEEPS the live QObject")
// activeSsid fallback: even without a connected flag, the hero SSID is dropped
ok(M.groupAps(raw, "cafe").every(r => r.name !== "cafe"), "activeSsid row filtered by name too")
ok(M.groupAps(null, "").length === 0, "null scan list → empty list")

// ── apsSignature() — the view's content-diff gate ──────────────────────────
const sig1 = M.apsSignature(g)
ok(sig1 === M.apsSignature(M.groupAps(raw, "active")), "equal scans → equal signature")
ok(M.apsSignature([{ name: "x", pct: 1, secured: true, known: false }]) !== sig1, "different lists differ")
const g2 = JSON.parse(JSON.stringify(g))  // same content, new identity
g2.forEach(r => { delete r.net })         // strip the QObject (JSON can't hold it)
ok(M.apsSignature(g2) === sig1, "signature is CONTENT-based, identity-blind")

// ── sigGlyph() — the settings table ────────────────────────────────────────
ok(M.sigGlyph(80) === "\u{f0928}", "80% → strong glyph U+F0928")
ok(M.sigGlyph(40) === "\u{f0925}", "40% → mid glyph U+F0925")
ok(M.sigGlyph(20) === "\u{f0922}", "20% → weak glyph U+F0922")
ok(M.sigGlyph(5) === "\u{f091f}", "5% → low glyph U+F091F")
ok(M.sigGlyph(80).length === 2 && [...M.sigGlyph(80)].length === 1, "glyph is one astral code point (2 UTF-16 units)")

// ── failLabel() — native ConnectionFailReason mapping ──────────────────────
ok(M.failLabel("NoSecrets") === "Password required", "NoSecrets label")
ok(M.failLabel("WifiClientFailed") === "Wrong password or rejected", "auth-fail label")
ok(M.failLabel("WifiAuthTimeout") === "Authentication timed out", "timeout label")
ok(M.failLabel("WifiNetworkLost") === "Network disappeared", "lost-network label")
ok(M.failLabel("Unknown") === "Connection failed", "unknown fallback")
ok(M.failLabel("Whatever") === "Connection failed", "any future enum → generic")

// ── median() — the speed test reports the middle sample ────────────────────
ok(M.median([3, 1, 2]) === 2, "median of 3")
ok(M.median([4, 1, 3, 2]) === 3, "even count takes the upper middle")
ok(M.median([]) === 0, "empty sample → 0")

// ── legacy surface intact ───────────────────────────────────────────────────
ok(M.throughputState(null, "wlan0", 10, 10, 1).rxRate === "", "throughputState still exported")
ok(M.formatBytes(2048) === "2.0 KB", "formatBytes re-exported from shared units.mjs")
ok(M.formatRate(2048) === "2.0 KB/s", "formatRate re-exported from shared units.mjs")

// source hygiene: no raw astral glyphs in the literals (the C2 transport law)
const src = await readFile(new URL("./NetworkModel.mjs", import.meta.url), "utf8")
ok(src.includes('"\\u{f0928}"'), "glyph literals use explicit escapes")

console.log("NetworkModel.test: " + n + " asserts")
