// =============================================================================
// ConfigPersistence.qml — Simple JSON Configuration Persistence
// =============================================================================
//
// Provides save/load functions for QML settings persistence.
// Uses QuickShell.Io.Process for file operations.
//
// Config storage: ~/.config/quickshell/wallpaper-config.json
// Other configs can use this utility with different configPath values.
//
// NOTE: This is NOT a singleton - multiple instances can be created with
// different configPath values for different config files.
//
// =============================================================================

import QtQuick
import Quickshell.Io

QtObject {
    // Config file path (set by user)
    property string configPath: ""

    // Callback for loaded data
    property var onLoaded: function(data) {}

    // Callback for save completion
    property var onSaved: function(success) {}

    // =========================================================================
    // SAVE CONFIGURATION
    // =========================================================================

    property Process saveProcess: Process {
        command: []
        running: false

        onExited: function(exitCode) {
            if (typeof onSaved === 'function')
                onSaved(exitCode === 0)
        }
    }

    function save(data) {
        if (configPath.length === 0) {
            console.log("[ConfigPersistence] No config path set")
            return false
        }

        var json = JSON.stringify(data, null, 2)
        // Atomic write: render to a per-PID tmp file, then rename. A crash
        // mid-write leaves the OLD file intact (only an orphaned .tmp.$$ behind)
        // — never a truncated/half-written config. Mirrors ThemeService._atomicWrite.
        saveProcess.command = ["sh", "-c", "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > \"" + configPath + ".tmp.$$\" && mv -f \"" + configPath + ".tmp.$$\" \"" + configPath + "\""]
        saveProcess.running = true
        return true
    }

    // =========================================================================
    // LOAD CONFIGURATION
    // =========================================================================

    property Process loadProcess: Process {
        command: []
        running: false

        property string buffer: ""

        stdout: SplitParser {
            onRead: function(data) {
                loadProcess.buffer += data
            }
        }

        onRunningChanged: {
            if (!running && loadProcess.buffer.length > 0) {
                try {
                    var data = JSON.parse(loadProcess.buffer)
                    if (typeof onLoaded === 'function')
                        onLoaded(data)
                } catch (e) {
                    console.log("[ConfigPersistence] Failed to parse config:", e)
                }
                loadProcess.buffer = ""
            }
        }
    }

    function load() {
        if (configPath.length === 0) {
            console.log("[ConfigPersistence] No config path set")
            return false
        }

        loadProcess.command = ["cat", configPath]
        loadProcess.running = true
        return true
    }
}
