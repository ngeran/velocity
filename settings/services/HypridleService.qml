// =============================================================================
// HypridleService.qml — Hypridle Configuration Management Service
// =============================================================================
//
// Manages hypridle.conf settings for idle/lock behavior.
// Reads and writes timeout values for dim, lock, display-off, and suspend stages.
//
// Config file: ~/.config/hypr/hypridle.conf
//
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root

    // =========================================================================
    // IDLE TIMEOUTS (seconds)
    // =========================================================================

    property int dimTimeout: 180        // 3 minutes - screen dim warning
    property int lockTimeout: 300       // 5 minutes - lock screen
    property int displayOffTimeout: 330 // 5.5 minutes - turn off display
    property int suspendTimeout: 1800   // 30 minutes - suspend to RAM
    property bool suspendEnabled: false // Whether suspend stage is active

    // =========================================================================
    // CONFIG FILE PATH
    // =========================================================================

    property string configFilePath: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
                                       .replace("file://", "") + "/hypr/hypridle.conf"

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
                parseConfig(readProcess.buffer)
                readProcess.buffer = ""
            }
        }
    }

    function parseConfig(content) {
        var lines = content.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            // Look for timeout lines in listener blocks
            if (line.indexOf("timeout = ") === 0) {
                var match = line.match(/timeout = (\d+)/)
                if (match) {
                    var timeout = parseInt(match[1])
                    // Determine which stage based on typical values
                    // This is a simple heuristic; could be improved by tracking listener blocks
                    if (timeout >= 120 && timeout <= 300) {
                        // Could be dim or lock - check surrounding context
                        var prevLines = lines.slice(Math.max(0, i - 5), i).join("\n")
                        if (prevLines.indexOf("brightnessctl") !== -1) {
                            root.dimTimeout = timeout
                        } else if (prevLines.indexOf("lock") !== -1 || timeout >= 240) {
                            root.lockTimeout = timeout
                        }
                    } else if (timeout >= 300 && timeout <= 400) {
                        root.displayOffTimeout = timeout
                    } else if (timeout >= 900) {
                        root.suspendTimeout = timeout
                        root.suspendEnabled = true
                    }
                }
            }
            // Check if suspend is commented out
            if (line.indexOf("#") === 0 && line.indexOf("suspend") !== -1) {
                if (line.indexOf("listener") !== -1) {
                    // This whole listener block is commented
                    var nextLines = lines.slice(i, Math.min(lines.length, i + 5)).join("\n")
                    if (nextLines.indexOf("systemctl suspend") !== -1) {
                        root.suspendEnabled = false
                    }
                }
            }
        }
        console.log("[HypridleService] Parsed config - dim:", dimTimeout, "lock:", lockTimeout, "off:", displayOffTimeout, "suspend:", suspendEnabled ? suspendTimeout : "disabled")
    }

    // =========================================================================
    // CONFIG WRITING
    // =========================================================================

    property Process writeProcess: Process {
        command: []
        running: false

        onExited: function(exitCode) {
            if (exitCode === 0) {
                console.log("[HypridleService] Config saved successfully")
                // Reload hypridle to apply changes
                reloadHypridle()
            } else {
                console.log("[HypridleService] Failed to save config, exit code:", exitCode)
            }
        }
    }

    function saveConfig() {
        // Read current config, modify it, and write back
        readProcess.command = ["cat", root.configFilePath]
        readProcess.running = true

        // Wait for read to complete, then write
        readProcess.onRunningChanged.connect(function() {
            if (!readProcess.running && readProcess.buffer.length > 0) {
                var modified = modifyConfig(readProcess.buffer)
                writeProcess.command = ["sh", "-c", "printf '%s' '" + modified.replace(/'/g, "'\\''") + "' > " + root.configFilePath]
                writeProcess.running = true
                readProcess.buffer = ""
            }
        })
    }

    function modifyConfig(content) {
        var lines = content.split("\n")
        var inDimListener = false
        var inLockListener = false
        var inDisplayOffListener = false
        var inSuspendListener = false
        var suspendListenerStart = -1

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]

            // Track which listener we're in
            if (line.indexOf("listener {") !== -1) {
                var nextLines = lines.slice(i, Math.min(lines.length, i + 10)).join("\n")
                if (nextLines.indexOf("brightnessctl") !== -1) {
                    inDimListener = true
                    inLockListener = false
                    inDisplayOffListener = false
                    inSuspendListener = false
                } else if (nextLines.indexOf("lock-session") !== -1) {
                    inLockListener = true
                    inDimListener = false
                    inDisplayOffListener = false
                    inSuspendListener = false
                } else if (nextLines.indexOf("dsp.dpms") !== -1 && nextLines.indexOf("disable") !== -1) {
                    inDisplayOffListener = true
                    inDimListener = false
                    inLockListener = false
                    inSuspendListener = false
                } else if (nextLines.indexOf("systemctl suspend") !== -1 || (line.indexOf("#") === 0 && nextLines.indexOf("suspend") !== -1)) {
                    inSuspendListener = true
                    inDimListener = false
                    inLockListener = false
                    inDisplayOffListener = false
                    if (line.indexOf("#") === 0) {
                        suspendListenerStart = i
                    }
                }
            }

            // Update timeout lines
            if (line.trim().indexOf("timeout = ") === 0) {
                if (inDimListener) {
                    lines[i] = "    timeout = " + root.dimTimeout
                } else if (inLockListener) {
                    lines[i] = "    timeout = " + root.lockTimeout
                } else if (inDisplayOffListener) {
                    lines[i] = "    timeout = " + root.displayOffTimeout
                } else if (inSuspendListener) {
                    lines[i] = "    timeout = " + root.suspendTimeout
                }
            }

            // Close listener blocks
            if (line.trim() === "}") {
                inDimListener = false
                inLockListener = false
                inDisplayOffListener = false
                inSuspendListener = false
            }
        }

        // Handle suspend enable/disable by commenting/uncommenting
        // This is a simplified version - full implementation would track the suspend block
        return lines.join("\n")
    }

    function reloadHypridle() {
        var reloadCmd = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        reloadCmd.command = ["sh", "-c", "systemctl reload hypridle || systemctl restart hypridle"]
        reloadCmd.running = true
        console.log("[HypridleService] Reloading hypridle")
    }

    // =========================================================================
    // PUBLIC API
    // =========================================================================

    function loadConfig() {
        console.log("[HypridleService] Loading config from:", root.configFilePath)
        readProcess.command = ["cat", root.configFilePath]
        readProcess.running = true
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        loadConfig()
    }
}
