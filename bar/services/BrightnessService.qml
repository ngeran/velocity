// =============================================================================
// BrightnessService.qml — display brightness for the Control Center
// =============================================================================
// Backend, probed once on first refresh():
//   "backlight" — brightnessctl (laptop panels, class backlight)
//   "ddc"       — ddcutil VCP 0x10 (external monitors; needs i2c access, ~1s/call)
//   "none"      — no tool / no device: `available` stays false, the slider hides
// Zero idle cost: reads happen only on refresh() (Control Center open); writes
// are debounced so a slider drag sends one command per settle.
// =============================================================================

pragma Singleton

import QtQuick

Item {
    id: root
    visible: false

    property string backend: ""          // "" = not probed yet
    readonly property bool available: backend === "backlight" || backend === "ddc"
    property int percent: 50

    function refresh() {
        if (root.backend === "") { probe.run(); return }
        if (root.available) reader.run()
    }

    function setPercent(p) {
        root.percent = Math.max(1, Math.min(100, Math.round(p)))
        writeDebounce.restart()
    }

    BoundedProcess {
        id: probe
        command: ["sh", "-c",
            "if command -v brightnessctl >/dev/null 2>&1 && [ -n \"$(brightnessctl -l -c backlight -m 2>/dev/null)\" ]; then echo backlight; " +
            "elif command -v ddcutil >/dev/null 2>&1 && ddcutil getvcp 10 --brief >/dev/null 2>&1; then echo ddc; " +
            "else echo none; fi"]
        timeoutMs: 10000
        onDone: function(out) {
            var b = out.trim()
            root.backend = (b === "backlight" || b === "ddc") ? b : "none"
            if (root.available) reader.run()
        }
        onLimit: function() { root.backend = "none" }
    }

    // backlight: "intel_backlight,backlight,4800,50%,9600"   ddc: "VCP 10 C 50 100"
    BoundedProcess {
        id: reader
        command: root.backend === "ddc" ? ["ddcutil", "getvcp", "10", "--brief"]
                                        : ["brightnessctl", "-m", "-c", "backlight"]
        timeoutMs: 8000
        onDone: function(out, err, code) {
            if (code !== 0) return
            var s = out.trim()
            if (root.backend === "ddc") {
                var f = s.split(/\s+/)
                var cur = Number(f[3]), max = Number(f[4])
                if (max > 0) root.percent = Math.round(cur * 100 / max)
            } else {
                var m = s.split(",")[3]
                if (m) root.percent = parseInt(m)
            }
        }
    }

    Timer {
        id: writeDebounce
        interval: 250
        onTriggered: {
            writer.command = root.backend === "ddc"
                ? ["ddcutil", "setvcp", "10", String(root.percent)]
                : ["brightnessctl", "-q", "-c", "backlight", "set", root.percent + "%"]
            writer.run()
        }
    }
    BoundedProcess {
        id: writer
        timeoutMs: 8000
    }
}
