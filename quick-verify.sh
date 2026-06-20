#!/bin/bash
# Quick Verification Script for Quickshell Installation
# Checks if all components are properly installed

echo "========================================="
echo "Quickshell Installation Verification"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

# Function to check file existence
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} $1 (missing)"
        ((FAIL++))
        return 1
    fi
}

# Function to check directory existence
check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1/"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} $1/ (missing)"
        ((FAIL++))
        return 1
    fi
}

# Function to check command existence
check_cmd() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 installed"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} $1 not found"
        ((FAIL++))
        return 1
    fi
}

echo "1. System Dependencies"
echo "────────────────────────"
check_cmd quickshell
check_cmd hyprctl
check_cmd hyprland
check_cmd git
check_cmd systemctl
echo ""

echo "2. Quickshell Core Files"
echo "────────────────────────"
check_file ~/.config/quickshell/qmldir
check_file ~/.config/quickshell/theme.json
echo ""

echo "3. Bar Component"
echo "────────────────────────"
check_dir ~/.config/quickshell/bar
check_file ~/.config/quickshell/bar/shell.qml
check_file ~/.config/quickshell/bar/qmldir
check_file ~/.config/quickshell/bar/config/BarConfig.qml
check_dir ~/.config/quickshell/bar/components
check_dir ~/.config/quickshell/bar/services
echo ""

echo "4. Settings Component"
echo "────────────────────────"
check_dir ~/.config/quickshell/settings
check_file ~/.config/quickshell/settings/shell.qml
check_file ~/.config/quickshell/settings/qmldir
check_file ~/.config/quickshell/settings/config/ThemeConfig.qml
check_file ~/.config/quickshell/settings/config/WallpaperConfig.qml
check_dir ~/.config/quickshell/settings/components
echo ""

echo "5. Login Component"
echo "────────────────────────"
check_dir ~/.config/quickshell/login
check_file ~/.config/quickshell/login/LoginScreen.qml
check_file ~/.config/quickshell/login/qmldir
echo ""

echo "6. System Files"
echo "────────────────────────"
check_file /usr/share/quickshell/LoginScreen.qml
check_file /usr/share/quickshell/theme.json
check_file /usr/share/quickshell/qmldir
echo ""

echo "7. Hyprland Configuration"
echo "────────────────────────"
if [ -f ~/.config/hypr/hyprland.conf ]; then
    if grep -q "quickshell -c ~/.config/quickshell/bar" ~/.config/hypr/hyprland.conf; then
        echo -e "${GREEN}✓${NC} Bar auto-start configured"
        ((PASS++))
    else
        echo -e "${YELLOW}⚠${NC} Bar auto-start not found in hyprland.conf"
        ((WARN++))
    fi
else
    echo -e "${YELLOW}⚠${NC} hyprland.conf not found"
    ((WARN++))
fi
echo ""

echo "========================================="
echo "Summary"
echo "========================================="
echo -e "✓ Passed: $PASS"
if [ $FAIL -gt 0 ]; then
    echo -e "✗ Failed: $FAIL"
fi
if [ $WARN -gt 0 ]; then
    echo -e "⚠ Warnings: $WARN"
fi
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "You can now test the components:"
    echo "  • Test bar:  quickshell -c ~/.config/quickshell/bar"
    echo "  • Test settings: quickshell -c ~/.config/quickshell/settings"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some checks failed!${NC}"
    echo ""
    echo "Fix issues and try again, or see INSTALLATION_GUIDE.md for help"
    echo ""
    exit 1
fi
