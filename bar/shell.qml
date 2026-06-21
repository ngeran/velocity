// =============================================================================
// shell.qml — Quickshell bar entry point
// =============================================================================
//
// This is the main entry point for Quickshell. It creates a panel window
// and arranges all UI components.
//
// LAYOUT
//   Left & Right: Handled inside the RowLayout flow.
//   Center: Clock is absolute-positioned relative to the window parent,
//           guaranteeing perfect mathematical centering on your screen.
//
// CUSTOMIZATION
//   All colors and sizes are configured in config/BarConfig.qml
// =============================================================================

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "components" as Components
import "config" as Config

ShellRoot {
    property bool powerMenuVisible: false

    PanelWindow {
        id: panelWindow

        // =========================================================================
        // POSITIONING
        // =========================================================================

        anchors {
            top: true
            left: true
            right: true
        }

        // =========================================================================
        // APPEARANCE (from config)
        // =========================================================================

        implicitHeight: Config.BarConfig.barHeight
        color: Config.BarConfig.colorBackground

        // =========================================================================
        // MAIN LAYOUT (Left and Right Sections)
        // =========================================================================

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // --- LEFT SIDE ---

            Components.ArchLogo {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Config.BarConfig.barPadding
            }

            Components.WorkspaceWidget {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Config.BarConfig.iconSpacing
            }

            // --- HUGE MIDDLE GAP ---
            // This spacer now pushes everything else all the way to the right side
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // --- RIGHT SIDE ---

            Components.NetworkIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 1
            }

            Components.BluetoothIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 1
            }

            Components.VolumeIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 1
            }

            Components.BatteryIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 1
            }

            Item {
                width: Config.BarConfig.barPadding
                Layout.fillHeight: true
            }
        }

        // =========================================================================
        // PERFECTLY CENTERED CLOCK
        // =========================================================================
        // Sitting outside the RowLayout, this anchors directly to the panel window.
        // It will remain dead-center even if you delete all icons on the right.

        Components.ClockWidget {
            anchors.centerIn: parent
        }
    }

    // =========================================================================
    // IPC HANDLERS — External Control
    // =========================================================================

    // Bar visibility toggle (for Hyprland keybind)
    IpcHandler {
        id: barToggleIpc
        target: "barToggle"

        function toggle() {
            panelWindow.visible = !panelWindow.visible
            console.log("[Bar] Visibility toggled:", panelWindow.visible)
        }
    }

    // Lock screen toggle (for Hyprland keybind)
    IpcHandler {
        id: lockScreenIpc
        target: "lockScreenToggle"

        function toggle() {
            lockScreen.locked = !lockScreen.locked
            console.log("[LockScreen] Toggled via IPC:", lockScreen.locked)
        }

        function lock() {
            lockScreen.locked = true
            console.log("[LockScreen] Locked via IPC")
        }

        function unlock() {
            lockScreen.locked = false
            console.log("[LockScreen] Unlocked via IPC")
        }
    }

    // Helper function to find child by objectName
    function findChild(name) {
        function search(item) {
            if (!item) return null
            if (item.objectName === name) return item
            if (item.children && item.children.length > 0) {
                for (let i = 0; i < item.children.length; i++) {
                    const result = search(item.children[i])
                    if (result) return result
                }
            }
            return null
        }
        return search(panelWindow)
    }

    // =========================================================================
    // LOCK SCREEN OVERLAY
    // =========================================================================

    Components.LockScreen {
        id: lockScreen
    }

    // =========================================================================
    // POWER MENU OVERLAY
    // =========================================================================
    // PowerMenu is wrapped in a full-screen transparent PanelWindow (the same
    // pattern LockScreen uses) so it gets a real render surface. An Item placed
    // directly in ShellRoot never lays out (content height was 0 → "200 x 16"),
    // which is why the menu never appeared before.

    PanelWindow {
        id: powerMenuWindow
        visible: powerMenuVisible

        // Full-screen transparent overlay.
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        // Click anywhere outside the menu to dismiss it.
        MouseArea {
            anchors.fill: parent
            onClicked: {
                powerMenuVisible = false
            }
        }

        Components.PowerMenu {
            id: powerMenu

            // Position below the bar, right-aligned with a 40px margin.
            anchors {
                top: parent.top
                right: parent.right
                topMargin: Config.BarConfig.barHeight + 12
                rightMargin: 40
            }

            Keys.onEscapePressed: {
                powerMenuVisible = false
            }

            Component.onCompleted: {
                console.log("[PowerMenu] Component loaded, size:", width, "x", height)
            }

            onVisibleChanged: {
                console.log("[PowerMenu] Visible changed:", visible)
                if (visible) {
                    forceActiveFocus()
                }
            }
        }
    }

    // =========================================================================
    // DESKTOP CLOCK OVERLAY (Hidden by default - toggle with keybind)
    // =========================================================================

    property bool desktopClockVisible: false

    PanelWindow {
        id: desktopClockWindow

        // Full screen overlay
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"
        visible: desktopClockVisible

        Components.DesktopClock {
            id: desktopClock
            anchors.centerIn: parent
        }
    }

    // IPC handler for desktop clock toggle
    IpcHandler {
        id: desktopClockIpc
        target: "desktopClockToggle"

        function toggle() {
            desktopClockVisible = !desktopClockVisible
            console.log("[DesktopClock] Toggled via IPC:", desktopClockVisible)
        }
    }

    // =========================================================================
    // HOVER POPUP OVERLAY SYSTEM
    // =========================================================================

    property var hoverPopupData: ({
        visible: false,
        text: "",
        subtext: "",
        details: [],
        x: 0,
        y: 0
    })

    // Hover popup overlay (displays below the bar)
    Rectangle {
        visible: hoverPopupData.visible
        x: hoverPopupData.x
        y: hoverPopupData.y + Config.BarConfig.barHeight + 8

        width: popupColumn.implicitWidth + 24
        height: popupColumn.implicitHeight + 16

        color: Config.ThemeConfig.colors.surface
        border.color: Config.BarConfig.colorAccent
        border.width: 1
        radius: 8

        opacity: hoverPopupData.visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        Column {
            id: popupColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 12
                leftMargin: 12
                rightMargin: 12
            }
            spacing: 8

            Text {
                text: hoverPopupData.text
                font.family: "JetBrains Mono"
                font.pixelSize: 14
                font.bold: true
                color: Config.ThemeConfig.colors.text
            }

            Text {
                text: hoverPopupData.subtext
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                color: Config.ThemeConfig.colors.textDim
            }

            Repeater {
                model: hoverPopupData.details
                delegate: Text {
                    text: modelData
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    color: Config.ThemeConfig.colors.text
                }
            }
        }
    }
}
