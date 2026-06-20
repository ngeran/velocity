// =============================================================================
// settings/config/ThemeConfig.qml
// CANONICAL THEME SOURCE OF TRUTH — Active Shell Instance
// =============================================================================
//
// PATH
//   ~/.config/quickshell/settings/config/ThemeConfig.qml
//
// ROLE
//   The single canonical definition of every theme token for the settings
//   shell — the ONLY place color/metadata token values are defined. Every
//   other consumer reads them, directly or via a shim:
//     • Components using the flat Colors.* namespace resolve through
//       settings/components/Colors.qml — a pure re-export shim that binds each
//       Colors.<x> to ThemeConfig.colors.<x> (BentoCard, NetworkRing,
//       NetworkWidget, IdentityWidget, CalendarWidget, ClockWidget).
//     • settings/config/SharedState.qml binds its theme* properties
//       (themePrimaryColor, themeSecondaryColor, themeTextColor, themeName,
//       themeIsOLED) directly to this singleton, so ThemeInfoCard and any other
//       SharedState reader track live mutations with no manual mirror loop.
//   This file lives in settings/config/ (NOT shared/) because the path is
//   reachable from BOTH the services layer (services/ → "../config") and the
//   layout widgets (components/ → "../config") as a one-level sibling import,
//   which avoids the "../../shared" relative-depth singleton-resolution bug
//   that yields an undefined instance at runtime. The legacy
//   shared/ThemeConfig.qml duplicate was RETIRED for this reason — do not
//   resurrect it.
//
// SCOPE — CROSS-PROCESS BAR
//   The bar (bar/) is a SEPARATE quickshell process (quickshell -c .../bar)
//   with its OWN config/ThemeConfig.qml copy. It CANNOT share this in-memory
//   singleton. It stays in sync only via the external ~/.cache/theme/colors.json
//   file (its own 1s poll), so settings-side Tier-2 accent mutations do NOT
//   reach the bar live. Bar theming is intentionally out of scope here.
//
// PUBLIC API
//   property var colors        — Tier-1 (structural) + Tier-2 (accent) tokens
//   property var metadata      — Tier-3 tracking state (name/source/applied/…)
//   function applyTheme(data)  — bulk intake from a parsed JSON payload
//   function updateColorToken(key, value) — mutate a single accent token
//                                            (reassigns whole object so QML
//                                             change signals fire reactively)
//
// REACTIVITY MODEL
//   - In-process: ThemeService mutates `colors`/`metadata` directly (or via
//     updateColorToken); QML re-evaluates every Config.ThemeConfig.colors.*
//     and UI.Colors.* binding (the latter via the Colors.qml shim).
//   - External intake: a Process polls ~/.cache/theme/colors.json every 1s so
//     the active shell still reacts to the pre-existing `theme-switcher` CLI
//     and other external writers WITHOUT requiring changes to those scripts.
//     ThemeService additionally mirrors internal changes to
//     ~/.config/quickshell/theme-active.json (see ThemeService.qml).
//
// I/O TARGETS
//   READ : ~/.cache/theme/colors.json   (external intake poll)
//   WRITE: none here — owned by ThemeService (theme-active.json loop)
//
// BACKWARD COMPATIBILITY
//   Retains the `.colors` and `.metadata` sub-objects so existing consumers
//   (ModernDashboard, TopNavBar, FooterBar, WeatherWidget, ThemeModule) keep
//   resolving Config.ThemeConfig.colors.* and Config.ThemeConfig.metadata.*.
//
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

Item {
    id: root
    visible: false

    // =========================================================================
    // TIER 1 + TIER 2 — COLOR TOKEN OBJECT
    // -------------------------------------------------------------------------
    // Tier 1 (structural, pure-dark foundation): background, surface,
    //   surfaceVariant, surfaceContainer, text, textDim, border, outline,
    //   outlineVariant.
    // Tier 2 (accents, runtime-mutable): primary, secondary, accent, success,
    //   warning, error, info.
    // surfaceContainer is added here (canonical) so the Colors.qml shim and
    // NetworkRing.qml resolve it instead of falling back to undefined.
    // =========================================================================

    property var colors: ({
        // --- Tier 1: Structural Foundations ---
        "background":      "#000000",
        "surface":         "#0a0a0a",
        "surfaceVariant":  "#111111",
        "surfaceContainer":"#111111",
        "text":            "#e0e0e0",
        "textDim":         "#808080",
        "border":          "#1a1a1a",
        "outline":         "#2a2a2a",
        "outlineVariant":  "#1a1a1a",

        // --- Tier 2: Accent Fields (mutable) ---
        "primary":         "#7c6bf0",
        "secondary":       "#00dce5",
        "accent":          "#f87171",
        "success":         "#34d399",
        "warning":         "#fbbf24",
        "error":           "#f87171",
        "info":            "#00dce5"
    })

    // =========================================================================
    // TIER 3 — THEME METADATA TRACKING
    // -------------------------------------------------------------------------
    // name          : human-readable active theme label
    // source        : "preset" | "matugen" | "manual"
    // applied       : ISO 8601 timestamp of last application ("" = never)
    // oledClamp     : force pure-black background (burn-in safety)
    // matugenEnabled: whether Matugen wallpaper-driven generation is active
    // =========================================================================

    property var metadata: ({
        "name":           "OLED Pure Black",
        "source":         "preset",
        "applied":        "",
        "oledClamp":      true,
        "matugenEnabled": false
    })

    // =========================================================================
    // SINGLE-TOKEN MUTATION HELPER
    // -------------------------------------------------------------------------
    // Nested var keys do not emit change signals on in-place edit, so the whole
    // object is rebuilt and reassigned. This forces QML to re-evaluate every
    // binding that reads colors.<key> (and the Colors.qml shim aliases).
    // =========================================================================

    function updateColorToken(key, value) {
        var next = {}
        var k
        for (k in root.colors) {
            if (Object.prototype.hasOwnProperty.call(root.colors, k)) {
                next[k] = root.colors[k]
            }
        }
        next[key] = value
        root.colors = next
    }

    // =========================================================================
    // BULK INTAKE — apply a parsed JSON payload
    // -------------------------------------------------------------------------
    // Accepts the historical { colors: {...}, metadata: {...} } schema emitted
    // by the theme-switcher CLI / colors.json, with per-field fallbacks so a
    // partial payload never blanks a token. Maps legacy `mode` onto Tier-3
    // `source` and stamps `applied` when absent.
    // =========================================================================

    function applyTheme(data) {
        if (!data) return

        if (data.colors) {
            var c = data.colors
            root.colors = {
                // Tier 1
                "background":       c.background       || root.colors.background,
                "surface":          c.surface          || root.colors.surface,
                "surfaceVariant":   c.surfaceVariant   || root.colors.surfaceVariant,
                "surfaceContainer": c.surfaceContainer || c.surfaceVariant || root.colors.surfaceContainer,
                "text":             c.text             || root.colors.text,
                "textDim":          c.textDim          || root.colors.textDim,
                "border":           c.border           || root.colors.border,
                "outline":          c.outline          || root.colors.outline,
                "outlineVariant":   c.outlineVariant   || root.colors.outlineVariant,
                // Tier 2
                "primary":          c.primary          || root.colors.primary,
                "secondary":        c.secondary        || root.colors.secondary,
                "accent":           c.accent           || root.colors.accent,
                "success":          c.success          || root.colors.success,
                "warning":          c.warning          || root.colors.warning,
                "error":            c.error            || root.colors.error,
                "info":             c.info             || root.colors.info
            }
        }

        if (data.metadata) {
            var m = data.metadata
            root.metadata = {
                "name":           m.name           || root.metadata.name,
                "source":         m.source         || (m.mode || root.metadata.source),
                "applied":        m.applied        || root.metadata.applied,
                "oledClamp":      (m.oledClamp !== undefined) ? m.oledClamp : root.metadata.oledClamp,
                "matugenEnabled": (m.matugenEnabled !== undefined) ? m.matugenEnabled : root.metadata.matugenEnabled
            }
        }
    }

    // =========================================================================
    // EXTERNAL INTAKE — poll ~/.cache/theme/colors.json
    // -------------------------------------------------------------------------
    // Keeps the settings shell reactive to the pre-existing theme-switcher CLI
    // and any external tool that writes the canonical cache file. ThemeService
    // owns the in-process mutation path and the theme-active.json write-back.
    // =========================================================================

    // Plain filesystem path. StandardPaths returns a file:// URL in this Qt
    // build; strip it via .replace so `cat` gets a real path (a literal
    // "file://..." name doesn't exist → empty buffer → theme never restored).
    readonly property string externalCachePath: (StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.cache/theme/colors.json").replace("file://", "")

    Process {
        id: catProc
        // sh -c (not bare cat) — mirrors the bar's working poll; this is the
        // pattern that reliably delivers stdout in this quickshell build.
        command: ["sh", "-c", "cat " + root.externalCachePath]
        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) { catProc.buffer += data }
        }

        onRunningChanged: {
            if (!running) {
                if (catProc.buffer.trim().length > 0) {
                    try {
                        root.applyTheme(JSON.parse(catProc.buffer))
                    } catch (e) {
                        // Silently ignore parse errors — keep last good theme
                    }
                }
                catProc.buffer = ""
            }
        }
    }

    // Poll for external changes every second; populate immediately on load.
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!catProc.running) catProc.running = true
        }
    }
}
