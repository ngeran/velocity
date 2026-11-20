// model.mjs — pure logic for the nikos.vnc plugin (no Quickshell imports;
// node-testable, same contract as wireguard/storage models). The QML service
// imports this as `import "lib/model.mjs" as Model` and keeps ALL parsing/
// formatting here so probes stay dumb argv→stdout pipes.

// ── probe output parsing ───────────────────────────────────────────────────

// Extract the RTT from `ping -c1` stdout, e.g.
//   "64 bytes from mac-mini.local (192.168.1.42): icmp_seq=1 ttl=64 time=0.412 ms"
// Returns rtt in ms, or null when the line is absent (timeout/DNS failure —
// the service then relies on the exit code, not the text).
export function parsePingMs(text) {
    if (typeof text !== "string") return null
    const m = text.match(/time[=<]([\d]+(?:\.\d+)?)\s*ms/i)
    return m ? parseFloat(m[1]) : null
}

// `ping -c1 -W1` exit codes: 0 = reply, 1 = timeout/no reply, 2 = error
// (unknown host / network unreachable). Both non-zero mean "unreachable"
// for our purposes.
export function pingOk(exitCode) {
    return exitCode === 0
}

// `nc -z -w1` prints nothing on success; exit 0 = port open, anything else
// (1 refused, 2 usage/timeout) = closed/unreachable.
export function portOpenFromExit(exitCode) {
    return exitCode === 0
}

// `pgrep -x vncviewer` exit codes: 0 = at least one match, 1 = none.
export function viewerRunningFromExit(exitCode) {
    return exitCode === 0
}

// ── settings clamps (service mirrors these for QML property writes) ───────

export function clampPort(value, fallback = 5900) {
    const n = parseInt(value, 10)
    if (!Number.isFinite(n)) return fallback
    return Math.min(65535, Math.max(1, n))
}

export function clampIntervalSec(value, fallback = 5) {
    const n = parseInt(value, 10)
    if (!Number.isFinite(n)) return fallback
    return Math.min(60, Math.max(2, n))
}

// ── viewer launch argv ─────────────────────────────────────────────────────

// vncviewer's `[host][::port]` endpoint syntax: double colon = RAW port
// (single colon would be display-number semantics — 5900 as ":5900" would
// be display 5900, i.e. port 35900. Never emit single-colon form).
export function endpoint(host, port) {
    return `${String(host).trim()}::${clampPort(port)}`
}

// Build the detached-launch argv for ctx.run. Returns null when the host is
// blank (service declines to launch rather than opening a viewer dialog).
// passwordFile is included ONLY when non-empty — the secret itself never
// appears, just the path to the vncpasswd file. `pwFile` (saved-connection
// field name) is accepted as an alias so connection records can be passed
// straight through.
export function buildViewerArgs(settings) {
    const host = String(settings?.host ?? "").trim()
    if (!host) return null
    const argv = ["vncviewer", endpoint(host, settings?.port)]
    const pw = String(settings?.passwordFile ?? settings?.pwFile ?? "").trim()
    if (pw) argv.push("-PasswordFile", pw)
    const ds = normalizeDesktopSize(settings?.desktopSize)
    if (ds) argv.push("-DesktopSize", ds)
    if (settings?.fullScreen) argv.push("-FullScreen")
    return argv
}

// ── per-connection desktop size (v2.2) ──────────────────────────────────────

// Validate a user-entered resolution. Blank / "auto" (any case) → "" (server
// default). Otherwise expects `WxH` with both axes in 200–10000 px; anything
// else normalizes to "" — a bad value silently means "auto" on reload, and
// the form validates before save so the user sees the error up front.
// Verified live 2026-11-20: macOS Screen Sharing honors `-DesktopSize WxH`
// on connect (single 2560x1440 screen instead of the combined dual-display
// framebuffer); empty = server default (all displays).
export function normalizeDesktopSize(raw) {
    const s = String(raw ?? "").trim().toLowerCase()
    if (!s || s === "auto") return ""
    const m = s.match(/^(\d{2,5})x(\d{2,5})$/)
    if (!m) return ""
    const w = parseInt(m[1], 10)
    const h = parseInt(m[2], 10)
    if (w < 200 || w > 10000 || h < 200 || h > 10000) return ""
    return `${w}x${h}`
}

// ── formatting ─────────────────────────────────────────────────────────────

export function fmtRtt(ms) {
    if (ms === null || ms === undefined || !Number.isFinite(ms) || ms <= 0) return "—"
    return `${ms < 10 ? ms.toFixed(1) : Math.round(ms)} ms`
}

export function fmtDuration(totalSec) {
    const s = Math.max(0, Math.floor(totalSec))
    if (s < 60) return `${s}s`
    const m = Math.floor(s / 60)
    if (m < 60) return `${m}m ${s % 60}s`
    const h = Math.floor(m / 60)
    return `${h}h ${m % 60}m`
}

// ── RTT history ring (sparkline feed) ──────────────────────────────────────

// Immutable push into a capped ring; returns the new array. 0/invalid
// samples are skipped (no data yet beats a zero-dip in the chart).
export function rttPush(history, ms, cap = 60) {
    if (!Number.isFinite(ms) || ms <= 0) return history ?? []
    const next = Array.isArray(history) ? history.concat([ms]) : [ms]
    return next.length > cap ? next.slice(next.length - cap) : next
}

// ── saved-connection store (v2) ─────────────────────────────────────────────

// Fresh connection id: `c-<base36 ms>` — generated, never derived from user
// input, so it is safe to interpolate into the sh -c writer paths by
// construction.
export function connectionId(now) {
    return `c-${Math.floor(now).toString(36)}`
}

// Blank draft for the popup form. Port defaults to the conventional 5900;
// pwFile stays empty until saveConnection pipes a password through vncpasswd.
export function newConnection(now) {
    return {
        id: connectionId(now),
        name: "",
        host: "",
        port: 5900,
        user: "",
        pwFile: "",
        desktopSize: "",
        fullScreen: false,
        lastUsedMs: 0,
        createdAtMs: Math.floor(now),
    }
}

// Coerce a record coming off disk (or out of the form) into a typed
// connection. Returns null when the host is blank — host is the only field
// a connection cannot exist without. Missing id gets a fresh generated one
// (hand-edited index files must never break the UI).
export function normalizeConnection(raw, now = Date.now()) {
    if (!raw || typeof raw !== "object") return null
    const host = String(raw.host ?? "").trim()
    if (!host) return null
    const ms = (v) => {
        const n = Number(v)
        return Number.isFinite(n) && n >= 0 ? Math.floor(n) : 0
    }
    return {
        id: typeof raw.id === "string" && raw.id.trim() ? raw.id.trim() : connectionId(now),
        name: String(raw.name ?? "").trim().slice(0, 40),
        host: host.slice(0, 63),
        port: clampPort(raw.port),
        user: String(raw.user ?? "").trim().slice(0, 40),
        pwFile: String(raw.pwFile ?? "").trim(),
        desktopSize: normalizeDesktopSize(raw.desktopSize),
        fullScreen: !!raw.fullScreen,
        lastUsedMs: ms(raw.lastUsedMs),
        createdAtMs: ms(raw.createdAtMs),
    }
}

// Upsert + prune for the connections array: drop invalid entries, dedupe by
// id (LATER occurrence wins — the freshly-edited record replaces its older
// self), sort most-recently-used first, cap at 12. Pure — returns a new array.
export function mergeConnections(list) {
    const byId = new Map()
    for (const raw of Array.isArray(list) ? list : []) {
        const conn = normalizeConnection(raw)
        if (conn) byId.set(conn.id, conn)
    }
    return [...byId.values()]
        .sort((a, b) => b.lastUsedMs - a.lastUsedMs)
        .slice(0, 12)
}

// ── error hygiene (process stderr → status rows) ───────────────────────────

// Strip ANSI escapes + control chars and elide to 160 chars — probe stderr
// can carry terminal noise and arbitrarily long DNS chatter.
export function sanitizeError(text) {
    const stripped = String(text ?? "")
        .replace(/\x1b\[[0-9;]*[A-Za-z]/g, "")   // CSI sequences
        .replace(/[\x00-\x1f\x7f]/g, " ")         // remaining controls
        .replace(/\s+/g, " ")
        .trim()
    return stripped.length > 160 ? stripped.slice(0, 159) + "…" : stripped
}
