/** Version: 12 — native Quickshell.Bluetooth (BlueZ over DBus):
 ** zero forks, zero timers, zero optimistic-update dances. **/
pragma Singleton
import QtQuick
import Quickshell.Bluetooth

Item {
    id: root
    visible: false

    // =========================================================================
    // NATIVE STATE — event-driven BlueZ client
    // =========================================================================
    // Replaces the 6 s `bluetoothctl show` poll (the bar icon's only always-on
    // need), the popup-gated device-list + battery sweeps, and the action
    // runners: power toggle and per-device disconnect are single property
    // writes, confirmed by the BlueZ events they trigger.

    readonly property var adapter: Bluetooth.defaultAdapter   // null = no BT

    property bool hasBluetooth: adapter !== null
    property bool powered: adapter !== null && adapter.enabled

    function togglePower() {
        if (adapter) adapter.enabled = !adapter.enabled
    }

    // Connected devices as PRIMITIVE rows ({address, name}) — never QObjects
    // (dangling C++ refs in delegates are a documented segfault class; v11
    // rule kept). BlueZ's device model is paired/known devices — no discovery
    // lease needed for a connected-only list.
    readonly property var devices: {
        const devs = Bluetooth.devices.values || []
        const rows = []
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i]
            if (d.connected) rows.push({ address: d.address, name: d.name })
        }
        return rows
    }

    property int deviceCount: devices.length

    // Battery percentage per MAC, straight from the device objects (the old
    // per-device `bluetoothctl info` sweep is gone).
    readonly property var deviceBatteries: {
        const devs = Bluetooth.devices.values || []
        const map = {}
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i]
            if (d.connected && d.batteryAvailable)
                map[d.address] = Math.round(d.battery * 100)   // 0..1 → percent
        }
        return map
    }

    function disconnectDevice(address) {
        const devs = Bluetooth.devices.values || []
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].address === address) {
                devs[i].connected = false   // writable prop → BlueZ disconnect
                return
            }
        }
    }

    // Kept for API compatibility: TrayCard still sets it, but state is
    // event-driven now — there is nothing to poll-gate anymore.
    property bool popupOpen: false

    // Registry enumeration is async — settle/hotplug visibility in the journal.
    onAdapterChanged: console.log("[BluetoothService] adapter now: " +
        (adapter ? adapter.name + " enabled=" + adapter.enabled : "none"))
    Connections {
        target: Bluetooth.devices
        function onValuesChanged() {
            console.log("[BluetoothService] devices now " +
                        (Bluetooth.devices.values || []).length +
                        " connected=" + deviceCount +
                        " batteries=" + JSON.stringify(deviceBatteries))
        }
    }

    Component.onCompleted: console.log("[BluetoothService] native BlueZ: adapter=" +
        (adapter ? adapter.name : "none") + " powered=" + powered +
        " devices=" + deviceCount)
}
