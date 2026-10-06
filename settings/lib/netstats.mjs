// netstats.mjs — latency-leg statistics (math adapted from omarchy-nexthop)
// =============================================================================
// Pure, node-testable fold for latency samples plus the two-leg WAN-point
// refusal. Consumers: NetworkControlService (two-leg latency section in the
// ENGINEER pane). No QML imports — keep this file dependency-free.
//
// Definitions that matter (do not "simplify" them back):
//   jitter  = IPDV — mean |rtt[i] - rtt[i-1]| over consecutive ok samples.
//             NOT stdev: 10/40/10/40 feels far worse than a smooth drift
//             across the same range, and only IPDV says so.
//   felt    = p75 + 1.5*jitter + lossFrac * lossCostMs(p75) — loss charged at
//             a retransmit timeout scaled by the link's own RTT (a dropped
//             packet costs more on a 600 ms satellite link than on fibre).
//   band    = [p50, p75, p95] clamped monotonic — best/typical/worst must
//             never read backwards.
// =============================================================================

export const LOSS_STALL_FACTOR = 5
export const LOSS_RTO_FLOOR_MS = 200
export const WAN_INVERSION_TOLERANCE_MS = 15

function percentile(sorted, p) {
    if (sorted.length === 0) return null
    const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1))
    return sorted[idx]
}

function round1(v) { return Math.round(v * 10) / 10 }

// fold(samples) — samples: [{ok: boolean, rtt: number|null}] (losses carry
// ok=false, rtt=null). Returns the leg statistics or null when empty.
export function fold(samples) {
    if (!Array.isArray(samples) || samples.length === 0) return null
    const rtts = samples.filter(s => s && s.ok && isFinite(s.rtt)).map(s => s.rtt)
    const lost = samples.length - rtts.length
    const lossFrac = lost / samples.length
    const sorted = [...rtts].sort((a, b) => a - b)
    const p50 = percentile(sorted, 50)
    const p75 = percentile(sorted, 75)
    const p95 = percentile(sorted, 95)

    let jitter = 0
    for (let i = 1; i < rtts.length; i++) jitter += Math.abs(rtts[i] - rtts[i - 1])
    jitter = rtts.length > 1 ? jitter / (rtts.length - 1) : 0

    const lossCost = LOSS_STALL_FACTOR * Math.max(LOSS_RTO_FLOOR_MS, 3 * (p75 || 0))
    const felt = p75 !== null ? p75 + 1.5 * jitter + lossFrac * lossCost : null

    // monotonic band: best <= typical <= worst, always
    let best = p50, typical = p75, worst = p95
    if (typical !== null && best !== null) typical = Math.max(typical, best)
    if (worst !== null && typical !== null) worst = Math.max(worst, typical)

    return {
        n: samples.length, ok: rtts.length, lost,
        lossPct: round1(lossFrac * 100),
        p50: p50 !== null ? round1(p50) : null,
        p75: p75 !== null ? round1(p75) : null,
        p95: p95 !== null ? round1(p95) : null,
        jitter: round1(jitter),
        felt: felt !== null ? round1(felt) : null,
        band: [best, typical, worst].map(v => (v !== null ? round1(v) : null))
    }
}

// wanPoint(totalMs, localMs) — the ISP leg for ONE paired reading
// (internet rtt minus gateway rtt), or null when the pair says nothing:
// a gateway answering SLOWER than the internet behind it (routers often
// deprioritize ICMP to themselves) is a refusal, never a clamped 0.0 ms.
export function wanPoint(totalMs, localMs) {
    if (!isFinite(totalMs) || !isFinite(localMs)) return null
    if (localMs > totalMs + WAN_INVERSION_TOLERANCE_MS) return null
    return round1(Math.max(0, totalMs - localMs))
}
