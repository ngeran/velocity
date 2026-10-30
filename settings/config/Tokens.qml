// GENERATED from shared/Tokens.qml by tools/sync-shared — do not edit
// =============================================================================
// shared/Tokens.qml — identity tokens (canonical, synced copy)
// =============================================================================
//
// CANONICAL SOURCE: this file is the source of truth; bar/config/,
// settings/config/ and lock/ hold byte-identical copies (tools/sync-shared —
// the VFS blocks cross-root imports, so roots hold synced copies; editing a
// root copy directly will fail tools/check-shared).
//
// P6 glyph identity: the type system is four families with strict roles —
//   display  "Doto"                     dot-matrix numerals, ≥ minDisplayPx ONLY
//   ui       "Space Grotesk"            prose: titles, body, greeting
//   mono     "Space Mono"               data + metadata: values, caps labels
//   icons    "JetBrainsMono Nerd Font"  icon glyphs
// plus a spacing scale, radii and the Doto legibility floor. Motion lives in
// MotionConfig; sizes stay PopupMetrics.px() (bar popups) / the styles' own
// scale — Tokens never re-models either. The qs.Ui kit keeps family LITERALS
// (D13: it must not reference config singletons); keep its strings in
// lockstep with the tokens here.
//
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    // ── font families (fc-match verified on this host) ─────────────────────
    readonly property string fontDisplay: "Doto"
    readonly property string fontUi: "Space Grotesk"
    readonly property string fontMono: "Space Mono"
    readonly property string fontIcons: "JetBrainsMono Nerd Font"

    // Doto renders as loose dots; below ~26 px digits stop reading (the
    // CalendarPanel rule). Small clocks and dense data use fontMono instead.
    readonly property int minDisplayPx: 26

    // ── spacing scale (logical px at scale 1.0) ────────────────────────────
    readonly property int spacingXs: 4    // icon ↔ label
    readonly property int spacingSm: 8    // intra-row gaps
    readonly property int spacingMd: 12   // card padding
    readonly property int spacingLg: 16   // section gaps
    readonly property int spacingXl: 24   // overlay padding
    readonly property int spacingXxl: 32  // hero separation

    // ── radii ──────────────────────────────────────────────────────────────
    readonly property int radiusCard: 14
    readonly property int radiusOverlay: 18
    readonly property int radiusPill: 999 // full round
}
