#!/bin/bash
# Validate Quickshell system configuration

echo "========================================="
echo "Quickshell System Config Validation"
echo "========================================="
echo ""

# Check required files
echo "Checking required files..."
files_to_check=(
    "/usr/share/quickshell/LoginScreen.qml"
    "/usr/share/quickshell/login/LoginScreen.qml"
    "/usr/share/quickshell/theme.json"
    "/usr/share/quickshell/qmldir"
    "/etc/greetd/config.toml"
)

all_found=true
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file - MISSING"
        all_found=false
    fi
done

echo ""
echo "Checking greetd config..."
if grep -q 'command = "quickshell -c /usr/share/quickshell"' /etc/greetd/config.toml; then
    echo "  ✅ greetd config points to /usr/share/quickshell"
else
    echo "  ❌ greetd config does not point to /usr/share/quickshell"
    echo "     Current config:"
    grep 'command' /etc/greetd/config.toml
    all_found=false
fi

echo ""
echo "Checking directory structure..."
if [ -f "/usr/share/quickshell/LoginScreen.qml" ] && [ -f "/usr/share/quickshell/login/LoginScreen.qml" ]; then
    echo "  ✅ LoginScreen.qml in both locations"
else
    echo "  ❌ LoginScreen.qml not in both locations"
    all_found=false
fi

echo ""
echo "========================================="
if [ "$all_found" = true ]; then
    echo "✅ All checks passed!"
    echo "========================================="
    echo ""
    echo "You can now reboot:"
    echo "  systemctl reboot"
else
    echo "❌ Some checks failed!"
    echo "========================================="
    echo ""
    echo "Run the complete fix script:"
    echo "  ./fix-complete.sh"
fi
