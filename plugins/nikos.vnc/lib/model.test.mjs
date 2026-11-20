// model.test.mjs — node asserts for the pure VNC plugin model (no framework,
// same contract as wireguard/storage tests). Run via tools/run-unit-tests.
import assert from "node:assert"
import {
    parsePingMs, pingOk, portOpenFromExit, viewerRunningFromExit,
    clampPort, clampIntervalSec, endpoint, buildViewerArgs,
    fmtRtt, fmtDuration, rttPush, sanitizeError,
    connectionId, newConnection, normalizeConnection, mergeConnections,
    normalizeDesktopSize
} from "./model.mjs"

let n = 0
const ok = (name, fn) => { fn(); n++; console.log("  ok " + name) }

// ── ping parsing ───────────────────────────────────────────────────────────
ok("parsePingMs extracts time= from a reply line", () => {
    const line = "64 bytes from mac-mini.local (192.168.1.42): icmp_seq=1 ttl=64 time=0.412 ms\n"
    assert.strictEqual(parsePingMs(line), 0.412)
})

ok("parsePingMs handles integer time and < form", () => {
    assert.strictEqual(parsePingMs("time=12 ms"), 12)
    assert.strictEqual(parsePingMs("time<1 ms"), 1)  // rare busybox-ish form
})

ok("parsePingMs returns null on timeout/DNS-fail output", () => {
    assert.strictEqual(parsePingMs(""), null)
    assert.strictEqual(parsePingMs("PING mac-mini.local 56(84) bytes of data.\n\n--- stats ---\n1 packets transmitted, 0 received"), null)
    assert.strictEqual(parsePingMs(undefined), null)
})

ok("pingOk maps exit codes", () => {
    assert.strictEqual(pingOk(0), true)
    assert.strictEqual(pingOk(1), false)   // timeout
    assert.strictEqual(pingOk(2), false)   // unknown host
})

// ── port + viewer exit codes ───────────────────────────────────────────────
ok("portOpenFromExit / viewerRunningFromExit", () => {
    assert.strictEqual(portOpenFromExit(0), true)
    assert.strictEqual(portOpenFromExit(1), false)
    assert.strictEqual(viewerRunningFromExit(0), true)
    assert.strictEqual(viewerRunningFromExit(1), false)
})

// ── clamps ─────────────────────────────────────────────────────────────────
ok("clampPort bounds and falls back", () => {
    assert.strictEqual(clampPort(5900), 5900)
    assert.strictEqual(clampPort(0), 1)
    assert.strictEqual(clampPort(70000), 65535)
    assert.strictEqual(clampPort("5901"), 5901)
    assert.strictEqual(clampPort("garbage"), 5900)
    assert.strictEqual(clampPort(undefined), 5900)
})

ok("clampIntervalSec bounds and falls back", () => {
    assert.strictEqual(clampIntervalSec(5), 5)
    assert.strictEqual(clampIntervalSec(1), 2)
    assert.strictEqual(clampIntervalSec(120), 60)
    assert.strictEqual(clampIntervalSec(null), 5)
})

// ── endpoint + argv ────────────────────────────────────────────────────────
ok("endpoint uses raw-port double colon", () => {
    assert.strictEqual(endpoint("mac-mini.local", 5900), "mac-mini.local::5900")
    assert.strictEqual(endpoint(" 192.168.1.42 ", "5901"), "192.168.1.42::5901")
})

ok("buildViewerArgs composes minimal launch", () => {
    assert.deepStrictEqual(
        buildViewerArgs({ host: "mac-mini.local", port: 5900, passwordFile: "", fullScreen: false }),
        ["vncviewer", "mac-mini.local::5900"]
    )
})

ok("buildViewerArgs adds -PasswordFile only when set", () => {
    assert.deepStrictEqual(
        buildViewerArgs({ host: "mac-mini.local", port: 5900, passwordFile: "/home/nikos/.config/secrets/mac-mini.vnc", fullScreen: false }),
        ["vncviewer", "mac-mini.local::5900", "-PasswordFile", "/home/nikos/.config/secrets/mac-mini.vnc"]
    )
})

ok("buildViewerArgs adds -FullScreen when bool set", () => {
    assert.deepStrictEqual(
        buildViewerArgs({ host: "m.local", port: 5900, passwordFile: "", fullScreen: true }),
        ["vncviewer", "m.local::5900", "-FullScreen"]
    )
})

ok("buildViewerArgs refuses blank host", () => {
    assert.strictEqual(buildViewerArgs({ host: "   ", port: 5900 }), null)
    assert.strictEqual(buildViewerArgs({}), null)
})

ok("buildViewerArgs passes a connection pwFile through", () => {
    assert.deepStrictEqual(
        buildViewerArgs({ host: "10.0.0.70", port: 5900, pwFile: "/home/nikos/.config/secrets/vnc/c-abc.vnc" }),
        ["vncviewer", "10.0.0.70::5900", "-PasswordFile", "/home/nikos/.config/secrets/vnc/c-abc.vnc"]
    )
})

// ── desktop size (v2.2) ────────────────────────────────────────────────────
ok("normalizeDesktopSize accepts WxH and auto/blank", () => {
    assert.strictEqual(normalizeDesktopSize("2560x1440"), "2560x1440")
    assert.strictEqual(normalizeDesktopSize(" 1920X1080 "), "1920x1080")   // caps X, trimmed
    assert.strictEqual(normalizeDesktopSize("AUTO"), "")
    assert.strictEqual(normalizeDesktopSize(""), "")
    assert.strictEqual(normalizeDesktopSize(null), "")
    assert.strictEqual(normalizeDesktopSize(undefined), "")
})

ok("normalizeDesktopSize rejects junk and out-of-range axes", () => {
    assert.strictEqual(normalizeDesktopSize("1440"), "")            // missing axis
    assert.strictEqual(normalizeDesktopSize("2560×1440"), "")       // unicode × is not x
    assert.strictEqual(normalizeDesktopSize("2560 x 1440"), "")     // spaces inside
    assert.strictEqual(normalizeDesktopSize("100x100"), "")         // below 200 floor
    assert.strictEqual(normalizeDesktopSize("20000x1440"), "")      // above 10000 ceiling
    assert.strictEqual(normalizeDesktopSize("x1440"), "")
    assert.strictEqual(normalizeDesktopSize(2560), "")              // non-string
})

ok("buildViewerArgs adds -DesktopSize only for a valid WxH", () => {
    assert.deepStrictEqual(
        buildViewerArgs({ host: "10.0.0.70", port: 5900, passwordFile: "", desktopSize: "2560x1440" }),
        ["vncviewer", "10.0.0.70::5900", "-DesktopSize", "2560x1440"]
    )
    // junk never reaches argv — record read off disk with a bad value degrades
    // to "server default", never an invalid viewer parameter
    assert.deepStrictEqual(
        buildViewerArgs({ host: "10.0.0.70", port: 5900, passwordFile: "", desktopSize: "garbage" }),
        ["vncviewer", "10.0.0.70::5900"]
    )
})

// ── saved-connection store (v2) ────────────────────────────────────────────
ok("connectionId is c- + base36 of the timestamp", () => {
    assert.strictEqual(connectionId(0), "c-0")
    assert.strictEqual(connectionId(1732118400000), "c-" + (1732118400000).toString(36))
})

ok("newConnection returns a blank typed draft", () => {
    const c = newConnection(5000)
    assert.strictEqual(c.id, connectionId(5000))   // same generated form
    assert.strictEqual(c.host, "")
    assert.strictEqual(c.port, 5900)
    assert.strictEqual(c.pwFile, "")
    assert.strictEqual(c.desktopSize, "")
    assert.strictEqual(c.fullScreen, false)
    assert.strictEqual(c.lastUsedMs, 0)
    assert.strictEqual(c.createdAtMs, 5000)
})

ok("normalizeConnection coerces types and trims", () => {
    const c = normalizeConnection({
        id: " c-x ", name: "  Mac mini ", host: " 10.0.0.70 ", port: "70000",
        user: " nikos ", pwFile: " /tmp/p.vnc ", desktopSize: " 2560X1440 ", fullScreen: 1, lastUsedMs: "123.7",
    })
    assert.deepStrictEqual(c, {
        id: "c-x", name: "Mac mini", host: "10.0.0.70", port: 65535,
        user: "nikos", pwFile: "/tmp/p.vnc", desktopSize: "2560x1440", fullScreen: true,
        lastUsedMs: 123, createdAtMs: 0,
    })
})

ok("normalizeConnection regenerates a missing id deterministically", () => {
    const c = normalizeConnection({ host: "10.0.0.70" }, 7000)
    assert.strictEqual(c.id, connectionId(7000))
})

ok("normalizeConnection drops hostless/invalid records", () => {
    assert.strictEqual(normalizeConnection({ name: "no host" }), null)
    assert.strictEqual(normalizeConnection(null), null)
    assert.strictEqual(normalizeConnection("junk"), null)
    assert.strictEqual(normalizeConnection({ host: "   " }), null)
})

ok("mergeConnections dedupes by id (later wins), sorts, caps at 12", () => {
    const mk = (id, lastUsedMs, host = "10.0.0.1") => ({ id, host, lastUsedMs, name: id })
    const list = [
        mk("a", 100), mk("b", 300), mk("a", 200),          // dup 'a' → later (200) wins
        null, mk("", 999), mk("z", 50, ""),                 // dropped: null, no-id-valid-host, hostless
        ...Array.from({ length: 9 }, (_, i) => mk(`n${i}`, 1000 + i)),
    ]
    const out = mergeConnections(list)                        // 12 valid (a,b,regen-id,n0..n8), z hostless-dropped
    assert.strictEqual(out.length, 12)
    assert.strictEqual(out.find((c) => c.id === "a").lastUsedMs, 200)
    assert.strictEqual(out[0].id, "n8")                       // most recently used first
    assert.strictEqual(out.find((c) => c.id === "z"), undefined)
})

ok("mergeConnections sorts never-used connections last", () => {
    const out = mergeConnections([{ id: "fresh", host: "h", lastUsedMs: 0 }, { id: "used", host: "h", lastUsedMs: 5 }])
    assert.deepStrictEqual(out.map((c) => c.id), ["used", "fresh"])
})

// ── formatting ─────────────────────────────────────────────────────────────
ok("fmtRtt formats sub-10ms with one decimal, else rounds", () => {
    assert.strictEqual(fmtRtt(0.412), "0.4 ms")
    assert.strictEqual(fmtRtt(7.56), "7.6 ms")
    assert.strictEqual(fmtRtt(23.49), "23 ms")
    assert.strictEqual(fmtRtt(0), "—")
    assert.strictEqual(fmtRtt(null), "—")
    assert.strictEqual(fmtRtt(NaN), "—")
})

ok("fmtDuration scales s → m+s → h+m", () => {
    assert.strictEqual(fmtDuration(45), "45s")
    assert.strictEqual(fmtDuration(0), "0s")
    assert.strictEqual(fmtDuration(252), "4m 12s")
    assert.strictEqual(fmtDuration(4980), "1h 23m")
    assert.strictEqual(fmtDuration(-5), "0s")
})

// ── RTT ring ───────────────────────────────────────────────────────────────
ok("rttPush appends and caps at 60, skipping invalid samples", () => {
    let h = []
    for (let i = 1; i <= 65; i++) h = rttPush(h, i)
    assert.strictEqual(h.length, 60)
    assert.strictEqual(h[0], 6)      // oldest surviving sample
    assert.strictEqual(h[59], 65)    // newest
    assert.deepStrictEqual(rttPush(h, 0), h)      // zero skipped
    assert.deepStrictEqual(rttPush(h, NaN), h)    // NaN skipped
    assert.deepStrictEqual(rttPush(undefined, 5), [5])
})

// ── error hygiene ──────────────────────────────────────────────────────────
ok("sanitizeError strips ANSI/control and elides at 160", () => {
    assert.strictEqual(sanitizeError("\x1b[31mping: x\x1b[0m"), "ping: x")
    assert.strictEqual(sanitizeError("a\x00b\x07c"), "a b c")
    const long = sanitizeError("e".repeat(300))
    assert.strictEqual(long.length, 160)
    assert.ok(long.endsWith("…"))
    assert.strictEqual(sanitizeError(null), "")
})

console.log(`model.test.mjs: ${n} ok`)
