// =============================================================================
// KeyboardLogic.test.mjs — plain-node suite for KeyboardLogic.mjs
// (run via tools/run-unit-tests; pattern: settings/lib/*.test.mjs)
// Ported/adapted from Keyboard-Layout-for-Omarchy tests/tst_ServiceLogic.qml.
// =============================================================================
import * as L from "./KeyboardLogic.mjs"

let passed = 0
let failed = 0
function t(name, fn) {
  try { fn(); passed++; console.log("  ok " + name) }
  catch (e) { failed++; console.error("  FAIL " + name + ": " + (e && e.message ? e.message : e)) }
}
function eq(actual, expected, label) {
  const a = JSON.stringify(actual), b = JSON.stringify(expected)
  if (a !== b) throw new Error((label ? label + ": " : "") + "expected " + b + ", got " + a)
}
function ok(cond, label) { if (!cond) throw new Error(label || "condition false") }

// ---------------------------------------------------------------- parseLua --
t("parseLua: reader output for the real look-and-feel.lua shape", () => {
  const r = L.parseLua(JSON.stringify({
    layouts: ["us", "gr"], variants: ["", ""], options: [],
    present: { kb_layout: true, kb_options: false, kb_variant: false },
    exists: true
  }))
  ok(r.ok, r.error)
  eq(r.value.layouts, [{ layout: "us", variant: "" }, { layout: "gr", variant: "" }])
  eq(r.value.hotkey, "none")
  eq(r.value.led, false)
  eq(r.value.hasLayout, true)
  eq(r.value.hasOptions, false)
})

t("parseLua: hotkey + LED extraction from options", () => {
  const r = L.parseLua(JSON.stringify({
    layouts: ["us"], variants: [""],
    options: ["compose:ralt", "grp:caps_toggle", "grp_led:caps"],
    present: { kb_layout: true, kb_options: true, kb_variant: false }
  }))
  ok(r.ok, r.error)
  eq(r.value.hotkey, "grp:caps_toggle")
  eq(r.value.led, true)
  eq(r.value.options.length, 3)
})

t("parseLua: rejects bad JSON and bad shapes", () => {
  ok(!L.parseLua("{nope").ok, "bad json accepted")
  ok(!L.parseLua("[]").ok, "array accepted")
  ok(!L.parseLua(JSON.stringify({ layouts: ["us"], variants: [], options: [] })).ok,
    "variant/layout length mismatch accepted")
  ok(!L.parseLua(JSON.stringify({
    layouts: ["bad name!"], variants: [""], options: [],
    present: { kb_layout: true, kb_options: false, kb_variant: false }
  })).ok, "invalid layout name accepted")
})

// ----------------------------------------------------------- parseEffective --
const batchOut = (l, v, o) =>
  `{"option": "input:kb_layout", "str": "${l}", "source": "file"}\n\n` +
  `{"option": "input:kb_variant", "str": "${v}", "source": "file"}\n\n` +
  `{"option": "input:kb_options", "str": "${o}", "source": "file"}`

t("parseEffective: three-chunk batch output", () => {
  const r = L.parseEffective(batchOut("us,gr", "", "grp:caps_toggle"))
  ok(r.ok, r.error)
  eq(r.value.layouts, [{ layout: "us", variant: "" }, { layout: "gr", variant: "" }])
  eq(r.value.hotkey, "grp:caps_toggle")
  eq(r.value.variantSet, false)
})

t("parseEffective: wrong chunk count fails", () => {
  ok(!L.parseEffective('{"option":"input:kb_layout","str":"us"}').ok, "single chunk accepted")
})

// ------------------------------------------------------------- parseDevices --
const devicesJson = kb => JSON.stringify({ keyboards: kb })

t("parseDevices: filters pseudo-keyboards, event keyboard wins", () => {
  const r = L.parseDevices(devicesJson([
    { name: "power-button", active_keymap: "", active_layout_index: 0, main: false },
    { name: "atschool-intel-hid-events", active_keymap: "English (US)", active_layout_index: 1, main: true },
    { name: "keyd-keyboard", active_keymap: "Greek", active_layout_index: 1, main: false },
    { name: "sony-wireless-radio-control", active_keymap: "English (US)", active_layout_index: 0, main: false }
  ]), "keyd-keyboard")
  ok(r.ok, r.error)
  eq(r.value.keyboardName, "keyd-keyboard")
  eq(r.value.currentKeymap, "Greek")
  eq(r.value.currentIndex, 1)
  eq(r.value.keyboards.length, 1, "pseudo-keyboards leaked into typed list")
})

t("parseDevices: main fallback, then furthest-index fallback", () => {
  const kb = [
    { name: "a-keyboard", active_keymap: "English (US)", active_layout_index: 0, main: false },
    { name: "b-keyboard", active_keymap: "Greek", active_layout_index: 1, main: true }
  ]
  const byMain = L.parseDevices(devicesJson(kb), "")
  ok(byMain.ok, byMain.error)
  eq(byMain.value.keyboardName, "b-keyboard")

  const noMain = L.parseDevices(devicesJson([
    { name: "a-keyboard", active_keymap: "English (US)", active_layout_index: 0, main: false },
    { name: "b-keyboard", active_keymap: "Greek", active_layout_index: 2, main: false }
  ]), "")
  ok(noMain.ok, noMain.error)
  eq(noMain.value.keyboardName, "b-keyboard", "furthest-index fallback")
})

t("parseDevices: no keyboards at all is empty success", () => {
  const r = L.parseDevices(devicesJson([
    { name: "power-button", active_keymap: "", active_layout_index: 0, main: false }
  ]), "")
  ok(r.ok, r.error)
  eq(r.value.keyboards, [])
  eq(r.value.keyboardName, "")
})

t("parseLayoutEventData: raw socket2 payload", () => {
  eq(L.parseLayoutEventData("keyd-keyboard,Greek (polytonic)"),
    { name: "keyd-keyboard", keymap: "Greek (polytonic)" })
  eq(L.parseLayoutEventData("power-button,Greek"), null, "untyped device passed")
  eq(L.parseLayoutEventData("no-comma"), null)
  eq(L.parseLayoutEventData(""), null)
})

// -------------------------------------------------------------- switching --
t("targetIndex: next/prev wrap, absolute set, refuse trivial", () => {
  eq(L.targetIndex(0, 2, "next"), 1)
  eq(L.targetIndex(1, 2, "next"), 0)
  eq(L.targetIndex(1, 2, "prev"), 0)
  eq(L.targetIndex(0, 2, "prev"), 1)
  eq(L.targetIndex(9, 2, 1), 1)
  eq(L.targetIndex(0, 1, "next"), -1, "single layout should not switch")
  eq(L.targetIndex(0, 0, "next"), -1)
})

t("resolveSetTarget: index, layout, spec, miss", () => {
  const layouts = [{ layout: "us", variant: "" }, { layout: "gr", variant: "polytonic" }]
  eq(L.resolveSetTarget("1", layouts), 1)
  eq(L.resolveSetTarget("gr", layouts), 1)
  eq(L.resolveSetTarget("gr(polytonic)", layouts), 1)
  eq(L.resolveSetTarget("gr(bare)", layouts), -1, "wrong variant matched bare")
  eq(L.resolveSetTarget("de", layouts), -1)
  eq(L.resolveSetTarget("5", layouts), -1)
  eq(L.resolveSetTarget("us;rm -rf", layouts), -1, "injection-ish text matched")
})

t("switchBatch: absolute index for every typed, batch-safe device", () => {
  const batch = L.switchBatch([
    { name: "keyd-keyboard" },
    { name: "px;reboot" },
    { name: "power-button" },
    { name: "a b keyboard" }
  ], 1)
  eq(batch, "switchxkblayout keyd-keyboard 1", "unsafe/typed filtering wrong")
  eq(L.switchBatch([{ name: "keyd-keyboard" }], -1), "")
  eq(L.switchBatch([{ name: "keyd-keyboard" }], 1.5), "")
})

// -------------------------------------------------------------- planOptions --
t("planOptions: plain hotkey replaces old switch options, keeps the rest", () => {
  const plan = L.planOptions(["compose:ralt", "grp:alt_shift_toggle"], "grp:caps_toggle", false)
  eq(plan.options, ["compose:ralt", "grp:caps_toggle"])
  eq(plan.notes, [])
})

t("planOptions: compose on the switch key moves to Right Ctrl (free home)", () => {
  const plan = L.planOptions(["compose:caps"], "grp:caps_toggle", false)
  eq(plan.options, ["compose:rctrl", "grp:caps_toggle"])
  eq(plan.notes.length, 1)
  ok(plan.notes[0].indexOf("Right Ctrl") !== -1, "note does not name the new home")
})

t("planOptions: rctrl home taken by lv5 -> compose lands on Menu", () => {
  const plan = L.planOptions(["compose:caps", "lv5:rctrl_switch"], "grp:caps_toggle", false)
  eq(plan.options, ["compose:menu", "lv5:rctrl_switch", "grp:caps_toggle"],
    "rctrl is a used home; menu is next; hotkey appended last")
})

t("planOptions: caps takeover removed when caps is the switch key", () => {
  const plan = L.planOptions(["caps:swapescape", "lv3:caps_switch"], "grp:caps_toggle", false)
  ok(plan.options.indexOf("caps:swapescape") === -1, "caps:* survived")
  ok(plan.options.indexOf("lv3:caps_switch") === -1, "lv3 takeover survived")
  eq(plan.notes.length, 2)
})

t("planOptions: LED appended only with caps_toggle", () => {
  eq(L.planOptions([], "grp:caps_toggle", true).options, ["grp:caps_toggle", "grp_led:caps"])
  eq(L.planOptions([], "grp:alt_shift_toggle", true).options, ["grp:alt_shift_toggle"])
})

t("planOptions: custom unlisted options survive", () => {
  const plan = L.planOptions(["custom:thing"], "none", false)
  eq(plan.options, ["custom:thing"])
  eq(L.planOptions([], "none", false).options, [])
})

// ----------------------------------------------------------- writeArguments --
t("writeArguments: happy path with variants", () => {
  const r = L.writeArguments(
    [{ layout: "us", variant: "" }, { layout: "gr", variant: "polytonic" }],
    "grp:caps_toggle", true, "none", null, [], false)
  ok(r.ok, r.error)
  eq(r.value.layouts, "us,gr")
  eq(r.value.variants, ",polytonic")
  eq(r.value.options, "grp:caps_toggle,grp_led:caps")
  eq(r.value.expected, "-")
})

t("writeArguments: no variant needed -> '-', variantNeeded -> ''", () => {
  const r1 = L.writeArguments([{ layout: "us", variant: "" }], "none", false, "none", null, [], false)
  eq(r1.value.variants, "-")
  const r2 = L.writeArguments([{ layout: "us", variant: "" }], "none", false, "none", null, [], true)
  eq(r2.value.variants, "")
})

t("writeArguments: validation rejections", () => {
  ok(!L.writeArguments([], "none", false, "none", null, [], false).ok, "empty layouts ok")
  ok(!L.writeArguments(
    [{ layout: "us", variant: "" }, { layout: "us", variant: "" }],
    "none", false, "none", null, [], false).ok, "duplicate accepted")
  ok(!L.writeArguments([{ layout: "us!", variant: "" }], "none", false, "none", null, [], false).ok,
    "bad name accepted")
  ok(!L.writeArguments([{ layout: "us", variant: "" }], "grp:made_up", false, "none", null, [], false).ok,
    "unknown hotkey accepted")
  ok(L.writeArguments([{ layout: "us", variant: "" }], "grp:made_up", false, "grp:made_up", null, [], false).ok
    && L.writeArguments([{ layout: "us", variant: "" }], "grp:made_up", false, "grp:made_up", null, [], false)
      .value.options.indexOf("grp:made_up") !== -1, "custom current hotkey not kept")
  ok(!L.writeArguments(
    Array.from({ length: 5 }, (_, i) => ({ layout: "l" + i, variant: "" })),
    "none", false, "none", null, [], false).ok, "5 layouts accepted")
})

// ------------------------------------------------------------------- config --
t("parseConfig/configText round-trip + rejection", () => {
  const r = L.parseConfig(L.configText({ osd: true, highlight: false }))
  ok(r.ok, r.error)
  eq(r.value, { osd: true, highlight: false })
  ok(!L.parseConfig("{").ok)
  ok(!L.parseConfig(JSON.stringify({ osd: "yes" })).ok, "wrong type accepted")
  ok(L.parseConfig("{}").ok, "empty prefs should be fine")
  eq(L.parseConfig("{}").value, { osd: false, highlight: false })
})

// ------------------------------------------------------------------ backups --
t("isBackupId: look-and-feel.lua rotating ids only", () => {
  ok(L.isBackupId("look-and-feel.lua.20261018-093813"))
  ok(L.isBackupId("look-and-feel.lua.20261018-093813-2"))
  ok(!L.isBackupId("input.lua.20261018-093813"), "upstream prefix accepted")
  ok(!L.isBackupId("input.lua.bak.123"), "legacy originals accepted")
  ok(!L.isBackupId("../secrets"), "traversal accepted")
  ok(!L.isBackupId(42), "non-string accepted")
})

t("parseBackups: rows validated, order preserved", () => {
  const r = L.parseBackups(JSON.stringify([
    { id: "look-and-feel.lua.20261018-093813", kind: "rotating", time: 1792330693,
      size: 4013, layouts: "us,gr", valid: true }
  ]))
  ok(r.ok, r.error)
  eq(r.value.length, 1)
  eq(r.value[0].layouts, "us,gr")
  ok(!L.parseBackups(JSON.stringify([
    { id: "evil", kind: "rotating", time: 1, size: 1, layouts: "", valid: true }
  ])).ok, "bad id accepted")
})

// -------------------------------------------------------------- risk gates --
t("password/bindings risk + confirm-on-new-risk", () => {
  eq(L.mainLayoutRisksPasswords([{ layout: "us", variant: "" }]), false)
  eq(L.mainLayoutRisksPasswords([{ layout: "gr", variant: "polytonic" }]), true)
  eq(L.mainLayoutBreaksBindings([{ layout: "gr", variant: "" }]), true)
  eq(L.mainLayoutBreaksBindings([{ layout: "us", variant: "" }]), false)
  // same main spec -> no NEW risk, no confirm (spec compare: gr->gr(polytonic)
  // DOES re-confirm, faithful to upstream)
  eq(L.needsPasswordConfirm([{ layout: "gr", variant: "" }], [{ layout: "gr", variant: "" }]), false)
  // us -> gr IS a new risk
  eq(L.needsPasswordConfirm([{ layout: "us", variant: "" }], [{ layout: "gr", variant: "" }]), true)
})

// ------------------------------------------------------------------ search --
t("search helpers: printable-only append, astral-safe backspace", () => {
  eq(L.searchTyped("", "gr", 64), "gr")
  eq(L.searchTyped("gr", "\t", 64), "gr", "control char typed")
  eq(L.searchTyped("gr", "é", 64), "gré")
  eq(L.searchTyped("x".repeat(64), "y", 64), "x".repeat(64), "over-limit typed")
  eq(L.searchBackspace("gré"), "gr")
  const astral = "𝛑x"
  eq(L.searchBackspace(astral), "𝛑", "split a surrogate pair")
  eq(L.searchBackspace(""), "")
})

// ------------------------------------------------------- parseCatalogEvdev --
const EVDEV_FIXTURE = `<?xml version="1.0" encoding="UTF-8"?>
<xkbConfigRegistry version="1.1">
  <modelList>
    <model><configItem><name>pc105</name><description>Generic 105-key PC</description></configItem></model>
  </modelList>
  <layoutList>
    <layout>
      <configItem>
        <name>gr</name>
        <!-- Keyboard indicator for Greek layouts -->
        <shortDescription>gr</shortDescription>
        <description>Greek</description>
      </configItem>
      <variantList>
        <variant>
          <configItem>
            <name>simple</name>
            <description>Greek (simple)</description>
          </configItem>
        </variant>
        <variant>
          <configItem>
            <name>polytonic</name>
            <shortDescription>gr</shortDescription>
            <description>Greek (polytonic)</description>
          </configItem>
        </variant>
      </variantList>
    </layout>
    <layout>
      <configItem>
        <name>us</name>
        <shortDescription>en</shortDescription>
        <description>English (US)</description>
      </configItem>
      <variantList>
        <variant>
          <configItem>
            <name>colemak</name>
            <description>English (US, Colemak)</description>
          </configItem>
        </variant>
      </variantList>
    </layout>
  </layoutList>
</xkbConfigRegistry>
`

t("parseCatalogEvdev: entries, briefs, variant brief fallback", () => {
  const r = L.parseCatalogEvdev(EVDEV_FIXTURE)
  ok(r.ok, r.error)
  const e = r.value.entries
  eq(e.length, 5, "gr + simple + polytonic + us + colemak")
  ok(e.some(x => x.layout === "gr" && x.variant === "polytonic"
    && x.description === "Greek (polytonic)" && x.brief === "gr"))
  ok(e.some(x => x.layout === "gr" && x.variant === "simple" && x.brief === "gr"),
    "variant without shortDescription should inherit layout brief")
  eq(r.value.briefs["$Greek"], "gr")
  eq(r.value.briefs["$Greek (simple)"], "gr")
  // sorted by description
  const descs = e.map(x => x.description)
  eq(descs, [...descs].sort())
})

t("parseCatalogEvdev: entity unescape + models ignored", () => {
  const r = L.parseCatalogEvdev(EVDEV_FIXTURE.replace(
    "<description>English (US)</description>",
    "<description>English &amp; US &lt;latin&gt;</description>"))
  ok(r.ok, r.error)
  ok(r.value.entries.some(x => x.description === "English & US <latin>"), "entity unescape")
  ok(!r.value.entries.some(x => x.layout === "pc105"), "modelList leaked in")
})

t("parseCatalogEvdev: empty input fails", () => {
  ok(!L.parseCatalogEvdev("<xkbConfigRegistry></xkbConfigRegistry>").ok, "empty accepted")
})

// ------------------------------------------------------- real evdev.xml smoke --
import { readFileSync } from "node:fs"
import { execSync } from "node:child_process"

t("parseCatalogEvdev: real xkeyboard-config evdev.xml from the store", () => {
  let xmlPath = ""
  try {
    xmlPath = execSync(
      "ls -t /nix/store/*xkeyboard-config*/share/X11/xkb/rules/evdev.xml 2>/dev/null | head -1",
      { encoding: "utf8" }).trim()
  } catch (e) { /* none */ }
  if (xmlPath === "") { console.log("    (skipped — no evdev.xml in store)"); return }
  const src = readFileSync(xmlPath, "utf8")
  const r = L.parseCatalogEvdev(src)
  ok(r.ok, r.error)
  ok(r.value.entries.length > 500, "suspiciously few entries: " + r.value.entries.length)
  const greek = r.value.entries.find(x => x.description === "Greek (polytonic)")
  ok(greek && greek.layout === "gr" && greek.variant === "polytonic", "polytonic missing")
})

console.log(`\n${passed} passed, ${failed} failed`)
process.exit(failed === 0 ? 0 : 1)
