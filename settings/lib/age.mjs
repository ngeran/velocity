// age.mjs — compact relative-age labels for state files carrying a `ts`.
// Pure so the "· 2h ago" suffix renders identically wherever a sample is
// shown (settings views); no locale dependency by design.

export function ageLabel(ts, now = Date.now()) {
    if (typeof ts !== "number" || !(ts > 0) || !(now >= ts)) return ""
    const s = Math.floor((now - ts) / 1000)
    if (s < 60) return "just now"
    const m = Math.floor(s / 60)
    if (m < 60) return m + "m ago"
    const h = Math.floor(m / 60)
    if (h < 24) return h + "h ago"
    return Math.floor(h / 24) + "d ago"
}
