// =============================================================================
// BatteryIcon.qml — Power status indicator with shell-level hover popup
// =============================================================================
//
// Shows the live power glyph from BatteryService (battery level on a laptop,
// power-plug on a desktop on AC). Click opens the Control Center POWER section,
// the same as the other tray icons (network / bluetooth / audio).
// =============================================================================

import QtQuick
import Quickshell.Io
import "../services" as Services
import "../config" as Config

Item {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize
    objectName: "batteryIcon"

    property bool hasBattery: Services.BatteryService.hasBattery
    property int percentage: Services.BatteryService.percentage
    property bool charging: Services.BatteryService.charging
    property var shellRoot: null

    Component.onCompleted: {
        function findShellRoot(item) {
            if (!item) return null
            if (item.hoverPopupData !== undefined) return item
            if (item.parent) return findShellRoot(item.parent)
            return null
        }
        shellRoot = findShellRoot(icon.parent)
        if (!shellRoot) console.log("[BatteryIcon] Could not find ShellRoot!")
    }

    Text {
        anchors.centerIn: parent
        text: Services.BatteryService.glyph
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : icon._color()

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: openProc.running = true

        onEntered: {
            if (icon.shellRoot) {
                var pos = icon.parent.mapToItem(icon.shellRoot, icon.x, icon.y)
                var subtext = icon.hasBattery
                    ? (icon.percentage + "%" + (icon.charging ? " ⚡" : ""))
                    : "AC POWER"
                icon.shellRoot.hoverPopupData = {
                    visible: true,
                    text: "Power",
                    subtext: subtext,
                    details: [
                        Services.BatteryService.stateLabel,
                        icon.hasBattery && icon.percentage <= 20 ? "⚠️ Low battery" : ""
                    ].filter(function(d) { return d !== "" }),
                    x: pos.x + icon.width/2 - 60,
                    y: pos.y
                }
            }
        }

        onExited: {
            if (icon.shellRoot) icon.shellRoot.hoverPopupData.visible = false
        }
    }

    // Open the Control Center on the POWER section (same pattern as the other
    // tray icons: network / bluetooth / audio).
    Process {
        id: openProc
        command: ["quickshell", "ipc", "-c", "settings", "call", "SettingsWindow", "openControl", "power"]
    }

    function _color() {
        if (!icon.hasBattery) return Config.BarConfig.colorText        // desktop on AC — neutral white
        if (icon.charging) return "#68d391"           // green while charging
        if (icon.percentage <= 20) return "#f87171"   // red when low
        if (icon.percentage <= 50) return "#fbbf24"   // yellow at half
        return Config.BarConfig.colorText
    }
}
