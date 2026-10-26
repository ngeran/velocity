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
    id: persistence

    // Config file path (set by user)
    property string configPath: ""

    // Callback for loaded data
    property var onLoaded: function(data) {}

    // Callback for save completion
    property var onSaved: function(success) {}

    // =========================================================================
    // SAVE CONFIGURATION
    // =========================================================================

    // Latest-wins slot: save() while a write is in flight used to be a silent
    // no-op (Process.running = true on a busy Process does nothing) — the last
    // config change of a burst could be lost. The queued write flushes from
    // onExited.
    property var pendingSave: null

    property Process saveProcess: Process {
        command: []
        running: false

        onExited: function(exitCode) {
            if (typeof onSaved === 'function')
                onSaved(exitCode === 0)
            if (persistence.pendingSave !== null) {
                var next = persistence.pendingSave
                persistence.pendingSave = null
                persistence._write(next)
            }
        }
    }

    function save(data) {
        if (configPath.length === 0) {
            console.log("[ConfigPersistence] No config path set")
            return false
        }
        if (saveProcess.running) {
            pendingSave = data
            return true
        }
        _write(data)
        return true
    }

    function _write(data) {
        var json = JSON.stringify(data, null, 2)
        // Atomic write: render to a per-PID tmp file, then rename. A crash
        // mid-write leaves the OLD file intact (only an orphaned .tmp.$$ behind)
        // — never a truncated/half-written config. Mirrors ThemeService._atomicWrite.
        // Payload + paths travel as positional args (B7): no quote escaping,
        // and $$ is built inside the shell so the tmp name stays PID-unique.
        var dir = configPath.substring(0, configPath.lastIndexOf("/"))
        saveProcess.command = ["sh", "-c",
            'tmp="$1/.tmp.$$"; printf \'%s\' "$2" > "$tmp" && mv -f "$tmp" "$3"',
            "sh", dir, json, configPath]
        saveProcess.running = true
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
                loadProcess.buffer += data + "\n"
            }
        }

        onRunningChanged: {
            if (!running) {
                var buf = loadProcess.buffer
                loadProcess.buffer = ""

                var data = null
                if (buf.trim().length > 0) {
                    try {
                        data = JSON.parse(buf)
                    } catch (e) {
                        console.log("[ConfigPersistence] Failed to parse config:", e)
                    }
                }
                // A missing (first run) / unreadable / unparseable config reads
                // as {} — onLoaded is the boot-sequencing signal for callers
                // (WallpaperService starts its scans from it) and must fire
                // exactly once per load() even with no file on disk.
                if (data === null || typeof data !== "object") data = {}
                if (typeof onLoaded === 'function')
                    onLoaded(data)
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
