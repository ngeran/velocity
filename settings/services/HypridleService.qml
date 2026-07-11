// =============================================================================
// HypridleService.qml — Hypridle Configuration Management (Tier 2: writable config)
// =============================================================================
// Manages idle/lock/display-off/suspend timeouts.
//
// ~/.config/hypr/hypridle.conf is a READ-ONLY nix-store symlink, so we can't edit
// it in place. Instead we GENERATE the runtime config to a writable path
// (~/.cache/hypr/hypridle.conf) and hypridle is launched with `-c` pointing there
// (see configs/hypr/environment.lua: seed via `cp -n` then `hypridle -c ...`).
// On every change we rewrite the cache config and kill+relaunch hypridle (systemctl
// reload isn't applicable here — hypridle runs via a launch script, not systemd).
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
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
    property bool suspendEnabled: false // Whether the suspend listener is active

    // =========================================================================
    // PATHS
    // =========================================================================

    readonly property string homeDir: ("" + StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "")
    // Runtime-writable config (generated from the property values below).
    readonly property string configFilePath: root.homeDir + "/.cache/hypr/hypridle.conf"
    // Read-only template (the nix-deployed default; used to seed the cache + to
    // parse the initial values shown in the UI on first run).
    readonly property string templatePath: root.homeDir + "/.config/hypr/hypridle.conf"

    // =========================================================================
    // CONFIG READING (parse current timeouts so the UI shows real values)
    // =========================================================================

    property Process readProcess: Process {
        command: []
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { readProcess.buffer += data }
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
            if (line.indexOf("timeout = ") === 0) {
                var match = line.match(/timeout = (\d+)/)
                if (match) {
                    var timeout = parseInt(match[1])
                    if (timeout >= 120 && timeout <= 300) {
                        var prevLines = lines.slice(Math.max(0, i - 5), i).join("\n")
                        if (prevLines.indexOf("brightnessctl") !== -1) {
                            root.dimTimeout = timeout
                        } else if (prevLines.indexOf("lock") !== -1 || timeout >= 240) {
                            root.lockTimeout = timeout
                        }
                    } else if (timeout > 300 && timeout <= 900) {
                        root.displayOffTimeout = timeout
                    } else if (timeout > 900) {
                        root.suspendTimeout = timeout
                        root.suspendEnabled = true
                    }
                }
            }
            // A commented-out suspend listener means suspend is disabled.
            if (line.indexOf("#") === 0 && line.indexOf("suspend") !== -1) {
                if (line.indexOf("listener") !== -1) {
                    var nextLines = lines.slice(i, Math.min(lines.length, i + 5)).join("\n")
                    if (nextLines.indexOf("systemctl suspend") !== -1) {
                        root.suspendEnabled = false
                    }
                }
            }
        }
        console.log("[HypridleService] Parsed - dim:", dimTimeout, "lock:", lockTimeout, "off:", displayOffTimeout, "suspend:", suspendEnabled ? suspendTimeout : "disabled")
    }

    // =========================================================================
    // CONFIG WRITING — generate the full config from the current values
    // =========================================================================

    property Process writeProcess: Process {
        command: []
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                console.log("[HypridleService] Wrote", configFilePath, "- reloading hypridle")
                reloadHypridle()
            } else {
                console.error("[HypridleService] Failed to write config, exit", exitCode)
            }
        }
    }

    function saveConfig() {
        // Generate the complete hypridle.conf from the live property values. This is
        // more robust than editing the read-only template text in place (which can't
        // be written anyway). The structure mirrors configs/hypr/hypridle.conf.
        var conf =
            "general {\n" +
            "    lock_cmd = pidof hyprlock || hyprlock\n" +
            "    before_sleep_cmd = loginctl lock-session\n" +
            "    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'\n" +
            "    ignore_dbus_inhibit = true\n" +
            "}\n\n" +
            "listener {\n" +
            "    timeout = " + root.dimTimeout + "\n" +
            "    on-timeout = brightnessctl -s set 10%\n" +
            "    on-resume = brightnessctl -r\n" +
            "}\n\n" +
            "listener {\n" +
            "    timeout = " + root.lockTimeout + "\n" +
            "    on-timeout = loginctl lock-session\n" +
            "}\n\n" +
            "listener {\n" +
            "    timeout = " + root.displayOffTimeout + "\n" +
            "    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'\n" +
            "    on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })' && sleep 1 && quickshell ipc -c bar call barToggle toggle\n" +
            "}\n"
        if (root.suspendEnabled) {
            conf +=
                "\nlistener {\n" +
                "    timeout = " + root.suspendTimeout + "\n" +
                "    on-timeout = systemctl suspend\n" +
                "}\n"
        }
        // Write via a temp file + atomic mv: mv only needs the DIRECTORY writable
        // (not the target), so this works even though the seeded file is read-only.
        writeProcess.command = ["sh", "-c", "mkdir -p " + root.homeDir + "/.cache/hypr && printf '%s' '" + conf.replace(/'/g, "'\\''") + "' > " + root.configFilePath + ".tmp && mv " + root.configFilePath + ".tmp " + root.configFilePath]
        writeProcess.running = true
    }

    // =========================================================================
    // RELOAD — kill + relaunch hypridle with the writable config
    // =========================================================================

    function reloadHypridle() {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        p.command = ["sh", "-c", "pkill -x hypridle; sleep 0.3; nohup hypridle -c " + root.configFilePath + " >> " + root.homeDir + "/.local/state/hypr/hypridle.log 2>&1 &"]
        p.running = true
        console.log("[HypridleService] Reloading hypridle (kill + relaunch with -c)")
    }

    // =========================================================================
    // PUBLIC API
    // =========================================================================

    function loadConfig() {
        readProcess.command = ["cat", root.configFilePath]
        readProcess.running = true
    }

    // =========================================================================
    // INITIALIZATION — seed the writable cache config from the read-only template
    // (cp -n: only if absent), then parse current values for the UI.
    // =========================================================================

    Component.onCompleted: {
        readProcess.command = ["sh", "-c", "mkdir -p " + root.homeDir + "/.cache/hypr && cp -n " + root.templatePath + " " + root.configFilePath + " 2>/dev/null || true; chmod u+w " + root.configFilePath + " 2>/dev/null || true; cat " + root.configFilePath]
        readProcess.running = true
    }
}
