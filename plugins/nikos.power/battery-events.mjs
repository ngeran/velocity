// =============================================================================
// battery-events.mjs — battery edge detection for the island (J7, pure)
// =============================================================================
// UPower delivers DBus property notifies; this file turns a stream of samples
// into at-most-one events per real transition — no polling, no timers.
//
//   · first sample is the BASELINE: boot must not fire (a bar restart while
//     already plugged in / already low stays silent)
//   · plug  — charging false→true
//   · full  — state reaches FullyCharged
//   · low   — armed + discharging + pct ≤ threshold; fires once, then
//             disarms; re-arms above threshold or on plug (hysteresis —
//             one nag per drain, not one per percentage point)
//   · charging/state transitions within `debounceMs` of the last accepted
//     transition are swallowed (AC-connector flap must not spam cards);
//     percentage updates bypass the debounce (slow, and they carry the
//     low-crossing)
//   · a sample with has=false (no system battery) never produces events and
//     never advances the baseline
//
// The QML side (BatteryService) owns the UPower reads and reassigns the
// state object this returns — never mutated (QML binding identity).
// =============================================================================

export const DEFAULT_DEBOUNCE_MS = 2000

// Fresh machine. `seen` stays false until the first has=true sample.
export function initState() {
    return { seen: false, charging: false, full: false, pct: 100,
             lowArmed: false, lastTransitionAt: 0 }
}

// Feed one sample; returns { state, events } where events is a list of
// { kind, pct } in emission order. `now` is injected so tests drive the clock.
//   sample: { has, charging, full, pct }     opts: { lowThreshold, debounceMs }
export function update(state, sample, opts, now) {
    const threshold = (opts && isFinite(opts.lowThreshold)) ? Number(opts.lowThreshold) : 20
    const debounce = (opts && isFinite(opts.debounceMs)) ? Number(opts.debounceMs) : DEFAULT_DEBOUNCE_MS
    const events = []

    // No system battery: permanently silent (and never baselined — a battery
    // that appears later starts a fresh baseline).
    if (!sample || !sample.has) return { state: state, events: events }

    const s = state || initState()

    // Baseline: arm low only if we booted above the threshold. The baseline
    // seeds NO debounce anchor (-Infinity): a genuine plug right after boot
    // is real, not flap.
    if (!s.seen) {
        const pct = normPct(sample.pct)
        return { state: { seen: true, charging: !!sample.charging, full: !!sample.full,
                          pct: pct, lowArmed: pct > threshold,
                          lastTransitionAt: -Infinity },
                 events: events }
    }

    const st = { seen: true, charging: s.charging, full: s.full, pct: s.pct,
                 lowArmed: s.lowArmed, lastTransitionAt: s.lastTransitionAt }
    const pct = normPct(sample.pct)
    const stateChanged = !!sample.charging !== st.charging || !!sample.full !== st.full

    // Transition debounce — percentage changes are exempt (they arrive
    // minutes apart and are what carries the low-battery crossing).
    if (stateChanged && now - st.lastTransitionAt < debounce) {
        return { state: st, events: events }
    }
    if (stateChanged) st.lastTransitionAt = Math.floor(now)

    const wasCharging = st.charging
    st.charging = !!sample.charging
    st.full = !!sample.full
    st.pct = pct

    // plug — and plugging re-arms low (the battery is about to climb).
    if (!wasCharging && st.charging) {
        st.lowArmed = true
        events.push({ kind: "plug", pct: pct })
    }

    // full — reaching FullyCharged re-arms low too (100% > any threshold).
    if (!s.full && st.full) {
        st.lowArmed = true
        events.push({ kind: "full", pct: pct })
    }

    // low — edge on the percentage while discharging; one fire per drain.
    if (pct > threshold) {
        st.lowArmed = true
    } else if (st.lowArmed && !st.charging && !st.full) {
        st.lowArmed = false
        events.push({ kind: "low", pct: pct })
    }

    return { state: st, events: events }
}

function normPct(p) {
    const n = Math.round(Number(p))
    if (!isFinite(n)) return 100
    return Math.max(0, Math.min(100, n))
}
