// =============================================================================
// HudConfig.qml — FIXED instrument-cluster tokens for the HUD dashboard chrome
// =============================================================================
// The approved "NixOS Telemetry & Instrument Cluster" look (the consolidated
// dashboard rework) is deliberately theme-INDEPENDENT: obsidian panels locked
// to pure black (QD-OLED doctrine) with amber/cyan telemetry accents, exactly
// like the mock. This is NOT part of the theme engine on purpose — ThemeConfig
// stays the user-theme SSOT (its schema is shared with theme-ingest.mjs), and
// ControlConfig's accents are theme-derived aliases. HUD surfaces read HERE.
//
// Non-HUD tab interiors (THEMES, CONTROL, …) keep reading ThemeConfig — only
// the chrome (sidebar/header/card) and the rebuilt Core cluster are HUD.
//
// Derived translucencies go through ThemeConfig.tint() (accepts color objects)
// — never `withAlpha` on a color object (bar law).
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    // --- Surfaces (mock literals; panel is #000 by design, not laziness) ---
    readonly property color panel:    "#000000"
    readonly property color well:     "#14161f"   // inner wells (sub-gauges, pools)
    readonly property color wellDeep: "#050608"   // deepest wells (dial backing)
    readonly property color borderHi: "#191b22"   // outer chrome borders
    readonly property color borderLo: "#1c202a"   // card borders
    readonly property color ledDim:   "#242836"   // unlit LED segments

    // --- Accents (mock literals — fixed by user decision) ---
    readonly property color amber:    "#ff7a00"
    readonly property color cyan:     "#38bdf8"
    readonly property color red:      "#f87171"   // destructive (power tile)

    // --- Text tiers (Tailwind slate equivalents from the mock) ---
    readonly property color textHi:    "#f1f5f9"   // slate-100 hero digits
    readonly property color textBody:  "#cbd5e1"   // slate-300
    readonly property color textMid:   "#94a3b8"   // slate-400
    readonly property color textDim:   "#64748b"   // slate-500
    readonly property color textFaint: "#475569"   // slate-600

    // --- Grid backdrop ---
    readonly property color gridLine: Qt.rgba(1, 1, 1, 0.02)
    readonly property int gridStep: 32

    // --- Shape / glow ---
    readonly property int radiusSm: 4
    readonly property int radiusMd: 6
    readonly property real glowAlpha: 0.45

    // --- Typography (both installed on this host) ---
    readonly property string fontUi:   "Space Grotesk"   // labels, eyebrows
    readonly property string fontData: "JetBrains Mono"  // telemetry digits

    // --- PCIe link rate: gen N ≈ 2.5 · 2^(N−1) GT/s per lane (gen 5 → 32) ---
    function gtRate(gen) { return Math.round(2.5 * Math.pow(2, gen - 1) * 10) / 10 }
}
