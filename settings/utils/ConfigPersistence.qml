// =============================================================================
// ConfigPersistence.qml — Simple JSON Configuration Persistence
// =============================================================================
//
// Provides save/load functions for QML settings persistence.
// Uses QuickShell.Io.Process for file operations.
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
        // Use printf to write file (handles special characters better)
        saveProcess.command = ["sh", "-c", "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + configPath + "'"]
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
