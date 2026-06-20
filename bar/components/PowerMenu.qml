// =============================================================================
// PowerMenu.qml — System Power Menu (Lock, Suspend, Reboot, Shutdown)
// =============================================================================
//
// OLED-minimal power menu matching your QuickShell bar aesthetic.
// Features:
//   - Icon + text buttons with hover effects
//   - Keyboard navigation (Arrow keys, Enter, Escape)
//   - Smooth animations (120ms fade/scale)
//   - Zero-radius corners, pure black background
//   - Obsidian teal accent (#00dce5")
//
// =============================================================================

import QtQuick
import Quickshell.Io
import "../config" as Config

Item {
    id: root

    // =========================================================================
    // CONFIGURATION
    // =========================================================================

    property int buttonHeight: 40
    property int buttonSpacing: 4
    property int menuWidth: 200
    property int menuPadding: 8

    // =========================================================================
    // APPEARANCE (matches your OLED-minimal aesthetic)
    // =========================================================================

    width: menuWidth
    height: menuColumn.height + (menuPadding * 2)

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        border.color: Config.BarConfig.colorAccent
        border.width: 1
        radius: 0

        // Fade in/out animation
        opacity: root.visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        // Scale animation
        scale: root.visible ? 1.0 : 0.95
        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        // Transform origin for scaling
        transformOrigin: Item.Top
    }

    // =========================================================================
    // MENU ITEMS
    // =========================================================================

    Column {
        id: menuColumn
        anchors {
            fill: parent
            margins: menuPadding
        }
        spacing: buttonSpacing

        // ── LOCK ────────────────────────────────────────────────────────

        PowerMenuItem {
            width: parent.width
            height: buttonHeight
            iconText: "󰌾"
            labelText: "Lock"
            itemIndex: 0
            selectedIndex: root.selectedIndex

            onItemClicked: {
                executeCommand("loginctl", ["lock-session"])
                root.visible = false
            }
        }

        // ── SUSPEND ──────────────────────────────────────────────────────

        PowerMenuItem {
            width: parent.width
            height: buttonHeight
            iconText: "󰏜"
            labelText: "Suspend"
            itemIndex: 1
            selectedIndex: root.selectedIndex

            onItemClicked: {
                executeCommand("systemctl", ["suspend"])
                root.visible = false
            }
        }

        // ── REBOOT ───────────────────────────────────────────────────────

        PowerMenuItem {
            width: parent.width
            height: buttonHeight
            iconText: "󰑐"
            labelText: "Reboot"
            itemIndex: 2
            selectedIndex: root.selectedIndex

            onItemClicked: {
                executeCommand("systemctl", ["reboot"])
                root.visible = false
            }
        }

        // ── SHUTDOWN ─────────────────────────────────────────────────────

        PowerMenuItem {
            width: parent.width
            height: buttonHeight
            iconText: "󰐥"
            labelText: "Shutdown"
            itemIndex: 3
            selectedIndex: root.selectedIndex

            onItemClicked: {
                executeCommand("systemctl", ["poweroff"])
                root.visible = false
            }
        }
    }

    // =========================================================================
    // KEYBOARD NAVIGATION
    // =========================================================================

    property int selectedIndex: 0
    property int itemCount: 4

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.visible = false
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            if (event.key === Qt.Key_Up) {
                selectedIndex = (selectedIndex > 0) ? selectedIndex - 1 : itemCount - 1
            } else {
                selectedIndex = (selectedIndex < itemCount - 1) ? selectedIndex + 1 : 0
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            var item = menuColumn.children[selectedIndex]
            if (item) {
                item.itemClicked()
            }
            event.accepted = true
        }
    }

    // =========================================================================
    // COMMAND EXECUTION
    // =========================================================================

    Process {
        id: commandProcess
        command: []
        running: false

        onRunningChanged: {
            if (!running && exitCode !== 0) {
                console.log("[PowerMenu] Command failed with exit code:", exitCode)
            }
        }
    }

    function executeCommand(program, args) {
        console.log("[PowerMenu] Executing:", program, args.join(" "))
        commandProcess.command = [program].concat(args)
        commandProcess.running = true
    }

    // =========================================================================
    // FOCUS MANAGEMENT
    // =========================================================================

    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0
            forceActiveFocus()
        }
    }

    Component.onCompleted: {
        console.log("[PowerMenu] Component loaded")
    }
}
