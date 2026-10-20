// island.mjs — pure state, geometry and burn-in math for styles/island
// (node-tested; Scene.qml imports it). Nothing here touches QML.
//
// States: rest (clock only) · glance (hover: all sections) · activity
// (transient live activity, e.g. volume) · panel (a popover presented inside
// the island). Sizes are the island's OUTER box; the flat edge sits on the
// screen edge, so height grows away from it.

export const REST = "rest"
export const GLANCE = "glance"
export const ACTIVITY = "activity"
export const PANEL = "panel"

// Hover intent: a quick pass-over must not bloom the island; leaving
// lingers so a diagonal mouse path into a widget doesn't collapse it.
export const HOVER_IN_MS = 90
export const HOVER_OUT_MS = 380
export const PANEL_OUT_MS = 450

// Morph spring (QML SpringAnimation): softly under-damped — a whisper of
// overshoot, no wobble. Collapse is a touch stiffer so retracting feels
// decisive but still glides to a stop instead of bouncing shut.
export const SPRING_OPEN = { spring: 4.0, damping: 0.72, mass: 1.0, epsilon: 0.4 }
export const SPRING_CLOSE = { spring: 4.6, damping: 0.82, mass: 1.0, epsilon: 0.4 }
// Window headroom while a spring is in flight (overshoot must not clip).
export const OVERSHOOT_PAD = 0.12
// Panel height ceiling as a fraction of the screen — both the island's own
// size cap (targetSize) and the window reservation Scene.qml makes when a
// panel presents, so the layer surface never has to resize again while the
// panel is open.
export const PANEL_MAX_H_FRAC = 0.8

// Content choreography — scale-led (user preference: resize, not fade).
// Presented content is scaled to fit the island's LIVE size (fitScale), so
// it grows and shrinks with the spring; opacity only snaps (no crossfade
// look) so two panels never read as overlapping. Outgoing content shrinks
// toward the screen edge while it snaps out.
export const CONTENT_OUT_MS = 140
export const CONTENT_IN_MS = 150
export const CONTENT_OUT_SCALE = 0.82
export const FIT_SCALE_MIN = 0.6

// event: "hoverIn" | "hoverOut" | "present" | "dismiss" | "activity" | "activityEnd"
// flags: { hovered, hasPanel, hasActivity }
export function nextState(state, event, flags) {
    var f = flags || {}
    var settle = f.hovered ? GLANCE : (f.hasActivity ? ACTIVITY : REST)
    switch (event) {
    case "present":
        return PANEL
    case "dismiss":
        return state === PANEL ? settle : state
    case "hoverIn":
        return state === PANEL ? PANEL : GLANCE
    case "hoverOut":
        if (state === PANEL) return PANEL
        return f.hasActivity ? ACTIVITY : REST
    case "activity":
        return state === REST ? ACTIVITY : state
    case "activityEnd":
        return state === ACTIVITY ? (f.hovered ? GLANCE : REST) : state
    default:
        return state
    }
}

function num(v, d) { var n = Number(v); return isFinite(n) ? n : d }

// m: { barH, restW, glanceW, activityW, activityH, panelW, panelH,
//      screenW, screenH, padX, panelPad, margin, maxHFrac }
// Returns { w, h } rounded to whole px (crisp edges at any scale).
export function targetSize(state, m) {
    var barH = Math.max(18, num(m.barH, 30))
    var padX = num(m.padX, Math.round(barH * 0.55))
    var panelPad = num(m.panelPad, 14)
    var margin = num(m.margin, 12)
    var screenW = num(m.screenW, 0)
    var screenH = num(m.screenH, 0)
    var maxHFrac = num(m.maxHFrac, PANEL_MAX_H_FRAC)
    var minW = Math.round(barH * 3.2)
    var w, h
    switch (state) {
    case GLANCE:
        w = num(m.glanceW, 0) + 2 * padX; h = barH; break
    case ACTIVITY:
        w = num(m.activityW, 0) + 2 * padX
        h = Math.max(barH, num(m.activityH, barH)); break
    case PANEL:
        w = num(m.panelW, 0) + 2 * panelPad
        h = num(m.panelH, 0) + 2 * panelPad; break
    default:
        w = num(m.restW, 0) + 2 * padX; h = barH
    }
    w = Math.max(minW, w)
    h = Math.max(barH, h)
    if (screenW > 0) w = Math.min(w, screenW - 2 * margin)
    if (screenH > 0) h = Math.min(h, Math.round(screenH * maxHFrac))
    return { w: Math.max(1, Math.round(w)), h: Math.max(1, Math.round(h)) }
}

// Far-corner radius: a full pill while the island is one row tall, then a
// fixed continuous-looking radius for panels (iOS keeps ~1/2 of the
// collapsed height as the expanded corner).
export function cornerRadius(state, h, barH) {
    var b = Math.max(18, num(barH, 30))
    var hh = Math.max(1, num(h, b))
    if (state === PANEL || hh > b * 1.6) return Math.min(hh / 2, Math.round(b * 0.8))
    return hh / 2
}

// Concave fillet where the island meets the screen edge.
export function filletRadius(barH) {
    var b = Math.max(18, num(barH, 30))
    return Math.max(6, Math.min(12, Math.round(b * 0.32)))
}

// Panel content budget: what a presented popover may occupy so the island
// (content + panelPad) stays on screen.
export function panelBudget(m) {
    var panelPad = num(m.panelPad, 14)
    var margin = num(m.margin, 12)
    var maxHFrac = num(m.maxHFrac, PANEL_MAX_H_FRAC)
    var screenW = num(m.screenW, 0)
    var screenH = num(m.screenH, 0)
    return {
        w: screenW > 0 ? Math.max(1, screenW - 2 * margin - 2 * panelPad) : -1,
        h: screenH > 0 ? Math.max(1, Math.round(screenH * maxHFrac) - 2 * panelPad) : -1
    }
}

// ── QD-OLED burn-in guard ──────────────────────────────────────────────────
// A slow orbit through 9 sub-perceptual offsets (one step per period). x
// moves the whole island; y only nudges content (the shape's flat edge must
// stay on the screen edge). amp 0 disables.
var ORBIT = [[0, 0], [1, 0], [2, 1], [1, 1], [0, 1], [-1, 1], [-2, 0], [-1, -1], [1, -1]]

export function orbitOffset(tick, amp) {
    var a = Math.max(0, Math.min(4, Math.round(num(amp, 2))))
    if (a === 0) return { x: 0, y: 0 }
    var i = ((Math.floor(num(tick, 0)) % ORBIT.length) + ORBIT.length) % ORBIT.length
    var p = ORBIT[i]
    return { x: Math.round(p[0] * a / 2), y: Math.max(-1, Math.min(1, p[1])) }
}

// Rest text alpha: dimmed even when active (never full-white on a static
// glyph) and dimmer still after `dimAfterMs` without interaction. Expanded
// states always read at full alpha.
export function restAlpha(state, idleMs, cfg) {
    var c = cfg || {}
    if (state !== REST) return 1
    if (c.guard === false) return num(c.activeAlpha, 0.82)
    var dimAfter = num(c.dimAfterMs, 90000)
    return num(idleMs, 0) >= dimAfter ? num(c.dimAlpha, 0.45) : num(c.activeAlpha, 0.82)
}

// Scale for presented content so it fits the island's current (animating)
// box: < 1 while the island is still smaller than the content, exactly 1
// once it has room (never upscales — spring overshoot must not magnify
// text). Floor keeps the first frames legible instead of a dot.
export function fitScale(islandW, islandH, contentW, contentH, pad, reserved) {
    var cw = num(contentW, 0), ch = num(contentH, 0)
    if (!(cw > 0) || !(ch > 0)) return 1
    var p = num(pad, 0), r = num(reserved, 0)
    var sw = (num(islandW, 0) - 2 * p) / cw
    var sh = (num(islandH, 0) - r - 2 * p) / ch
    var s = Math.min(1, sw, sh)
    if (!isFinite(s)) return 1
    return Math.max(FIT_SCALE_MIN, s)
}
