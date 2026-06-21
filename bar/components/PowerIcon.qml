// =============================================================================
// PowerIcon.qml — Power trigger + hover battery/system status drop-up
// =============================================================================
//
// INTERACTIONS:
//   - Hover  : Reveals a drop-up panel with live battery + system stats
//   - Click  : Toggles the full-screen PowerMenu overlay (IPC to settings shell)
//
// PROBES (all via Process + stdout parsing):
//   battery %       → /sys/class/power_supply/BAT0/capacity
//   battery status  → /sys/class/power_supply/BAT0/status
//   time-to-empty   → upower -i /org/freedesktop/UPower/devices/battery_BAT0
//   CPU governor    → /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
//   thermal         → /sys/class/thermal/thermal_zone0/temp
//
// DESIGN RULES:
//   - OLED true black (#000000) background
//   - Accent: #00dce5 (teal)
//   - radius: 0 everywhere
//   - font.family: "monospace"
//   - No anchors.* mixed with Layout.*
//   - No inline hex strings (use Config.BarConfig tokens or local props)
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config

Rectangle {
    id: icon
    objectName: "powerIcon"
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize
    color: "transparent"

    // ── Theme tokens (no inline hex in logic below) ───────────────────────
    readonly property color colorBg:      "#000000"
    readonly property color colorSurface: "#0d0d0d"
    readonly property color colorAccent:  Config.BarConfig.colorAccent   // #00dce5
    readonly property color colorMuted:   "#4a5568"
    readonly property color colorText:    "#e2e8f0"
    readonly property color colorWarn:    "#f6ad55"
    readonly property color colorDanger:  "#fc8181"
    readonly property color colorGood:    "#68d391"
    readonly property color colorBorder:  "#1a1a1a"

    // ── Live data state ───────────────────────────────────────────────────
    property int    batteryPct:    -1        // -1 = unknown
    property string batteryStatus: "Unknown" // Charging / Discharging / Full
    property string timeRemaining: "—"       // "1h 23m" or "—"
    property string cpuGovernor:   "—"       // performance / powersave / etc
    property int    thermalTemp:   -1        // °C, -1 = unknown

    // ── Derived helpers ───────────────────────────────────────────────────
    property color batteryColor: {
        if (batteryPct < 0)   return colorMuted
        if (batteryStatus === "Charging") return colorAccent
        if (batteryPct <= 15) return colorDanger
        if (batteryPct <= 35) return colorWarn
        return colorGood
    }

    property string batteryGlyph: {
        if (batteryStatus === "Charging") return "󰂄"
        if (batteryStatus === "Full")     return "󰁹"
        if (batteryPct < 0)               return "󰂑"
        if (batteryPct >= 90)             return "󰁹"
        if (batteryPct >= 70)             return "󰂀"
        if (batteryPct >= 50)             return "󰁾"
        if (batteryPct >= 30)             return "󰁼"
        if (batteryPct >= 15)             return "󰁺"
        return "󰂎"
    }

    property string thermalGlyph: {
        if (thermalTemp < 0)   return "󰔄"
        if (thermalTemp >= 80) return "󰸁"
        if (thermalTemp >= 60) return "󰔅"
        return "󰔄"
    }

    property color thermalColor: {
        if (thermalTemp < 0)   return colorMuted
        if (thermalTemp >= 80) return colorDanger
        if (thermalTemp >= 60) return colorWarn
        return colorGood
    }

    property string governorGlyph: {
        if (cpuGovernor === "performance")    return "󰓅"
        if (cpuGovernor === "powersave")      return "󰾅"
        if (cpuGovernor === "schedutil")      return "󰾆"
        if (cpuGovernor === "ondemand")       return "󱐋"
        return "󰻟"
    }

    // ── Hover tracking ────────────────────────────────────────────────────
    property bool hovered: mouseArea.containsMouse || panelMouseArea.containsMouse

    // ── Polling: fire all probes on hover-in, then every 5 s while open ──
    Timer {
        id: pollTimer
        interval: 5000
        repeat: true
        running: icon.hovered
        triggeredOnStart: true
        onTriggered: {
            batCapProc.running    = true
            batStatusProc.running = true
            upowerProc.running    = true
            govProc.running       = true
            thermalProc.running   = true
        }
    }

    // ── Processes ─────────────────────────────────────────────────────────
    Process {
        id: batCapProc
        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        stdout: SplitParser {
            onRead: data => {
                var n = parseInt(data.trim())
                if (!isNaN(n)) icon.batteryPct = n
            }
        }
    }

    Process {
        id: batStatusProc
        command: ["cat", "/sys/class/power_supply/BAT0/status"]
        stdout: SplitParser {
            onRead: data => {
                var s = data.trim()
                if (s.length > 0) icon.batteryStatus = s
            }
        }
    }

    Process {
        id: upowerProc
        command: ["sh", "-c",
            "upower -i $(upower -e | grep BAT) 2>/dev/null | grep -E 'time to|percentage' | head -2"]
        stdout: SplitParser {
            onRead: data => {
                // "  time to empty:      1.5 hours"  or  "  time to full:  23 minutes"
                var line = data.trim()
                if (line.indexOf("time to") !== -1) {
                    var parts = line.split(":")
                    if (parts.length >= 2) {
                        var raw = parts.slice(1).join(":").trim()
                        // Convert "1.5 hours" → "1h 30m", "23 minutes" → "23m"
                        var hoursMatch = raw.match(/([\d.]+)\s*hour/)
                        var minsMatch  = raw.match(/([\d.]+)\s*min/)
                        if (hoursMatch) {
                            var h = parseFloat(hoursMatch[1])
                            var hh = Math.floor(h)
                            var mm = Math.round((h - hh) * 60)
                            icon.timeRemaining = hh + "h " + (mm > 0 ? mm + "m" : "")
                        } else if (minsMatch) {
                            icon.timeRemaining = Math.round(parseFloat(minsMatch[1])) + "m"
                        }
                    }
                }
            }
        }
    }

    Process {
        id: govProc
        command: ["cat", "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"]
        stdout: SplitParser {
            onRead: data => {
                var s = data.trim()
                if (s.length > 0) icon.cpuGovernor = s
            }
        }
    }

    Process {
        id: thermalProc
        command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo -1"]
        stdout: SplitParser {
            onRead: data => {
                var n = parseInt(data.trim())
                if (!isNaN(n) && n > 0) icon.thermalTemp = Math.round(n / 1000)
            }
        }
    }

    // ── Power menu toggle (direct shell access) ───────────────────────────
    property bool menuVisible: false

    // Walk up the parent chain to the ShellRoot and toggle its power menu.
    // (Direct call is reliable; the old IPC Process call failed because the
    //  bar runs under a full-path config with no "default" target.)
    function togglePowerMenu() {
        var node = icon.parent
        var depth = 0
        while (node) {
            depth++
            console.log("[PowerIcon] Depth", depth, "node:", node.constructor.name, "togglePowerMenu?", typeof node.togglePowerMenu === "function")
            if (typeof node.togglePowerMenu === "function") {
                console.log("[PowerIcon] Found togglePowerMenu at depth", depth)
                node.togglePowerMenu()
                return
            }
            node = node.parent
        }
        console.log("[PowerIcon] Could not find ShellRoot! Searched", depth, "levels")
    }

    // ── Power icon glyph ──────────────────────────────────────────────────
    Text {
        id: powerGlyph
        anchors.centerIn: parent
        text: "󰐦"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: icon.hovered ? colorAccent : "#ffffff"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Component.onCompleted: {
        console.log("[PowerIcon] Component loaded - width:", width, "height:", height, "x:", x, "y:", y)
        console.log("[PowerIcon] Expected size:", Config.BarConfig.iconSize)
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: {
            console.log("[PowerIcon] CLICK REGISTERED!")
            console.log("[PowerIcon] Toggling power menu...")
            icon.togglePowerMenu()
        }
        onPressAndHold: {
            console.log("[PowerIcon] PRESS AND HOLD!")
        }
    }

    // ── Drop-up panel ─────────────────────────────────────────────────────
    Rectangle {
        id: panel
        visible: opacity > 0
        opacity: icon.hovered ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }

        // Position: anchor bottom edge to top of icon, centred horizontally
        width: 200
        height: panelColumn.implicitHeight + 20
        anchors.bottom: icon.top
        anchors.horizontalCenter: icon.horizontalCenter
        anchors.bottomMargin: 8

        color: colorBg
        border.color: colorBorder
        border.width: 1
        radius: 0

        // Eat mouse events so hoverEnabled works across the gap
        MouseArea {
            id: panelMouseArea
            anchors.fill: parent
            hoverEnabled: true
            // don't consume clicks on the panel itself
        }

        ColumnLayout {
            id: panelColumn
            anchors {
                top:    parent.top
                left:   parent.left
                right:  parent.right
                topMargin:    10
                leftMargin:   12
                rightMargin:  12
                bottomMargin: 10
            }
            spacing: 0

            // ── Battery row ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: icon.batteryGlyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: icon.batteryColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: icon.batteryPct >= 0 ? icon.batteryPct + "%" : "—"
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: true
                            color: icon.batteryColor
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: icon.batteryStatus
                            font.family: "monospace"
                            font.pixelSize: 10
                            color: icon.colorMuted
                        }
                    }

                    // Battery bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 2
                        color: icon.colorSurface
                        radius: 0
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, icon.batteryPct / 100))
                            height: parent.height
                            color: icon.batteryColor
                            radius: 0
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }

                    // Time remaining
                    Text {
                        text: {
                            if (icon.batteryStatus === "Charging") return "time to full: " + icon.timeRemaining
                            if (icon.batteryStatus === "Full")     return "fully charged"
                            return "remaining: " + icon.timeRemaining
                        }
                        font.family: "monospace"
                        font.pixelSize: 10
                        color: icon.colorMuted
                        Layout.topMargin: 1
                    }
                }
            }

            // ── Divider ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: icon.colorBorder
                Layout.topMargin: 8
                Layout.bottomMargin: 8
            }

            // ── Thermal row ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: icon.thermalGlyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: icon.thermalColor
                }
                Text {
                    text: "cpu temp"
                    font.family: "monospace"
                    font.pixelSize: 11
                    color: icon.colorMuted
                    Layout.fillWidth: true
                }
                Text {
                    text: icon.thermalTemp >= 0 ? icon.thermalTemp + " °C" : "—"
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: icon.thermalColor
                }
            }

            // ── Governor row ──────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Layout.topMargin: 6

                Text {
                    text: icon.governorGlyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: icon.colorAccent
                }
                Text {
                    text: "governor"
                    font.family: "monospace"
                    font.pixelSize: 11
                    color: icon.colorMuted
                    Layout.fillWidth: true
                }
                Text {
                    text: icon.cpuGovernor
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: icon.colorAccent
                }
            }

            // ── Divider ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: icon.colorBorder
                Layout.topMargin: 8
                Layout.bottomMargin: 8
            }

            // ── Click hint ────────────────────────────────────────────────
            Text {
                text: "click to power menu"
                font.family: "monospace"
                font.pixelSize: 9
                color: icon.colorMuted
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
