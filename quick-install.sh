#!/bin/bash
# Quick Installation Script for Quickshell Configuration
# This script automates most of the installation steps

set -e

echo "========================================="
echo "Quickshell Auto-Installation"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo "ℹ $1"
}

# Step 1: Install system dependencies
echo "Step 1: Installing system dependencies..."
echo "Installing Quickshell, Hyprland utilities, and required tools..."

sudo pacman -S --noconfirm quickshell hyprctl socat networkmanager bluez-utils wireplumber upower impala bluetui wiremix kitty ttf-jetbrains-mono-nerd 2>&1 | grep -v "already up to date" || true

print_success "System dependencies installed"

# Step 2: Verify Hyprland
echo ""
echo "Step 2: Verifying Hyprland installation..."
if command -v hyprland &> /dev/null; then
    print_success "Hyprland is installed: $(hyprland --version)"
else
    print_error "Hyprland not found! Please install it first."
    exit 1
fi

# Step 3: Ensure config directory exists
echo ""
echo "Step 3: Setting up config directory..."
mkdir -p ~/.config/quickshell
print_success "Config directory created"

# Step 4: Clone repository (if git is available)
echo ""
echo "Step 4: Cloning repository..."
if git rev-parse --git-dir > /dev/null 2>&1; then
    if [ -d ~/.config/quickshell ] && [ -d ~/.config/quickshell/.git ]; then
        print_info "Repository already cloned, pulling latest changes..."
        cd ~/.config/quickshell
        git pull
    else
        print_info "Cloning repository from GitHub..."
        git clone git@github.com:ngeran/velocity.git ~/.config/quickshell
    fi
    print_success "Repository cloned"
else
    print_warning "Git not found. Skipping clone."
    print_info "Please manually clone the repository:"
    print_info "  git clone git@github.com:ngeran/velocity.git ~/.config/quickshell"
fi

# Step 5: Install Bar Component
echo ""
echo "Step 5: Installing Bar component..."
if [ -d ~/.config/quickshell/bar ]; then
    [ -d ~/.config/quickshell/bar.backup ] && rm -rf ~/.config/quickshell/bar.backup
    cp -r ~/.config/quickshell/bar ~/.config/quickshell/
    print_success "Bar component installed"
else
    print_error "Bar directory not found! Check your repository clone."
fi

# Step 6: Install Settings Component
echo ""
echo "Step 6: Installing Settings component..."
if [ -d ~/.config/quickshell/settings ]; then
    [ -d ~/.config/quickshell/settings.backup ] && rm -rf ~/.config/quickshell/settings.backup
    cp -r ~/.config/quickshell/settings ~/.config/quickshell/
    print_success "Settings component installed"
else
    print_error "Settings directory not found! Check your repository clone."
fi

# Step 7: Install Login Component
echo ""
echo "Step 7: Installing Login component..."
if [ -d ~/.config/quickshell/login ]; then
    [ -d ~/.config/quickshell/login.backup ] && rm -rf ~/.config/quickshell/login.backup
    cp -r ~/.config/quickshell/login ~/.config/quickshell/
    print_success "Login component installed"
else
    print_error "Login directory not found! Check your repository clone."
fi

# Step 8: Create system files for login
echo ""
echo "Step 8: Setting up system-wide login files..."
sudo mkdir -p /usr/share/quickshell

if [ -f /usr/share/quickshell/LoginScreen.qml ]; then
    print_info "LoginScreen.qml already exists in system directory"
else
    if [ -f ~/.config/quickshell/login/LoginScreen.qml ]; then
        sudo cp ~/.config/quickshell/login/LoginScreen.qml /usr/share/quickshell/
        print_success "LoginScreen.qml copied to system directory"
    else
        print_warning "LoginScreen.qml not found in user config"
    fi
fi

# Create theme.json if it doesn't exist
if [ ! -f /usr/share/quickshell/theme.json ]; then
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
    print_success "theme.json created"
fi

# Set permissions
sudo chown -R root:greeter /usr/share/quickshell/
print_success "System permissions set"

# Step 9: Configure Hyprland (optional)
echo ""
echo "Step 9: Configuring Hyprland auto-start..."
if [ -f ~/.config/hypr/hyprland.conf ]; then
    if ! grep -q "quickshell -c ~/.config/quickshell/bar" ~/.config/hypr/hyprland.conf; then
        print_info "Adding Quickshell auto-start to Hyprland config..."
        echo "exec-once = quickshell -c ~/.config/quickshell/bar" >> ~/.config/hypr/hyprland.conf
        print_success "Hyprland config updated"
    else
        print_info "Quickshell auto-start already configured"
    fi
else
    print_warning "Hyprland config not found at ~/.config/hypr/hyprland.conf"
    print_info "Add 'exec-once = quickshell -c ~/.config/quickshell/bar' manually"
fi

# Step 10: Test installation
echo ""
echo "Step 10: Testing installation..."
echo "========================================="
echo ""

# Test Quickshell command
if command -v quickshell &> /dev/null; then
    print_success "Quickshell is installed: $(quickshell --version)"
else
    print_error "Quickshell not found! Please run: sudo pacman -S quickshell"
fi

# Test bar files
if [ -f ~/.config/quickshell/bar/shell.qml ]; then
    print_success "Bar component files found"
else
    print_error "Bar component files missing"
fi

# Test settings files
if [ -f ~/.config/quickshell/settings/shell.qml ]; then
    print_success "Settings component files found"
else
    print_error "Settings component files missing"
fi

# Test login files
if [ -f ~/.config/quickshell/login/LoginScreen.qml ]; then
    print_success "Login component files found"
else
    print_error "Login component files missing"
fi

echo ""
echo "========================================="
echo "✅ Installation Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Test the bar manually: quickshell -c ~/.config/quickshell/bar"
echo "2. Test the settings: quickshell -c ~/.config/quickshell/settings"
echo "3. Reboot to test the login screen (if using greetd)"
echo "4. Review INSTALLATION_GUIDE.md for detailed documentation"
echo ""
echo "Manual configuration required:"
echo "  • Configure Hyprland keybinds in ~/.config/hypr/hyprland.conf"
echo "  • Set up greetd if you want a graphical login screen"
echo "  • Customize themes in ~/.config/quickshell/settings/config/ThemeConfig.qml"
echo ""
