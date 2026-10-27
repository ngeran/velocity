// =============================================================================
// bar/config/ThemeConfig.qml — Dynamic Theme Singleton
// =============================================================================
//
// This singleton provides dynamic theme configuration by watching
// ~/.cache/theme/colors.json for changes. When the theme file changes,
// all properties automatically update, triggering reactive updates across
// all QuickShell components.
//
// Reads ~/.cache/theme/colors.json via FileView with watchChanges, the
// settings `theme reload` IPC nudge, and a 15s fallback reload() for writers
// that don't nudge (all zero-fork; see EXTERNAL INTAKE below).
//
// =============================================================================
// SYNC WITH: settings/config/ThemeConfig.qml — the 16 color-token defaults,
// metadata defaults, updateColorToken(), and applyTheme()'s token-mapping MUST
// stay identical (bar + settings are separate processes). Divergences here are
// INTENTIONAL (don't "fix" them): no isUserInitiated (the bar is READ-ONLY — it
// only reads colors.json that settings wrote), a defensive OLED clamp on ingest
// that calls the SHARED theme-core clampOLED (same module as ThemeService —
// 4 bg tokens → #000, luminance-rescued text/textDim → DEFAULT_BUNDLE), and a
// zero-fork hybrid intake:
// FileView.watchChanges (instant on same-inode writes), the theme.reload
// nudge, plus a 15s fallback reload() Timer. Plain watchChanges alone missed tmp+mv inode swaps
// cross-process (see git history); reload() re-reads by path in C++, so it
// is immune. The intake mechanism is process-specific by design.
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io
import "." as Config
import "../lib/theme-mix.mjs" as Mix
import "../lib/theme-core.mjs" as ThemeCore

Item {
    id: root
    visible: false

    // =========================================================================
    // THEME COLORS (reactive - update when cache file changes)
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

    property var metadata: ({
        "name":           "OLED Pure Black",
        "source":         "preset",
        "applied":        "",
        "oledClamp":      true,
        "matugenEnabled": false
    })

    // =========================================================================
    // THEME FILE PATH
    // =========================================================================

    readonly property string themeFilePath: (StandardPaths.writableLocation(StandardPaths.HomeLocation).toString() + "/.cache/theme/colors.json").replace("file://", "")
    property string lastCachedData: ""

    // =========================================================================
    // PALETTE CROSS-FADE (ryoku Tokens blend, adapted)
    // -------------------------------------------------------------------------
    // applyTheme routes through _setColors: the previous palette (as parsed
    // RGB) is kept and _blend walks 0→1 at MotionConfig.swap/OutCubic,
    // recomputing root.colors as a per-frame hex mix — every colors.* binding
    // in the process fades with zero consumer changes. Instant paths: startup
    // restore (applied === "" — no boot flash), reduceMotion, and unchanged
    // palettes (equality guard also stops nudge/poll double-fires from
    // restarting a running fade). The final frame assigns the exact target.
    // =========================================================================
    property real _blend: 1
    property var _fadePrevRGB: null
    property var _fadeTarget: null

    // Standalone animation (NOT "on _blend"): a value-source `on` animation
    // owns the property even while stopped, making the manual _blend writes
    // below ambiguous. target/property form stays fully imperative.
    NumberAnimation {
        id: paletteFade
        target: root
        property: "_blend"
        to: 1
        duration: Config.MotionConfig.swap
        easing.type: Easing.OutCubic
    }

    on_BlendChanged: root._applyBlend(root._blend)

    function _applyBlend(t) {
        if (!root._fadeTarget) return
        root.colors = (t >= 1) ? root._fadeTarget : Mix.mixPalettes(root._fadePrevRGB, root._fadeTarget, t)
    }

    function _setColors(next) {
        if (root._fadeTarget && Mix.palettesEqual(next, root._fadeTarget)) return
        var instant = (Config.MotionConfig.swap === 0) || (root.metadata.applied === "")
        var prevRGB = Mix.parsePalette(root.colors)
        root._fadeTarget = next
        root._fadePrevRGB = prevRGB
        paletteFade.stop()
        if (instant) {
            root._blend = 1
            root._applyBlend(1)
            return
        }
        root._blend = 0
        root._applyBlend(0)
        paletteFade.start()
    }

    // =========================================================================
    // HYPRLAND BORDER SYNC — live border theming (reload-then-eval contract)
    // -------------------------------------------------------------------------
    // Any `hyprctl reload` reverts borders to the login-time Lua values
    // (Tier-1 T1 experiment); a `hyprctl eval` lands them live again. So this
    // runs on EVERY palette intake (startup + theme swaps) and again on the
    // socket2 `configreloaded` event (wired in shell.qml). Alphas preserved
    // from look-and-feel.lua (active 0x88, inactive 0x66 — same OLED
    // headroom). argv form, no sh -c, so no quote escaping. Borders snap
    // (1px) rather than riding the palette cross-fade; sourcing from
    // _fadeTarget because root.colors is the frame-0 mix at call time.
    // =========================================================================
    /// colors.json values get pasted into a Lua string for `hyprctl eval` —
    /// anything that isn't a plain 6-digit hex must never reach that string
    /// (a crafted value could break out of the Lua literal and execute inside
    /// Hyprland's config interpreter), and 8-digit #rrggbbaa plus the appended
    /// alpha below would form an invalid colour anyway. Returns "" to signal
    /// "skip this eval".
    function _hex6(v: string): string {
        var h = String(v || "").trim().replace(/^#/, "").toLowerCase()
        return /^[0-9a-f]{6}$/.test(h) ? h : ""
    }

    function applyHyprlandBorders() {
        var c = root._fadeTarget || root.colors
        var active = _hex6(c.secondary)
        var inactive = _hex6(c.border)
        if (active.length === 0 || inactive.length === 0) {
            console.warn("[Bar ThemeConfig] border colours not plain #rrggbb — skipping hyprctl eval",
                         JSON.stringify([c.secondary, c.border]))
            return
        }
        active = "rgba(" + active + "88)"
        inactive = "rgba(" + inactive + "66)"
        var lua = "hl.config({ general = { col = { active_border = \"" + active
                + "\", inactive_border = \"" + inactive + "\" } } })"
        if (borderProc.running) borderProc.running = false
        borderProc.command = ["hyprctl", "eval", lua]
        borderProc.running = true
    }

    Process {
        id: borderProc
        onExited: function(code, status) {
            if (code !== 0)
                console.warn("[Bar ThemeConfig] hyprland border eval failed, exit", code)
        }
    }

    // =========================================================================
    // SINGLE-TOKEN MUTATION HELPER
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

    // Relative luminance (0..1, sRGB) of a "#rrggbb" string — the math lives
    // in shared/theme-core.mjs (DU2/DU3: the same module settings' ThemeService
    // uses; the fork this used to be could silently diverge).
    function luminance(hex) {
        return ThemeCore.luminance(hex)
    }

    // =========================================================================
    // DERIVED SURFACES — state-alpha tiers (Omarchy interactive vocabulary)
    // -------------------------------------------------------------------------
    // Fixed alphas over theme roles instead of hardcoded Qt.rgba() literals,
    // so every tint in the bar re-derives when the theme swaps. withAlpha()
    // takes a HEX STRING token (the colors.* values) — never a color object
    // (a color has no .replace; that is exactly the old tint() bug).
    // =========================================================================
    function withAlpha(hex, a) {
        var h = (hex || "#ffffff").replace("#", "")
        if (h.length !== 6) return Qt.rgba(1, 1, 1, a)
        return Qt.rgba(parseInt(h.substring(0, 2), 16) / 255,
                       parseInt(h.substring(2, 4), 16) / 255,
                       parseInt(h.substring(4, 6), 16) / 255, a)
    }

    readonly property color fillRest:        withAlpha(colors.text, 0.04)       // neutral pill / idle button
    readonly property color fillHover:       withAlpha(colors.text, 0.08)       // hover fill on interactive rows/buttons
    readonly property color hairline:        withAlpha(colors.text, 0.07)       // section separators
    readonly property color hairlineSoft:    withAlpha(colors.text, 0.12)       // slider/meter tracks, inactive bars
    readonly property color accentTint:      withAlpha(colors.secondary, 0.10)  // connected/status pills
    readonly property color accentTintSoft:  withAlpha(colors.secondary, 0.08)  // action-button accent state
    readonly property color successTint:     withAlpha(colors.success, 0.15)
    readonly property color errorTint:       withAlpha(colors.error, 0.15)

    // =========================================================================
    // THEME APPLICATION
    // =========================================================================

    function applyTheme(data) {
        if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] applyTheme called with theme:", data.metadata ? data.metadata.name : "unknown")

        if (!data) {
            if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] ERROR: No data provided")
            return
        }

        var next = null
        if (data.colors) {
            var c = data.colors
            next = {
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
            var newOledClamp = (m.oledClamp !== undefined) ? m.oledClamp : root.metadata.oledClamp

            root.metadata = {
                "name":           m.name           || root.metadata.name,
                "source":         m.source         || (m.mode || root.metadata.source),
                "applied":        m.applied        || root.metadata.applied,
                "oledClamp":      newOledClamp,
                "matugenEnabled": (m.matugenEnabled !== undefined) ? m.matugenEnabled : root.metadata.matugenEnabled
            }
            if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] Metadata applied. oledClamp:", root.metadata.oledClamp)
        }

        // QD-OLED Safe: force pure-black backgrounds. Clamped IN PLACE on the
        // mapped palette BEFORE the cross-fade, so the fade target is final
        // (fading toward a color that then snaps to the clamp would flicker).
        // Defense only — ThemeService is the sole pre-clamping writer. The
        // clamp is the SHARED theme-core one (its text rescue falls back to
        // DEFAULT_BUNDLE — the same hardcoded #e0e0e0/#808080 this block used
        // to carry, now divergence-proof).
        if (next && root.metadata.oledClamp) {
            ThemeCore.clampOLED(next, true, ThemeCore.DEFAULT_BUNDLE)
            if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] OLED clamp applied")
        }

        if (next) {
            root._setColors(next)
            root.applyHyprlandBorders()
            if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] Colors applied. New background:", root.colors.background)
        }
    }

    // =========================================================================
    // EXTERNAL INTAKE — FileView + theme.reload nudge + 15s fallback (zero forks)
    // -------------------------------------------------------------------------
    // Hybrid: watchChanges catches same-inode writes instantly via inotify;
    // the Timer's reload() covers the tmp+mv inode swap — writers (ThemeService,
    // theme-switcher) atomically rename, which cross-process file watches have
    // historically missed here (see git history). reload()+text() re-read by
    // path in C++, replacing the old `sh -c stat` gate (~60 spawns/min).
    // FileView.text is a METHOD in this Quickshell build, not a property.
    // =========================================================================

    property string lastCachedTimestamp: ""

    // Single ingest path for startup restore, inotify hits, and timer reloads.
    function ingestThemeText(raw) {
        var newData = (raw || "").trim()
        if (newData.length === 0 || newData === root.lastCachedData) return
        try {
            var dataObj = JSON.parse(newData)
            root.lastCachedData = newData
            if (dataObj.metadata && dataObj.metadata.applied) root.lastCachedTimestamp = dataObj.metadata.applied
            root.applyTheme(dataObj)
            if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] Cache file changed, re-applying theme")
        } catch (e) {
            // Silent retry on parse error (file might be mid-write)
        }
    }

    // IPC nudge entry point (theme.reload) — the settings process fires this
    // right after its atomic colors.json write, because cross-process file
    // watches can miss atomic-rename inode swaps (see ryoku nudgePalette).
    // reload() is the ASYNC path re-read (completes via onTextChanged — a
    // synchronous text() right after reload() returns stale cache); the
    // immediate ingestThemeText(text()) covers the same-inode case. Both
    // dedupe through lastCachedData, so a nudge racing the fallback poll is free.
    function reloadFromDisk() {
        themeFile.reload()
        root.ingestThemeText(themeFile.text())
    }

    FileView {
        id: themeFile
        path: root.themeFilePath
        watchChanges: true
        printErrors: false

        // Instant path (same-inode writes)
        onFileChanged: root.ingestThemeText(themeFile.text())
        // Covers the timer's ASYNC reload() completions (a synchronous text()
        // right after reload() returns the stale cache — proven in
        // SystemMetricsService; textChanged fires when a completed read changes
        // the cache).
        onTextChanged: root.ingestThemeText(text())

        // Startup restore: text() does a blocking read of the existing file.
        Component.onCompleted: root.ingestThemeText(themeFile.text())
    }

    // Backstop for writers that don't nudge (matugen hooks, theme CLI).
    // 60s idle cadence — the settings writer nudges `theme reload` on every
    // atomic write; watchChanges covers in-place edits, this catches tmp+mv.
    Timer {
        id: cachePoller
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            themeFile.reload()
            root.ingestThemeText(themeFile.text())
        }
    }
}
