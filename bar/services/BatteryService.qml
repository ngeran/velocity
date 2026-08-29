// =============================================================================
// BatteryService.qml — battery / AC power state monitoring
// =============================================================================
//
// Native UPower client (event-driven DBus; zero forks, zero timers). Replaced
// the 10 s sysfs sh-loop walk. Requires services.upower.enable in NixOS
// (added 2026-08-29); without the daemon this degrades to desktop defaults
// (no battery, on AC) — same as a desktop sysfs walk reports.
//
// A system battery is any PRESENT device flagged powerSupply. Peripheral
// batteries are not: the hidpp mouse battery (85 %, discharging) reports
// power supply: no — verified live — so it never flips the bar into
// "on battery".
//
// PROPERTIES (unchanged from the sysfs version — BatteryIcon/TrayCard intact)
//   hasBattery : bool   — a system battery device is present
//   onAc       : bool   — running on AC / wall power
//   percentage : int    — battery charge (0-100; 100 when no battery)
//   charging   : bool   — battery is charging
//   glyph      : string — Nerd Font glyph (battery level / charging / plug)
//   stateLabel : string — human status (CHARGING / ON BATTERY / AC POWER …)
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Services.UPower

Item {
    id: root
    visible: false

    // The system battery: first present device that is a power supply.
    // Re-evaluates when devices appear/disappear or flags change
    // (ObjectModel.values + property notifies from the DBus state).
    readonly property var sysBattery: {
        const devs = UPower.devices.values || []
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i]
            if (d.isPresent && d.powerSupply) return d
        }
        return null
    }

    property bool hasBattery: sysBattery !== null
    property bool onAc: !UPower.onBattery || !hasBattery   // desktop default: AC
    property int percentage: sysBattery ? Math.round(sysBattery.percentage) : 100
    property bool charging: sysBattery ? sysBattery.state === UPowerDevice.Charging
                                       : false

    Component.onCompleted: console.log(
        "[BatteryService] native UPower: hasBattery=" + hasBattery +
        " onAc=" + onAc + " pct=" + percentage + " charging=" + charging +
        " devices=" + (UPower.devices.values ? UPower.devices.values.length : 0) +
        " stateCharging=" + UPowerDevice.Charging)   // canary: validates enum scope

    // DBus enumeration is async — log when the device set lands/changes so
    // hotplug (dock, laptop battery) is visible in the journal.
    Connections {
        target: UPower.devices
        function onValuesChanged() {
            console.log("[BatteryService] devices now " +
                        (UPower.devices.values ? UPower.devices.values.length : 0) +
                        " hasBattery=" + hasBattery)
        }
    }

    readonly property string glyph: {
        if (!root.hasBattery) return "󰇄"        // power plug (AC)
        if (root.charging) return "󰂄"
        if (root.percentage >= 95) return "󰁹"
        if (root.percentage < 10) return "󰁺"
        if (root.percentage < 30) return "󰁻"
        if (root.percentage < 50) return "󰁼"
        if (root.percentage < 70) return "󰁽"
        if (root.percentage < 85) return "󰁿"
        return "󰂀"
    }

    readonly property string stateLabel: {
        if (!root.hasBattery) return root.onAc ? "AC POWER" : "NO BATTERY"
        if (root.charging) return "CHARGING"
        if (root.percentage >= 95) return "FULLY CHARGED"
        return "ON BATTERY"
    }
}
