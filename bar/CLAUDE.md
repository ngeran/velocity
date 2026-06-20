# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This is a **quickshell-bar** — a minimal top bar for Hyprland on Arch Linux, built with [Quickshell](https://quickshell.outfoxxed.me/). It's a QML-based Wayland layer-shell that displays workspace buttons, a clock, and system tray icons (Bluetooth, Network, Volume, Battery).

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
- **`shell.qml`** — The only file Quickshell reads. Uses `Variants` to spawn one `PanelWindow` per detected screen, anchoring each to the top edge with `WlrLayerShell.Top`.

### Three-layer separation

1. **`config/BarConfig.qml`** (singleton) — All design tokens: colours, sizes, fonts, workspace count. This is the single source of truth for theming.

2. **`services/*.qml`** (singletons) — Background data bridges. Each uses a `Process` or `SocketNotifier` to expose reactive state:
   - `HyprlandService` — Reads workspace state via `hyprctl` + socket2 IPC
   - `BluetoothService` — Polls `bluetoothctl` for power/connection state
   - `NetworkService` — Polls `nmcli` for connection type + signal strength
   - `AudioService` — Polls `wpctl` (PipeWire) for volume + mute state
   - `BatteryService` — Polls `upower` for battery percentage + charging state

3. **`components/*.qml`** — UI components. Read from singleton services directly; no imports needed once registered in `qmldir`.

### Component structure

```
shell.qml (root layout)
├── WorkspaceWidget.qml → WorkspaceButton.qml (repeater)
├── ClockWidget.qml (centered)
└── System tray icons (right-aligned)
    ├── NetworkIcon.qml (click → impala)
    ├── BluetoothIcon.qml (click → bluetui)
    ├── VolumeIcon.qml (scroll → volume, click → wiremix)
    └── BatteryIcon.qml (click → popup with % & status)
```

### QML module registration

Every directory has a `qmldir` file. Components/services are registered there and resolved automatically. **When adding a new component or service, you must add an entry to the corresponding `qmldir`.**

---

## Icon interactions

### Workspaces
- **Click dot**: Switch to that workspace

### Network (W)
- **Click**: Launch impala network TUI

### Bluetooth (B)
- **Click**: Launch bluetui bluetooth TUI

### Volume (V)
- **Scroll up**: Increase volume
- **Scroll down**: Decrease volume
- **Click**: Launch wiremix audio TUI

### Battery (BATT)
- **Click**: Toggle popup showing battery percentage, status, and level bar

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
| `socat` | Hyprland socket2 event streaming |
| `hyprctl` | Workspace state queries |
| `bluetoothctl` | Bluetooth state |
| `nmcli` | Network state |
| `wpctl` | Volume/mute (PipeWire) |
| `upower` | Battery state |
| `impala` | Network TUI |
| `bluetui` | Bluetooth TUI |
| `wiremix` | Audio TUI |

Install on Arch: `sudo pacman -S quickshell socat networkmanager bluez-utils wireplumber upower impala bluetui wiremix kitty`

---

## Portability notes

- `HYPRLAND_INSTANCE_SIGNATURE` must be set (automatic in Hyprland sessions).
- Font assumes JetBrains Mono; falls back to `monospace`.
- For HiDPI screens, adjust `BarConfig.barHeight`.
- `kitty` is used for launching TUI apps with floating window class.
