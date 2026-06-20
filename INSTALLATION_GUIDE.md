# Quickshell Installation Guide

Complete step-by-step guide to install and configure the Quickshell desktop environment for Hyprland.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [System Dependencies](#system-dependencies)
3. [Installation Overview](#installation-overview)
4. [Step 1: Install Hyprland Dependencies](#step-1-install-hyprland-dependencies)
5. [Step 2: Clone Repository](#step-2-clone-repository)
6. [Step 3: Install Quickshell Core](#step-3-install-quickshell-core)
7. [Step 4: Install Bar Component](#step-4-install-bar-component)
8. [Step 5: Install Settings Component](#step-5-install-settings-component)
9. [Step 6: Install Login Component](#step-6-install-login-component)
10. [Step 7: Configure Hyprland](#step-7-configure-hyprland)
11. [Step 8: Test Installation](#step-8-test-installation)
12. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have:

- ✅ **Arch Linux** (or Arch-based system)
- ✅ **Hyprland** installed and working
- ✅ **sudo** access
- ✅ **Terminal access**
- ✅ **Git** installed

Verify Hyprland:
```bash
hyprland --version
```

---

## System Dependencies

### Required System Tools

```bash
# Quickshell framework
sudo pacman -S --noconfirm quickshell

# Hyprland IPC utilities
sudo pacman -S --noconfirm hyprctl socat

# Network and Bluetooth
sudo pacman -S --noconfirm networkmanager bluez-utils

# Audio system (PipeWire)
sudo pacman -S --noconfirm wireplumber upower

# TUI tools for status icons
sudo pacman -S --noconfirm impala bluetui wiremix kitty

# Fonts (JetBrains Mono for terminal aesthetic)
sudo pacman -S --noconfirm ttf-jetbrains-mono-nerd
```

---

## Installation Overview

The Quickshell configuration consists of **four main components**:

```
~/.config/quickshell/
├── bar/           # Top status bar (workspace, clock, icons)
├── settings/      # Settings UI with theme switcher
├── login/         # Login screen (for greetd)
└── components/    # Shared UI components
```

---

## Step 1: Install Hyprland Dependencies

If you don't have Hyprland installed, install it first:

```bash
# Create a temporary directory
mkdir -p ~/hypr-install
cd ~/hypr-install

# Clone Hyprland from AUR (if using yay)
yay -S hyprland --needed --remake

# Or clone and build from source
git clone https://github.com/hyprwm/Hyprland.git
cd Hyprland
meson setup build
cd build
ninja
sudo ninja install

# Go back to home
cd ~
rm -rf ~/hypr-install
```

---

## Step 2: Clone Repository

Clone the Quickshell configuration repository:

```bash
# Create config directory if it doesn't exist
mkdir -p ~/.config/quickshell

# Clone the repository
git clone git@github.com:ngeran/velocity.git ~/.config/quickshell

# Or if you prefer HTTPS:
# git clone https://github.com/ngeran/velocity.git ~/.config/quickshell
```

Verify the clone:
```bash
ls -la ~/.config/quickshell/
# Expected: bar/, settings/, login/, components/, shell.qml, qmldir
```

---

## Step 3: Install Quickshell Core

Install Quickshell framework:

```bash
sudo pacman -S --noconfirm quickshell
```

### Verify Installation

```bash
quickshell --version
# Expected output: quickshell X.Y.Z
```

---

## Step 4: Install Bar Component

The bar component provides the top status bar with workspace buttons, clock, and system tray icons.

### Copy Bar Files

```bash
# Backup existing if present
[ -d ~/.config/quickshell/bar ] && mv ~/.config/quickshell/bar ~/.config/quickshell/bar.backup

# Copy bar component
cp -r ~/.config/quickshell/bar ~/.config/quickshell/

# Verify bar files
ls -la ~/.config/quickshell/bar/
# Expected: shell.qml, config/, components/, services/, qmldir
```

### Test Bar Launch

```bash
# Test bar manually
quickshell -c ~/.config/quickshell/bar

# Press Ctrl+C to stop
```

### Configure Auto-Start

Edit `~/.config/hypr/hyprland.conf` and add:

```ini
# Add this line to exec-once
exec-once = quickshell -c ~/.config/quickshell/bar
```

---

## Step 5: Install Settings Component

The settings component provides a graphical settings UI with theme switcher and wallpaper picker.

### Copy Settings Files

```bash
# Backup existing if present
[ -d ~/.config/quickshell/settings ] && mv ~/.config/quickshell/settings ~/.config/quickshell/settings.backup

# Copy settings component
cp -r ~/.config/quickshell/settings ~/.config/quickshell/

# Verify settings files
ls -la ~/.config/quickshell/settings/
# Expected: shell.qml, components/, config/, qmldir
```

### Test Settings Launch

```bash
# Test settings manually
quickshell -c ~/.config/quickshell/settings

# Press Ctrl+C to stop
```

---

## Step 6: Install Login Component

The login component provides a graphical login screen for greetd (SDDM replacement).

### Copy Login Files

```bash
# Backup existing if present
[ -d ~/.config/quickshell/login ] && mv ~/.config/quickshell/login ~/.config/quickshell/login.backup

# Copy login component
cp -r ~/.config/quickshell/login ~/.config/quickshell/

# Verify login files
ls -la ~/.config/quickshell/login/
# Expected: LoginScreen.qml, components/, qmldir
```

### Install System-Wide Files

```bash
# Create system directory
sudo mkdir -p /usr/share/quickshell

# Copy LoginScreen.qml to system location
sudo cp /usr/share/quickshell/LoginScreen.qml /usr/share/quickshell/

# Copy theme.json
cat > /tmp/theme.json << 'EOF'
{
    "version": "1.0",
    "theme": {
        "name": "Obsidian Core",
        "primary": "#8E9192",
        "background": "#000000",
        "font": "JetBrains Mono"
    }
}
EOF
sudo tee /usr/share/quickshell/theme.json > /dev/null
```

---

## Step 7: Configure Hyprland

### Configure Quickshell Auto-Start

Edit `~/.config/hypr/hyprland.conf`:

```ini
# Enable Quickshell bar
exec-once = quickshell -c ~/.config/quickshell/bar

# Enable Quickshell settings window (optional - toggled via keybind)
exec-once = quickshell -c ~/.config/quickshell/settings
```

### Configure Greetd (Login Screen)

**Option A: Use greetd (recommended)**

```bash
# Install greetd
sudo pacman -S --noconfirm greetd

# Create greeter user
sudo useradd -m -s /bin/bash greeter
sudo usermod -aG video greeter

# Create obsidian-greet helper
sudo tee /usr/local/bin/obsidian-greet > /dev/null << 'EOF'
#!/bin/bash
# Wait for user input
echo -n "Username: " && read -r USERNAME
echo -n "Password: " && read -rs PASSWORD
echo

# Authenticate using PAM
echo "$PASSWORD" | sudo -u "$USERNAME" pamlogin "$USERNAME" "obsidian-login"

# If PAM succeeds, start the session
if [ $? -eq 0 ]; then
    exec $*
else
    echo "Login failed"
    exit 1
fi
EOF

sudo chmod +x /usr/local/bin/obsidian-greet
```

Update `/etc/greetd/config.toml`:

```toml
[terminal]
vt = 1

[default_session]
command = "quickshell -c /usr/share/quickshell"
user = "greeter"
```

**Option B: Use Hyprland as default session (simpler)**

```bash
# Update Hyprland default session
echo "[default_session]
command = "hyprland"
user = "ngeran" >> /etc/greetd/config.toml
```

---

## Step 8: Test Installation

### 1. Test Bar Component

```bash
# Stop any running Quickshell instances
pkill -f quickshell

# Start bar
quickshell -c ~/.config/quickshell/bar

# Expected: Top bar appears with workspace dots, clock, and icons
```

### 2. Test Settings Component

```bash
# Stop bar
pkill -f quickshell

# Start settings
quickshell -c ~/.config/quickshell/settings

# Expected: Settings window appears with theme switcher, wallpaper picker
```

### 3. Test Theme Switcher

In the settings UI:
1. Open Settings application
2. Navigate to "Themes" tab
3. Click on different themes to switch
4. Verify bar and settings UI update colors

### 4. Test Wallpaper Picker

In the settings UI:
1. Navigate to "Wallpaper" tab
2. Click different wallpapers
3. Verify background changes

### 5. Test Bar Components

**Workspace Icons:**
- Click on workspace dots to switch workspaces

**Clock:**
- Verify time updates every second

**Network Icon (W):**
- Click to launch `impala` network TUI

**Bluetooth Icon (B):**
- Click to launch `bluetui` bluetooth TUI

**Volume Icon (V):**
- Scroll up/down to adjust volume
- Click to launch `wiremix` audio mixer

**Battery Icon (BATT):**
- Click to see battery percentage and status

---

## Troubleshooting

### Quickshell Not Starting

```bash
# Enable debug mode
quickshell --debug --inspect -c ~/.config/quickshell/bar

# Check for errors in journal
journalctl -f | grep quickshell
```

### Bar Not Showing Icons

Verify system services are running:
```bash
# NetworkManager
systemctl status NetworkManager

# Bluetooth
systemctl status bluetooth

# PipeWire
systemctl status wireplumber
```

### Theme Not Updating

```bash
# Check if theme service is running
ps aux | grep ThemeService

# Restart theme service
# (Settings UI will auto-restart on tab change)
```

### Greetd Login Screen Issues

```bash
# Check greetd status
systemctl status greetd

# View greetd logs
journalctl -u greetd -f

# Restart greetd
sudo systemctl restart greetd
```

### Component Not Found

Verify all required files exist:
```bash
# Check bar
ls ~/.config/quickshell/bar/{shell.qml,qmldir,config/,components/,services/}

# Check settings
ls ~/.config/quickshell/settings/{shell.qml,qmldir,components/,config/}

# Check login
ls ~/.config/quickshell/login/{LoginScreen.qml,qmldir}
```

### Permission Issues

```bash
# Ensure correct ownership
sudo chown -R ngeran:ngeren ~/.config/quickshell/bar
sudo chown -R ngeran:ngeren ~/.config/quickshell/settings
sudo chown -R ngeran:ngeren ~/.config/quickshell/login

# Ensure system files are root-owned
sudo chown -R root:greeter /usr/share/quickshell/
```

---

## Next Steps

1. **Customize Bar**
   - Edit `~/.config/quickshell/bar/config/BarConfig.qml` to adjust colors, height, workspace count

2. **Customize Themes**
   - Edit `~/.config/quickshell/settings/config/ThemeConfig.qml` to add custom themes

3. **Configure Shortcuts**
   - Add your preferred keybinds in `~/.config/hypr/hyprland.conf`

4. **Set Default Wallpaper**
   - Edit `~/.config/quickshell/settings/config/WallpaperConfig.qml` to set default wallpaper

5. **Auto-Start Settings UI**
   - Add `exec-once = quickshell -c ~/.config/quickshell/settings` to Hyprland config for persistent settings window

---

## Resources

- **Quickshell Documentation**: https://quickshell.outfoxxed.me/
- **Hyprland Documentation**: https://wiki.hyprland.org/
- **Project Repository**: https://github.com/ngeran/velocity
- **Design System**: See `~/nikos-qml-SKILL.md` for component design patterns

---

## Support

If you encounter issues:
1. Check the [Troubleshooting](#troubleshooting) section above
2. Review logs: `journalctl -xe`
3. Enable debug mode and check output
4. Open an issue on GitHub: https://github.com/ngeran/velocity/issues
