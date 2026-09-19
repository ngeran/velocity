// =============================================================================
// theme-mix.mjs — palette cross-fade math (pure, node-testable)
// =============================================================================
// Consumed by bar/config/ThemeConfig.qml's _applyBlend: interpolates the 16
// token hex strings from a previous palette to a target at factor t, so every
// colors.* binding in the process fades per-frame during a theme swap without
// any consumer changes.
//
// SYNC WITH: settings/lib/theme-mix.js — must stay identical (Quickshell
// sandboxes relative JS imports to each config root, so the two processes
// cannot share one copy). Drift is caught by the test suite, which runs the
// same assertions against BOTH files.
// =============================================================================

function clamp255(v) {
    v = Math.round(v)
    return v < 0 ? 0 : (v > 255 ? 255 : v)
}

// "#rrggbb" -> [r,g,b] (0..255); tolerates #rrggbbaa; null when unparseable.
export function parseHex(h) {
    if (typeof h !== "string") return null
    var s = h.replace("#", "")
    if (s.length === 8) s = s.substring(0, 6)
    if (s.length !== 6 || /[^0-9a-fA-F]/.test(s)) return null
    return [
        parseInt(s.substring(0, 2), 16),
        parseInt(s.substring(2, 4), 16),
        parseInt(s.substring(4, 6), 16)
    ]
}

export function toHex(r, g, b) {
    function two(v) {
        var s = clamp255(v).toString(16)
        return s.length === 1 ? "0" + s : s
    }
    return "#" + two(r) + two(g) + two(b)
}

// String equality over the target's keys — the fade's equality guard. A key
// present in only one side is a difference (never silently equal).
export function palettesEqual(a, b) {
    if (!a || !b) return false
    for (var k in b) {
        if (!Object.prototype.hasOwnProperty.call(a, k)) return false
        if (String(a[k]) !== String(b[k])) return false
    }
    for (var k2 in a) {
        if (!Object.prototype.hasOwnProperty.call(b, k2)) return false
    }
    return true
}

// Palette -> { key: [r,g,b] } for fast per-frame mixing.
export function parsePalette(p) {
    var out = {}
    for (var k in p) {
        if (!Object.prototype.hasOwnProperty.call(p, k)) continue
        var rgb = parseHex(p[k])
        if (rgb) out[k] = rgb
    }
    return out
}

// Per-frame mix: prevRGB (parsePalette output) -> target (hex strings) at t.
// Keys lacking a parseable prev fall through to the target instantly — a
// partial prev never paints a missing channel as black.
export function mixPalettes(prevRGB, target, t) {
    if (t <= 0) t = 0
    if (t >= 1) t = 1
    var out = {}
    for (var k in target) {
        if (!Object.prototype.hasOwnProperty.call(target, k)) continue
        var to = parseHex(target[k])
        var from = (prevRGB && Object.prototype.hasOwnProperty.call(prevRGB, k)) ? prevRGB[k] : null
        if (!from || !to || t === 1) {
            out[k] = target[k]
            continue
        }
        out[k] = toHex(
            from[0] + (to[0] - from[0]) * t,
            from[1] + (to[1] - from[1]) * t,
            from[2] + (to[2] - from[2]) * t
        )
    }
    return out
}
