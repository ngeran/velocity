// =============================================================================
// bar/config/PopupMetrics.qml — popup/dashboard scale token singleton
// =============================================================================
//
// px(n) applies uiScale and rounds, so every migrated value equals its old
// literal at the default scale 1.0 — migrating a popup (TrayCard,
// NotificationCenter, overlays) means replacing its pixel literals with
// Pm.px(n) (one-off derivations may use `Pm.scale` directly). The optional key
// "uiScale" (0.75–2.0) lives in bar-config.json; BarConfig is the one reader
// of that file (DU13 — this used to be a second FileView + 15s timer for a
// single key) and this singleton just mirrors its parsed property, so a
// write lands here through the same nudge/watch/backstop chain as every
// other BarConfig key.
//
// Bounded popups (unlike the bar strip) are where extra DPI headroom pays
// off; the bar itself scales through BarConfig._contentScale instead.
//
// =============================================================================

pragma Singleton

import QtQuick
import "." as Config

Item {
    id: root
    visible: false

    // Mirror of BarConfig.uiScale (the validated 0.75–2.0 intake lives there).
    property real uiScale: Config.BarConfig.uiScale
    // Shorthand for bindings: `width: Pm.scale * 320` etc. Read-only mirror.
    readonly property real scale: root.uiScale

    function px(n) {
        return Math.round((Number(n) || 0) * root.uiScale)
    }

    // Hairlines snap to whole device pixels: a logical 1px line at a fractional
    // scale (1.25 / 1.5) straddles two device pixels and anti-aliases into a
    // soft band, while 1/dpr is the thinnest crisp line the output can draw.
    // Falls back to exactly 1 when the item has no screen (unmounted window)
    // or the scale is integral, so 1.0-scale rendering is unchanged. `item` is
    // any Item the hairline lives in (all items in a window share one screen).
    function hairline(item) {
        var dpr = 0
        if (item && item.Screen) dpr = item.Screen.devicePixelRatio
        return (isFinite(dpr) && dpr > 0) ? 1 / dpr : 1
    }
}
