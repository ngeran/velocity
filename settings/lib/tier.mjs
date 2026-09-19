// =============================================================================
// tier.mjs — severity-tier selection (pure, node-testable)
// =============================================================================
// Extracted from settings ThemeConfig.tierColor. Returns the TOKEN KEY, not a
// color — the caller maps the key through the live palette so ramps retint on
// theme swap. Single authority for the cool → warn → hot thresholds contract.
// =============================================================================

// value < warn            -> "secondary" (cool)
// warn <= value < crit    -> "warning"
// value >= crit           -> "error"
// non-finite / negative   -> "secondary" (sensor absent reads as calm, not hot)
export function tierFor(value, warn, crit) {
    if (!isFinite(value) || value < 0) return "secondary"
    if (value >= crit) return "error"
    if (value >= warn) return "warning"
    return "secondary"
}
