pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Singleton usage service for Z.ai GLM Coding Plan quota.
// Polls zai_usage.py on an interval; the script itself owns
// threshold detection + notify-send, this just surfaces state to QML.
//
// Integration:
//   1. Save this as e.g. services/ZaiUsageService.qml
//   2. Add a qmldir entry: `singleton ZaiUsageService 1.0 ZaiUsageService.qml`
//   3. Adjust `scriptPath` below to wherever you drop zai_usage.py
//   4. `import "../services"` (or your services path) wherever you use it

Singleton {
    id: root

    // ---- config ----
    property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/scripts/zai_usage.py"
    property int pollIntervalMs: 60000

    // ---- state ----
    property bool loading: false
    property bool hasError: false
    property string errorMessage: ""

    property real sessionPercentage: 0
    property string sessionResetIn: "—"
    property var sessionRemaining: null
    property var sessionUsage: null

    property real weeklyPercentage: 0
    property string weeklyResetIn: "—"
    property var weeklyRemaining: null
    property var weeklyUsage: null

    property string lastUpdated: ""

    function refresh() {
        if (pollProcess.running)
            return;
        loading = true;
        pollProcess.running = true;
    }

    Process {
        id: pollProcess
        command: ["python3", root.scriptPath]

        stdout: SplitParser {
            id: stdoutParser
            splitMarker: "\n"
            onRead: data => {
                // defer parsing — stdout can deliver partial/queued chunks
                bufferTimer.buffer += data;
                bufferTimer.restart();
            }
        }

        onRunningChanged: {
            if (!running) {
                root.loading = false;
            }
        }
    }

    Timer {
        id: bufferTimer
        interval: 50
        property string buffer: ""
        onTriggered: {
            if (buffer.length === 0)
                return;
            root._handleOutput(buffer);
            buffer = "";
        }
    }

    function _handleOutput(text) {
        try {
            const data = JSON.parse(text.trim());

            if (data.error) {
                root.hasError = true;
                root.errorMessage = data.error;
                return;
            }

            root.hasError = false;
            root.errorMessage = "";

            if (data.session) {
                root.sessionPercentage = data.session.percentage;
                root.sessionResetIn = data.session.resetIn;
                root.sessionRemaining = data.session.remaining;
                root.sessionUsage = data.session.usage;
            }
            if (data.weekly) {
                root.weeklyPercentage = data.weekly.percentage;
                root.weeklyResetIn = data.weekly.resetIn;
                root.weeklyRemaining = data.weekly.remaining;
                root.weeklyUsage = data.weekly.usage;
            }
            root.lastUpdated = new Date().toLocaleTimeString();
        } catch (e) {
            root.hasError = true;
            root.errorMessage = "Failed to parse usage data";
        }
    }

    Timer {
        interval: root.pollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
