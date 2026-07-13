// =============================================================================
// settings/services/ThemeService.qml
// Core Architectural State Machine Engine
// =============================================================================
//
// THEME SOURCES (5) — which apply path emits each:
//   "preset"  — applyPreset()                 (a curated palette from ThemePresets)
//   "stylix"  — stylixSeedLoader              (Stylix cold-boot seed, build-time)
//   "matugen" — matugenRunner                 (runtime wallpaper → Material-You, instant)
//   "manual"  — applyManualOverride()         (per-token hex edits)
//   "custom"  — applyCustomTheme()            (a user-saved palette)
//
// HYBRID PALETTE ARCHITECTURE
//   Stylix = the cold-boot seed (build-time base16 from wallpaper.jpg →
//     stylix-palette.json). Loaded once at boot if no live theme is chosen.
//   matugen = the runtime generator (`matugen image <live-wallpaper> --json hex`),
//     producing a Material-You palette instantly with NO rebuild. This is what
//     makes "custom palette from the active wallpaper" instant.
//   They never fight: once a non-stylix source is active, loadStylixSeed()'s
//   clobber-guard skips the seed on later boots.
//
// INVARIANT: ThemeService is the SOLE writer that pre-clamps (clampOLED runs
//   before every applyTheme + every colors.json write). ThemeConfig therefore
//   does NOT re-clamp on intake. The bar (separate process) keeps its own
//   clamp as defense against external writers.
// =============================================================================

pragma Singleton
import QtQuick
import Qt.labs.platform
import Quickshell.Io
import "../config" as Config

Item {
    id: themeService

    // =========================================================================
    // EXPOSED PUBLIC API STATE
    // =========================================================================
    readonly property string currentThemeName:   Config.ThemeConfig.metadata.name
    readonly property string currentThemeSource: Config.ThemeConfig.metadata.source
    readonly property bool   isOledClampActive:  Config.ThemeConfig.metadata.oledClamp

    property bool isRegenerating:    false
    property bool pendingOLEDClamp:  false

    // Regeneration error state for visible error reporting in the UI
    property string regenError:  ""    // Human-readable error message
    property bool   regenFailed: false // True if last operation failed

    // If matugen fails, fall back to the old Stylix rebuild path instead of
    // surfacing an error. Default OFF: surface errors so problems are visible.
    property bool fallbackToRebuild: false

    // StandardPaths.writableLocation() returns a QUrl ("file:///home/nikos") in
    // this Qt build. Concatenation coerces it to a string first, then we strip
    // the "file://" scheme. Routing every write through this real path fixes
    // the bug where theme writes landed in literal "file:" dirs.
    readonly property string homeDir: ("" + StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "")

    // =========================================================================
    // PROCESS CREATION WITH ERROR HANDLING
    // =========================================================================

    function createProcess(cmd, label) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        proc.command = cmd;
        proc.onExited.connect(function(code) {
            if (code !== 0) {
                var errorMsg = "Process failed with exit code " + code + ": " + (label || "unknown");
                console.error("[ThemeService] " + errorMsg);
                CommandService.pushLog("[ThemeService] " + errorMsg, "error");
            }
        });
        return proc;
    }

    // Curated matrix representation for legacy interface alignment
    readonly property var curatedThemes: [
        "OLED Pure Black",
        "Catppuccin Mocha",
        "Tokyo Night"
    ]

    // =========================================================================
    // PRESET PALETTE REFERENCE — reads from ThemePresets (SSOT)
    // =========================================================================
    readonly property var presetPalettes: Config.ThemePresets.palettes

    // =========================================================================
    // CUSTOM SCHEMES — user-saved palettes (max 5), persisted to
    // ~/.config/quickshell/custom-themes.json so they survive reboot.
    // =========================================================================
    property var customThemes: []
    readonly property string customThemesPath: themeService.homeDir + "/.config/quickshell/custom-themes.json"

    Component.onCompleted: {
        themeService.loadCustomThemes();
        themeService.loadStylixSeed();
    }

    // =========================================================================
    // SCHEMA — token keys + default seed (canonical source, shared with
    // settings/config/ThemeConfig.qml + essentials.nix). Live color VALUES
    // still flow only through ThemeConfig; this is keys + the default bundle.
    // =========================================================================
    readonly property var defaultBundle: Config.ThemeSchema.defaults

    // Relative luminance (0..1, sRGB) of a "#rrggbb" string; invalid → 0.
    function luminance(hex) {
        var h = (hex || "#000000").replace("#", "")
        if (h.length !== 6) return 0
        var ch = function (s) {
            var v = parseInt(s, 16) / 255
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * ch(h.substring(0, 2)) + 0.7152 * ch(h.substring(2, 4)) + 0.0722 * ch(h.substring(4, 6))
    }

    // Canonical 16-token bundle from a raw/partial color object.
    function normalizeBundle(raw) {
        var d = themeService.defaultBundle
        var has = function (k) { return raw && typeof raw[k] === "string" && raw[k].charAt(0) === "#" }
        var pick = function (k, fb) { return has(k) ? raw[k] : fb }
        return {
            background:       pick("background", d.background),
            surface:          pick("surface", d.surface),
            surfaceVariant:   pick("surfaceVariant", d.surfaceVariant),
            surfaceContainer: pick("surfaceContainer", has("surfaceVariant") ? raw.surfaceVariant : d.surfaceContainer),
            text:             pick("text", d.text),
            textDim:          pick("textDim", d.textDim),
            border:           pick("border", d.border),
            outline:          pick("outline", d.outline),
            outlineVariant:   pick("outlineVariant", d.outlineVariant),
            primary:          pick("primary", d.primary),
            secondary:        pick("secondary", d.secondary),
            accent:           pick("accent", d.accent),
            success:          pick("success", d.success),
            warning:          pick("warning", d.warning),
            error:            pick("error", d.error),
            info:             pick("info", d.info)
        }
    }

    /**
     * Single OLED Clamp Function — forces surface tokens to pure black.
     * The ONLY clamp in the settings process. All apply paths route through it.
     */
    function clampOLED(bundle, clamp) {
        if (!clamp) {
            return bundle;
        }
        // Force ONLY the four surface tokens to pure black
        bundle.background = "#000000";
        bundle.surface = "#000000";
        bundle.surfaceVariant = "#000000";
        bundle.surfaceContainer = "#000000";
        // Pure-black bg: guarantee text legibility. If the source palette's text
        // is too dim to read on #000, fall back to the default light tokens.
        if (themeService.luminance(bundle.text) < 0.18)
            bundle.text = themeService.defaultBundle.text;
        if (themeService.luminance(bundle.textDim) < 0.12)
            bundle.textDim = themeService.defaultBundle.textDim;
        return bundle;
    }

    // =========================================================================
    // ATOMIC I/O HELPERS
    // -------------------------------------------------------------------------
    // _runSh       — one-shot `sh -c` Process; logs failures (no silent errors).
    // _atomicWrite — write to <path>.tmp.$$ then mv. Readers (bar FileView,
    //   nvim dofile, rofi) never see a half-written file. Single quotes in the
    //   payload are escaped; paths are space-free under ~ so left bare for $$.
    // =========================================================================
    function _runSh(script, label) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', themeService);
        p.command = ["sh", "-c", script];
        p.onExited.connect(function(code) {
            if (code !== 0) {
                var msg = (label || "shell") + " failed (exit " + code + ")";
                console.error("[ThemeService] " + msg);
                CommandService.pushLog("[ThemeService] " + msg, "error");
            }
        });
        p.running = true;
        return p;
    }

    function _atomicWrite(path, content) {
        var dir = path.substring(0, path.lastIndexOf("/"));
        var safe = String(content).replace(/'/g, "'\\''");
        themeService._runSh(
            "mkdir -p " + dir + " && printf '%s' '" + safe + "' > " + path + ".tmp.$$ && mv -f " + path + ".tmp.$$ " + path,
            "write " + path
        );
    }

    /**
     * Writes the theme bundle to ~/.cache/theme/colors.json (bar sync channel).
     * Atomic, consolidated helper for all apply paths.
     */
    function _writeColorsJson(bundle, metadata) {
        var colorsJsonPath = themeService.homeDir + "/.cache/theme/colors.json";
        themeService._atomicWrite(colorsJsonPath, JSON.stringify({ colors: bundle, metadata: metadata }));
    }

    /**
     * Re-apply the current theme with new OLED clamp state (public toggle API).
     */
    function setOledClamp(clamp) {
        if (Config.DebugConfig.debugTheme) console.log("=== setOledClamp CALLED ===", clamp)
        var currentName = Config.ThemeConfig.metadata.name || "OLED Pure Black";
        var currentSource = Config.ThemeConfig.metadata.source || "preset";

        if (currentSource === "preset") {
            themeService.applyPreset(currentName, clamp);
        } else if (currentSource === "stylix" || currentSource === "matugen" || currentSource === "custom" || currentSource === "manual") {
            // Re-clamp the CURRENT palette in place. Do NOT reload the seed —
            // its hardcoded oledClamp:false would revert this toggle ~1s later,
            // and reloading would discard a custom/manual/matugen palette.
            var bundle = themeService.normalizeBundle(Config.ThemeConfig.colors);
            themeService.clampOLED(bundle, clamp);
            Config.ThemeConfig.applyTheme({
                colors: bundle,
                metadata: {
                    name: Config.ThemeConfig.metadata.name,
                    source: currentSource,
                    applied: new Date().toISOString(),
                    oledClamp: clamp,
                    matugenEnabled: Config.ThemeConfig.metadata.matugenEnabled
                }
            }, true);
            themeService._writeColorsJson(bundle, Config.ThemeConfig.metadata);
            themeService.syncToExternalApps(bundle);
        } else {
            if (Config.DebugConfig.debugTheme) console.warn("[setOledClamp] Unknown source:", currentSource, "- falling back to OLED Pure Black")
            themeService.applyPreset("OLED Pure Black", clamp);
        }
    }

    /**
     * Apply a curated preset palette (instant in-process recolor + cache write).
     */
    function applyPreset(presetName, applyOLEDClamp) {
        if (Config.DebugConfig.debugTheme) console.log("=== applyPreset CALLED ===", presetName)
        themeService.isRegenerating = true;

        var palette = themeService.presetPalettes[presetName];
        if (!palette) {
            themeService.isRegenerating = false;
            console.warn("[applyPreset] unknown preset:", presetName);
            return;
        }

        var bundle = themeService.normalizeBundle(palette);
        themeService.clampOLED(bundle, applyOLEDClamp);

        var meta = {
            name: presetName,
            source: "preset",
            applied: new Date().toISOString(),
            oledClamp: applyOLEDClamp ? true : false,
            matugenEnabled: false
        };
        Config.ThemeConfig.applyTheme({ colors: bundle, metadata: meta }, true);
        themeService._writeColorsJson(bundle, meta);
        themeService.syncToExternalApps(bundle);

        themeService.isRegenerating = false;
    }

    // =========================================================================
    // RUNTIME PALETTE — matugen (instant wallpaper → Material-You, no rebuild)
    // =========================================================================
    // matugen emits { base16, colors: {<name>: {dark/default/light:{color}}} }.
    // We use the `colors` (Material-You) block — the base16 block is a tonal
    // ramp (base08 "red" is dark teal here), not semantically meaningful.
    // `--prefer darkness` picks the darkest dominant color (deterministic,
    // non-interactive). `-m dark` selects the dark scheme.
    property var matugenRunner: Process {
        id: matugenProc
        property string buffer: ""
        property string pendingWallpaper: ""
        command: []
        stdout: SplitParser { onRead: function(data) { matugenProc.buffer += data } }
        onExited: function(code) {
            themeService.isRegenerating = false;
            var path = matugenProc.pendingWallpaper;
            if (code === 0 && matugenProc.buffer.length > 0) {
                try {
                    var parsed = JSON.parse(matugenProc.buffer.trim());
                    var bundle = themeService._matugenSchemeToBundle(parsed);
                    var liveClamp = Config.ThemeConfig.metadata.oledClamp;
                    themeService.clampOLED(bundle, liveClamp);
                    var meta = {
                        name: "Matugen (" + (path.split("/").pop() || "wallpaper") + ")",
                        source: "matugen",
                        applied: new Date().toISOString(),
                        oledClamp: liveClamp,
                        matugenEnabled: true
                    };
                    Config.ThemeConfig.applyTheme({ colors: bundle, metadata: meta }, true);
                    themeService._writeColorsJson(bundle, meta);
                    themeService.syncToExternalApps(bundle);
                    themeService.regenFailed = false;
                    themeService.regenError = "";
                    console.log("[ThemeService] matugen palette applied for", path);
                } catch (e) {
                    console.error("[ThemeService] matugen parse failed:", e);
                    themeService._matugenFallback(path, "matugen output unreadable: " + e);
                }
            } else {
                console.error("[ThemeService] matugen exited", code);
                themeService._matugenFallback(path, "matugen failed (exit " + code + ")");
            }
            matugenProc.buffer = "";
        }
    }

    // Map matugen Material-You `colors` block → 16-token schema (dark variants).
    // MY has no success/warning/info semantic colors → fall back to defaultBundle.
    function _matugenSchemeToBundle(parsed) {
        var d = themeService.defaultBundle;
        var col = (parsed && parsed.colors) ? parsed.colors : {};
        function my(key) {
            var e = col[key];
            return (e && e.dark && typeof e.dark.color === "string") ? e.dark.color : null;
        }
        var background   = my("background") || d.background;
        var surface      = my("surface") || d.surface;
        var surfaceVar   = my("surface_variant") || d.surfaceVariant;
        var surfaceCont  = my("surface_container") || surfaceVar || d.surfaceContainer;
        var onSurface    = my("on_surface") || my("on_background") || d.text;
        var onSurfaceV   = my("on_surface_variant") || d.textDim;
        var outline      = my("outline") || d.outline;
        var outlineVar   = my("outline_variant") || d.outlineVariant;
        var primary      = my("primary") || d.primary;
        var secondary    = my("secondary") || d.secondary;
        var tertiary     = my("tertiary") || d.accent;
        var error        = my("error") || d.error;
        return {
            background: background,
            surface: surface,
            surfaceVariant: surfaceVar,
            surfaceContainer: surfaceCont,
            text: onSurface,
            textDim: onSurfaceV,
            border: outlineVar,
            outline: outline,
            outlineVariant: outlineVar,
            primary: primary,
            secondary: secondary,
            accent: tertiary,
            success: d.success,
            warning: d.warning,
            error: error,
            info: primary
        };
    }

    // matugen failure → either rebuild fallback (opt-in) or surfaced error.
    function _matugenFallback(path, reason) {
        if (themeService.fallbackToRebuild) {
            console.warn("[ThemeService] matugen failed → falling back to rebuild:", reason);
            themeService.applyDynamicThemeViaRebuild(path);
        } else {
            themeService.regenError = reason;
            themeService.regenFailed = true;
        }
    }

    /**
     * Generate a palette from the ACTIVE wallpaper via matugen (instant, no
     * rebuild). wallpaperPath comes from WallpaperService.currentWallpaper.
     * The OLED-clamp param is honoured via the live clamp state (matugen's
     * surfaces get clamped like any other source).
     */
    function applyDynamicTheme(wallpaperPath, applyOLEDClamp_unused) {
        if (Config.DebugConfig.debugTheme) console.log("=== applyDynamicTheme (matugen) CALLED ===", wallpaperPath)

        if (themeService.isRegenerating) {
            if (Config.DebugConfig.debugTheme) console.log("[applyDynamicTheme] already regenerating, skipping")
            return;
        }

        var actualPath = wallpaperPath || Config.SharedState.wallpaperPath
        if (!actualPath || actualPath === "") {
            themeService.regenError = "No wallpaper selected — set a wallpaper in the Wallpaper tab first"
            themeService.regenFailed = true
            return;
        }

        themeService.regenError = ""
        themeService.regenFailed = false
        themeService.isRegenerating = true;
        rebuildTimeout.restart();

        var cleanPath = actualPath.startsWith("file://") ? actualPath.substring(7) : actualPath;
        matugenProc.pendingWallpaper = cleanPath;
        matugenProc.buffer = "";
        matugenProc.command = ["matugen", "image", cleanPath, "--json", "hex", "--prefer", "darkness", "-m", "dark"];
        matugenProc.running = true;
    }

    // =========================================================================
    // REBUILD FALLBACK — the old Stylix-rebuild path (kept for when matugen is
    // unavailable/broken and fallbackToRebuild is on). Copies the wallpaper
    // into the flake tree and rebuilds; Stylix regenerates the seed.
    // =========================================================================
    property var rebuildRunner: Process {
        id: rebuilder
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { rebuilder.buffer += data } }
        onRunningChanged: function() {
            if (!running) {
                console.log("[ThemeService] Rebuild output:", rebuilder.buffer.trim());
                rebuilder.buffer = "";
            }
        }
        onExited: function(code) {
            themeService.isRegenerating = false;
            if (code === 0) {
                themeService.regenFailed = false;
                themeService.regenError = "";
                console.log("[ThemeService] Rebuild succeeded — applying new Stylix seed");
                themeService.applyStylixSeedNow();
            } else {
                console.error("[ThemeService] Rebuild failed with exit code:", code);
                themeService.regenError = "Rebuild failed (exit code " + code + ")";
                themeService.regenFailed = true;
            }
        }
    }

    function applyDynamicThemeViaRebuild(wallpaperPath) {
        var cleanPath = (wallpaperPath || "").startsWith("file://") ? wallpaperPath.substring(7) : (wallpaperPath || "");
        if (!cleanPath) return;
        themeService.isRegenerating = true;
        rebuildTimeout.restart();
        rebuilder.command = ["pkexec", "/run/current-system/sw/bin/qs-apply-wallpaper", cleanPath];
        rebuilder.running = true;
    }

    // Safety timeout: clear isRegenerating after 60s if generation hangs.
    Timer {
        id: rebuildTimeout
        interval: 60000
        running: false
        repeat: false
        onTriggered: {
            if (themeService.isRegenerating) {
                console.warn("ThemeService: generation timeout - clearing isRegenerating flag")
                themeService.regenError = "Theme generation timed out";
                themeService.regenFailed = true;
                themeService.isRegenerating = false;
            }
        }
    }

    // =========================================================================
    // STYLIX SEED (cold-boot only) — loaded on startup if colors.json is absent
    // or its source is "stylix". The clobber-guard preserves a user's live choice.
    // =========================================================================
    property var stylixChecker: Process {
        property string buffer: ""
        command: []
        stdout: SplitParser { onRead: function(data) { stylixChecker.buffer += data } }
        onExited: function(code) {
            var shouldLoadSeed = true;
            if (stylixChecker.buffer.trim() !== "NONE") {
                try {
                    var existing = JSON.parse(stylixChecker.buffer.trim());
                    if (existing.metadata && existing.metadata.source && existing.metadata.source !== "stylix") {
                        shouldLoadSeed = false;
                        console.log("[ThemeService] Skipping Stylix seed - existing theme:", existing.metadata.name);
                    }
                } catch (e) { /* File exists but invalid, load seed */ }
            }
            if (shouldLoadSeed) stylixSeedLoader.running = true;
            stylixChecker.buffer = "";
        }
    }

    property var stylixSeedLoader: Process {
        property string buffer: ""
        command: ["sh", "-c", "cat ~/.config/quickshell/stylix-palette.json 2>/dev/null"]
        stdout: SplitParser { onRead: function(data) { stylixSeedLoader.buffer += data } }
        onRunningChanged: {
            if (!running && stylixSeedLoader.buffer.length > 0) {
                try {
                    var seed = JSON.parse(stylixSeedLoader.buffer.trim());
                    if (seed && seed.colors && seed.metadata) {
                        var bundle = themeService.normalizeBundle(seed.colors);
                        var liveClamp = Config.ThemeConfig.metadata.oledClamp;
                        var meta = {
                            name: seed.metadata.name,
                            source: seed.metadata.source,
                            applied: new Date().toISOString(),
                            oledClamp: liveClamp,
                            matugenEnabled: false
                        };
                        themeService.clampOLED(bundle, liveClamp);
                        Config.ThemeConfig.applyTheme({ colors: bundle, metadata: meta });
                        themeService._writeColorsJson(bundle, meta);
                        themeService.syncToExternalApps(bundle);
                        console.log("[ThemeService] Stylix seed loaded:", seed.metadata.name, "(oledClamp preserved:", liveClamp + ")");
                    } else {
                        console.warn("[ThemeService] Stylix seed invalid or missing colors");
                    }
                } catch (e) {
                    console.error("[ThemeService] Failed to parse Stylix seed:", e);
                }
                stylixSeedLoader.buffer = "";
            }
        }
    }

    function loadStylixSeed() {
        var colorsPath = themeService.homeDir + "/.cache/theme/colors.json";
        stylixChecker.command = ["sh", "-c", "test -f " + colorsPath + " && cat " + colorsPath + " || echo 'NONE'"];
        stylixChecker.running = true;
    }

    /** Force-load the Stylix seed NOW, bypassing the clobber guard. */
    function applyStylixSeedNow() { stylixSeedLoader.running = true; }

    /**
     * Manual per-token override. Runs through clampOLED so OLED-on + a manual
     * non-black surface is clamped back to pure black (the previous bypass bug).
     */
    function applyManualOverride(tokenKey, hexValue) {
        if (!/^#[0-9A-Fa-f]{6}$/.test(hexValue)) return;

        Config.ThemeConfig.updateColorToken(tokenKey, hexValue);

        // Re-clamp the whole bundle: an OLED user editing a surface token must
        // still get pure black. Reads back the just-updated colors.
        var bundle = themeService.normalizeBundle(Config.ThemeConfig.colors);
        var clamp = themeService.isOledClampActive;
        themeService.clampOLED(bundle, clamp);
        var meta = {
            name: "Custom Modification",
            source: "manual",
            applied: new Date().toISOString(),
            oledClamp: clamp,
            matugenEnabled: Config.ThemeConfig.metadata.matugenEnabled
        };
        Config.ThemeConfig.applyTheme({ colors: bundle, metadata: meta }, true);
        themeService._writeColorsJson(bundle, meta);
        themeService.syncToExternalApps(bundle);
    }

    // =========================================================================
    // CUSTOM SCHEME PERSISTENCE + API
    // =========================================================================
    property var customThemeLoader: Process {
        id: customLoader
        property string buffer: ""
        command: ["sh", "-c", "cat " + themeService.customThemesPath + " 2>/dev/null"]
        stdout: SplitParser { onRead: function(data) { customLoader.buffer += data } }
        onRunningChanged: {
            if (!running) {
                try {
                    var raw = customLoader.buffer.trim()
                    if (raw.length > 0) {
                        var arr = JSON.parse(raw)
                        themeService.customThemes = Array.isArray(arr) ? arr : []
                    }
                } catch (e) { /* no/invalid file yet */ }
                customLoader.buffer = ""
            }
        }
    }

    function loadCustomThemes() { customLoader.running = true }

    function saveCustomTheme(name) {
        var n = (name || "").trim()
        if (n.length === 0) return
        var entry = { name: n, colors: {} }
        var c = Config.ThemeConfig.colors
        for (var k in c) {
            if (Object.prototype.hasOwnProperty.call(c, k)) entry.colors[k] = c[k]
        }
        var arr = themeService.customThemes.filter(function(e) { return e.name !== n })
        arr.unshift(entry)
        if (arr.length > 5) arr = arr.slice(0, 5)
        themeService.customThemes = arr
        themeService._writeCustomThemes()
    }

    function deleteCustomTheme(name) {
        themeService.customThemes = themeService.customThemes.filter(function(e) { return e.name !== name })
        themeService._writeCustomThemes()
    }

    function applyCustomTheme(name) {
        var found = null
        for (var i = 0; i < themeService.customThemes.length; i++) {
            if (themeService.customThemes[i].name === name) { found = themeService.customThemes[i]; break }
        }
        if (!found || !found.colors) return

        var bundle = themeService.normalizeBundle(found.colors)
        themeService.clampOLED(bundle, themeService.isOledClampActive)
        var meta = {
            name: found.name,
            source: "custom",
            applied: new Date().toISOString(),
            oledClamp: themeService.isOledClampActive,
            matugenEnabled: false
        }
        Config.ThemeConfig.applyTheme({ colors: bundle, metadata: meta }, true)
        themeService._writeColorsJson(bundle, meta)
        themeService.syncToExternalApps(bundle)
    }

    function _writeCustomThemes() {
        themeService._atomicWrite(themeService.customThemesPath, JSON.stringify(themeService.customThemes));
    }

    // =========================================================================
    // EXTERNAL APP SYNC — debounced dispatcher
    // -------------------------------------------------------------------------
    // syncToExternalApps() debounces 80ms (coalesces rapid preset/manual/matugen
    // bursts) then fans out to the _syncers registry. Each syncer writes one
    // app's config; failures are caught + logged per-app (previously silent).
    // =========================================================================
    property var _pendingSyncColors: null

    property var _syncDebounce: Timer {
        interval: 80
        repeat: false
        onTriggered: {
            if (themeService._pendingSyncColors) {
                themeService._runAllSyncers(themeService._pendingSyncColors);
                themeService._pendingSyncColors = null;
            }
        }
    }

    // Registry — add a target by appending {key, fn}.
    property var _syncers: [
        { key: "ghostty",  fn: function(c) { themeService._syncGhostty(c) } },
        { key: "kitty",    fn: function(c) { themeService._syncKitty(c) } },
        { key: "hyprlock", fn: function(c) { themeService._syncHyprlock(c) } },
        { key: "nvim",     fn: function(c) { themeService._syncNvim(c) } },
        { key: "rofi",     fn: function(c) { themeService._syncRofi(c) } },
        { key: "gtk",      fn: function(c) { themeService._syncGtk(c) } }
    ]

    function syncToExternalApps(colors) {
        if (!colors) colors = Config.ThemeConfig.colors;
        themeService._pendingSyncColors = colors;
        themeService._syncDebounce.restart();
    }

    function _runAllSyncers(colors) {
        for (var i = 0; i < themeService._syncers.length; i++) {
            var s = themeService._syncers[i];
            try {
                s.fn(colors);
            } catch (e) {
                var msg = "syncer '" + s.key + "' threw: " + e;
                console.error("[ThemeService] " + msg);
                CommandService.pushLog("[ThemeService] " + msg, "error");
            }
        }
    }

    // -------------------------------------------------------------------------
    // ghostty: managed palette block appended to the MAIN config. We read→strip
    // the prior block→append a fresh one in `sh`+`sed` — NOT python3. python is
    // not guaranteed on the runtime PATH, and every other syncer stays in pure
    // sh/Qt; a missing python3 silently no-op'd this syncer (ghostty stalled on
    // a stale palette while kitty/hyprlock updated). ghostty watches its main
    // config and reloads on change, so no reload signal is needed.
    // -------------------------------------------------------------------------
    function _syncGhostty(colors) {
        var ghosttyMain = themeService.homeDir + "/.config/ghostty/config";
        var ghosttyLines = [
            "background = " + colors.background,
            "foreground = " + colors.text,
            "cursor-color = " + colors.primary,
            "selection-background = " + colors.primary,
            "selection-foreground = " + colors.background,
            "palette = 0=" + colors.background,
            "palette = 1=" + colors.error,
            "palette = 2=" + colors.success,
            "palette = 3=" + colors.warning,
            "palette = 4=" + colors.primary,
            "palette = 5=" + colors.secondary,
            "palette = 6=" + colors.info,
            "palette = 7=" + colors.text,
            "palette = 8=" + colors.textDim,
            "palette = 9=" + colors.error,
            "palette = 10=" + colors.success,
            "palette = 11=" + colors.warning,
            "palette = 12=" + colors.primary,
            "palette = 13=" + colors.secondary,
            "palette = 14=" + colors.info,
            "palette = 15=" + colors.text
        ].join("\n");
        var block = "# >>> quickshell-theme >>>\n" + ghosttyLines + "\n# <<< quickshell-theme <<<";
        // sh single-quote escape (same scheme as _atomicWrite); block has no quotes.
        var quoted = "'" + String(block).replace(/'/g, "'\\''") + "'";
        // Ensure file exists, drop the old managed block (marker→EOF) and any
        // trailing blank lines, then append the fresh block. User settings above
        // the marker are preserved.
        var script =
            "f=" + ghosttyMain + " && " +
            "mkdir -p \"$(dirname \"$f\")\" && " +
            "{ [ -f \"$f\" ] || : > \"$f\"; } && " +
            "sed -i '/# >>> quickshell-theme >>>/,$d' \"$f\" && " +
            "sed -i -e :a -e '/^\\n*$/{$d;N;ba}' \"$f\" && " +
            "printf '\\n\\n%s\\n' " + quoted + " >> \"$f\"";
        themeService._runSh(script, "sync ghostty");
    }

    // -------------------------------------------------------------------------
    // kitty: palette to ~/.cache/theme/kitty.conf (runtime-writable; kitty.conf
    // includes it). SIGUSR1 asks kitty to reload. Atomic write.
    // -------------------------------------------------------------------------
    function _syncKitty(colors) {
        var kittyConf = themeService.homeDir + "/.cache/theme/kitty.conf";
        var kittyContent =
            "background " + colors.background + "\n" +
            "foreground " + colors.text + "\n" +
            "cursor " + colors.primary + "\n" +
            "selection_background " + colors.primary + "\n" +
            "selection_foreground " + colors.background + "\n" +
            "color0 "  + colors.background + "\n" +
            "color1 "  + colors.error + "\n" +
            "color2 "  + colors.success + "\n" +
            "color3 "  + colors.warning + "\n" +
            "color4 "  + colors.primary + "\n" +
            "color5 "  + colors.secondary + "\n" +
            "color6 "  + colors.info + "\n" +
            "color7 "  + colors.text + "\n" +
            "color8 "  + colors.textDim + "\n" +
            "color9 "  + colors.error + "\n" +
            "color10 " + colors.success + "\n" +
            "color11 " + colors.warning + "\n" +
            "color12 " + colors.primary + "\n" +
            "color13 " + colors.secondary + "\n" +
            "color14 " + colors.info + "\n" +
            "color15 " + colors.text + "\n";
        themeService._atomicWrite(kittyConf, kittyContent);
        themeService._runSh("pkill -SIGUSR1 kitty || true", "kitty reload");
    }

    // -------------------------------------------------------------------------
    // hyprlock: sourced at the END of hyprlock.conf — single source for the
    // lock background + input-field. Keep geometry in sync with the build-time
    // fallback seedHyprlockColors in modules/apps/essentials.nix.
    // -------------------------------------------------------------------------
    function _syncHyprlock(colors) {
        var hyprlockFile = themeService.homeDir + "/.config/hypr/quickshell-colors.conf";
        var hyprlockContent =
            "# Managed by QuickShell ThemeService — sourced at END of hyprlock.conf.\n" +
            "# Single source for the lock background + input-field (themed).\n" +
            "background {\n    color = rgba(" + colors.background.replace("#","") + "ff)\n}\n" +
            "input-field {\n" +
            "    monitor =\n" +
            "    size = 400, 50\n" +
            "    position = 0, 0\n" +
            "    halign = center\n" +
            "    valign = center\n" +
            "    rounding = 16\n" +
            "    outline_thickness = 2\n" +
            "    inner_color = rgba(" + colors.surfaceContainer.replace("#","") + "ff)\n" +
            "    outer_color = rgba(" + colors.secondary.replace("#","") + "ff)\n" +
            "    font_color = rgba(" + colors.text.replace("#","") + "ff)\n" +
            "    font_family = JetBrainsMono Nerd Font\n" +
            "    placeholder_text = Enter Password\n" +
            "    fail_text = <i>$FAIL ($ATTEMPTS)</i>\n" +
            "    shadow_passes = 0\n" +
            "    fade_on_empty = false\n" +
            "}\n";
        themeService._atomicWrite(hyprlockFile, hyprlockContent);
    }

    // NOTE: Hyprland window borders are intentionally NOT themed (read-only
    // Lua config; hyprctl keyword rejected; reload reverts). Border colour is
    // a deliberate OLED burn-in mitigation hardcoded in configs/hypr/look-and-feel.lua.
    // NOTE: mako removed — notifications handled by Quickshell NotificationCenter.

    // -------------------------------------------------------------------------
    // nvim (base16): Lua table the nvim-base16 plugin dofile()s on launch +
    // FocusGained. ~/.cache/theme (runtime-owned). 16 slots: 11 direct + 5 fb.
    // -------------------------------------------------------------------------
    function _syncNvim(colors) {
        var nvimLua = "return {\n" +
            "  base00 = " + JSON.stringify(colors.background) + ",\n" +
            "  base01 = " + JSON.stringify(colors.surface) + ",\n" +
            "  base02 = " + JSON.stringify(colors.surfaceVariant) + ",\n" +
            "  base03 = " + JSON.stringify(colors.textDim) + ",\n" +
            "  base04 = " + JSON.stringify(colors.textDim) + ",\n" +
            "  base05 = " + JSON.stringify(colors.text) + ",\n" +
            "  base06 = " + JSON.stringify(colors.text) + ",\n" +
            "  base07 = " + JSON.stringify(colors.text) + ",\n" +
            "  base08 = " + JSON.stringify(colors.error) + ",\n" +
            "  base09 = " + JSON.stringify(colors.warning) + ",\n" +
            "  base0A = " + JSON.stringify(colors.warning) + ",\n" +
            "  base0B = " + JSON.stringify(colors.success) + ",\n" +
            "  base0C = " + JSON.stringify(colors.secondary) + ",\n" +
            "  base0D = " + JSON.stringify(colors.primary) + ",\n" +
            "  base0E = " + JSON.stringify(colors.accent) + ",\n" +
            "  base0F = " + JSON.stringify(colors.error) + "\n" +
            "}";
        themeService._atomicWrite(themeService.homeDir + "/.cache/theme/nvim-base16.lua", nvimLua);
    }

    // -------------------------------------------------------------------------
    // rofi: rasi palette config.rasi @imports (ABSOLUTE path → read-only nix
    // store workaround). Hyphen-free var names; UNQUOTED hex (quoting breaks it).
    // -------------------------------------------------------------------------
    function _syncRofi(colors) {
        var rofiRasi = "* {\n" +
            "    bg:          " + colors.background + ";\n" +
            "    surface:     " + colors.surface + ";\n" +
            "    surfacevar:  " + colors.surfaceVariant + ";\n" +
            "    text:        " + colors.text + ";\n" +
            "    textdim:     " + colors.textDim + ";\n" +
            "    primary:     " + colors.primary + ";\n" +
            "    secondary:   " + colors.secondary + ";\n" +
            "    accent:      " + colors.accent + ";\n" +
            "    border:      " + colors.border + ";\n" +
            "    outline:     " + colors.outline + ";\n" +
            "    outlinealt:  " + colors.outlineVariant + ";\n" +
            "    success:     " + colors.success + ";\n" +
            "    warning:     " + colors.warning + ";\n" +
            "    error:       " + colors.error + ";\n" +
            "    info:        " + colors.info + ";\n" +
            "}";
        themeService._atomicWrite(themeService.homeDir + "/.cache/theme/rofi.rasi", rofiRasi);
    }

    // -------------------------------------------------------------------------
    // GTK (4/libadwaita + 3): @define-color overrides in colors.css. libadwaita
    // reads ~/.config/gtk-4.0/colors.css at app STARTUP — running apps do not
    // recolor live; newly opened GTK apps pick up the change. No collision with
    // HM (apps.nix writes settings.ini, not colors.css). Qt is NOT covered here
    // (platformTheme=gtk won't read named colors) — see home/apps.nix follow-up.
    // -------------------------------------------------------------------------
    function _syncGtk(colors) {
        var css =
            "/* Managed by QuickShell ThemeService — do not edit. */\n" +
            "@define-color window_bg_color " + colors.background + ";\n" +
            "@define-color window_fg_color " + colors.text + ";\n" +
            "@define-color view_bg_color " + colors.surface + ";\n" +
            "@define-color view_fg_color " + colors.text + ";\n" +
            "@define-color headerbar_bg_color " + colors.background + ";\n" +
            "@define-color headerbar_fg_color " + colors.text + ";\n" +
            "@define-color sidebar_bg_color " + colors.surface + ";\n" +
            "@define-color sidebar_fg_color " + colors.text + ";\n" +
            "@define-color dialog_bg_color " + colors.surface + ";\n" +
            "@define-color dialog_fg_color " + colors.text + ";\n" +
            "@define-color card_bg_color " + colors.surfaceContainer + ";\n" +
            "@define-color card_fg_color " + colors.text + ";\n" +
            "@define-color popover_bg_color " + colors.surface + ";\n" +
            "@define-color popover_fg_color " + colors.text + ";\n" +
            "@define-color accent_color " + colors.primary + ";\n" +
            "@define-color accent_bg_color " + colors.primary + ";\n" +
            "@define-color accent_fg_color " + colors.background + ";\n" +
            "@define-color destructive_color " + colors.error + ";\n" +
            "@define-color destructive_bg_color " + colors.error + ";\n" +
            "@define-color success_color " + colors.success + ";\n" +
            "@define-color success_bg_color " + colors.success + ";\n" +
            "@define-color warning_color " + colors.warning + ";\n" +
            "@define-color warning_bg_color " + colors.warning + ";\n" +
            "@define-color error_color " + colors.error + ";\n" +
            "@define-color error_bg_color " + colors.error + ";\n" +
            "@define-color borders " + colors.border + ";\n" +
            "@define-color insensitive_fg_color " + colors.textDim + ";\n";
        themeService._atomicWrite(themeService.homeDir + "/.config/gtk-4.0/colors.css", css);
        themeService._atomicWrite(themeService.homeDir + "/.config/gtk-3.0/colors.css", css);
    }
}
