/** Version: 11 - structured device objects, per-device battery, disconnect action **/
pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property bool powered: false
    property int deviceCount: 0

    // Structured rows — primitives-only objects ({address, name}); never
    // QObjects (dangling C++ refs in delegates are a documented segfault
    // class). Replaces the old comma-joined name string.
    property var devices: []                  // [{address, name}] of CONNECTED devices

    // Battery percentage per MAC (from `bluetoothctl info`), e.g.
    // {"AA:BB:...": 80}. Popup-gated — probes are slow-ish and rarely change.
    property var deviceBatteries: ({})

    // bluetoothctl presence — when absent we stop polling instead of forking a
    // failing process forever and showing a misleading "OFF" state.
    property bool hasBluetooth: true

    // ── Popup gating ─────────────────────────────────────────────────────────
    // The bar icon only needs `powered` (btShowProc). The connected-device
    // list + battery sweep exist solely for the TrayCard popup, so they are
    // fetched on open and polled only while open. Set by TrayCard.
    property bool popupOpen: false

    onPopupOpenChanged: {
        if (!popupOpen) return
        if (!btDevProc.running)     btDevProc.running = true
        if (!btBatteryProc.running) btBatteryProc.running = true
    }

    // One-shot presence probe; gates the poll timer on exit.
    Process {
        id: detectProc
        command: ["sh", "-c", "command -v bluetoothctl >/dev/null && bluetoothctl show >/dev/null 2>&1"]
        onExited: function(code) {
            root.hasBluetooth = (code === 0)
            btPollTimer.running = root.hasBluetooth
        }
    }

    Process {
        id: btShowProc
        command: ["bluetoothctl", "show"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { btShowProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                root.powered = btShowProc.buffer.indexOf("Powered: yes") !== -1
                btShowProc.buffer = ""
            }
        }
    }

    // Full "Device AA:BB:CC:DD:EE:FF Name" lines — parsed into {address, name}.
    Process {
        id: btDevProc
        command: ["sh", "-c", "bluetoothctl devices Connected"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { btDevProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                const rows = []
                const lines = btDevProc.buffer.trim().split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const m = lines[i].match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.*)$/)
                    if (m) rows.push({ address: m[1], name: m[2].trim() })
                }
                root.devices = rows                      // reassign whole array → bindings re-evaluate
                root.deviceCount = rows.length
                btDevProc.buffer = ""
            }
        }
    }

    // ── Per-device battery sweep (popup-only): one shell loop instead of one
    // Process per device. Emits "<mac> <percent>" lines; devices without a
    // battery report simply don't appear (map keeps last-known for others).
    Process {
        id: btBatteryProc
        command: ["sh", "-c",
            "bluetoothctl devices Connected 2>/dev/null | while read -r _ mac _; do " +
            "pct=$(bluetoothctl info \"$mac\" 2>/dev/null | awk '/Battery Percentage/ {gsub(/[()]/, \"\", $4); print $4; exit}'); " +
            "[ -n \"$pct\" ] && echo \"$mac $pct\"; done"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { btBatteryProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                const map = {}
                const lines = btBatteryProc.buffer.trim().split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const f = lines[i].trim().split(/\s+/)
                    if (f.length === 2) {
                        const pct = parseInt(f[1], 10)
                        if (!isNaN(pct)) map[f[0]] = pct
                    }
                }
                root.deviceBatteries = map               // reassign whole object
                btBatteryProc.buffer = ""
            }
        }
    }

    // Battery changes slowly — 30s while the popup is open is plenty.
    Timer {
        id: btBatteryTimer
        interval: 30000
        repeat: true
        running: root.hasBluetooth && root.popupOpen
        onTriggered: if (!btBatteryProc.running) btBatteryProc.running = true
    }

    // Always-on state poll: ONLY btShowProc (powers the bar icon). The device
    // list rides along at the same cadence but only while the popup is open.
    Timer {
        id: btPollTimer
        interval: 6000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (!btShowProc.running) btShowProc.running = true
            if (root.popupOpen && !btDevProc.running) btDevProc.running = true
        }
    }

    // Hung-process reaper (Omarchy tailscale pattern): bluetoothctl can hang
    // when BlueZ is wedged; a stuck Process would otherwise silently stop all
    // refreshing forever because every poll skips while it reports running.
    Timer {
        id: btWatchdog
        interval: 15000
        repeat: true
        running: true
        onTriggered: {
            if (btShowProc.running)    btShowProc.running = false
            if (btDevProc.running)     btDevProc.running = false
            if (btBatteryProc.running) btBatteryProc.running = false
        }
    }

    // Re-poll 1 s after a toggle/action so UI reflects the real state quickly
    Timer {
        id: refreshTimer
        interval: 1000; repeat: false
        onTriggered: {
            if (!btShowProc.running) btShowProc.running = true
            if (!btDevProc.running)  btDevProc.running  = true
            if (root.popupOpen && !btBatteryProc.running) btBatteryProc.running = true
        }
    }

    // Per-device action runner. (Quickshell.exec() does NOT exist in this build.)
    Process { id: actionProc }

    function disconnectDevice(address) {
        actionProc.command = ["bluetoothctl", "disconnect", address]
        actionProc.running = true
        refreshTimer.restart()   // device list re-syncs ~1s later
    }

    // Quickshell.exec() does NOT exist in this build — run the command via Process.
    Process { id: powerProc }

    function togglePower() {
        powerProc.command = ["bluetoothctl", "power", root.powered ? "off" : "on"]
        powerProc.running = true
        root.powered = !root.powered   // optimistic update
        refreshTimer.restart()
    }

    Component.onCompleted: detectProc.running = true
}
