// =============================================================================
// theme-sync.mjs — pure app-config TEXT generation for ThemeService (I8)
// =============================================================================
// The external-app syncers split in two: the file CONTENT (this file — plain
// functions from the 16-token palette to one app's config text, node-tested
// byte-exactly) and the IO (ThemeService keeps paths, _atomicWrite, _runSh and
// the reload signals: kitty SIGUSR1, tmux source-file, ghostty's inode-
// preserving in-place write). Byte-faithfulness is the contract — users diff
// these files — so the tests assert full literal outputs.
//
// settings-local (NOT part of the sync-shared pair — the bar never generates
// app configs; shared/theme-core.mjs stays the canonical 16-token logic).
// =============================================================================

// matugen Material-You `colors` block → 16-token schema (dark variants).
// MY has no success/warning/info semantic colors → the default bundle fills
// them. `defaults` is the service's defaultBundle (ThemeSchema.defaults).
export function matugenSchemeToBundle(parsed, defaults) {
    var d = defaults
    var col = (parsed && parsed.colors) ? parsed.colors : {}
    function my(key) {
        var e = col[key]
        return (e && e.dark && typeof e.dark.color === "string") ? e.dark.color : null
    }
    var background   = my("background") || d.background
    var surface      = my("surface") || d.surface
    var surfaceVar   = my("surface_variant") || d.surfaceVariant
    var surfaceCont  = my("surface_container") || surfaceVar || d.surfaceContainer
    var onSurface    = my("on_surface") || my("on_background") || d.text
    var onSurfaceV   = my("on_surface_variant") || d.textDim
    var outline      = my("outline") || d.outline
    var outlineVar   = my("outline_variant") || d.outlineVariant
    var primary      = my("primary") || d.primary
    var secondary    = my("secondary") || d.secondary
    var tertiary     = my("tertiary") || d.accent
    var error        = my("error") || d.error
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
    }
}

// ghostty: managed palette block appended to the MAIN config (the service
// owns the inode-preserving read→strip→write and the validate-then-rollback).
export function ghosttyBlock(colors) {
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
        "palette = 5=" + colors.accent,
        "palette = 6=" + colors.info,
        "palette = 7=" + colors.text,
        "palette = 8=" + colors.outline,
        "palette = 9=" + colors.error,
        "palette = 10=" + colors.success,
        "palette = 11=" + colors.warning,
        "palette = 12=" + colors.textDim,
        "palette = 13=" + colors.secondary,
        "palette = 14=" + colors.info,
        "palette = 15=" + colors.text
    ].join("\n")
    return "# >>> quickshell-theme >>>\n" + ghosttyLines + "\n# <<< quickshell-theme <<<"
}

// kitty: palette config sourced by kitty.conf; reload = SIGUSR1 (service).
export function kittyConf(colors) {
    return "background " + colors.background + "\n" +
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
        "color15 " + colors.text + "\n"
}

// tmux: palette sourced at END of tmux.conf; `tmux source-file` hot-applies.
// Colour mapping matches the ghostty palette block: blue→primary, black→
// background, brightblack→outline. tmux accepts #rrggbb in all styles.
export function tmuxConf(colors) {
    return "# Managed by QuickShell ThemeService — sourced at END of tmux.conf.\n" +
        "# Do not edit; regenerate by switching theme in the dashboard.\n" +
        "set -g status-style \"bg=default,fg=" + colors.text + "\"\n" +
        "set -g status-left \"#[fg=" + colors.background + ",bg=" + colors.primary + ",bold] #S #[bg=default] \"\n" +
        "set -g status-right \"#[fg=" + colors.primary + "]#{?pane_in_mode,COPY ,}#{?client_prefix,PREFIX ,}#{?window_zoomed_flag,ZOOM ,}#[fg=" + colors.outline + "]#h \"\n" +
        "set -g window-status-format \"#[fg=" + colors.outline + "] #I:#W \"\n" +
        "set -g window-status-current-format \"#[fg=" + colors.primary + ",bold] #I:#W \"\n" +
        "set -g pane-border-style \"fg=" + colors.outline + "\"\n" +
        "set -g pane-active-border-style \"fg=" + colors.primary + "\"\n" +
        "set -g message-style \"bg=default,fg=" + colors.primary + "\"\n" +
        "set -g message-command-style \"bg=default,fg=" + colors.primary + "\"\n" +
        "set -g mode-style \"bg=" + colors.primary + ",fg=" + colors.background + "\"\n" +
        "setw -g clock-mode-colour \"" + colors.primary + "\"\n"
}

// hyprlock: sourced at the END of hyprlock.conf — single source for the lock
// background + input-field. Keep geometry in sync with the build-time
// fallback seedHyprlockColors in modules/apps/essentials.nix.
export function hyprlockConf(colors) {
    return "# Managed by QuickShell ThemeService — sourced at END of hyprlock.conf.\n" +
        "# Single source for the lock background + input-field (themed).\n" +
        "background {\n    color = rgba(" + colors.background.replace("#", "") + "ff)\n}\n" +
        "input-field {\n" +
        "    monitor =\n" +
        "    size = 400, 50\n" +
        "    position = 0, 0\n" +
        "    halign = center\n" +
        "    valign = center\n" +
        "    rounding = 16\n" +
        "    outline_thickness = 2\n" +
        "    inner_color = rgba(" + colors.surfaceContainer.replace("#", "") + "ff)\n" +
        "    outer_color = rgba(" + colors.secondary.replace("#", "") + "ff)\n" +
        "    font_color = rgba(" + colors.text.replace("#", "") + "ff)\n" +
        "    font_family = JetBrainsMono Nerd Font\n" +
        "    placeholder_text = Enter Password\n" +
        "    fail_text = <i>$FAIL ($ATTEMPTS)</i>\n" +
        "    shadow_passes = 0\n" +
        "    fade_on_empty = false\n" +
        "}\n"
}

// nvim (base16): Lua table the nvim-base16 plugin dofile()s on launch +
// FocusGained. 16 slots: 11 direct + 5 fb.
export function nvimLua(colors) {
    return "return {\n" +
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
        "}"
}

// rofi: rasi palette config.rasi @imports. Hyphen-free var names; UNQUOTED
// hex (quoting breaks it).
export function rofiRasi(colors) {
    return "* {\n" +
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
        "}"
}

// btop: pure-black .theme (flat theme[key]="#hex" assignments, no INI
// sections); graphs are 3-stop gradients (start/mid/end). The btop.conf
// color_theme edit stays in the service (path-dependent sh).
export function btopTheme(colors) {
    var bg = colors.background
    return "# velocity.theme — generated by Quickshell ThemeService. DO NOT EDIT.\n" +
        "# btop 1.4.7 flat theme: theme[key]=\"#hex\". Graphs are gradients:\n" +
        "# single color = leave mid/end empty; 2-color = start+end; 3-color = all.\n" +
        "\n" +
        "# === Background & text ===\n" +
        "theme[main_bg]=\"" + bg + "\"\n" +
        "theme[main_fg]=\"" + colors.text + "\"\n" +
        "theme[title]=\"" + colors.text + "\"\n" +
        "theme[hi_fg]=\"" + colors.secondary + "\"\n" +
        "theme[inactive_fg]=\"" + colors.textDim + "\"\n" +
        "theme[graph_text]=\"" + colors.textDim + "\"\n" +
        "\n" +
        "# === Selection / meters / dividers ===\n" +
        "theme[selected_bg]=\"" + colors.secondary + "\"\n" +
        "theme[selected_fg]=\"" + bg + "\"\n" +
        "theme[meter_bg]=\"" + colors.textDim + "\"\n" +
        "theme[div_line]=\"" + colors.textDim + "\"\n" +
        "\n" +
        "# === Per-domain box outlines ===\n" +
        "theme[cpu_box]=\"" + colors.secondary + "\"\n" +
        "theme[mem_box]=\"" + colors.primary + "\"\n" +
        "theme[net_box]=\"" + colors.success + "\"\n" +
        "theme[proc_box]=\"" + colors.secondary + "\"\n" +
        "theme[proc_misc]=\"" + colors.secondary + "\"\n" +
        "\n" +
        "# === Process-box extras (1.4.x) ===\n" +
        "theme[proc_banner_bg]=\"" + colors.secondary + "\"\n" +
        "theme[proc_banner_fg]=\"" + bg + "\"\n" +
        "theme[followed_bg]=\"" + colors.primary + "\"\n" +
        "theme[followed_fg]=\"" + bg + "\"\n" +
        "theme[proc_follow_bg]=\"" + colors.primary + "\"\n" +
        "theme[proc_pause_bg]=\"" + colors.warning + "\"\n" +
        "\n" +
        "# === Temperature graph: cool -> warm -> hot ===\n" +
        "theme[temp_start]=\"" + colors.secondary + "\"\n" +
        "theme[temp_mid]=\"" + colors.warning + "\"\n" +
        "theme[temp_end]=\"" + colors.error + "\"\n" +
        "\n" +
        "# === CPU graph: primary -> secondary -> success ===\n" +
        "theme[cpu_start]=\"" + colors.primary + "\"\n" +
        "theme[cpu_mid]=\"" + colors.secondary + "\"\n" +
        "theme[cpu_end]=\"" + colors.success + "\"\n" +
        "\n" +
        "# === Mem/Disk meters ===\n" +
        "theme[free_start]=\"" + colors.textDim + "\"\n" +
        "theme[free_mid]=\"" + colors.primary + "\"\n" +
        "theme[free_end]=\"" + colors.secondary + "\"\n" +
        "theme[cached_start]=\"" + colors.primary + "\"\n" +
        "theme[cached_mid]=\"" + colors.secondary + "\"\n" +
        "theme[cached_end]=\"" + colors.success + "\"\n" +
        "theme[available_start]=\"" + colors.textDim + "\"\n" +
        "theme[available_mid]=\"" + colors.secondary + "\"\n" +
        "theme[available_end]=\"" + colors.success + "\"\n" +
        "theme[used_start]=\"" + colors.secondary + "\"\n" +
        "theme[used_mid]=\"" + colors.success + "\"\n" +
        "theme[used_end]=\"" + colors.warning + "\"\n" +
        "\n" +
        "# === Network graphs ===\n" +
        "theme[download_start]=\"" + colors.secondary + "\"\n" +
        "theme[download_mid]=\"" + colors.success + "\"\n" +
        "theme[download_end]=\"" + colors.primary + "\"\n" +
        "theme[upload_start]=\"" + colors.primary + "\"\n" +
        "theme[upload_mid]=\"" + colors.secondary + "\"\n" +
        "theme[upload_end]=\"" + colors.success + "\"\n" +
        "\n" +
        "# === Process cpu/mem heat ramp: success -> warning -> error ===\n" +
        "theme[process_start]=\"" + colors.success + "\"\n" +
        "theme[process_mid]=\"" + colors.warning + "\"\n" +
        "theme[process_end]=\"" + colors.error + "\"\n"
}

// GTK (4/libadwaita + 3): @define-color overrides in colors.css (both
// versions get the same content — the service writes the two paths).
export function gtkColorsCss(colors) {
    return "/* Managed by QuickShell ThemeService — do not edit. */\n" +
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
        "@define-color insensitive_fg_color " + colors.textDim + ";\n"
}

// ── dominant color (P5.3/5: matugen 4.x source-color pre-step) ──────────────
// matugen 4.x picks the source color from an image INTERACTIVELY (arrow-key
// picker; "IO error: not a terminal" headless — the bar has no TTY ever), so
// ThemeService feeds it `matugen color hex <dom>` instead of `image`. The
// dominant comes from ffmpeg's 16×16 rawvideo rgb24 dump (hex chars, one byte
// pair per channel) — quantized to 4 bits/channel and mode-counted here.
// Tie-break: the DARKEST winner (matugen's old `--prefer darkness` intent);
// the OLED clamp reshapes everything else downstream.
export function dominantHexFromRgbBytes(hexChars) {
    var s = String(hexChars || "").toLowerCase().replace(/[^0-9a-f]/g, "")
    var bytes = s.length - (s.length % 2)
    if (bytes < 3) return ""
    var counts = {}
    var best = null
    for (var o = 0; o + 5 < bytes; o += 6) {
        var r = parseInt(s.substring(o, o + 2), 16)
        var g = parseInt(s.substring(o + 2, o + 4), 16)
        var b = parseInt(s.substring(o + 4, o + 6), 16)
        // 4-bit quantization: <<4 restores a representative 8-bit level
        var k = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)
        var e = counts[k]
        if (!e) { e = counts[k] = { n: 0, r: (r >> 4) << 4, g: (g >> 4) << 4, b: (b >> 4) << 4 } }
        e.n++
        if (best === null || e.n > best.n ||
            (e.n === best.n && (e.r + e.g + e.b) < (best.r + best.g + best.b))) best = e
    }
    if (best === null) return ""
    var hx = v => ("0" + v.toString(16)).slice(-2)
    return ("#" + hx(best.r) + hx(best.g) + hx(best.b)).toUpperCase()
}
