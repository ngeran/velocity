# Quick Start Guide

Get Quickshell up and running in **5 minutes**.

---

## ⚡ Fast Installation

### Option 1: Automatic (Recommended)

```bash
cd ~/.config/quickshell
./quick-install.sh
```

This script will:
- ✅ Install all system dependencies
- ✅ Clone repository (if not already cloned)
- ✅ Install bar, settings, and login components
- ✅ Configure system files
- ✅ Update Hyprland auto-start config

### Option 2: Manual Installation

If you prefer manual control, follow the detailed guide:

```bash
# 1. Install dependencies
sudo pacman -S --noconfirm quickshell hyprctl socat networkmanager bluez-utils wireplumber upower impala bluetui wiremix kitty ttf-jetbrains-mono-nerd

# 2. Clone repository (if not already done)
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

## 🚀 Quick Test

### Test Bar (Top Status Bar)

```bash
# Stop any running Quickshell
pkill -f quickshell

# Launch bar
quickshell -c ~/.config/quickshell/bar

# Expected: Top bar appears with workspace dots, clock, and icons
```

**Interactions:**
- Click workspace dots → Switch workspaces
- Click W icon → Open impala (network TUI)
- Click B icon → Open bluetui (bluetooth TUI)
- Scroll V icon → Adjust volume
- Click BATT icon → See battery status

### Test Settings (Theme Switcher)

```bash
# Stop bar
pkill -f quickshell

# Launch settings
quickshell -c ~/.config/quickshell/settings

# Expected: Settings window appears with theme switcher and wallpaper picker
```

**Interactions:**
- Navigate to "Themes" tab → Click different themes to switch
- Navigate to "Wallpaper" tab → Click different wallpapers
- All changes apply immediately to bar and settings UI

### Test Login Screen

If using greetd, reboot to see the graphical login screen:
```bash
reboot
```

After login, the Hyprland bar will appear with Quickshell components.

---

## 🔧 Basic Configuration

### Customize Bar Appearance

Edit `~/.config/quickshell/bar/config/BarConfig.qml`:

```qml
// Change bar height
readonly property int barHeight: 28

// Change accent color
readonly property color colorAccent: "#00dce5"  // Teal, Blue, Red, etc.

// Change workspace count
readonly property int workspaceCount: 5
```

### Set Default Wallpaper

Edit `~/.config/quickshell/settings/config/WallpaperConfig.qml`:

```qml
property string defaultWallpaper: "~/.config/hypr/wallpaper.png"
```

### Add Keybinds

Edit `~/.config/hypr/hyprland.conf`:

```ini
# Open settings window
bind = SUPER, RETURN, exec, quickshell -c ~/.config/quickshell/settings
```

---

## 📚 Resources

- **Full Installation Guide**: See `INSTALLATION_GUIDE.md`
- **Component Documentation**: See `nikos-qml-SKILL.md`
- **Quick Verification**: Run `./quick-verify.sh`
- **Auto-Installation**: Run `./quick-install.sh`

---

## 🐛 Troubleshooting

### Quickshell won't start

```bash
# Enable debug mode
quickshell --debug --inspect -c ~/.config/quickshell/bar

# Check for errors
journalctl -f | grep quickshell
```

### Icons not showing

```bash
# Check system services
systemctl status NetworkManager
systemctl status bluetooth
systemctl status wireplumber
```

### Bar doesn't appear after reboot

Make sure Hyprland config has auto-start enabled:
```bash
grep "quickshell" ~/.config/hypr/hyprland.conf
```

---

## 📖 Next Steps

1. **Customize themes** – Edit `~/.config/quickshell/settings/config/ThemeConfig.qml`
2. **Add more components** – See `nikos-qml-SKILL.md` for design patterns
3. **Configure shortcuts** – Edit `~/.config/hypr/hyprland.conf`
4. **Set up login screen** – Follow [greetd setup](INSTALLATION_GUIDE.md#step-7-configure-greetd-login-screen)

---

## ✨ Features

### Bar Component
- ✅ Workspace navigation (5-9 workspaces supported)
- ✅ Live clock with date
- ✅ Network status with impala integration
- ✅ Bluetooth status with bluetui integration
- ✅ Volume control with wiremix integration
- ✅ Battery status with popup

### Settings Component
- ✅ Theme switcher (multiple built-in themes)
- ✅ Wallpaper picker
- ✅ Real-time preview
- ✅ Settings persistence

### Login Component
- ✅ Full-screen login screen
- ✅ PAM authentication support
- ✅ User avatar display
- ✅ Power actions
- ✅ Large clock display

---

## 🆘 Need Help?

1. Run verification: `./quick-verify.sh`
2. Check logs: `journalctl -xe | grep quickshell`
3. Read full guide: `INSTALLATION_GUIDE.md`
4. Open issue: https://github.com/ngeran/velocity/issues
