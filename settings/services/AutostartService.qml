// =============================================================================
// AutostartService.qml — Hyprland Autostart Management Service
// =============================================================================
//
// Manages Hyprland exec-once entries for autostart applications.
// Stores entries in ~/.config/quickshell/autostart.json and syncs to hyprland.conf.
//
// This provides a cleaner interface than directly editing hyprland.conf.
//
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

Item {
    id: root

    // =========================================================================
    // AUTOSTART ENTRIES
    // =========================================================================

    property var autostartEntries: []  // Array of { name, command, enabled }

    // =========================================================================
    // CONFIG FILE PATHS
    // =========================================================================

    property string configFilePath: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString()
                                       .replace("file://", "") + "/quickshell/autostart.json"

    property string hyprlandConfPath: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString()
                                          .replace("file://", "") + "/hypr/hyprland.conf"

    // =========================================================================
    // CONFIG READING
    // =========================================================================

    property Process readProcess: Process {
        command: []
        running: false

        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) {
                readProcess.buffer += data
            }
        }

        onRunningChanged: {
            if (!running && readProcess.buffer.length > 0) {
                try {
                    var data = JSON.parse(readProcess.buffer)
                    if (Array.isArray(data)) {
                        root.autostartEntries = data
                        console.log("[AutostartService] Loaded", data.length, "entries")
                    }
                } catch (e) {
                    console.log("[AutostartService] Failed to parse config, using defaults:", e)
                    // Use default entries if config is corrupt
                    root.autostartEntries = getDefaultEntries()
                }
                readProcess.buffer = ""
            }
        }
    }

    function getDefaultEntries() {
        return [
            { name: "Bar", command: "quickshell -c ~/.config/quickshell/bar", enabled: true },
            { name: "Settings", command: "quickshell -c ~/.config/quickshell/settings", enabled: false },
            { name: "Notification Daemon", command: "mako", enabled: true },
            { name: "Clipboard Manager", command: "wl-paste --type text --watch cliphist store", enabled: false },
            { name: "Policy Kit", command: "lxpolkit", enabled: false }
        ]
    }

    // =========================================================================
    // CONFIG WRITING
    // =========================================================================

    property Process writeProcess: Process {
        command: []
        running: false

        onExited: function(exitCode) {
            if (exitCode === 0) {
                console.log("[AutostartService] Config saved successfully")
            } else {
                console.log("[AutostartService] Failed to save config, exit code:", exitCode)
            }
        }
    }

    function saveConfig() {
        var json = JSON.stringify(root.autostartEntries, null, 2)
        writeProcess.command = ["sh", "-c", "mkdir -p ~/.config/quickshell && printf '%s' '" + json.replace(/'/g, "'\\''") + "' > " + root.configFilePath]
        writeProcess.running = true
    }

    // =========================================================================
    // PUBLIC API
    // =========================================================================

    function loadConfig() {
        console.log("[AutostartService] Loading config from:", root.configFilePath)
        readProcess.command = ["cat", root.configFilePath]
        readProcess.running = true
    }

    function addEntry(name, command) {
        autostartEntries.push({ name: name, command: command, enabled: true })
        saveConfig()
    }

    function removeEntry(index) {
        if (index >= 0 && index < autostartEntries.length) {
            autostartEntries.splice(index, 1)
            saveConfig()
        }
    }

    function toggleEntry(index) {
        if (index >= 0 && index < autostartEntries.length) {
            autostartEntries[index].enabled = !autostartEntries[index].enabled
            saveConfig()
        }
    }

    function updateEntry(index, name, command) {
        if (index >= 0 && index < autostartEntries.length) {
            autostartEntries[index].name = name
            autostartEntries[index].command = command
            saveConfig()
        }
    }

    function generateHyprlandConfig() {
        var lines = []
        var enabled = autostartEntries.filter(function(e) { return e.enabled })

        if (enabled.length > 0) {
            lines.push("# Autostart applications (managed by Obsidian Core Settings)")
            for (var i = 0; i < enabled.length; i++) {
                lines.push("exec-once = " + enabled[i].command + " # " + enabled[i].name)
            }
        }

        return lines.join("\n")
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        loadConfig()
    }
}
