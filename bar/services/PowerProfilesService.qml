// =============================================================================
// PowerProfilesService.qml — power-profiles-daemon bridge (powerprofilesctl).
// =============================================================================
// DEGRADES SILENTLY: when power-profiles-daemon isn't installed on the system,
// `available` stays false and the volume-style profile picker hides. Add the
// daemon to the flake and the section appears on the next popup open — no
// code changes needed.
// GATED like the other popup probes: the profile is only read while the power
// popup is open (TrayCard calls refresh()).
// =============================================================================
pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property bool available: false      // powerprofilesctl found on PATH
    property string profile: ""         // "power-saver" | "balanced" | "performance"
    property bool busy: false
    property bool probed: false

    // One-time availability probe at construction.
    Component.onCompleted: _probeProc.command = ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && echo YES || echo NO"]
    property var _probeProc: Process {
        command: []
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { root._probeProc.buffer += d } }
        onRunningChanged: {
            if (running) return
            root.available = root._probeProc.buffer.indexOf("YES") !== -1
            root._probeProc.buffer = ""
            root.probed = true
        }
    }

    function refresh() {
        if (!root.available || root.busy) return
        root.busy = true
        _getProc.command = ["sh", "-c", "powerprofilesctl get 2>/dev/null || echo unknown"]
        _getProc.running = true
    }

    property var _getProc: Process {
        command: []
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { root._getProc.buffer += d } }
        onRunningChanged: {
            if (running) return
            var p = root._getProc.buffer.trim()
            root._getProc.buffer = ""
            root.busy = false
            root.profile = p
        }
    }

    function setProfile(key) {
        if (!root.available || root.busy || key === root.profile) return
        root.busy = true
        root.profile = key      // optimistic; confirmed by the follow-up read
        _setProc.command = ["sh", "-c",
            "powerprofilesctl set " + key + " 2>/dev/null && powerprofilesctl get"]
        _setProc.running = true
    }

    property var _setProc: Process {
        command: []
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { root._setProc.buffer += d } }
        onRunningChanged: {
            if (running) return
            var p = root._setProc.buffer.trim()
            root._setProc.buffer = ""
            root.busy = false
            root.profile = p !== "" ? p : root.profile
        }
    }
}
