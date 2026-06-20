// =============================================================================
// ArchLogo.qml — Arch Linux glyph (theme-aware)
// =============================================================================
//
// Vector Arch logo drawn on a Canvas and filled with BarConfig.colorAccent,
// so it recolors live with the active theme (the same accent the workspace
// dots use). Placed top-left of the bar, before the workspace dots.
//
// PUBLIC API
//   (none) — sized to BarConfig.iconSize; color follows BarConfig.colorAccent.
//
// THEME
//   Reads Config.BarConfig.colorAccent (→ ThemeConfig.colors.primary), so it
//   tracks the global theme via the bar's ThemeConfig poll of colors.json.
//
// =============================================================================

import QtQuick
import "../config" as Config

Canvas {
    id: root

    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize

    // --- SECTION: THEME BINDING ---
    // Repaint whenever the accent changes (theme switch) or the icon resizes.
    property color glyphColor: Config.BarConfig.colorAccent
    onGlyphColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    // --- SECTION: GLYPH RENDER ---
    // Arch logo: an upward triangle with a notch cut from the bottom centre
    // (the distinctive Arch "wedge"). Coordinates are normalised to the
    // Canvas size so it scales cleanly with BarConfig.iconSize.
    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = root.glyphColor
        var w = root.width
        var h = root.height
        ctx.beginPath()
        ctx.moveTo(0.50 * w, 0.08 * h)   // apex
        ctx.lineTo(0.08 * w, 0.92 * h)   // bottom-left
        ctx.lineTo(0.37 * w, 0.92 * h)   // left foot
        ctx.lineTo(0.50 * w, 0.60 * h)   // notch peak (Arch wedge)
        ctx.lineTo(0.63 * w, 0.92 * h)   // right foot
        ctx.lineTo(0.92 * w, 0.92 * h)   // bottom-right
        ctx.closePath()
        ctx.fill()
    }
}
