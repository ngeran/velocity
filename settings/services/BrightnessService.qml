// =============================================================================
// BrightnessService.qml — Screen Brightness Control Service
// =============================================================================
//
// Manages screen brightness via brightnessctl.
// Provides brightness percentage (0-100) and setBrightness() function.
//
// Uses brightnessctl -e4 -n2 flags for PWM backlight compatibility.
//
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root

    // =========================================================================
    // BRIGHTNESS STATE
    // =========================================================================

    property int brightness: 100  // Current brightness percentage (0-100)
    property int maxBrightness: 100  // Maximum brightness value from device

    // =========================================================================
    // BRIGHTNESS READING
    // =========================================================================

    Timer {
        id: pollTimer
        interval: 2000  // Poll every 2 seconds
        running: true
        repeat: true
        onTriggered: refreshBrightness()
    }

    Process {
        id: brightnessReader

        property string buffer: ""

        command: ["sh", "-c", "brightnessctl -e4 -n2 max"]

        stdout: SplitParser {
            onRead: function(data) {
                brightnessReader.buffer += data
            }
        }

        onRunningChanged: {
            if (!running && brightnessReader.buffer.length > 0) {
                var max = parseInt(brightnessReader.buffer.trim())
                if (!isNaN(max) && max > 0) {
                    root.maxBrightness = max
                }
                brightnessReader.buffer = ""

                // Now get current brightness
                currentBrightnessReader.running = true
            }
        }
    }

    Process {
        id: currentBrightnessReader

        property string buffer: ""

        command: ["sh", "-c", "brightnessctl -e4 -n2 get"]

        stdout: SplitParser {
            onRead: function(data) {
                currentBrightnessReader.buffer += data
            }
        }

        onRunningChanged: {
            if (!running && currentBrightnessReader.buffer.length > 0) {
                var current = parseInt(currentBrightnessReader.buffer.trim())
                if (!isNaN(current)) {
                    // Convert to percentage
                    var percent = Math.round((current / root.maxBrightness) * 100)
                    root.brightness = Math.max(0, Math.min(100, percent))
                }
                currentBrightnessReader.buffer = ""
            }
        }
    }

    // =========================================================================
    // BRIGHTNESS SETTING
    // =========================================================================

    Process {
        id: brightnessSetter
        command: []
        running: false

        onExited: function(exitCode) {
            if (exitCode === 0) {
                // Refresh brightness after setting
                refreshBrightness()
            }
        }
    }

    function setBrightness(percent) {
        var clamped = Math.max(0, Math.min(100, percent))
        brightnessSetter.command = ["sh", "-c", "brightnessctl -e4 -n2 set " + clamped + "%"]
        brightnessSetter.running = true
    }

    function adjustBrightness(delta) {
        var newBrightness = root.brightness + delta
        setBrightness(newBrightness)
    }

    // =========================================================================
    // PUBLIC API
    // =========================================================================

    function refreshBrightness() {
        brightnessReader.running = true
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[BrightnessService] Starting brightness control")
        refreshBrightness()
    }
}
