// =============================================================================
// settings/config/ThemeSchema.qml
// Canonical token KEYS + default seed for the 16-token theme schema.
// =============================================================================
//
// ROLE
//   The single source for the theme token KEYS and the DEFAULT seed palette.
//   Consumed by ThemeService.defaultBundle so the engine has one copy of the
//   defaults instead of duplicating them inline.
//
//   Live color VALUES still flow only through ThemeConfig (CLAUDE.md:
//   "ThemeConfig is the SSOT for all colors"). This file is keys + the default
//   seed only — it is NOT a live color definition.
//
// KEEP IN SYNC (separate copies that cannot import this singleton):
//   • settings/config/ThemeConfig.qml   colors defaults  (settings process)
//   • bar/config/ThemeConfig.qml        colors defaults  (bar process)
//   • ~/.omni-nix/modules/apps/essentials.nix  seedThemeColors  (Nix copy)
// =============================================================================

pragma Singleton

import QtQuick
import "../lib/theme-core.mjs" as ThemeCore

Item {
    id: root
    visible: false

    // The 16 canonical token keys: Tier 1 (structural) + Tier 2 (accents).
    readonly property var tokenKeys: [
        "background", "surface", "surfaceVariant", "surfaceContainer",
        "text", "textDim", "border", "outline", "outlineVariant",
        "primary", "secondary", "accent", "success", "warning", "error", "info"
    ]

    // The default seed palette ("OLED Pure Black") — delegates to
    // shared/theme-core.mjs DEFAULT_BUNDLE (the ONE seed copy; the bar's
    // defensive clamp rescues from the same values this exposes).
    readonly property var defaults: ThemeCore.DEFAULT_BUNDLE

    // A fresh bundle object seeded from defaults (safe to mutate in place).
    function emptyBundle() {
        var d = root.defaults, o = {}
        for (var k in d) {
            if (Object.prototype.hasOwnProperty.call(d, k)) o[k] = d[k]
        }
        return o
    }
}
