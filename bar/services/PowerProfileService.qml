// =============================================================================
// PowerProfileService.qml — power-profiles-daemon for the Control Center
// =============================================================================
// `powerprofilesctl list` gives both the available profiles and the active
// one (marked "*"). Probed only on refresh() (Control Center open); missing
// daemon/tool → `available` false and the tile hides.
// =============================================================================

pragma Singleton

import QtQuick

Item {
    id: root
    visible: false

    property bool available: false
    property var profiles: []            // e.g. ["performance", "balanced", "power-saver"]
    property string profile: ""

    readonly property string label: profile === "power-saver" ? "Saver"
                                  : profile === "performance" ? "Performance"
                                  : profile === "balanced" ? "Balanced" : "—"

    function refresh() { lister.run() }

    function cycle() {
        if (!root.available || root.profiles.length === 0) return
        // Saver → Balanced → Performance order, whatever the daemon lists first.
        var order = ["power-saver", "balanced", "performance"].filter(function(p) {
            return root.profiles.indexOf(p) !== -1
        })
        var next = order[(order.indexOf(root.profile) + 1) % order.length]
        root.profile = next
        setter.command = ["powerprofilesctl", "set", next]
        setter.run()
    }

    BoundedProcess {
        id: lister
        command: ["powerprofilesctl", "list"]
        onDone: function(out, err, code) {
            if (code !== 0) { root.available = false; return }
            var found = [], active = ""
            out.split("\n").forEach(function(line) {
                var m = line.match(/^\s*(\*)?\s*([a-z-]+):\s*$/)
                if (!m) return
                found.push(m[2])
                if (m[1]) active = m[2]
            })
            root.profiles = found
            root.profile = active
            root.available = found.length > 0
        }
        onLimit: function() { root.available = false }
    }

    BoundedProcess {
        id: setter
        onDone: function(out, err, code) { if (code !== 0) lister.run() }
    }
}
