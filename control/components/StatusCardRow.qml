// =============================================================================
// StatusCardRow.qml — three live status cards (Network / Bluetooth / Audio)
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Row {
    spacing: 12
    height: Config.ControlConfig.statusCardHeight

    StatusCard {
        width: Config.ControlConfig.statusCardWidth
        height: Config.ControlConfig.statusCardHeight
        title: "NETWORK"
        active: Services.NetworkControlService.connectionStatus.connected
        line1: {
            var s = Services.NetworkControlService.connectionStatus
            if (!s.connected) return "OFFLINE"
            return s.type === "wifi" ? (s.ssid ? s.ssid.toUpperCase() : "WIFI") : "ETH0: LINK"
        }
        line2: Services.NetworkControlService.connectionStatus.ip || "no ip address"
    }

    StatusCard {
        width: Config.ControlConfig.statusCardWidth
        height: Config.ControlConfig.statusCardHeight
        title: "BLUETOOTH"
        active: Services.BluetoothControlService.powered
        line1: Services.BluetoothControlService.powered
               ? ("DEV: " + Services.BluetoothControlService.devices.length)
               : "OFFLINE"
        line2: Services.BluetoothControlService.powered ? "POWERED" : "—"
    }

    StatusCard {
        width: Config.ControlConfig.statusCardWidth
        height: Config.ControlConfig.statusCardHeight
        title: "AUDIO"
        active: Services.AudioControlService.defaultSink.length > 0
        line1: Services.AudioControlService.defaultSink.length > 0 ? "PIPEWIRE: ACTIVE" : "PIPEWIRE: IDLE"
        line2: Services.AudioControlService.defaultSink || "no sink"
    }
}
