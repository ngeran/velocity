// =============================================================================
// QuickTogglesGrid.qml — Quick Settings Toggles Grid
// =============================================================================
//
// Functional quick toggles: Wi-Fi, Bluetooth, Mute, Do-Not-Disturb.
//   - Icons use JetBrainsMono Nerd Font glyphs (not letters).
//   - State is read from the system (nmcli / bluetoothctl / wpctl) on load and
//     after each toggle.
//   - Clicking runs the real on/off command for the device.
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config

Rectangle {
    id: root

    implicitWidth: 280
    implicitHeight: headerCol.implicitHeight + 16

    color: Config.ThemeConfig.colors.surface
    border.color: Config.ThemeConfig.colors.border
    border.width: 1
    radius: 8

    // Colours that definitely exist in the ThemeConfig palette (the old code
    // referenced colors.onPrimary, which is undefined → QColor warnings).
    readonly property color checkedBg:    Config.ThemeConfig.colors.primary      // #7c6bf0
    readonly property color checkedFg:    Config.ThemeConfig.colors.background
    readonly property color uncheckedBg:  Config.ThemeConfig.colors.surfaceVariant
    readonly property color uncheckedIcon:Config.ThemeConfig.colors.text
    readonly property color uncheckedFg:  Config.ThemeConfig.colors.textDim

    // ── Live state ──────────────────────────────────────────────────────────
    property bool wifiOn: false
    property bool btOn: false
    property bool muteOn: false
    property bool dndOn: false

    Component.onCompleted: {
        root.refreshAll()
        console.log("[QuickToggles] Grid loaded")
    }

    function refreshAll() {
        wifiCheck.running = true
        btCheck.running = true
        volCheck.running = true
        dndCheck.running = true
    }

    // ── State probes ────────────────────────────────────────────────────────
    Process {
        id: wifiCheck
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { wifiCheck.buffer += d } }
        onRunningChanged: {
            if (!running) {
                root.wifiOn = (wifiCheck.buffer.trim() === "enabled")
                wifiCheck.buffer = ""
            }
        }
    }

    Process {
        id: btCheck
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -i 'Powered:'"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { btCheck.buffer += d } }
        onRunningChanged: {
            if (!running) {
                root.btOn = (btCheck.buffer.indexOf("yes") !== -1)
                btCheck.buffer = ""
            }
        }
    }

    Process {
        id: volCheck
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { volCheck.buffer += d } }
        onRunningChanged: {
            if (!running) {
                root.muteOn = (volCheck.buffer.indexOf("MUTED") !== -1)
                volCheck.buffer = ""
            }
        }
    }

    Process {
        id: dndCheck
        command: ["sh", "-c", "makoctl set-dnd 2>/dev/null; echo done"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { dndCheck.buffer += d } }
        onRunningChanged: {
            if (!running) { dndCheck.buffer = "" }
        }
    }

    // ── Toggle actors (command built at click time) ─────────────────────────
    Process { id: wifiToggleProc; command: []; property bool _armed: false
        onRunningChanged: if (!running && _armed) { _armed = false; wifiCheck.running = true }
    }
    Process { id: btToggleProc;   command: []; property bool _armed: false
        onRunningChanged: if (!running && _armed) { _armed = false; btCheck.running = true }
    }
    Process { id: volToggleProc;  command: []; property bool _armed: false
        onRunningChanged: if (!running && _armed) { _armed = false; volCheck.running = true }
    }
    Process { id: dndToggleProc;  command: []; property bool _armed: false
        onRunningChanged: if (!running && _armed) { _armed = false; dndOn = !dndOn }
    }

    function toggleWifi() {
        wifiToggleProc.command = ["sh", "-c", root.wifiOn ? "nmcli radio wifi off" : "nmcli radio wifi on"]
        wifiToggleProc._armed = true
        wifiToggleProc.running = true
        console.log("[QuickToggles] Wi-Fi ->", !root.wifiOn)
    }

    function toggleBt() {
        btToggleProc.command = ["sh", "-c", root.btOn ? "bluetoothctl power off" : "bluetoothctl power on"]
        btToggleProc._armed = true
        btToggleProc.running = true
        console.log("[QuickToggles] Bluetooth ->", !root.btOn)
    }

    function toggleMute() {
        volToggleProc.command = ["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"]
        volToggleProc._armed = true
        volToggleProc.running = true
        console.log("[QuickToggles] Mute ->", !root.muteOn)
    }

    function toggleDnd() {
        // Best-effort: works with mako; no-op silently otherwise.
        dndToggleProc.command = ["sh", "-c", "command -v makoctl >/dev/null && makoctl set-dnd toggle || dunstctl set-paused toggle 2>/dev/null || true"]
        dndToggleProc._armed = true
        dndToggleProc.running = true
        console.log("[QuickToggles] DND toggled")
    }

    // =========================================================================
    // LAYOUT
    // =========================================================================

    ColumnLayout {
        id: headerCol
        anchors { fill: parent; margins: 10 }
        spacing: 10

        Text {
            text: "QUICK TOGGLES"
            font.pixelSize: 8
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 1.5
            color: Config.ThemeConfig.colors.textDim
        }

        GridLayout {
            columns: 4
            rowSpacing: 8
            columnSpacing: 8
            Layout.fillWidth: true

            ToggleTile {
                label: "Wi-Fi"
                glyph: root.wifiOn ? "󰖩" : "󰖪"
                checked: root.wifiOn
                onClicked: root.toggleWifi()
            }

            ToggleTile {
                label: "Bluetooth"
                glyph: root.btOn ? "󰂯" : "󰂲"
                checked: root.btOn
                onClicked: root.toggleBt()
            }

            ToggleTile {
                label: "Mute"
                glyph: root.muteOn ? "󰝟" : "󰕾"
                checked: root.muteOn
                onClicked: root.toggleMute()
            }

            ToggleTile {
                label: "DND"
                glyph: root.dndOn ? "󰂛" : "󰂚"
                checked: root.dndOn
                onClicked: root.toggleDnd()
            }
        }
    }

    // ── Reusable tile visual (inline component, no Loader needed) ────────────
    component ToggleTile: Rectangle {
        id: tile
        property string label: ""
        property string glyph: ""
        property bool checked: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: 8
        color: tile.checked ? root.checkedBg : root.uncheckedBg
        border.color: Config.ThemeConfig.colors.border
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.glyph
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20
                color: tile.checked ? root.checkedFg : root.uncheckedIcon
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                font.pixelSize: 8
                font.family: Config.SettingsConfig.fontFamily
                color: tile.checked ? root.checkedFg : root.uncheckedFg
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }
}
