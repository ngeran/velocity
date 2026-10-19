// popover-geometry.mjs — pure clamp math for Popover.qml (node-tested).
// Hosts are layer windows spanning the screen BELOW the bar (their
// margins.top = barHeight), so the caller's parent size already excludes the
// bar strip; the card fits inside it minus an edge margin per side and the
// drop gap at the top.

export const MIN_CARD = 1

// Card width: never wider than the host window minus margins. Unknown parent
// geometry (0/negative, pre-attach) keeps the requested width — the clamp
// re-applies reactively once the parent reports real dimensions.
export function clampCardWidth(cardWidth, parentWidth, edgeMargin) {
    var w = Number(cardWidth) || 0
    if (!(Number(parentWidth) > 0)) return w
    var max = parentWidth - 2 * edgeMargin
    if (max < MIN_CARD) return MIN_CARD
    return Math.max(MIN_CARD, Math.min(w, max))
}

// Vertical budget for the card: parent height minus the drop gap (card y
// offset) and margins. -1 = no geometry yet → unclamped (auto height).
export function clampMaxHeight(parentHeight, reservedTop, edgeMargin) {
    if (!(Number(parentHeight) > 0)) return -1
    var max = parentHeight - reservedTop - 2 * edgeMargin
    return max < MIN_CARD ? MIN_CARD : max
}

// A Flickable only scrolls when the body actually overflows; +1 absorbs
// subpixel rounding so an exact-fit body never grows scroll affordance.
export function scrollNeeded(contentHeight, viewportHeight) {
    return contentHeight > viewportHeight + 1
}
