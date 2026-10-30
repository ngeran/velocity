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
// SYNC WITH: settings/config/ThemeConfig.qml — the shared core (16 color-token
// defaults, metadata defaults, updateColorToken, applyTheme()'s token-mapping,
// and the raw-read parse/dedupe) lives in shared/theme-ingest.mjs (P2.7), so
// there is nothing left to keep byte-identical by hand. Divergences here are
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
import "../lib/theme-ingest.mjs" as ThemeIngest

Item {
    id: root
    visible: false

    // =========================================================================
    // THEME COLORS (reactive - update when cache file changes)
    // =========================================================================

    // Boot palette + tracking defaults: the shared theme-ingest copies (kept
    // separate from ThemeService's DEFAULT_BUNDLE seed on purpose — see the
    // module header). applyTheme/ingestThemeText reassign fresh objects.
    property var colors: ThemeIngest.DEFAULT_COLORS
    property var metadata: ThemeIngest.DEFAULT_METADATA

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

    // Shared core: rebuild + reassign (nested var keys don't notify on
    // in-place edit — the reassign is the QML signal).
    function updateColorToken(key, value) {
        root.colors = ThemeIngest.withToken(root.colors, key, value)
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
        if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] applyTheme:", data && data.metadata ? data.metadata.name : "unknown")
        if (!data) return

        // Shared core: per-field fallbacks over the current palette/metadata
        // (via theme-core's normalizeBundle — intake uses the writer's own
        // token validation). Each half is null when the payload omits it.
        var mapped = ThemeIngest.mapPayload(data, root.colors, root.metadata)
        if (mapped.metadata) root.metadata = mapped.metadata

        // QD-OLED Safe: force pure-black backgrounds. Clamped IN PLACE on the
        // mapped palette BEFORE the cross-fade, so the fade target is final
        // (fading toward a color that then snaps to the clamp would flicker).
        // Defense only — ThemeService is the sole pre-clamping writer. The
        // clamp is the SHARED theme-core one (its text rescue falls back to
        // DEFAULT_BUNDLE — the same hardcoded #e0e0e0/#808080 this block used
        // to carry, now divergence-proof).
        if (mapped.colors && root.metadata.oledClamp) {
            ThemeCore.clampOLED(mapped.colors, true, ThemeCore.DEFAULT_BUNDLE)
            if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] OLED clamp applied")
        }

        if (mapped.colors) {
            root._setColors(mapped.colors)
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
    // Shared core (theme-ingest.parseIngest) does trim/dedupe/parse — null
    // means empty, byte-identical to the last applied read (nudge racing the
    // fallback poll must be free), or mid-write garbage (silent retry).
    function ingestThemeText(raw) {
        var hit = ThemeIngest.parseIngest(raw, root.lastCachedData)
        if (!hit) return
        root.lastCachedData = raw.trim()
        if (hit.applied) root.lastCachedTimestamp = hit.applied
        root.applyTheme(hit.data)
        if (Config.DebugConfig.debugTheme) console.log("[Bar ThemeConfig] Cache file changed, re-applying theme")
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
