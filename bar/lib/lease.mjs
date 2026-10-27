// lease.mjs — bounded lease math for cross-process metric polling (H7).
// The bar polls /proc + nvidia-smi ONLY while a consumer holds a lease:
// the Fastfetch overlay (shown-state) or an IPC grant. Pure so the clamp
// and expiry rules are node-tested and identical wherever a lease lives.

export const LEASE_MAX_S = 30

// Grant a lease: seconds clamped to [0, LEASE_MAX_S]; junk → 0 (no grant).
// Returns the absolute expiry (epoch ms) — 0 means "nothing granted".
export function acquire(seconds, now = Date.now()) {
    if (typeof seconds !== "number" || !(seconds > 0)) return 0
    const s = Math.min(Math.floor(seconds), LEASE_MAX_S)
    return s > 0 ? now + s * 1000 : 0
}

// A lease is expired once its expiry instant has passed (== counts as gone).
export function expired(expiryMs, now = Date.now()) {
    if (typeof expiryMs !== "number" || !(expiryMs > 0)) return true
    return expiryMs <= now
}

// Milliseconds left, floored at 0 — for "renews in Ns" UIs and tests.
export function remainingMs(expiryMs, now = Date.now()) {
    if (expired(expiryMs, now)) return 0
    return expiryMs - now
}
