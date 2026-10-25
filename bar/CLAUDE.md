# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This is a **quickshell-bar** — a minimal top bar for Hyprland on NixOS, built with [Quickshell](https://quickshell.outfoxxed.me/). It's a QML-based Wayland layer-shell that displays workspace buttons, plugin widgets (center clock), and system tray icons (Network, Bluetooth, Volume, Privacy); battery/power is the `nikos.power` plugin.

**Design language:** Pure black background (`#000000`) · Obsidian Teal accent (`#00dce5`) · JetBrains Mono font

---

## Launching / testing

```bash
# Launch the bar (Quickshell auto-discovers shell.qml in subdirectories)
quickshell -c ~/.config/quickshell/bar

# Launch with verbose output for debugging
quickshell -v -c ~/.config/quickshell/bar
```

The bar runs persistently. Kill it with Ctrl+C or close the terminal. For auto-start with Hyprland, add to `~/.config/hypr/hyprland.conf`:

```ini
exec-once = quickshell -c ~/.config/quickshell/bar
```

---

## Architecture

### Entry point
- **`shell.qml` — the HOST**: IPC handlers, shared overlays (TrayCard, NotificationCenter, OSD; Fastfetch/Keybinds/log viewer/Z.ai usage are overlay built-ins `velocity.fastfetch|keybinds|logs-viewer|zai-usage` reached via `toggleOverlay(id)`), the tray state (`trayOwner/trayAnchor/activeTray`, `toggleTray/closeTray`), the `hostApi` it injects into the plugin engine, `Engine.PluginHost` (service + overlay plugins, `plugins` IPC), and the **style Loader** — it loads `styles/<barStyle>/Scene.qml` (barStyle from bar-config.json, default `vector`; Loader.Error auto-falls back to vector so a broken style never renders an empty bar).
- **`styles/<name>/Scene.qml` — a bar style**: one `PanelWindow` per real output via `Variants { model: Quickshell.screens }` (hotplug-safe; delegates must carry a plain `property var modelData`). A style owns only window chrome; WHAT renders comes from three `Engine.BarSection`s (left/center/right, from the engine layout). A style may swap one widget's look via `overrides: { id: Component }` (ryoku's workspaces). It receives the host as `host` and exposes `instances` for the barToggle IPC.
- **Adding a bar style** = new folder `styles/<name>/` with a `Scene.qml` honoring the same host contract (see vector's header). It appears automatically in Settings → Bar (styles are scanned, shown as "Bar form" preview cards — add a silhouette + copy for it in `settings/components/BarFormCard.qml`) and swaps live — no restart.
- **Styles today:** `vector` (default, full strip), `notch` (lobe + caret carve), `ryoku` (paper-and-ink strip), `island` (Dynamic Island).
- **`island`** (`styles/island/`, math in `lib/island.mjs`, node-tested): clock-only pill at rest → hover blooms a one-row glance with the left/right sections → any plugin panel or tray card opens *inside* the island, which springs to the content's size. Each island window registers in `Engine.PopupCoordinator.islands[screen]`; `Popover.embedHost` (PluginPopup via `ctx.popup.island`, TrayCard via the shell) makes the card's content get adopted (`present/withdraw`) instead of mapping its own window. OSD feedback renders as an island live activity (Osd.qml stands down while an island exists). QD-OLED guard (`bar-config.json` `islandBurnGuard`, default on): opaque black fill, no stroke, dimmed rest clock, idle dim, 1–2px orbit every 3 min. NotificationCenter and overlays keep their own windows.
- **Control Center** (`components/ControlCenterBody.qml`, TrayCard body `"control"`): tile grid (Wi-Fi, Bluetooth, Focus/DND, mic, power profile, theme) + volume/brightness sliders + SETTINGS › deep link. Opens from an empty-island click / the island dock, the `velocity.settings` gear (left click; right click = settings app), or `qs -c bar ipc call controlCenter toggle`. Tiles drill into the network/bluetooth/volume bodies in place (`switchRequested`, ‹ back). `BrightnessService` (brightnessctl → ddcutil) and `PowerProfileService` (powerprofilesctl) probe only on open; their controls hide when the tool is absent.

### Plugin engine (`engine/`)

Everything on the bar is a plugin — logo, workspaces, tray icons are first-party built-ins in `builtins/velocity.*` (thin wrappers over `components/`). Developer guide + CLI: `../plugins/README.md`, `../bin/velocity-plugin`.

- **Standalone (D1):** `engine/` imports nothing from config/services/components; the host injects `hostApi` (theme, bar, osd, hypr, focusedMonitor, shell, legacyBarConfigPath). Enforced by `tools/check-engine`.
- **`PluginRegistry`** (singleton): discovery over the search path (user `~/.config/velocity/plugins` → `$VELOCITY_PLUGIN_PATH` / `$XDG_DATA_DIRS/*/velocity/plugins` → `<repo>/plugins` → `bar/builtins`; same id = higher wins), state, instances per window, `summon/hide/call`, hot reload (`revs`, entry-file watchers). Pure logic lives in `engine/lib/*.mjs` (manifest, discovery, layout, settings — node-tested, shared with the CLI).
- **State:** `<repo>/plugins-state.json` schema 2 `{ enabled, layout: { left, center, right } }`. **The bar is its only writer** — settings app and CLI go through the `plugins` IPC. Same for each plugin's settings file (`$XDG_STATE_HOME/velocity/plugins/<id>.json`, `SettingsStore`). Plugins are opt-in; built-ins default on.
- **`PluginContext` (`ctx`)**: the one object a plugin root gets (api 2) — no raw singletons. Built-ins alone also get `ctx.host` (the shell).
- **`PopupCoordinator`** (singleton): one popup at a time across tray card (`tray`), notification center (`nc`), plugin panels (`<id>[.<sub>]`) and overlays (`overlay:<id>`). `request(key, closer)` closes the previous holder; `connected` is the notch-carve geometry. Never write cross-closing glue — claim the slot.
- **`qs.Ui` (`Ui/`)**: stateless kit plugins import (BarPill, PluginPopup, …). It must never reference engine/service/config singletons (D13: a second instance via the qs path would split the registry); engine state only through `ctx`.

### Three-layer separation

1. **`config/BarConfig.qml`** (singleton) — All design tokens: colours, sizes, fonts, workspace count. This is the single source of truth for theming.

2. **`services/*.qml`** (singletons) — Background data bridges. Event-driven where Quickshell has a native client; forked `Process` probes only where it doesn't (idle cost: zero recurring forks):
   - `HyprlandService` — THE socket2 owner (`nc -U` stream, watchdog); re-emits every raw event on `socketEvent(line)` for subscribers. Workspace switch via the Lua-config dispatcher (`hyprctl dispatch 'hl.dsp.focus(...)'`)
   - `BluetoothService` — Native `Quickshell.Bluetooth` (BlueZ): powered/devices/battery as bindings; toggle + disconnect are property writes
   - `NetworkService` — Native `Quickshell.Networking` for bar state (type/SSID/connected); wifi scanner leased to `popupOpen`; IP + throughput are popup-gated probes (full diagnostics live in settings)
   - `AudioService` — Native `Quickshell.Services.Pipewire`: default sink tracked, volume/mute as bindings
   - `EventService` — always-on kernel incident recorder (`journalctl -f -k`, watchdog-healed) writing `events.jsonl`
   - Clock: the built-in ClockWidget was removed — the center clock is the `nikos.clock` plugin, which uses `SystemClock { precision: Minutes }` (zero-poll, boundary-exact); its zone is the plugin's `zone` setting (zone math: `lib/tz.mjs`, synced from `shared/tz.mjs`)

3. **`components/*.qml`** — UI components. Read from singleton services directly; no imports needed once registered in `qmldir`. Bar icons are mounted through their `builtins/velocity.*` wrappers, never placed by a scene directly.

### Default layout (plugins-state.json)

```
left:   velocity.logo · velocity.workspaces
center: nikos.clock · velocity.settings
right:  nikos.keyboard · nikos.power · nikos.timezones · randazraik.xray
        velocity.network · bluetooth · volume · privacy · logs · notifications
```
Rearrange live: `velocity-plugin place <id> <section> [index]` / `move <id> <delta>`, or Settings ▸ Plugins.

### QML module registration

Every directory has a `qmldir` file. Components/services are registered there and resolved automatically. **When adding a new component or service, you must add an entry to the corresponding `qmldir`.**

---

## Icon interactions

### Workspaces
- **Click dot**: Switch to that workspace

### Keyboard (US/GR)
- **Click**: Cycle to the next XKB layout (EN ↔ GR); **right click** opens the layout manager panel (`hyprctl switchxkblayout`, tracked by the `nikos.keyboard` plugin via socket2 `activelayout` events from `ctx.events`). Layout list lives in `~/.omni-nix/configs/hypr/look-and-feel.lua` (`input.kb_layout`). Also SUPER+SHIFT+SPACE (`qs -c bar ipc call plugins call nikos.keyboard next ""`; the old `keyboard.next` target is a transitional forwarder in shell.qml).

### Network (W)
- **Click**: Quick info — SSID, IP, signal, ↓/↑ rates, radio toggle; OPEN IN SETTINGS › for networks/DNS/QR

### Bluetooth (B)
- **Click**: Quick info — connected devices (battery, disconnect), power toggle; OPEN IN SETTINGS › to pair

### Volume (V)
- **Scroll up**: Increase volume
- **Scroll down**: Decrease volume
- **Click**: Quick volume — slider + mute; OPEN IN SETTINGS › for outputs, mic, per-app streams

### Power (plugin pill)
- **Click**: Open the nikos.power popup (AC state, charge, source, power menu)

---

## Adding a new bar widget

Third-party / personal: `velocity-plugin new author.name` (see `../plugins/README.md`).

First-party icon that needs bar services:
1. `components/MyIcon.qml` + register it in `components/qmldir`.
2. `builtins/velocity.myicon/{manifest.json,BarWidget.qml}` — wrapper with `property var ctx: null` (copy `velocity.network`; tray icons call `ctx.host.toggleTray(ctx.window, "<name>", root)`).
3. `velocity-plugin place velocity.myicon right` (built-ins are on by default; unplaced ones append to `bar.defaultSection`).

---

## Adding a new background service

1. Create `services/MyService.qml` with `pragma Singleton`.
2. Register in `services/qmldir`:
   ```
   singleton MyService 1.0 MyService.qml
   ```
3. Read properties from any component — no import needed once registered.

---

## Deployment — two modes

**Deployed (the sanctioned mode):** `tools/deploy-link` symlinks
`~/.config/quickshell` → this repo. Every service already assumes that path —
config writes (settings-config.json, bar-config.json, theme cache,
plugins-state.json, events.jsonl), `qs -c bar`/`-c settings` resolution
(plugin-manager IPC, theme push nudge, hypridle), and the repo doubling as
the live config dir. Launch with `-c`, not `-p`:

    quickshell -c bar &        quickshell -c settings &

Optional systemd units (`deploy/quickshell-*.service`) add crash-restart,
boot autostart and journal logs; installing them makes BarWatch's
systemd-unit probe real (it watches `quickshell-bar`'s MainPID).

**Dev (`-p`):** `quickshell -p bar/shell.qml` from the repo works without the
link, but the cross-process surfaces degrade BY DESIGN — the plugin manager's
`qs -c bar` calls fail ("bad list output"), the theme push nudge can't find
the bar, and BarWatch goes inert (devMode: no unit → no banner). Functional
verification of those surfaces requires deployed mode.

Moving between modes: stop the -p instances first (`quickshell -p` and `-c`
instances of the same shell fight over IPC targets and layer space).

## Customisation

All visual changes happen in `config/BarConfig.qml`:
- Bar height → `barHeight`
- Workspace count → `workspaceCount`
- Colours → `colorBackground`, `colorAccent`, etc.
- Animation speed → `motionScale` (0..2) / `reduceMotion` (bool) in `bar-config.json`, read by `config/MotionConfig.qml`

To move the bar to the bottom: Settings → Bar → BAR POSITION (`barPosition` in `bar-config.json`); every style mirrors live.

---

## Dependencies

| Tool | Used by |
|------|---------|
| `quickshell` | Runtime framework (0.3.0: Pipewire, UPower, Bluetooth, Networking native clients) |
| `nc` (netcat) | The one socket2 consumer (`nc -U`; socat is NOT installed) |
| `hyprctl` | Workspace seed + Lua dispatcher (`hl.dsp.*`) + keyboard layout probes |
| `upower` | Daemon (enabled in omni-nix) behind the native UPower client |
| `journalctl` | EventService kernel incident tail |
| `nmcli` | Settings network section (the bar popup reads ip/sysfs only) |
| `bluetoothctl` / `wpctl` | Settings process only (control services); the bar is native |
| `qrencode` | Settings Wi-Fi QR share |

**On NixOS:** All packages managed via `~/.omni-nix/flake.nix`.

---

## Portability notes

- `HYPRLAND_INSTANCE_SIGNATURE` must be set (automatic in Hyprland sessions).
- Font assumes JetBrains Mono; falls back to `monospace`.
- For HiDPI screens, adjust `BarConfig.barHeight`.
- `kitty` is used for launching TUI apps with floating window class.
- **Theme/config sync:** Bar watches `~/.cache/theme/colors.json` + `bar-config.json` via FileView (`watchChanges` + `onTextChanged`, plus a 15s fallback `reload()` — reload is ASYNC, a synchronous `text()` reads stale; the whole contract is documented in the files). The settings process nudges the bar right after each atomic write (`theme reload` for colors.json, `config reload` for bar-config.json), so its changes land instantly; other writers within ≤15s. The Stylix seed at `~/.config/quickshell/stylix-palette.json` is loaded on bar startup if `colors.json` has source `"stylix"`.
- **Editing singletons that own Timers/Processes:** make ONE atomic edit or `systemctl --user restart quickshell-bar` after — split hot-reloads leave the old timer alive against removed ids.
