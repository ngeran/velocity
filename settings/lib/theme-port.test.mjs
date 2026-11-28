// theme-port.test.mjs — node checks for shared/theme-port.mjs (P5.5).
// Run: tools/run-unit-tests (auto-discovered). Plain asserts, no framework.
import * as Port from "./theme-port.mjs";

let failed = 0;
function ok(cond, name) {
    if (cond) { console.log("  ok", name); }
    else { console.error("  FAIL", name); failed++; }
}

const BUNDLE = {
    background: "#000000", surface: "#000000", surfaceVariant: "#0A0A0A",
    surfaceContainer: "#111111", text: "#E0E0E0", textDim: "#808080",
    border: "#1A1A1A", outline: "#2A2A2A", outlineVariant: "#1A1A1A",
    primary: "#7C6BF0", secondary: "#00DCE5", accent: "#F87171",
    success: "#34D399", warning: "#FBBF24", error: "#F87171", info: "#00DCE5"
};

// ── JSON export/import ──────────────────────────────────────────────────────
var json = Port.exportJson("My Theme", BUNDLE);
var pj = Port.parseJson(json);
ok(pj.ok && pj.name === "My Theme", "JSON roundtrip: name");
ok(pj.ok && Object.keys(pj.colors).length === 16, "JSON roundtrip: 16 tokens");
ok(pj.ok && pj.colors.primary === "#7C6BF0" && pj.colors.text === "#E0E0E0", "JSON roundtrip: values");
// colors.json payload shape (colors + metadata halves)
var pj2 = Port.parseJson(JSON.stringify({ colors: BUNDLE, metadata: { name: "x" } }));
ok(pj2.ok && pj2.colors.background === "#000000", "JSON: colors.json payload accepted");
// rejections
ok(!Port.parseJson("{nope").ok, "JSON: garbage rejected");
ok(!Port.parseJson('{"colors":{"text":"red"}}').ok, "JSON: non-hex value rejected");
ok(!Port.parseJson('{"colors":{}}').ok, "JSON: zero tokens rejected");

// ── base16 YAML export/import ───────────────────────────────────────────────
var yaml = Port.exportBase16Yaml("Yaml Theme", BUNDLE);
ok(yaml.indexOf("scheme: \"Yaml Theme\"") === 0, "YAML: scheme line first");
ok((yaml.match(/base[0-9A-F]{2}:/g) || []).length === 16, "YAML: 16 base entries");
var py = Port.parseBase16Yaml(yaml);
ok(py.ok && py.name === "Yaml Theme", "YAML roundtrip: name");
ok(py.ok && Object.keys(py.colors).length === 16, "YAML roundtrip: 16 tokens");
ok(py.ok && py.colors.primary === "#7C6BF0" && py.colors.background === "#000000",
   "YAML roundtrip: base0D→primary, base00→background");
// unquoted values + comments + author + blanks (upstream-file realism)
var py2 = Port.parseBase16Yaml("# a comment\nscheme: Upstream\nauthor: someone\nbase00: #101010\nbase05: \"#eeeeee\"\n\nbase0D: '#7c6bf0'\n");
ok(py2.ok && py2.name === "Upstream" && py2.colors.background === "#101010"
   && py2.colors.text === "#EEEEEE" && py2.colors.primary === "#7C6BF0",
   "YAML: bare hex, quoted hex, comments, author skipped");
ok(!Port.parseBase16Yaml("scheme: x\nbase00: nothex\n").ok, "YAML: bad hex rejected");
ok(!Port.parseBase16Yaml("just some prose\n").ok, "YAML: no tokens rejected");

// ── validation ──────────────────────────────────────────────────────────────
var partial = Port.validateBundle({ text: "#ffffff", junk: "#123456" });
ok(partial.ok && Object.keys(partial.colors).length === 1 && partial.colors.text === "#FFFFFF",
   "validate: partial bundle keeps known tokens, skips unknown");
var mixed = Port.validateBundle({ text: "#ffffff", textDim: "123456" });
ok(mixed.ok && mixed.invalid.indexOf("textDim") >= 0 && mixed.colors.text === "#FFFFFF",
   "validate: bad-# key flagged, good key kept");
ok(Port.validateBundle(null).ok === false, "validate: null rejected");
ok(Port.validateBundle({ name: "only" }).ok === false, "validate: no colors rejected");

// ── auto-detect ─────────────────────────────────────────────────────────────
ok(Port.parseAny(json).ok && Port.parseAny(yaml).ok, "parseAny: both formats");
ok(Port.parseAny(yaml).name === "Yaml Theme", "parseAny: YAML name survives");

// ── lowercase input normalizes to uppercase ─────────────────────────────────
var low = Port.parseJson('{"name":"l","colors":{"text":"#abcd12"}}');
ok(low.ok && low.colors.text === "#ABCD12", "JSON: lowercase hex normalized");

// ── Omarchy colors.toml ─────────────────────────────────────────────────────
// The user's own theme: quoted hex, inline # comments after values, and
// unmapped keys (selection, bright_*, hyprland_*_border). Every mapping
// source key is exercised.
var AURA = [
    '# Aura Dark for Omarchy, from the official palette by Dalton Menezes',
    'mode = "dark"',
    '',
    'accent = "#a277ff"             # violet, Aura\'s signature colour',
    'selection = "#29263c"          # unmapped',
    'muted = "#525156"              # inactive elements',
    '',
    'background = "#15141b"',
    'dark_background = "#110f18"',
    'darker_background = "#0f0f0f"',
    'lighter_background = "#2d2b38"',
    '',
    'foreground = "#edecee"',
    'dark_foreground = "#6d6d6d"    # comment colour',
    'light_foreground = "#cdccce"',
    'bright_foreground = "#edecee"',
    '',
    'red = "#ff6767"',
    'yellow = "#ffca85"',
    'orange = "#ffca85"',
    'green = "#61ffca"              # mint',
    'cyan = "#82e2ff"',
    'blue = "#a277ff"',
    'magenta = "#f694ff"            # pink',
    'brown = "#a19c77"',
    '',
    'bright_magenta = "#f694ff"',
    'hyprland_active_border = "rgba(26a269ee) rgba(2ec27eee) 45deg"',   // upstream hackerman
    'hyprland_inactive_border = "#2d2b38"',
    ''
].join("\n");
var po = Port.parseOmarchyToml(AURA, "aura-dark");
ok(po.ok && po.name === "aura-dark", "Omarchy: named by the caller (the folder)");
ok(po.ok && Object.keys(po.colors).length === 16, "Omarchy: all 16 tokens mapped");
ok(po.ok && po.colors.background === "#0F0F0F" && po.colors.surface === "#110F18"
   && po.colors.surfaceVariant === "#15141B" && po.colors.surfaceContainer === "#2D2B38",
   "Omarchy: background ladder -> background..surfaceContainer, in order");
ok(po.ok && po.colors.text === "#EDECEE" && po.colors.textDim === "#6D6D6D",
   "Omarchy: foreground -> text, dark_foreground -> textDim");
ok(po.ok && po.colors.outline === "#6D6D6D" && po.colors.border === "#6D6D6D"
   && po.colors.outlineVariant === "#6D6D6D",
   "Omarchy: dark_foreground -> border + outline + outlineVariant");
ok(po.ok && po.colors.primary === "#A277FF" && po.colors.secondary === "#82E2FF"
   && po.colors.info === "#82E2FF" && po.colors.accent === "#FF6767"
   && po.colors.error === "#FF6767" && po.colors.success === "#61FFCA"
   && po.colors.warning === "#FFCA85",
   "Omarchy: accents, paired like the default seed");
ok(po.ok && po.invalid.length === 0, "Omarchy: unmapped + non-hex keys skipped, not reported bad");
ok(po.ok && po.colors.selection === undefined && po.colors.bright_foreground === undefined,
   "Omarchy: unmapped keys never reach the bundle");
// dark only, by the file's own mode line
var light = Port.parseOmarchyToml(AURA.replace('mode = "dark"', 'mode = "light"'));
ok(!light.ok && /mode = "light"/.test(light.error), "Omarchy: light theme rejected, names the mode");
var noMode = Port.parseOmarchyToml(AURA.replace('mode = "dark"\n', ""));
ok(!noMode.ok && /no mode line/.test(noMode.error), "Omarchy: missing mode line rejected");
var badFirst = Port.parseOmarchyToml('mode = "light"\nforeground = "oops"\n');
ok(!badFirst.ok && /no valid color tokens/.test(badFirst.error),
   "Omarchy: bad tokens reported before the mode check");
ok(!Port.parseOmarchyToml('mode = "dark"\nfoo = "#123456"\n').ok, "Omarchy: no mapped keys rejected");
var oneBad = Port.parseOmarchyToml('mode = "dark"\nforeground = "#edecee"\naccent = "zzz"\nred = "#ff6767"\n');
ok(oneBad.ok && oneBad.invalid.length === 1 && oneBad.invalid[0] === "primary"
   && oneBad.colors.primary === undefined && oneBad.colors.accent === "#FF6767",
   "Omarchy: a mapped key with bad hex is reported, the rest import");
ok(Port.parseOmarchyToml('mode = "dark"\r\nforeground = "#edecee"\r\n').ok,
   "Omarchy: CRLF line endings accepted");
ok(/mode = ""/.test(Port.parseOmarchyToml('mode =\nforeground = "#edecee"\n').error)
   && /mode = ""/.test(Port.parseOmarchyToml('mode = ""\nforeground = "#edecee"\n').error),
   "Omarchy: an empty mode line is reported as seen, not as missing");
// bare (unquoted) values + auto-detect
var bare = Port.parseAny('background = #0a1220\nmode = dark\n', "bare");
ok(bare.ok && bare.name === "bare" && bare.colors.surfaceVariant === "#0A1220",
   "Omarchy: bare hex + bare mode accepted");
ok(Port.parseAny(AURA, "aura-dark").ok && Port.parseAny(AURA).name === "imported",
   "parseAny: Omarchy TOML detected (comment-first); clipboard falls back to \"imported\"");
ok(Port.parseAny(json).name === "My Theme" && Port.parseAny(yaml, "ignored").name === "Yaml Theme"
   && Port.parseAny('scheme: x = y\nbase00: "#101010"\n').colors.background === "#101010",
   "parseAny: JSON + base16 keep their own path and names");
// name = the theme's folder
ok(Port.themeFolderName("/home/u/.config/omarchy/themes/tokyo-night/colors.toml") === "tokyo-night"
   && Port.themeFolderName("themes/aura-dark/colors.toml") === "aura-dark",
   "themeFolderName: the file's parent folder");
ok(Port.themeFolderName("colors.toml") === "" && Port.themeFolderName("./colors.toml") === ""
   && Port.themeFolderName("/x/../colors.toml") === ""
   && Port.themeFolderName("") === "" && Port.themeFolderName(null) === "",
   "themeFolderName: no usable folder -> \"\"");
// the themes folder, read in one process: a `>>> <path>` header, then the file
var M = Port.OMARCHY_SCAN_MARK;
var stream = [M + "/t/zeta/colors.toml", AURA, "", M + "/t/muted/colors.toml",
   'mode = "dark"\nforeground = "#f0f2f5"\n', "", M + "/t/latte/colors.toml",
   AURA.replace('mode = "dark"', 'mode = "light"'), "", M + "/t/broken/colors.toml",
   "not a theme\n", ""].join("\n");
var scan = Port.parseOmarchyScan(stream);
ok(scan.themes.length === 2 && scan.light === 1 && scan.invalid === 1,
   "Omarchy scan: dark themes listed, light and unreadable counted");
ok(scan.themes[0].name === "muted" && scan.themes[1].name === "zeta",
   "Omarchy scan: sorted by folder name");
ok(scan.themes[1].path === "/t/zeta/colors.toml" && scan.themes[1].colors.accent === "#FF6767",
   "Omarchy scan: a card gets the path to import and the mapped colours");
ok(Port.parseOmarchyScan("").themes.length === 0 && Port.parseOmarchyScan("noise\n").invalid === 0,
   "Omarchy scan: no stream, or text before any header, is not a theme");

// A header is the mark AND the theme file's name: file text starting with the
// mark must not split its own file, whatever follows it.
var forged = [M + "/t/forged/colors.toml", 'mode = "dark"', '>>> stray = "#111111"',
    'foreground = "#123456"', ""].join("\n");
var kept = Port.parseOmarchyScan(forged);
ok(kept.themes.length === 1 && kept.themes[0].name === "forged"
    && kept.themes[0].colors.text === "#123456" && kept.invalid === 0,
    "Omarchy scan: a line of file text does not open a file");
ok(Port.parseOmarchyScan([M + "/t/notes.txt", AURA, ""].join("\n")).themes.length === 0,
    "Omarchy scan: a header must end in the theme file's name");
ok(Port.parseOmarchyToml(AURA.replace('mode = "dark"', 'mode = "light"'), "x").light === true,
    "Omarchy scan: a non-dark theme is flagged, not only worded");

// ── Omarchy export (the import's reverse) ───────────────────────────────────
// The eleven tokens the import reads come back unchanged; the rest of the file
// is derived, and its comment says so.
var STORED = ["background", "surface", "surfaceVariant", "surfaceContainer", "text",
              "textDim", "primary", "secondary", "accent", "success", "warning"]
var toml = Port.exportToml("aura", BUNDLE)
var back = Port.parseOmarchyToml(toml, "x")
ok(back.ok && STORED.every(function(k) { return back.colors[k] === BUNDLE[k].toUpperCase() }),
    "exportToml: the eleven tokens the import reads round-trip")
ok(/^mode = "dark"$/m.test(toml), "exportToml: declares a dark theme")
function tomlValue(text, key) {
    var m = text.match(new RegExp("^" + key + ' = "(.*)"$', "m"))
    return m ? m[1] : null
}
ok(tomlValue(toml, "selection") === BUNDLE.surfaceContainer.toUpperCase()
        && tomlValue(toml, "bright_red") === tomlValue(toml, "red")
        && tomlValue(toml, "bright_magenta") === tomlValue(toml, "magenta"),
    "exportToml: derived keys follow their rule")
ok(/^darker_background = "#0A0B0C"$/m.test(Port.exportToml("x", { background: "#0a0b0c" })),
    "exportToml: lower-case hex is written upper-case")
ok(/^background = "#000000"$/m.test(Port.exportToml("x", {})), "exportToml: a missing token is written as black")
ok(Port.parseAny(toml, "folder").name === "folder", "exportToml: parseAny reads the export as an Omarchy theme")

process.exit(failed ? 1 : 0);
