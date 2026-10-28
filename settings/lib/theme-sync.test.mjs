// theme-sync.test.mjs — app-config text generators (I8 split)
// The full-literal assertions are the contract: users diff these files, so
// any transcription slip must fail here, not in a running ghostty.
import * as T from "./theme-sync.mjs"

let n = 0
function ok(cond, label) {
    n++
    if (!cond) { console.error("FAIL: " + label); process.exitCode = 1 }
}
function eq(got, want, label) {
    n++
    if (got !== want) {
        console.error("FAIL: " + label)
        const a = want.split("\n"), b = got.split("\n")
        for (let i = 0; i < Math.max(a.length, b.length); i++)
            if (a[i] !== b[i]) console.error(`  line ${i + 1}: want=${JSON.stringify(a[i])} got=${JSON.stringify(b[i])}`)
        process.exitCode = 1
    }
}

// 16-token fixture palette
const C = {
    background: "#000000", surface: "#0a0a0a", surfaceVariant: "#111111",
    surfaceContainer: "#161616", text: "#e0e0e0", textDim: "#808080",
    border: "#222222", outline: "#333333", outlineVariant: "#1a1a1a",
    primary: "#00dce5", secondary: "#007f85", accent: "#00b3ba",
    success: "#4caf50", warning: "#ff9800", error: "#f44336", info: "#00dce5"
}

// ── ghostty block ───────────────────────────────────────────────────────────
eq(T.ghosttyBlock(C),
   "# >>> quickshell-theme >>>\n" +
   "background = #000000\n" +
   "foreground = #e0e0e0\n" +
   "cursor-color = #00dce5\n" +
   "selection-background = #00dce5\n" +
   "selection-foreground = #000000\n" +
   "palette = 0=#000000\npalette = 1=#f44336\npalette = 2=#4caf50\n" +
   "palette = 3=#ff9800\npalette = 4=#00dce5\npalette = 5=#00b3ba\n" +
   "palette = 6=#00dce5\npalette = 7=#e0e0e0\npalette = 8=#333333\n" +
   "palette = 9=#f44336\npalette = 10=#4caf50\npalette = 11=#ff9800\n" +
   "palette = 12=#808080\npalette = 13=#007f85\npalette = 14=#00dce5\n" +
   "palette = 15=#e0e0e0\n" +
   "# <<< quickshell-theme <<<",
   "ghostty block exact")
ok(!T.ghosttyBlock(C).endsWith("\n"), "ghostty block has no trailing newline")

// ── kitty ───────────────────────────────────────────────────────────────────
eq(T.kittyConf(C),
   "background #000000\nforeground #e0e0e0\ncursor #00dce5\n" +
   "selection_background #00dce5\nselection_foreground #000000\n" +
   "color0 #000000\ncolor1 #f44336\ncolor2 #4caf50\ncolor3 #ff9800\n" +
   "color4 #00dce5\ncolor5 #007f85\ncolor6 #00dce5\ncolor7 #e0e0e0\n" +
   "color8 #808080\ncolor9 #f44336\ncolor10 #4caf50\ncolor11 #ff9800\n" +
   "color12 #00dce5\ncolor13 #007f85\ncolor14 #00dce5\ncolor15 #e0e0e0\n",
   "kitty exact")
ok(T.kittyConf(C).endsWith("\n"), "kitty trailing newline")

// ── tmux ────────────────────────────────────────────────────────────────────
const tmux = T.tmuxConf(C)
ok(tmux.startsWith("# Managed by QuickShell ThemeService — sourced at END of tmux.conf.\n"), "tmux header")
eq(tmux.split("\n")[2],
   "set -g status-style \"bg=default,fg=#e0e0e0\"", "tmux status-style")
ok(tmux.includes("set -g status-left \"#[fg=#000000,bg=#00dce5,bold] #S #[bg=default] \"\n"), "tmux status-left")
ok(tmux.includes("#{?pane_in_mode,COPY ,}#{?client_prefix,PREFIX ,}#{?window_zoomed_flag,ZOOM ,}"), "tmux status-right conditionals")
ok(tmux.includes("setw -g clock-mode-colour \"#00dce5\"\n"), "tmux clock colour")
ok(tmux.split("\n").length === 14, "tmux line count (2 comments + 11 sets + trailing)")

// ── hyprlock ────────────────────────────────────────────────────────────────
const hl = T.hyprlockConf(C)
ok(hl.includes("background {\n    color = rgba(000000ff)\n}\n"), "hyprlock bg rgba (strip # + ff)")
ok(hl.includes("inner_color = rgba(161616ff)"), "hyprlock inner = surfaceContainer")
ok(hl.includes("outer_color = rgba(007f85ff)"), "hyprlock outer = secondary")
ok(hl.includes("font_color = rgba(e0e0e0ff)"), "hyprlock font = text")
ok(hl.includes("fail_text = <i>$FAIL ($ATTEMPTS)</i>"), "hyprlock fail_text placeholders intact")

// ── nvim ────────────────────────────────────────────────────────────────────
eq(T.nvimLua(C),
   "return {\n" +
   "  base00 = \"#000000\",\n  base01 = \"#0a0a0a\",\n  base02 = \"#111111\",\n" +
   "  base03 = \"#808080\",\n  base04 = \"#808080\",\n  base05 = \"#e0e0e0\",\n" +
   "  base06 = \"#e0e0e0\",\n  base07 = \"#e0e0e0\",\n  base08 = \"#f44336\",\n" +
   "  base09 = \"#ff9800\",\n  base0A = \"#ff9800\",\n  base0B = \"#4caf50\",\n" +
   "  base0C = \"#007f85\",\n  base0D = \"#00dce5\",\n  base0E = \"#00b3ba\",\n" +
   "  base0F = \"#f44336\"\n}",
   "nvim lua exact")

// ── rofi ────────────────────────────────────────────────────────────────────
eq(T.rofiRasi(C),
   "* {\n" +
   "    bg:          #000000;\n" +
   "    surface:     #0a0a0a;\n" +
   "    surfacevar:  #111111;\n" +
   "    text:        #e0e0e0;\n" +
   "    textdim:     #808080;\n" +
   "    primary:     #00dce5;\n" +
   "    secondary:   #007f85;\n" +
   "    accent:      #00b3ba;\n" +
   "    border:      #222222;\n" +
   "    outline:     #333333;\n" +
   "    outlinealt:  #1a1a1a;\n" +
   "    success:     #4caf50;\n" +
   "    warning:     #ff9800;\n" +
   "    error:       #f44336;\n" +
   "    info:        #00dce5;\n" +
   "}",
   "rofi rasi exact (unquoted hex)")

// ── btop ────────────────────────────────────────────────────────────────────
const bt = T.btopTheme(C)
ok(bt.startsWith("# velocity.theme — generated by Quickshell ThemeService. DO NOT EDIT.\n"), "btop header")
ok(bt.includes("theme[main_bg]=\"#000000\"\n"), "btop main_bg")
ok(bt.includes("theme[selected_fg]=\"#000000\"\n"), "btop selected_fg uses local bg var")
ok(bt.includes("theme[temp_start]=\"#007f85\"\ntheme[temp_mid]=\"#ff9800\"\ntheme[temp_end]=\"#f44336\"\n"), "btop temp gradient")
ok(bt.includes("theme[download_end]=\"#00dce5\"\ntheme[upload_start]=\"#00dce5\"\n"), "btop network gradients")
ok(bt.endsWith("theme[process_end]=\"#f44336\"\n"), "btop last line + trailing newline")
ok((bt.match(/^theme\[/gm) || []).length === 48, "btop key count (line-anchored; comment mention excluded)")

// ── gtk ─────────────────────────────────────────────────────────────────────
const css = T.gtkColorsCss(C)
ok(css.startsWith("/* Managed by QuickShell ThemeService — do not edit. */\n"), "css header")
ok(css.includes("@define-color card_bg_color #161616;\n"), "css card = surfaceContainer")
ok(css.includes("@define-color accent_fg_color #000000;\n"), "css accent_fg = background")
ok(css.includes("@define-color insensitive_fg_color #808080;\n") && css.endsWith("\n"), "css last line + newline")
ok((css.match(/@define-color/g) || []).length === 27, "css define count")

// ── matugen mapping ─────────────────────────────────────────────────────────
const D = {
    background: "#000000", surface: "#050505", surfaceVariant: "#0d0d0d",
    surfaceContainer: "#101010", text: "#ffffff", textDim: "#666666",
    border: "#111111", outline: "#222222", outlineVariant: "#0e0e0e",
    primary: "#00dce5", secondary: "#00838f", accent: "#00acc1",
    success: "#2e7d32", warning: "#f57c00", error: "#c62828", info: "#00dce5"
}
const MG = { colors: {
    background:       { dark: { color: "#101010" } },
    surface:          { dark: { color: "#1a1a1a" } },
    surface_variant:  { dark: { color: "#202020" } },
    surface_container:{ dark: { color: "#262626" } },
    on_surface:       { dark: { color: "#e5e5e5" } },
    on_surface_variant: { dark: { color: "#a0a0a0" } },
    outline:          { dark: { color: "#505050" } },
    outline_variant:  { dark: { color: "#303030" } },
    primary:          { dark: { color: "#11ddee" } },
    secondary:        { dark: { color: "#223344" } },
    tertiary:         { dark: { color: "#334455" } },
    error:            { dark: { color: "#ff0000" } }
}}
const b = T.matugenSchemeToBundle(MG, D)
ok(b.background === "#101010" && b.surface === "#1a1a1a", "matugen bg/surface")
ok(b.surfaceVariant === "#202020" && b.surfaceContainer === "#262626", "matugen surface variants")
ok(b.text === "#e5e5e5" && b.textDim === "#a0a0a0", "matugen text (on_surface / on_surface_variant)")
ok(b.outline === "#505050" && b.outlineVariant === "#303030" && b.border === "#303030",
   "matugen outlines (border = outlineVariant)")
ok(b.primary === "#11ddee" && b.secondary === "#223344" && b.accent === "#334455", "matugen primaries")
ok(b.error === "#ff0000", "matugen error")
ok(b.success === "#2e7d32" && b.warning === "#f57c00", "MY has no success/warning → defaults")
ok(b.info === "#11ddee", "info follows the resolved primary")

// fallbacks
const b2 = T.matugenSchemeToBundle({ colors: {
    on_background: { dark: { color: "#f0f0f0" } },
    surface_variant: { dark: { color: "#202020" } }
}}, D)
ok(b2.text === "#f0f0f0", "text falls back to on_background")
ok(b2.surfaceContainer === "#202020", "surface_container falls back to surface_variant")
ok(b2.surface === D.surface && b2.primary === D.primary, "missing keys → defaults")
ok(T.matugenSchemeToBundle({}, D).background === D.background, "no colors block → all defaults")
ok(T.matugenSchemeToBundle(null, D).text === D.text, "null parsed → all defaults")
const b3 = T.matugenSchemeToBundle({ colors: {
    background: { dark: { color: 12345 } }   // non-string → treated absent
}}, D)
ok(b3.background === D.background, "non-string color rejected")
const b4 = T.matugenSchemeToBundle({ colors: {
    background: { light: { color: "#ffffff" } }   // only light → absent (dark required)
}}, D)
ok(b4.background === D.background, "light-only variant ignored (dark scheme contract)")

console.log(`theme-sync.test: ${n} asserts`)
