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

process.exit(failed ? 1 : 0);
