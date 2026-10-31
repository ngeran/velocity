// GENERATED from shared/keybinds-default.mjs by tools/sync-shared — do not edit
// keybinds-default.mjs — embedded fallback of the keybinds table for
// KeybindsOverlay. Canonical copy: tools/keybinds-default.json (the single
// source the HM module renders ~/.config/velocity/keybinds.json from and
// tools/check-ipc validates against); tools/check-ipc asserts this file
// stays in lockstep with it. Dev checkouts without the HM render (no
// ~/.config/velocity/keybinds.json) fall back to this.
export const KEYBINDS_META = {
  source: "tools/keybinds-default.json (D3 table + preserved velocity binds)",
  actionForms: {
    "exec <cmd>": "hyprland hl.dsp.exec_cmd(<cmd>)",
    "ipc <target> <fn> [arg…]": "hyprland hl.dsp.exec_cmd(qs -c bar ipc call <target> <fn> [arg…])"
  }
};

export const KEYBINDS_DEFAULT = [
  { key: "SUPER+SPACE",       action: "ipc launcher toggle",            label: "App launcher",            section: "QUICK ACCESS", available: true,  order: 1 },
  { key: "SUPER+SHIFT+V",     action: "ipc clipboard toggle",           label: "Clipboard history",       section: "QUICK ACCESS", available: true,  order: 2 },
  { key: "SUPER+N",           action: "ipc controlCenter toggle",       label: "Control Center",          section: "QUICK ACCESS", available: true,  order: 3 },
  { key: "SUPER+COMMA",       action: "ipc controlCenter page bar",     label: "Control Center › BAR",    section: "QUICK ACCESS", available: true,  order: 4 },
  { key: "SUPER+SHIFT+R",     action: "ipc record toggle",              label: "Screen recorder",         section: "QUICK ACCESS", available: true,  order: 5 },
  { key: "SUPER+SHIFT+W",     action: "ipc wallpaper-service cycleNow", label: "Wallpaper cycle",         section: "QUICK ACCESS", available: true,  order: 6 },
  { key: "SUPER+SHIFT+N",     action: "ipc notifications dndToggle",    label: "Do not disturb",          section: "QUICK ACCESS", available: true,  order: 7 },
  { key: "SUPER+SHIFT+S",     action: "ipc screenshot region",          label: "Screenshot region",       section: "QUICK ACCESS", available: true,  order: 8 },
  { key: "PRINT",             action: "ipc screenshot output",          label: "Screenshot output",       section: "QUICK ACCESS", available: true,  order: 9 },
  { key: "SUPER+SHIFT+T",     action: "ipc SettingsWindow openControlNetwork", label: "Network / Bluetooth center", section: "OVERLAYS", available: true, order: 12 },
  { key: "SUPER+K",           action: "ipc keybinds toggle",            label: "This cheat sheet",        section: "OVERLAYS",     available: true,  order: 13 },
  { key: "SUPER+A",           action: "ipc controlCenter toggle",       label: "Control Center",          section: "OVERLAYS",     available: true,  order: 14 },
  { key: "SUPER+T",           action: "ipc logs toggle",                label: "System logs",             section: "OVERLAYS",     available: true,  order: 15 },
  { key: "SUPER+Z",           action: "ipc zaiUsage toggle",            label: "Z.ai usage",              section: "OVERLAYS",     available: true,  order: 16 },
  { key: "SUPER+P",           action: "ipc powerMenu toggle",           label: "Power menu",              section: "OVERLAYS",     available: true,  order: 17 },
  { key: "SUPER+SHIFT+B",     action: "ipc barToggle toggle",           label: "Toggle the bar",          section: "OVERLAYS",     available: true,  order: 18 },
  { key: "SUPER+SHIFT+SPACE", action: "ipc keyboard next",              label: "Next keyboard layout",    section: "OVERLAYS",     available: true,  order: 19 },
  { key: "SUPER+L",           action: "exec velocity-lock",             label: "Lock screen",             section: "SESSION",      available: true,  order: 20 }
];

// Grouped, ordered model for the cheat sheet (sections in first-appearance
// order, rows by `order`).
export function keybindsSections(binds) {
  const rows = (binds || KEYBINDS_DEFAULT).slice().sort((a, b) => (a.order || 999) - (b.order || 999));
  const sections = [];
  for (const b of rows) {
    let sec = sections.find(s => s.sectionName === b.section);
    if (!sec) { sec = { sectionName: b.section, binds: [] }; sections.push(sec); }
    sec.binds.push(b);
  }
  return sections;
}
