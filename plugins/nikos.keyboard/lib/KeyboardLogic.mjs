// =============================================================================
// KeyboardLogic.mjs — pure logic for nikos.keyboard (node-testable)
// =============================================================================
// Port of Keyboard-Layout-for-Omarchy's ServiceLogic.js (MIT), adapted:
//   - prefs are {osd, highlight} (no placement/asked — plugin-manager order
//     and the fixed pill placement replace them)
//   - backup ids are look-and-feel.lua.* (no legacy input.lua.bak originals)
//   - the layout catalog is parsed from xkeyboard-config's evdev.xml (xkbcli
//     is not in this system's closure)
//   - activelayout events arrive as raw socket2 data ("name,keymap") from the
//     bar's single HyprlandService stream, not an OmarchyEvent parse
// QML side imports this by relative path; tests run under plain node.
// =============================================================================

export const INPUT_MAX_BYTES = 262144
export const CONFIG_MAX_BYTES = 16384
export const DEVICES_MAX_BYTES = 262144
export const XKB_MAX_BYTES = 524288
export const EFFECTIVE_MAX_BYTES = 16384
export const BACKUPS_MAX_BYTES = 65536

// xkb holds at most four groups, so that is what the plugin writes. A file
// written by hand may list more; those are read (and shown) but only the
// first four ever take effect.
export const MAX_LAYOUTS = 4
export const MAX_READ_LAYOUTS = 32
export const MAX_LAYOUT_NAME_CHARS = 64
export const MAX_OPTIONS = 32
export const MAX_OPTION_CHARS = 128
export const MAX_DEVICE_ROWS = 128
export const MAX_DEVICE_NAME_CHARS = 256
export const MAX_KEYMAP_NAME_CHARS = 256
export const MAX_LAYOUT_INDEX = 4096
export const MAX_KEYMAP_ROWS = 4096
export const MAX_BRIEF_CHARS = 64
export const MAX_DESCRIPTION_CHARS = 256
export const MAX_BACKUP_ROWS = 64

// These devices carry the seat layout and answer switchxkblayout, but are not
// keyboards a user types on: virtual keyboards, power/sleep buttons, and the
// hotkey/media pseudo-keyboards laptops and receivers expose. Device
// capability bits cannot tell these apart from real keyboards, so names are
// the practical signal.
export const untypedKeyboard = /^(hl-virtual-keyboard|power-button|sleep-button|lid-switch|video-bus)|-(hid-events|extra-buttons|consumer-control|system-control|wireless-radio-control)(-[0-9]+)?$/
const controls = /[\u0000-\u001f\u007f]/
export const layoutName = /^[A-Za-z0-9_+-]{1,64}$/
export const variantName = /^[A-Za-z0-9_+-]{0,64}$/
export const optionName = /^[A-Za-z0-9_+.-]+:[A-Za-z0-9_+.-]+$/
export const groupOption = /^grp:[a-z0-9_]{1,48}$/
// Names that go into a `hyprctl --batch` string, where `;` separates commands
// and whitespace separates arguments. Anything else is never switched.
export const batchSafeName = /^[A-Za-z0-9_.:-]{1,256}$/
export const rotatingBackupId = /^look-and-feel\.lua\.[0-9]{8}-[0-9]{6}(?:-[0-9]{1,2})?$/

// Switch-key choices, as xkb option names. Every Super/Win and *_space_*
// variant is left out on purpose: this setup binds Super+Space (and the bar's
// keybinds overlay documents it).
// "none" writes no grp: option at all, for switching through a Hyprland
// binding to `qs -c bar ipc call keyboard next` instead.
export const HOTKEYS = [
  { value: "grp:caps_toggle", label: "Caps Lock" },
  { value: "grp:shift_caps_toggle", label: "Shift+Caps Lock" },
  { value: "grp:alt_caps_toggle", label: "Alt+Caps Lock" },
  { value: "grp:alt_shift_toggle", label: "Alt+Shift" },
  { value: "grp:lalt_lshift_toggle", label: "Left Alt+Left Shift" },
  { value: "grp:ctrl_shift_toggle", label: "Ctrl+Shift" },
  { value: "grp:lctrl_lshift_toggle", label: "Left Ctrl+Left Shift" },
  { value: "grp:ctrl_alt_toggle", label: "Ctrl+Alt" },
  { value: "grp:shifts_toggle", label: "Both Shifts together" },
  { value: "grp:alts_toggle", label: "Both Alts together" },
  { value: "grp:menu_toggle", label: "Menu key" },
  { value: "grp:rctrl_toggle", label: "Right Ctrl" },
  { value: "grp:toggle", label: "Right Alt" },
  { value: "grp:rshift_toggle", label: "Right Shift" },
  { value: "grp:sclk_toggle", label: "Scroll Lock" },
  { value: "none", label: "None (keybinding / bar only)" }
]
export const LED_HOTKEY = "grp:caps_toggle"
export const LED_OPTION = "grp_led:caps"

export function success(value) {
  return { ok: true, value: value, error: "" }
}

export function failure(message) {
  return { ok: false, value: null, error: message }
}

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function isBoundedText(value, maxChars, allowEmpty) {
  return typeof value === "string"
    && value.length <= maxChars
    && (allowEmpty || value.length > 0)
    && !controls.test(value)
}

function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key)
}

// ----------------------------------------------------------------- config --

// Validates the JSON printed by the writer and shapes it for the UI. The
// prefs file holds only display toggles; anything else rejects the whole
// file (a rejected file never replaces the last good state).
export function parseConfig(text) {
  var parsed
  try { parsed = JSON.parse(String(text)) }
  catch (error) { return failure("config.json is not valid JSON") }

  if (!isRecord(parsed)) return failure("config.json must contain an object")
  if (parsed.osd !== undefined && typeof parsed.osd !== "boolean")
    return failure("config.json osd must be a boolean")
  if (parsed.highlight !== undefined && typeof parsed.highlight !== "boolean")
    return failure("config.json highlight must be a boolean")

  return success({
    osd: parsed.osd === true,
    highlight: parsed.highlight === true
  })
}

export function configText(state) {
  return JSON.stringify({
    osd: state.osd === true,
    highlight: state.highlight === true
  }) + "\n"
}

// ------------------------------------------------------------ config file --

function isStringArray(value, maxItems) {
  if (!Array.isArray(value) || value.length > maxItems) return false
  for (var i = 0; i < value.length; i++)
    if (typeof value[i] !== "string") return false
  return true
}

// Validates the JSON printed by `InputLua.pl read` and shapes it for the UI.
export function parseLua(text) {
  var parsed
  try { parsed = JSON.parse(String(text)) }
  catch (error) { return failure("config reader returned invalid JSON") }

  if (!isRecord(parsed)) return failure("config reader returned an invalid shape")
  if (!isStringArray(parsed.layouts, MAX_READ_LAYOUTS)
      || !isStringArray(parsed.variants, MAX_READ_LAYOUTS)
      || !isStringArray(parsed.options, MAX_OPTIONS)
      || parsed.variants.length !== parsed.layouts.length)
    return failure("config reader returned an invalid shape")

  var layouts = []
  for (var i = 0; i < parsed.layouts.length; i++) {
    if (!layoutName.test(parsed.layouts[i]) || !variantName.test(parsed.variants[i]))
      return failure("look-and-feel.lua contains an invalid layout or variant name")
    layouts.push({ layout: parsed.layouts[i], variant: parsed.variants[i] })
  }

  var hotkey = "none"
  var led = false
  for (var j = 0; j < parsed.options.length; j++) {
    var option = parsed.options[j]
    if (option.length > MAX_OPTION_CHARS || !optionName.test(option))
      return failure("look-and-feel.lua contains an invalid kb_options entry")
    if (option === LED_OPTION) led = true
    else if (hotkey === "none" && groupOption.test(option)) hotkey = option
  }

  var present = isRecord(parsed.present) ? parsed.present : {}
  return success({
    layouts: layouts,
    options: parsed.options.slice(),
    hotkey: hotkey,
    led: led,
    hasLayout: present.kb_layout === true,
    hasVariant: present.kb_variant === true,
    hasOptions: present.kb_options === true
  })
}

export function layoutSpec(entry) {
  if (!entry) return ""
  return entry.variant ? entry.layout + "(" + entry.variant + ")" : entry.layout
}

export function parseLayoutSpec(spec) {
  var match = String(spec).match(/^([A-Za-z0-9_+-]{1,64})(?:\(([A-Za-z0-9_+-]{1,64})\))?$/)
  if (!match) return null
  return { layout: match[1], variant: match[2] || "" }
}

// Password prompts that start on the first layout (hyprlock, a fresh
// session, apps that reset the layout) type whatever that layout produces.
// Anything other than plain English (US) there risks a password typed with
// the wrong characters, so the panel warns and asks before applying it.
export const PASSWORD_SAFE_MAIN = "us"

// Hyprland resolves keybindings against the first layout, so with one of
// these first, SUPER shortcuts stop firing.
export const NON_LATIN_LAYOUTS = " af am ara bd bg by et ge gr il in iq ir kg kh kz la lk mk mm mn mv np rs ru sy th tj ua "

export function mainLayoutBreaksBindings(layouts) {
  if (!Array.isArray(layouts) || layouts.length === 0 || !layouts[0]) return false
  return NON_LATIN_LAYOUTS.indexOf(" " + layouts[0].layout + " ") !== -1
}

export function mainLayoutRisksPasswords(layouts) {
  if (!Array.isArray(layouts) || layouts.length === 0) return false
  return layoutSpec(layouts[0]) !== PASSWORD_SAFE_MAIN
}

// True when applying DRAFT would newly put a password-risky layout first.
export function needsPasswordConfirm(current, draft) {
  if (!mainLayoutRisksPasswords(draft)) return false
  var before = Array.isArray(current) && current.length > 0 ? layoutSpec(current[0]) : ""
  return before !== layoutSpec(draft[0])
}

export function isKnownHotkey(value) {
  for (var i = 0; i < HOTKEYS.length; i++)
    if (HOTKEYS[i].value === value) return true
  return false
}

export function hotkeyLabel(value) {
  for (var i = 0; i < HOTKEYS.length; i++)
    if (HOTKEYS[i].value === value) return HOTKEYS[i].label
  return "Custom (" + value + ")"
}

// The physical key a single-key switch occupies. Compose, or a caps:* remap,
// on that same key cannot also work, so the planner moves or drops it.
export const SWITCH_KEYS = {
  "grp:caps_toggle": "caps",
  "grp:shift_caps_toggle": "caps",
  "grp:alt_caps_toggle": "caps",
  "grp:caps_switch": "caps",
  "grp:shift_caps_switch": "caps",
  "grp:toggle": "ralt",
  "grp:menu_toggle": "menu",
  "grp:rctrl_toggle": "rctrl",
  "grp:sclk_toggle": "sclk"
}
// Options that put Compose on Caps Lock.
export const CAPS_COMPOSE = {
  "compose:caps": "Caps Lock",
  "compose:caps-altgr": "AltGr+Caps Lock",
  "omarchy:shift_caps_compose": "Shift+Caps Lock"
}
// Options that take Caps Lock over and silence a Caps switch key.
export const CAPS_TAKEOVERS = ["lv3:caps_switch", "lv3:caps_switch_latch",
  "lv3:caps_switch_capslock_with_ctrl", "lv5:caps_switch"]
// Where Compose goes when its key becomes the switch key. Right Ctrl and Menu
// type Compose on every layout; Right Alt does so only on layout 1, because
// layouts such as gr and de keep it as their AltGr.
export const COMPOSE_HOMES = ["rctrl", "menu", "ralt"]
// Options that already use a home key, so Compose there would not work.
export const HOME_USERS = {
  rctrl: ["ctrl:rctrl_ralt", "ctrl:swap_ralt_rctl", "ctrl:swap_rwin_rctl",
    "korean:rctrl_hangul", "korean:rctrl_hanja", "lv3:switch", "lv5:rctrl_switch"],
  menu: ["ctrl:menu_rctrl", "lv3:menu_switch", "lv5:menu_switch"],
  ralt: ["ctrl:ralt_rctrl", "ctrl:swap_ralt_rctl", "korean:ralt_hangul", "korean:ralt_hanja",
    "lv3:alt_switch", "lv3:ralt_switch", "lv3:ralt_switch_multikey", "lv5:ralt_switch",
    "lv5:ralt_switch_lock"]
}
export const KEY_NAMES = { caps: "Caps Lock", ralt: "Right Alt", menu: "Menu", rctrl: "Right Ctrl", sclk: "Scroll Lock" }

export function keyName(key) {
  return hasOwn(KEY_NAMES, key) ? KEY_NAMES[key] : key
}

// The key a Compose option puts Compose on, or "" for any other option.
export function composeKey(option) {
  if (hasOwn(CAPS_COMPOSE, option)) return "caps"
  var match = option.match(/^compose:(.+)$/)
  return match ? match[1] : ""
}

export function composeLabel(option) {
  return hasOwn(CAPS_COMPOSE, option) ? CAPS_COMPOSE[option] : keyName(composeKey(option))
}

// Plans the complete kb_options Apply will write. BASE is look-and-feel.lua's
// live kb_options when the key is present there, otherwise the options
// Hyprland currently has in effect, so Compose-on-Caps and friends survive
// the first Apply. Switch options are replaced by HOTKEY (+ the Caps LED).
// A Compose on the switch key moves once to a free home, or goes when another
// Compose stays; options that take the switch key over go. Every change gets
// a note.
export function planOptions(base, hotkey, led) {
  var options = base || []
  var kept = []
  var notes = []
  var seen = {}
  var switchKey = hasOwn(SWITCH_KEYS, hotkey) ? SWITCH_KEYS[hotkey] : ""

  function push(option) {
    if (hasOwn(seen, "$" + option)) return
    seen["$" + option] = true
    kept.push(option)
  }

  function conflicts(option) {
    return switchKey !== "" && composeKey(option) === switchKey
  }

  function takesOver(option) {
    return switchKey === "caps" && (/^caps:/.test(option) || CAPS_TAKEOVERS.indexOf(option) !== -1)
  }

  var survivor = ""
  var composeHomes = {}
  for (var s = 0; s < options.length; s++) {
    var key = composeKey(options[s])
    if (key === "") continue
    composeHomes["$" + key] = true
    if (survivor === "" && !conflicts(options[s])) survivor = options[s]
  }

  function free(home) {
    if (home === switchKey || hasOwn(composeHomes, "$" + home)) return false
    for (var u = 0; u < options.length; u++)
      if (HOME_USERS[home].indexOf(options[u]) !== -1 && !takesOver(options[u])) return false
    return true
  }

  var moved = ""
  var handled = {}
  for (var i = 0; i < options.length; i++) {
    var option = options[i]
    if (/^grp(_led)?:/.test(option)) continue
    if (hasOwn(handled, "$" + option)) continue
    if (takesOver(option)) {
      handled["$" + option] = true
      notes.push(option + " is removed: Caps Lock is now the switch key.")
      continue
    }
    if (!conflicts(option)) {
      push(option)
      continue
    }
    handled["$" + option] = true
    if (survivor !== "") {
      notes.push(option + " is removed: " + keyName(switchKey)
        + " is now the switch key, and Compose stays on " + composeLabel(survivor) + ".")
      continue
    }
    if (moved !== "") {
      notes.push(option + " is removed: Compose is now on " + keyName(moved) + ".")
      continue
    }
    for (var h = 0; h < COMPOSE_HOMES.length && moved === ""; h++)
      if (free(COMPOSE_HOMES[h])) moved = COMPOSE_HOMES[h]
    if (moved !== "") {
      push("compose:" + moved)
      notes.push("Compose moves from " + composeLabel(option) + " to " + keyName(moved)
        + ": " + keyName(switchKey) + " is now the switch key.")
    } else {
      notes.push(option + " is removed: " + keyName(switchKey) + " is now the switch key.")
    }
  }

  if (hotkey !== "none") push(hotkey)
  if (led === true && hotkey === LED_HOTKEY) push(LED_OPTION)
  return { options: kept, notes: notes }
}

// Returns the writer's arguments, or an error. CURRENT_HOTKEY lets an
// unlisted grp: option already in look-and-feel.lua be kept. FILE_OPTIONS is
// null when the file has no live kb_options; EFFECTIVE_OPTIONS are
// Hyprland's. VARIANT_NEEDED: the file has a live kb_variant, or Hyprland has
// a non-empty one in effect; then kb_variant is always written.
export function writeArguments(layouts, hotkey, led, currentHotkey, fileOptions, effectiveOptions, variantNeeded) {
  if (!Array.isArray(layouts) || layouts.length === 0)
    return failure("Pick at least one layout")
  if (layouts.length > MAX_LAYOUTS)
    return failure("xkb supports at most " + MAX_LAYOUTS + " layouts")

  var seen = {}
  var names = []
  var variants = []
  for (var i = 0; i < layouts.length; i++) {
    var entry = layouts[i]
    if (!isRecord(entry) || typeof entry.layout !== "string" || typeof entry.variant !== "string"
        || !layoutName.test(entry.layout) || !variantName.test(entry.variant))
      return failure("Invalid layout name")
    var key = "$" + layoutSpec(entry)
    if (hasOwn(seen, key)) return failure("The same layout is listed twice")
    seen[key] = true
    names.push(entry.layout)
    variants.push(entry.variant)
  }

  if (typeof hotkey !== "string"
      || !(isKnownHotkey(hotkey) || (hotkey === currentHotkey && groupOption.test(hotkey))))
    return failure("Unknown switch key: " + hotkey)

  var present = Array.isArray(fileOptions)
  var base = present ? fileOptions : (Array.isArray(effectiveOptions) ? effectiveOptions : [])
  for (var j = 0; j < base.length; j++)
    if (typeof base[j] !== "string" || base[j].length > MAX_OPTION_CHARS || !optionName.test(base[j]))
      return failure("Current kb_options contain an entry that cannot be kept safely")
  var plan = planOptions(base, hotkey, led)
  if (plan.options.length > MAX_OPTIONS) return failure("Too many kb_options")

  var anyVariant = variants.some(function (v) { return v !== "" })
  return success({
    layouts: names.join(","),
    variants: anyVariant ? variants.join(",") : (variantNeeded === true ? "" : "-"),
    options: plan.options.join(","),
    expected: present ? fileOptions.join(",") : "-",
    notes: plan.notes
  })
}

// Reads `hyprctl -j --batch "getoption input:kb_layout ; … kb_variant ;
// … kb_options"`: three JSON objects separated by blank lines. Returns the
// values Hyprland has in effect, defaults included.
export function parseEffective(text) {
  var chunks = String(text).split(/\n\s*\n/).map(function (c) { return c.trim() })
    .filter(function (c) { return c !== "" })
  if (chunks.length !== 3) return failure("hyprctl getoption returned an unexpected shape")
  var values = {}
  for (var i = 0; i < chunks.length; i++) {
    var parsed
    try { parsed = JSON.parse(chunks[i]) }
    catch (error) { return failure("hyprctl getoption returned invalid JSON") }
    if (!isRecord(parsed) || typeof parsed.option !== "string"
        || !isBoundedText(parsed.str, 2048, true))
      return failure("hyprctl getoption returned an invalid value")
    values["$" + parsed.option] = parsed.str
  }
  var layoutText = values["$input:kb_layout"]
  var variantText = values["$input:kb_variant"]
  var optionText = values["$input:kb_options"]
  if (layoutText === undefined || variantText === undefined || optionText === undefined)
    return failure("hyprctl getoption is missing a keyboard option")

  var layoutList = layoutText.split(",").map(function (x) { return x.trim() })
    .filter(function (x) { return x !== "" })
  var variantList = variantText === "" ? [] : variantText.split(",").map(function (x) { return x.trim() })
  var optionList = optionText.split(",").map(function (x) { return x.trim() })
    .filter(function (x) { return x !== "" })
  if (layoutList.length > MAX_READ_LAYOUTS || optionList.length > MAX_OPTIONS)
    return failure("hyprctl getoption returned too many entries")

  var layouts = []
  for (var j = 0; j < layoutList.length; j++) {
    var variant = variantList[j] || ""
    if (!layoutName.test(layoutList[j]) || !variantName.test(variant))
      return failure("hyprctl getoption returned an invalid layout")
    layouts.push({ layout: layoutList[j], variant: variant })
  }
  var hotkey = "none"
  var led = false
  for (var k = 0; k < optionList.length; k++) {
    if (optionList[k].length > MAX_OPTION_CHARS || !optionName.test(optionList[k]))
      return failure("hyprctl getoption returned an invalid option")
    if (optionList[k] === LED_OPTION) led = true
    else if (hotkey === "none" && groupOption.test(optionList[k])) hotkey = optionList[k]
  }
  return success({
    layouts: layouts, options: optionList, hotkey: hotkey, led: led,
    variantSet: variantText.replace(/,/g, "").trim() !== ""
  })
}

// ---------------------------------------------------------------- devices --

export function isTypedKeyboard(name) {
  return !untypedKeyboard.test(String(name || ""))
}

// Every keyboard on the seat carries the same layout list, but only the one
// being typed on advances through it. The keyboard the latest activelayout
// event named wins; the furthest-advanced one is only a fallback. Comparing
// positions alone reads a stale keyboard the moment the typed one wraps from
// its last layout back to the first.
export function selectKeyboard(typed, namedByEvent) {
  if (!typed || typed.length === 0) return null
  for (var i = 0; i < typed.length; i++)
    if (typed[i].name === namedByEvent) return typed[i]
  // Before any event: the keyboard Hyprland marks main, when it is a typed one.
  for (var m = 0; m < typed.length; m++)
    if (typed[m].main === true) return typed[m]
  var furthest = typed[0]
  for (var j = 1; j < typed.length; j++)
    if (typed[j].index > furthest.index) furthest = typed[j]
  return furthest
}

export function parseDevices(text, namedByEvent) {
  var parsed
  try { parsed = JSON.parse(String(text)) }
  catch (error) { return failure("hyprctl devices returned invalid JSON") }

  if (!isRecord(parsed) || !Array.isArray(parsed.keyboards))
    return failure("hyprctl devices has an invalid top-level shape")
  if (parsed.keyboards.length > MAX_DEVICE_ROWS)
    return failure("hyprctl devices returned too many keyboard rows")

  var typed = []
  for (var i = 0; i < parsed.keyboards.length; i++) {
    var row = parsed.keyboards[i]
    if (!isRecord(row)) return failure("hyprctl devices contains a non-object keyboard row")

    if (!isBoundedText(row.name, MAX_DEVICE_NAME_CHARS, false))
      return failure("hyprctl devices contains an invalid keyboard name")

    var keymap = row.active_keymap
    if (!isBoundedText(keymap, MAX_KEYMAP_NAME_CHARS, true))
      return failure("hyprctl devices contains an invalid active keymap")

    var index = row.active_layout_index
    if (typeof index !== "number" || !isFinite(index) || Math.floor(index) !== index
        || index < 0 || index > MAX_LAYOUT_INDEX)
      return failure("hyprctl devices contains an invalid layout index")

    if (isTypedKeyboard(row.name))
      typed.push({ name: row.name, keymap: keymap, index: index, main: row.main === true })
  }

  var chosen = selectKeyboard(typed, namedByEvent)
  if (chosen === null)
    return success({ keyboards: [], keyboardName: "", currentKeymap: "", currentIndex: 0 })
  if (chosen.keymap === "")
    return failure("hyprctl devices did not report an active keymap")

  return success({
    keyboards: typed,
    keyboardName: chosen.name,
    currentKeymap: chosen.keymap,
    currentIndex: chosen.index
  })
}

// An activelayout event's data is "keyboard,layout description" — the raw
// socket2 payload after "activelayout>>". Returns null for a keyboard nobody
// types on or for anything malformed.
export function parseLayoutEventData(data) {
  var text = String(data === undefined || data === null ? "" : data)
  var comma = text.indexOf(",")
  if (comma < 0) return null
  var name = text.slice(0, comma)
  var keymap = text.slice(comma + 1)
  if (!isBoundedText(name, MAX_DEVICE_NAME_CHARS, false) || !isTypedKeyboard(name)) return null
  if (!isBoundedText(keymap, MAX_KEYMAP_NAME_CHARS, false)) return null
  return { name: name, keymap: keymap }
}

// The index a next / prev / set action lands on, or -1 when it cannot apply.
export function targetIndex(current, count, action) {
  if (typeof count !== "number" || count < 1) return -1
  var from = typeof current === "number" && current >= 0 && current < count ? current : 0
  if (action === "next") return count < 2 ? -1 : (from + 1) % count
  if (action === "prev") return count < 2 ? -1 : (from + count - 1) % count
  if (typeof action === "number" && Math.floor(action) === action && action >= 0 && action < count)
    return action
  return -1
}

// `set` accepts an index ("1"), a layout ("gr") or a spec ("gr(polytonic)").
export function resolveSetTarget(argument, layouts) {
  var text = String(argument === undefined || argument === null ? "" : argument).trim()
  if (/^[0-9]{1,2}$/.test(text)) {
    var index = parseInt(text, 10)
    return index < layouts.length ? index : -1
  }
  var wanted = parseLayoutSpec(text)
  if (!wanted) return -1
  for (var i = 0; i < layouts.length; i++)
    if (layoutSpec(layouts[i]) === text) return i
  if (text.indexOf("(") === -1)
    for (var j = 0; j < layouts.length; j++)
      if (layouts[j].layout === wanted.layout) return j
  return -1
}

// One `hyprctl --batch` string that sets every typed keyboard to the same
// absolute index, so several physical keyboards never drift apart. Returns
// "" when nothing safe can be switched.
export function switchBatch(keyboards, index) {
  if (typeof index !== "number" || index < 0 || Math.floor(index) !== index
      || index > MAX_LAYOUT_INDEX)
    return ""
  var commands = []
  for (var i = 0; i < (keyboards || []).length; i++) {
    var name = keyboards[i] && keyboards[i].name
    if (typeof name === "string" && batchSafeName.test(name) && isTypedKeyboard(name))
      commands.push("switchxkblayout " + name + " " + index)
  }
  return commands.join(" ; ")
}

// ------------------------------------------------------------- xkb catalog --

function xmlUnescape(value) {
  return String(value)
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"").replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&")
}

// Reads xkeyboard-config's evdev.xml (xkbcli is not in this system's
// closure): every layout/variant pair with its short language code and
// description. Returns { briefs, entries } where briefs is a
// "$"-prefixed description -> brief lookup (the prefix keeps descriptions
// such as "__proto__" away from object prototype names).
export function parseCatalogEvdev(text) {
  var source = String(text)
  if (source.length > XKB_MAX_BYTES) return failure("evdev.xml exceeds the byte limit")

  var briefs = {}
  var entries = []
  var rowCount = 0

  var layoutRe = /<layout>\s*<configItem>([\s\S]*?)<\/configItem>([\s\S]*?)<\/layout>/g
  var match
  while ((match = layoutRe.exec(source)) !== null) {
    rowCount++
    if (rowCount > MAX_KEYMAP_ROWS) return failure("evdev.xml has too many layouts")
    var item = match[1]
    var rest = match[2]

    var name = (item.match(/<name>([^<]*)<\/name>/) || [])[1]
    var brief = (item.match(/<shortDescription>([^<]*)<\/shortDescription>/) || [])[1]
    var description = (item.match(/<description>([^<]*)<\/description>/) || [])[1]
    if (name === undefined || description === undefined) continue
    name = xmlUnescape(name)
    description = xmlUnescape(description)
    if (!layoutName.test(name) || !isBoundedText(description, MAX_DESCRIPTION_CHARS, false))
      continue
    var layoutBrief = brief !== undefined && isBoundedText(xmlUnescape(brief), MAX_BRIEF_CHARS, false)
      ? xmlUnescape(brief) : ""
    if (layoutBrief !== "") briefs["$" + description] = layoutBrief

    entries.push({
      layout: name,
      variant: "",
      brief: layoutBrief,
      description: description
    })

    var variantRe = /<variant>\s*<configItem>([\s\S]*?)<\/configItem>\s*<\/variant>/g
    var vmatch
    var variantCount = 0
    while ((vmatch = variantRe.exec(rest)) !== null) {
      variantCount++
      if (variantCount > MAX_KEYMAP_ROWS) return failure("evdev.xml has too many variants")
      var vItem = vmatch[1]
      var vName = (vItem.match(/<name>([^<]*)<\/name>/) || [])[1]
      var vBrief = (vItem.match(/<shortDescription>([^<]*)<\/shortDescription>/) || [])[1]
      var vDescription = (vItem.match(/<description>([^<]*)<\/description>/) || [])[1]
      if (vName === undefined || vDescription === undefined) continue
      vName = xmlUnescape(vName)
      vDescription = xmlUnescape(vDescription)
      if (!variantName.test(vName) || !isBoundedText(vDescription, MAX_DESCRIPTION_CHARS, false))
        continue
      var effBrief = vBrief !== undefined && isBoundedText(xmlUnescape(vBrief), MAX_BRIEF_CHARS, false)
        ? xmlUnescape(vBrief) : layoutBrief
      if (effBrief !== "") briefs["$" + vDescription] = effBrief
      entries.push({
        layout: name,
        variant: vName,
        brief: effBrief,
        description: vDescription
      })
    }
  }

  if (entries.length === 0 && Object.keys(briefs).length === 0)
    return failure("evdev.xml contained no keymap descriptions")
  entries.sort(function (a, b) {
    return a.description < b.description ? -1 : a.description > b.description ? 1 : 0
  })
  return success({ briefs: briefs, entries: entries })
}

// ----------------------------------------------------------------- backups --

export function isBackupId(id) {
  return typeof id === "string" && rotatingBackupId.test(id)
}

// Validates the JSON printed by `InputLua.pl backups`.
export function parseBackups(text) {
  var parsed
  try { parsed = JSON.parse(String(text)) }
  catch (error) { return failure("backup list is not valid JSON") }
  if (!Array.isArray(parsed)) return failure("backup list has an invalid shape")

  var rows = []
  for (var i = 0; i < parsed.length && rows.length < MAX_BACKUP_ROWS; i++) {
    var row = parsed[i]
    if (!isRecord(row) || !isBackupId(row.id)
        || row.kind !== "rotating"
        || typeof row.time !== "number" || !isFinite(row.time)
        || typeof row.size !== "number" || !isFinite(row.size)
        || !isBoundedText(row.layouts, 2048, true)
        || typeof row.valid !== "boolean")
      return failure("backup list has an invalid row")
    rows.push({
      id: row.id, kind: row.kind, time: row.time, size: row.size,
      layouts: row.layouts, valid: row.valid
    })
  }
  return success(rows)
}

// ------------------------------------------------------------------ search --

// The layout search box (LayoutSearch.qml) builds its query from key events,
// never from a text input. Only printable text is typed: Tab, Return and
// other control characters keep their key meaning. Lengths count characters,
// not UTF-16 units, so Backspace never splits a surrogate pair.
export const SEARCH_MAX_CHARS = 64

function isSearchText(text) {
  if (typeof text !== "string" || text === "") return false
  for (var i = 0; i < text.length; i++) {
    var code = text.charCodeAt(i)
    if (code < 0x20 || (code >= 0x7f && code <= 0x9f)) return false
  }
  return true
}

export function searchTyped(query, text, max) {
  if (!isSearchText(text)) return query
  if ([...query].length + [...text].length > max) return query
  return query + text
}

export function searchBackspace(query) {
  // Spread, not Array.from: Array.from splits a string into UTF-16 units.
  var chars = [...query]
  chars.pop()
  return chars.join("")
}
