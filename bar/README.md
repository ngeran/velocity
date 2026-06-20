# quickshell-bar

A minimal, modular top bar for Hyprland on Arch Linux, built with [Quickshell](https://quickshell.outfoxxed.me/).

```
┌─────────────────────────────────────────────┐
│ ●  ●  ●  ●  ●        10:23    W B V BATT    │
└─────────────────────────────────────────────┘
  workspaces              clock  icons
```

## Features

| Section | Icon | Function |
|---------|------|----------|
| Left | ●●●●● | Workspace dots (click to switch) |
| Center | 10:23 | Clock (HH:MM format) |
| Right | W | Network status (click → impala) |
| Right | B | Bluetooth status (click → bluetui) |
| Right | V | Volume (scroll → adjust, click → wiremix) |
| Right | BATT | Battery (click → popup with % & status) |

## Installation

### Dependencies

```bash
# Required
sudo pacman -S quickshell

# For functionality
sudo pacman -S networkmanager bluez-utils wireplumber
sudo pacman -S ttf-jetbrains-mono-nerd

# TUI apps
sudo pacman -S impala bluetui wiremix kitty
```

### Setup

```bash
# Clone to your Quickshell config directory
mkdir -p ~/.config/quickshell
cp -r quickshell-bar ~/.config/quickshell/bar

# Launch
quickshell -c ~/.config/quickshell/bar
```

### Auto-start with Hyprland

Add to `~/.config/hypr/hyprland.conf`:

```ini
exec-once = quickshell -c ~/.config/quickshell/bar
```

## Customization

All visual customization is done through `config/BarConfig.qml`:

```qml
// Bar height
readonly property int barHeight: 26

// Accent color (teal)
readonly property color colorAccent: "#00dce5"

// Number of workspaces
readonly property int workspaceCount: 5
```

### Change the accent color

Edit `config/BarConfig.qml`:
```qml
readonly property color colorAccent: "#ff6b6b"  // Red
```

### Adjust bar height

Edit `config/BarConfig.qml`:
```qml
readonly property int barHeight: 32  // Taller bar
```

### Change workspace count

Edit `config/BarConfig.qml`:
```qml
readonly property int workspaceCount: 9  // More workspaces
```

## Project Structure

```
bar/
├── shell.qml              # Entry point (Quickshell reads this)
├── config/
│   ├── qmldir             # Module definition
│   └── BarConfig.qml      # Design tokens
├── components/
│   ├── qmldir             # Module definition
│   ├── ClockWidget.qml    # Time display
│   ├── WorkspaceWidget.qml # Workspace dots
│   ├── NetworkIcon.qml    # Network status
│   ├── BluetoothIcon.qml  # Bluetooth status
│   ├── VolumeIcon.qml     # Volume with scroll
│   └── BatteryIcon.qml    # Battery status with popup
└── services/
    ├── qmldir             # Module definition
    ├── HyprlandService.qml   # Workspace state
    ├── NetworkService.qml    # Connection state
    ├── BluetoothService.qml  # Bluetooth state
    ├── AudioService.qml      # Volume state
    └── BatteryService.qml    # Battery state
```

## Keyboard Shortcuts & Interactions

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
- **Click**: Show popup with battery percentage, status, and level bar

## Architecture

### Three-layer separation

1. **Config layer** (`config/BarConfig.qml`) - All design tokens as readonly properties
2. **Service layer** (`services/*.qml`) - Background state monitoring via polling
3. **Component layer** (`components/*.qml`) - UI components consuming services

### QML modules

Each directory has a `qmldir` file defining its module:
- Components declare themselves in `components/qmldir`
- Services are singletons declared in `services/qmldir`
- Config is a singleton in `config/qmldir`

### State flow

```
External Command → Service (Process) → Property Update → Component UI
```

Example:
```
hyprctl dispatch workspace 2 → HyprlandService.activeWorkspace = 2 → WorkspaceWidget updates dot 2
```

## Troubleshooting

### Icons not showing

Check the debug logs:
```bash
journalctl -f | grep quickshell
```

### Workspace not updating

Verify `HYPRLAND_INSTANCE_SIGNATURE` is set (automatic in Hyprland sessions).

### Bluetooth commands failing

Ensure `bluetoothctl` is installed and the daemon is running:
```bash
sudo systemctl start bluetooth
```

## Portability

To move to another machine:

1. Install dependencies (see above)
2. Copy the entire `bar/` directory
3. Adjust `BarConfig.qml` for your preferences
4. Launch with `quickshell -c ~/.config/quickshell/bar`

## License

MIT

## Credits

Built with [Quickshell](https://quickshell.outfoxxed.me/)
Inspired by minimal bar designs for Hyprland
