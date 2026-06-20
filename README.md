# Obsidian Core - Quickshell Desktop Environment

A complete Quickshell configuration for Hyprland with theme switcher, settings UI, and graphical login screen.

---

## 📋 Overview

This configuration provides:

- **Bar Component**: Top status bar with workspaces, clock, and system tray icons
- **Settings Component**: Graphical settings UI with theme switcher and wallpaper picker
- **Login Component**: Full-screen login screen for greetd (SDDM replacement)
- **Components Library**: Shared UI components (BentoCard, NetworkRing, etc.)

**Design Language**: Pure black background (#000000) · Obsidian teal accent (#00dce5) · JetBrains Mono font

---

## 🚀 Quick Start

### Automated Installation (Recommended)

```bash
cd ~/.config/quickshell
./quick-install.sh
```

### Manual Installation

```bash
# 1. Install dependencies
sudo pacman -S --noconfirm quickshell hyprctl socat networkmanager bluez-utils wireplumber upower impala bluetui wiremix kitty ttf-jetbrains-mono-nerd

# 2. Clone repository
git clone git@github.com:ngeran/velocity.git ~/.config/quickshell

# 3. Copy components
cp -r ~/.config/quickshell/bar ~/.config/quickshell/
cp -r ~/.config/quickshell/settings ~/.config/quickshell/
cp -r ~/.config/quickshell/login ~/.config/quickshell/

# 4. Configure Hyprland
echo "exec-once = quickshell -c ~/.config/quickshell/bar" >> ~/.config/hypr/hyprland.conf

# 5. Verify installation
./quick-verify.sh
```

---

## 📚 Documentation

### Installation Guides

- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Detailed step-by-step guide

### Reference Documentation

- **[nikos-qml-SKILL.md](nikos-qml-SKILL.md)** - Component design patterns and API reference
- **[bar/README.md](bar/README.md)** - Bar component documentation
- **[bar/CLAUDE.md](bar/CLAUDE.md)** - Bar architecture and implementation details

---

## 🔧 Features

### Bar Component (`bar/`)

Top status bar with:
- ✅ **Workspace Navigation** - Click dots to switch workspaces (5-9 supported)
- ✅ **Live Clock** - Real-time clock with date display
- ✅ **Network Icon (W)** - Status display + impala TUI launcher
- ✅ **Bluetooth Icon (B)** - Status display + bluetui TUI launcher
- ✅ **Volume Icon (V)** - Scroll to adjust + wiremix mixer launcher
- ✅ **Battery Icon (BATT)** - Status display + percentage popup

**Architecture**:
- Config layer: `config/BarConfig.qml` (design tokens)
- Service layer: `services/*.qml` (background state monitoring)
- Component layer: `components/*.qml` (UI elements)

### Settings Component (`settings/`)

Graphical settings UI with:
- ✅ **Theme Switcher** - Multiple built-in themes with real-time preview
- ✅ **Wallpaper Picker** - Select and apply wallpapers
- ✅ **Settings Persistence** - Changes saved automatically
- ✅ **Live Preview** - See changes before applying

**Architecture**:
- Config layer: `config/ThemeConfig.qml` (canonical theme source)
- Service layer: `services/ThemeService.qml` (theme management)
- Component layer: `components/*.qml` (UI modules)

### Login Component (`login/`)

Full-screen login screen for greetd with:
- ✅ **PAM Authentication** - User password authentication
- ✅ **User Identity** - Avatar display with user name
- ✅ **Large Clock** - Prominent clock display
- ✅ **Power Actions** - Shutdown and reboot buttons
- ✅ **Grid Background** - Aesthetic geometric background

### Components Library (`components/`)

Shared UI components:
- **Colors.qml** - Theme color palette singleton
- **BentoCard.qml** - Reusable card container with border and inset
- **NetworkRing.qml** - Circular gauge for signal strength
- **IdentityWidget.qml** - Avatar + username display
- **ClockWidget.qml** - Self-contained live clock
- **NetworkWidget.qml** - Network monitoring widget
- **CalendarWidget.qml** - Dynamic monthly calendar

---

## 🎨 Customization

### Change Bar Appearance

Edit `~/.config/quickshell/bar/config/BarConfig.qml`:

```qml
readonly property int barHeight: 28
readonly property color colorAccent: "#00dce5"
readonly property int workspaceCount: 5
```

### Change Themes

Edit `~/.config/quickshell/settings/config/ThemeConfig.qml`:

```qml
property var colors: ({
    "primary": "#7c6bf0",
    "accent": "#00dce5",
    // ... more colors
})
```

### Add Keybinds

Edit `~/.config/hypr/hyprland.conf`:

```ini
# Open settings
bind = SUPER, RETURN, exec, quickshell -c ~/.config/quickshell/settings
```

---

## 🧪 Testing

### Test Components Manually

```bash
# Test bar
quickshell -c ~/.config/quickshell/bar

# Test settings
quickshell -c ~/.config/quickshell/settings

# Test login (requires greetd)
reboot
```

### Verify Installation

```bash
./quick-verify.sh
```

---

## 📂 Project Structure

```
~/.config/quickshell/
├── README.md                    # This file
├── QUICKSTART.md                # Quick start guide
├── INSTALLATION_GUIDE.md        # Detailed installation guide
├── quick-install.sh            # Automated installation script
├── quick-verify.sh             # Installation verification script
├── nikos-qml-SKILL.md          # Component design patterns
├── theme.json                  # Theme configuration
├── qmldir                      # Quickshell module definition
│
├── bar/                        # Top status bar component
│   ├── shell.qml               # Entry point
│   ├── config/                 # Configuration
│   │   ├── BarConfig.qml       # Design tokens
│   │   └── qmldir
│   ├── components/             # UI components
│   │   ├── qmldir
│   │   ├── ClockWidget.qml
│   │   ├── WorkspaceWidget.qml
│   │   ├── NetworkIcon.qml
│   │   ├── BluetoothIcon.qml
│   │   ├── VolumeIcon.qml
│   │   └── BatteryIcon.qml
│   └── services/               # Background services
│       ├── qmldir
│       ├── HyprlandService.qml
│       ├── NetworkService.qml
│       ├── BluetoothService.qml
│       ├── AudioService.qml
│       └── BatteryService.qml
│
├── settings/                   # Settings UI component
│   ├── shell.qml               # Entry point
│   ├── components/             # UI components
│   │   ├── ThemeModule.qml
│   │   ├── WallpaperModule.qml
│   │   ├── BentoCard.qml
│   │   └── ThemeInfoCard.qml
│   ├── config/                 # Configuration
│   │   ├── ThemeConfig.qml     # Canonical theme source
│   │   ├── WallpaperConfig.qml
│   │   ├── SettingsConfig.qml
│   │   └── qmldir
│   └── services/               # Background services
│       ├── qmldir
│       ├── ThemeService.qml    # Theme management
│       └── WallpaperService.qml
│
├── login/                      # Login screen component
│   ├── LoginScreen.qml         # Entry point
│   ├── components/             # UI components
│   │   └── qmldir
│   └── qmldir
│
└── components/                 # Shared components library
    ├── Colors.qml              # Theme palette singleton
    ├── BentoCard.qml           # Reusable card container
    ├── NetworkRing.qml         # Circular gauge
    ├── IdentityWidget.qml      # Avatar display
    ├── ClockWidget.qml         # Live clock
    ├── NetworkWidget.qml       # Network widget
    └── CalendarWidget.qml      # Calendar widget
```

---

## 🔌 Dependencies

### Required System Tools

```bash
sudo pacman -S quickshell hyprctl socat
```

### Functional Tools

```bash
sudo pacman -S networkmanager bluez-utils wireplumber
sudo pacman -S ttf-jetbrains-mono-nerd
sudo pacman -S impala bluetui wiremix kitty
```

### Services

```bash
sudo pacman -S greetd  # For login screen
```

### Hyprland

```bash
# Via yay (AUR)
yay -S hyprland

# Or from source
git clone https://github.com/hyprwm/Hyprland.git
cd Hyprland && meson setup build && cd build && ninja && sudo ninja install
```

---

## 🎯 Getting Started

### First-time Setup

1. **Install dependencies**: See `INSTALLATION_GUIDE.md`
2. **Clone repository**: `git clone git@github.com:ngeran/velocity.git ~/.config/quickshell`
3. **Run auto-install**: `./quick-install.sh`
4. **Verify installation**: `./quick-verify.sh`
5. **Test components**: Follow `QUICKSTART.md`

### After Installation

1. **Test bar**: `quickshell -c ~/.config/quickshell/bar`
2. **Test settings**: `quickshell -c ~/.config/quickshell/settings`
3. **Customize**: Edit configuration files as needed
4. **Reboot**: Apply all changes

---

## 📖 Component Documentation

### Bar Component

See [bar/README.md](bar/README.md) for detailed documentation.

### Settings Component

See `settings/config/ThemeConfig.qml` for theme structure and `nikos-qml-SKILL.md` for design patterns.

### Login Component

See `login/LoginScreen.qml` for login screen implementation details.

---

## 🐛 Troubleshooting

### Quickshell Not Starting

```bash
# Enable debug mode
quickshell --debug --inspect -c ~/.config/quickshell/bar

# Check logs
journalctl -f | grep quickshell
```

### Icons Not Showing

```bash
systemctl status NetworkManager
systemctl status bluetooth
systemctl status wireplumber
```

### Bar Not Appearing After Reboot

Verify Hyprland config:
```bash
grep "quickshell" ~/.config/hypr/hyprland.conf
```

See [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) for detailed troubleshooting.

---

## 🆘 Getting Help

1. **Run verification**: `./quick-verify.sh`
2. **Check logs**: `journalctl -xe | grep quickshell`
3. **Read guides**: `QUICKSTART.md` and `INSTALLATION_GUIDE.md`
4. **View documentation**: `nikos-qml-SKILL.md` and `bar/README.md`
5. **Report issues**: https://github.com/ngeran/velocity/issues

---

## 📝 License

See individual files for licensing information.

---

## 🙏 Credits

- **Quickshell**: https://quickshell.outfoxxed.me/
- **Hyprland**: https://wiki.hyprland.org/
- **Design System**: Based on Obsidian terminal aesthetic

---

## 🚦 Status

- ✅ Bar component: Fully functional
- ✅ Settings component: Fully functional
- ✅ Login component: Ready for greetd
- ✅ Theme switcher: Multiple themes supported
- ✅ Wallpaper picker: Integrated with Hyprland

---

**Installation Status**: Ready to install
**Documentation Status**: Complete
**Testing Status**: Verified on Arch Linux
