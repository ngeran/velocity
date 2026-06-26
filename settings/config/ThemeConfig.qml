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
import "./" as Config

Item {
    id: root
    visible: false

    // Flag to prevent polling from overwriting user-initiated changes
    property bool userInitiatedChange: false

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
    // COLOR UTILITY — hex + alpha → translucent color
    // -------------------------------------------------------------------------
    // Lets widgets derive translucent accents (glows, ring backings, tints) from
    // theme tokens, so alpha-based highlights follow the theme too. Accepts a
    // "#rrggbb" string (any colors.* token) and an alpha in 0..1.
    // =========================================================================
    function tint(hex, alpha) {
        var h = (hex || "#000000").replace("#", "")
        if (h.length !== 6) return Qt.rgba(0, 0, 0, alpha)
        return Qt.rgba(parseInt(h.substring(0, 2), 16) / 255,
                       parseInt(h.substring(2, 4), 16) / 255,
                       parseInt(h.substring(4, 6), 16) / 255,
                       alpha)
    }

    // =========================================================================
    // BULK INTAKE — apply a parsed JSON payload
    // -------------------------------------------------------------------------
    // Accepts the historical { colors: {...}, metadata: {...} } schema emitted
    // by the theme-switcher CLI / colors.json, with per-field fallbacks so a
    // partial payload never blanks a token. Maps legacy `mode` onto Tier-3
    // `source` and stamps `applied` when absent.
    // =========================================================================

    function applyTheme(data, isUserInitiated) {
        if (Config.DebugConfig.debugTheme) {
            console.log("=== Config.ThemeConfig.applyTheme CALLED ===")
            console.log("[applyTheme] Input data:", JSON.stringify(data))
            console.log("[applyTheme] isUserInitiated:", isUserInitiated, "(type:", typeof isUserInitiated, ")")
        }

        // Set flag if this is a user-initiated change
        if (isUserInitiated === true) {
            root.userInitiatedChange = true
            if (Config.DebugConfig.debugTheme) console.log("[applyTheme] Set userInitiatedChange flag")
        }

        if (!data) {
            if (Config.DebugConfig.debugTheme) console.log("[applyTheme] ERROR: No data provided")
            return
        }

        if (Config.DebugConfig.debugTheme) console.log("[applyTheme] Current metadata.oledClamp BEFORE:", root.metadata.oledClamp)

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
            if (Config.DebugConfig.debugTheme) console.log("[applyTheme] Colors applied. New background:", root.colors.background)
        }

        if (data.metadata) {
            var m = data.metadata
            if (Config.DebugConfig.debugTheme) {
                console.log("[applyTheme] Processing metadata. m.oledClamp:", m.oledClamp, "(undefined?", m.oledClamp === undefined, ")")
                console.log("[applyTheme] Current root.metadata.oledClamp:", root.metadata.oledClamp)
            }

            var newOledClamp = (m.oledClamp !== undefined) ? m.oledClamp : root.metadata.oledClamp
            if (Config.DebugConfig.debugTheme) console.log("[applyTheme] NEW oledClamp will be:", newOledClamp)

            root.metadata = {
                "name":           m.name           || root.metadata.name,
                "source":         m.source         || (m.mode || root.metadata.source),
                "applied":        m.applied        || root.metadata.applied,
                "oledClamp":      newOledClamp,
                "matugenEnabled": (m.matugenEnabled !== undefined) ? m.matugenEnabled : root.metadata.matugenEnabled
            }

            if (Config.DebugConfig.debugTheme) console.log("[applyTheme] Metadata APPLIED. root.metadata.oledClamp AFTER:", root.metadata.oledClamp)
        }

        // QD-OLED Safe: force pure-black backgrounds
        if (root.metadata.oledClamp) {
            var cs = {}
            for (var ks in root.colors) cs[ks] = root.colors[ks]
            cs.background = "#000000"
            cs.surface = "#000000"
            cs.surfaceVariant = "#000000"
            cs.surfaceContainer = "#000000"
            root.colors = cs
        }

        if (Config.DebugConfig.debugTheme) {
            console.log("[applyTheme] Final metadata.oledClamp:", root.metadata.oledClamp)
            console.log("=== Config.ThemeConfig.applyTheme COMPLETE ===")
        }
    }

    // =========================================================================
    // EXTERNAL INTAKE — FileView.onFileChanged watching colors.json
    // -------------------------------------------------------------------------
    // Event-driven sync (replaces 1s poll). Reacts to external writes from
    // ThemeService (settings writes) and external tools (theme-switcher CLI).
    // ThemeService owns the in-process mutation path and theme-active.json write-back.
    // =========================================================================

    // Plain filesystem path. StandardPaths returns a file:// URL in this Qt
    // build; strip it via .replace so FileView gets a real path (a literal
    // "file://..." name doesn't exist → onFileChanged never fires).
    readonly property string externalCachePath: (StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.cache/theme/colors.json").replace("file://", "")

    // Track last cached data and timestamp to avoid redundant re-application
    property string lastCachedData: ""
    property string lastCachedTimestamp: ""

    // FileView watcher for event-driven theme sync
    property var cacheWatcher: FileView {
        path: root.externalCachePath

        onFileChanged: {
            // FileView.text is a METHOD (not a property) in this Quickshell build
            let raw = cacheWatcher.text();
            if (!raw || raw.trim() === "") return;

            try {
                var newData = raw.trim();
                var data = JSON.parse(newData);

                // Check if data actually changed by comparing timestamps
                var newTimestamp = data.metadata && data.metadata.applied ? data.metadata.applied : "";
                if (newTimestamp === root.lastCachedTimestamp && newData === root.lastCachedData) {
                    return;  // No actual change
                }

                // Update timestamp
                if (newTimestamp) {
                    root.lastCachedTimestamp = newTimestamp;
                }

                // Only apply if not a user-initiated change in the last 100ms
                // This window prevents race conditions where an external write
                // during a user action would silently drop the user's intent
                var timeSinceUserChange = Date.now() - (root.metadata.applied ? new Date(root.metadata.applied).getTime() : 0);
                if (timeSinceUserChange < 100 && root.userInitiatedChange) {
                    if (Config.DebugConfig.debugFile) console.log("[ThemeConfig] External write during user action, skipping");
                    root.lastCachedData = newData;  // Update tracking but don't apply
                    return;
                }

                if (Config.DebugConfig.debugFile) console.log("[ThemeConfig] Cache file changed, re-applying theme");
                root.lastCachedData = newData;
                root.applyTheme(data);

                // Reset user-initiated flag after applying
                root.userInitiatedChange = false;
            } catch (e) {
                // Silently ignore parse errors — keep last good theme
                if (Config.DebugConfig.debugFile) console.log("[ThemeConfig] Parse error reading cache:", e);
            }
        }
    }

    // Fallback: if FileView isn't working, check every minute
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // If we haven't seen any data yet, FileView might not be working
            if (root.lastCachedData.length === 0) {
                var fallback = Qt.createQmlObject('import Quickshell.Io; Process { command: ["sh", "-c", "cat ' + root.externalCachePath + '"] }', root);
                fallback.running = true;
            }
        }
    }
}
