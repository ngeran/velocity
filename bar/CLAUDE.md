# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This is a **quickshell-bar** — a minimal top bar for Hyprland on NixOS, built with [Quickshell](https://quickshell.outfoxxed.me/). It's a QML-based Wayland layer-shell that displays workspace buttons, plugin widgets (center clock), and system tray icons (Bluetooth, Network, Volume, Battery).

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
- **`shell.qml` — the HOST** (Phase-1 style architecture): IPC handlers, shared overlays (TrayCard, NotificationCenter, Logs/Keybinds/Zai/Fastfetch, OSD), headless plugin services, and the **style Loader** — it loads `styles/<barStyle>/Scene.qml` (barStyle from bar-config.json, default `vector`; Loader.Error auto-falls back to vector so a broken style never renders an empty bar).
- **`styles/vector/Scene.qml` — THE VECTOR BAR** (default style): one `PanelWindow` per real output via `Variants { model: Quickshell.screens }` (hotplug-safe; delegates must carry a plain `property var modelData`). The whole rail layout — workspaces, slots, tray icons, plugin pills — lives here. It receives the host as `host` (trayOwner, overlay toggles + ncShown/logsShown, pluginItems registry) and exposes `instances` for the barToggle IPC.
- **Adding a bar style** = new folder `styles/<name>/` with a `Scene.qml` honoring the same host contract (see vector's header). It appears automatically in Settings → Bar (styles are scanned) and swaps live — no restart.

### Three-layer separation

1. **`config/BarConfig.qml`** (singleton) — All design tokens: colours, sizes, fonts, workspace count. This is the single source of truth for theming.

2. **`services/*.qml`** (singletons) — Background data bridges. Event-driven where Quickshell has a native client; forked `Process` probes only where it doesn't (idle cost: zero recurring forks):
   - `HyprlandService` — THE socket2 owner (`nc -U` stream, watchdog); re-emits every raw event on `socketEvent(line)` for subscribers. Workspace switch via the Lua-config dispatcher (`hyprctl dispatch 'hl.dsp.focus(...)'`)
   - `BluetoothService` — Native `Quickshell.Bluetooth` (BlueZ): powered/devices/battery as bindings; toggle + disconnect are property writes
   - `NetworkService` — Native `Quickshell.Networking` for bar state (type/SSID/connected); wifi scanner leased to `popupOpen`; diagnostics (IP/gateway/DNS/ping/throughput) are popup-gated one-shot probes
   - `AudioService` — Native `Quickshell.Services.Pipewire`: default sink tracked, volume/mute as bindings
   - `BatteryService` — Native `Quickshell.Services.UPower` (daemon enabled in omni-nix; peripheral batteries filtered by `powerSupply`)
   - `EventService` — always-on kernel incident recorder (`journalctl -f -k`, watchdog-healed) writing `events.jsonl`
   - Clock: the built-in ClockWidget was removed — the center clock is the `nikos.clock` plugin, which uses `SystemClock { precision: Minutes }` (zero-poll, boundary-exact) via `api.bar`

3. **`components/*.qml`** — UI components. Read from singleton services directly; no imports needed once registered in `qmldir`.

### Component structure

```
shell.qml (root layout)
├── WorkspaceWidget.qml → WorkspaceButton.qml (repeater)
└── System tray icons (right-aligned)
    ├── NetworkIcon.qml    (hover: live IP · click → TrayCard NETWORK popup)
    ├── BluetoothIcon.qml  (click → TrayCard BLUETOOTH popup)
    ├── VolumeIcon.qml     (scroll → volume · click → TrayCard VOLUME popup)
    ├── [plugin pills — nikos.keyboard, nikos.timezones, nikos.power …]
    ├── LogsIcon.qml       (click → system log overlay)
    └── NotificationButton.qml (click → notification center; unread badge)
```

### QML module registration

Every directory has a `qmldir` file. Components/services are registered there and resolved automatically. **When adding a new component or service, you must add an entry to the corresponding `qmldir`.**

---

## Icon interactions

### Workspaces
- **Click dot**: Switch to that workspace

### Keyboard (US/GR)
- **Click**: Cycle to the next XKB layout (`hyprctl switchxkblayout`, tracked by `KeyboardService` via socket2 `activelayout` events). Layout list lives in `~/.omni-nix/configs/hypr/look-and-feel.lua` (`input.kb_layout`). Also SUPER+SHIFT+SPACE (via `quickshell ipc -c bar call keyboard next`).

### Network (W)
- **Click**: Open the TrayCard NETWORK popup (status, DNS picker, QR, networks)

### Bluetooth (B)
- **Click**: Open the TrayCard BLUETOOTH popup (devices, connect/pair, scan)

### Volume (V)
- **Scroll up**: Increase volume
- **Scroll down**: Decrease volume
- **Click**: Open the TrayCard VOLUME popup (slider, sink picker, mic)

### Power (plugin pill)
- **Click**: Open the nikos.power popup (AC state, charge, source, power menu)

---

## Adding a new tray icon

1. Create `components/MyIcon.qml`:
   ```qml
   import QtQuick
   Item {
       width: BarConfig.iconSize
       height: BarConfig.iconSize
       // Your icon implementation
   }
   ```

2. Add to `shell.qml` inside the right-side Row.

3. Register in `components/qmldir`:
   ```
   MyIcon 1.0 MyIcon.qml
   ```

---

## Adding a new background service

1. Create `services/MyService.qml` with `pragma Singleton`.
2. Register in `services/qmldir`:
   ```
   singleton MyService 1.0 MyService.qml
   ```
3. Read properties from any component — no import needed once registered.

---

## Customisation

All visual changes happen in `config/BarConfig.qml`:
- Bar height → `barHeight`
- Workspace count → `workspaceCount`
- Colours → `colorBackground`, `colorAccent`, etc.
- Animation duration → `animDuration` (set to 0 to disable globally)

To move the bar to the bottom, edit `shell.qml` and change `anchors.top` → `anchors.bottom`.

---

## Dependencies

| Tool | Used by |
|------|---------|
| `quickshell` | Runtime framework |
| Tool | Used by |
|------|---------|
| `quickshell` | Runtime framework (0.3.0: Pipewire, UPower, Bluetooth, Networking native clients) |
| `nc` (netcat) | The one socket2 consumer (`nc -U`; socat is NOT installed) |
| `hyprctl` | Workspace seed + Lua dispatcher (`hl.dsp.*`) + keyboard layout probes |
| `upower` | Daemon (enabled in omni-nix) behind the native UPower client |
| `journalctl` | EventService kernel incident tail |
| `nmcli` | BAR popup probes (link/DNS/ping) + QR credentials + settings network section |
| `bluetoothctl` / `wpctl` | Settings process only (control services); the bar is native |
| `qrencode` | TrayCard NETWORK popup QR (add to flake — currently missing) |

**On NixOS:** All packages managed via `~/.omni-nix/flake.nix`.

---

## Portability notes

- `HYPRLAND_INSTANCE_SIGNATURE` must be set (automatic in Hyprland sessions).
- Font assumes JetBrains Mono; falls back to `monospace`.
- For HiDPI screens, adjust `BarConfig.barHeight`.
- `kitty` is used for launching TUI apps with floating window class.
- **Theme/config sync:** Bar watches `~/.cache/theme/colors.json` + `bar-config.json` via FileView (`watchChanges` + `onTextChanged` + a 2s forced `reload()` — reload is ASYNC, a synchronous `text()` reads stale; the whole contract is documented in the files). Updates land ≤2s after the settings process writes. The Stylix seed at `~/.config/quickshell/stylix-palette.json` is loaded on bar startup if `colors.json` has source `"stylix"`.
- **Editing singletons that own Timers/Processes:** make ONE atomic edit or `systemctl --user restart quickshell-bar` after — split hot-reloads leave the old timer alive against removed ids.
