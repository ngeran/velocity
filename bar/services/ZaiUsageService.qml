// =============================================================================
// ZaiUsageService.qml — Z.ai GLM Coding Plan quota monitor
// =============================================================================
// Polls the (undocumented) Z.ai subscription quota endpoint every 60s via curl
// (python3 isn't on PATH under NixOS, so this is pure QML — same Process +
// SplitParser idiom as BatteryService). Surfaced state is read directly by
// ZaiUsageOverlay; threshold crossings are emitted as `thresholdAlert`, which
// shell.qml bridges into NotificationService (no notify-send/mako on this box —
// the repo's own NotificationService is the single notification sink).
//
// ENDPOINT  GET https://api.z.ai/api/monitor/usage/quota/limit
//           Bearer auth. data.limits[] entries of type TOKENS_LIMIT carry:
//             unit/number  -> window identity ((3,5)=5h session, (6,7)=weekly)
//             percentage   -> % of quota used
//             usage/currentValue/remaining -> token counts
//             nextResetTime -> epoch ms (drives the reset countdown + re-arm)
//
// API KEY   Read from ~/.config/secrets/zai_usage_key (a sibling dir, OUTSIDE
//           this repo, so it's GitHub-safe). The curl command reads the file
//           itself so the secret never appears in argv (ps) or in QML JS memory;
//           an optional $ZAI_API_KEY env override wins if set. NB: nix
//           home.sessionVariables do NOT reach the bar (Hyprland exec_cmd child),
//           so the key is read from the file directly rather than via env.
//
// PROPERTIES
//   windows      : var[]   — {key,type,label,pct,remaining,resetLabel,tier,statusWord}
//   peakPct      : real    — highest window % (the HUD headline figure)
//   peakTier     : int     — severity tier (0/1/2) of the peak window
//   peakLabel    : string  — label of the peak window
//   level        : string  — plan level (e.g. "PRO")
//   sparkline    : var[]   — rolling 5h-session % samples (≤60) for the Canvas
//   loading      : bool
//   hasError     : bool
//   errorMessage : string
//   lastUpdated  : string
//   keyConfigured: bool
//
// SIGNALS
//   thresholdAlert(var info)  — {windowName, pct, urgency, resetLabel}
//   dataRefreshed()           — new data in; overlays re-paint sparkline
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    // ---- endpoint + cadence ----
    readonly property string apiUrl: "https://api.z.ai/api/monitor/usage/quota/limit"
    readonly property string keyFile: "~/.config/secrets/zai_usage_key"
    readonly property int pollIntervalMs: 60000
    readonly property var thresholds: [50, 75, 80, 90, 95, 100]

    // ---- exposed state ----
    property var windows: []
    property real peakPct: 0
    property int peakTier: 0
    property string peakLabel: "—"
    property string level: "—"
    property var sparkline: []
    property bool loading: false
    property bool hasError: false
    property string errorMessage: ""
    property string lastUpdated: ""
    property bool keyConfigured: false

    // ---- threshold re-arm state per window, keyed by window.key ----
    //   { <key>: { reset: <epochMs|null>, notified: [<thresholds>] } }
    // In-memory only (stateless like every other service); a new reset cycle
    // (nextResetTime change) re-arms all thresholds for that window.
    property var _threshState: ({})

    signal thresholdAlert(var info)
    signal dataRefreshed()

    // =========================================================================
    // API KEY PRESENCE CHECK (one-shot on startup)
    // =========================================================================
    // We only check existence here — the curl Process reads the file itself at
    // call time (see _pollCommand), so the secret stays out of QML/argv. This
    // just gives us a useful "not configured" error state.
    Process {
        id: keyCheck
        command: []
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { keyCheck.buffer += data } }
        onRunningChanged: {
            if (!running) {
                root.keyConfigured = (keyCheck.buffer.trim() === "1")
                keyCheck.buffer = ""
                if (!root.keyConfigured) {
                    root.hasError = true
                    root.errorMessage = "No Z.ai API key. Put it at " + root.keyFile
                } else {
                    root.refresh()   // first poll immediately once we know we're configured
                }
            }
        }
    }

    // =========================================================================
    // POLL (curl via sh -c; key read from file inside the shell)
    // =========================================================================
    Process {
        id: poll
        command: []
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { poll.buffer += data } }
        onRunningChanged: {
            if (!running) {
                root.loading = false
                var raw = poll.buffer
                poll.buffer = ""
                var trimmed = (raw || "").trim()
                if (trimmed.length === 0) return          // curl timeout / network blip → silent skip
                try {
                    root._handleJson(JSON.parse(trimmed))
                } catch (e) {
                    // don't clobber a real "unconfigured" error with a parse noise message
                    if (root.keyConfigured) {
                        root.hasError = true
                        root.errorMessage = "Bad response from Z.ai"
                    }
                    console.warn("[ZaiUsageService] JSON parse error")
                }
            }
        }
    }

    Timer {
        interval: root.pollIntervalMs
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // -------------------------------------------------------------------------
    function refresh() {
        if (poll.running || !root.keyConfigured) return
        poll.command = root._pollCommand()
        root.loading = true
        poll.running = true
    }

    // Single sh -c argv: read the key from the file (no secret in argv), honour
    // an env override, then curl. tr strips any stray whitespace/newline.
    function _pollCommand() {
        var cmd = "KEY=$(cat " + root.keyFile + " 2>/dev/null | tr -d '[:space:]'); " +
                  "curl -s --max-time 10 -H \"Authorization: Bearer ${ZAI_API_KEY:-$KEY}\" " +
                  root.apiUrl
        return ["sh", "-c", cmd]
    }

    // =========================================================================
    // RESPONSE HANDLING
    // =========================================================================
    function _handleJson(payload) {
        if (!payload || !payload.success || !payload.data || !payload.data.limits) {
            root.hasError = true
            root.errorMessage = "Z.ai usage response unsuccessful."
            return
        }

        var limits = payload.data.limits
        var wins = []
        var peakPct = 0, peakLabel = "—", peakTier = 0, sessionPct = null

        for (var i = 0; i < limits.length; i++) {
            var lim = limits[i]
            // TOKENS_LIMIT windows carry only percentage+reset; TIME_LIMIT (the
            // search quota) additionally carries usage/currentValue/remaining.
            if (lim.type !== "TOKENS_LIMIT" && lim.type !== "TIME_LIMIT") continue

            var pct = Math.max(0, Math.min(100, Number(lim.percentage) || 0))
            var remaining = (lim.remaining != null) ? Number(lim.remaining) : null

            wins.push({
                key: lim.type + "-" + lim.unit + "-" + lim.number,
                type: lim.type,
                label: root._windowLabel(lim.type, lim.unit, lim.number),
                pct: pct,
                remaining: remaining,
                resetMs: lim.nextResetTime || null,
                resetLabel: root._formatReset(lim.nextResetTime),
                tier: root._tier(pct),
                statusWord: root._statusWord(pct)
            })

            if (lim.type === "TOKENS_LIMIT" && lim.unit === 3 && lim.number === 5)
                sessionPct = pct                                  // 5h window drives the sparkline
            if (pct > peakPct) { peakPct = pct; peakLabel = wins[wins.length - 1].label; peakTier = root._tier(pct) }
        }

        if (wins.length === 0) {
            root.hasError = true
            root.errorMessage = "No quota limits in Z.ai response."
            return
        }

        root.windows = wins
        root.peakPct = peakPct
        root.peakTier = peakTier
        root.peakLabel = peakLabel
        root.level = ((payload.data && payload.data.level) || "—").toString().toUpperCase()
        root.hasError = false
        root.errorMessage = ""
        root.lastUpdated = root._clock()
        console.log("[ZaiUsageService] parsed " + wins.length + " windows · peak "
                    + peakLabel + " " + Math.round(peakPct) + "% · level " + root.level)

        // sparkline tracks the 5h session % (the fast-moving window); fall back to peak.
        var sample = sessionPct != null ? sessionPct : peakPct
        var s = root.sparkline.slice()
        s.push(sample)
        if (s.length > 60) s.shift()
        root.sparkline = s

        root._checkThresholds(wins)
        root.dataRefreshed()
    }

    // Fire one notification per freshly-crossed threshold, per window. Re-arms
    // every threshold when the window's reset cycle changes.
    function _checkThresholds(wins) {
        var st = root._threshState
        var changed = false
        for (var i = 0; i < wins.length; i++) {
            var win = wins[i]
            var cyc = st[win.key]
            if (!cyc || cyc.reset !== win.resetMs) {
                cyc = { reset: win.resetMs, notified: [] }
                st[win.key] = cyc
                changed = true
            }
            for (var t = 0; t < root.thresholds.length; t++) {
                var th = root.thresholds[t]
                if (win.pct >= th && cyc.notified.indexOf(th) < 0) {
                    root.thresholdAlert({
                        windowName: win.label,
                        pct: win.pct,
                        urgency: th >= 90 ? 2 : (th >= 75 ? 1 : 0),
                        resetLabel: win.resetLabel
                    })
                    cyc.notified.push(th)
                    changed = true
                }
            }
        }
        if (changed) root._threshState = st
    }

    // ---- helpers ----
    function _windowLabel(type, unit, number) {
        if (type === "TOKENS_LIMIT") {
            if (unit === 3 && number === 5) return "5HR QUOTA"
            if (unit === 6 && number === 1) return "WEEKLY"
            return "TOKENS " + unit + "/" + number
        }
        if (type === "TIME_LIMIT") {
            if (unit === 5 && number === 1) return "SEARCH"
            return "TIME " + unit + "/" + number
        }
        return type + " " + unit + "/" + number
    }

    // 0 = nominal (secondary), 1 = warn, 2 = critical
    function _tier(pct) {
        if (pct >= 90) return 2
        if (pct >= 75) return 1
        return 0
    }

    function _statusWord(pct) {
        if (pct >= 100) return "EXHAUSTED"
        if (pct >= 90) return "CRITICAL"
        if (pct >= 75) return "WARNING"
        if (pct >= 50) return "NOTICE"
        return "OPTIMAL"
    }

    function _formatReset(epochMs) {
        if (!epochMs) return "unknown"
        var remaining = epochMs / 1000 - Date.now() / 1000
        if (remaining <= 0) return "now"
        var hrs = Math.floor(remaining / 3600)
        var mins = Math.floor((remaining % 3600) / 60)
        if (hrs >= 24) {
            var days = Math.floor(hrs / 24)
            return days + "d " + (hrs % 24) + "h"
        }
        if (hrs > 0) return hrs + "h " + mins + "m"
        return mins + "m"
    }

    // Plain-JS HH:MM:SS (avoids Qt.locale()/toLocaleTimeString portability quirks).
    function _clock() {
        var d = new Date()
        var p = function (n) { return (n < 10 ? "0" : "") + n }
        return p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds())
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================
    Component.onCompleted: {
        console.log("[ZaiUsageService] started")
        keyCheck.command = ["sh", "-c", "test -f " + root.keyFile + " && echo 1 || echo 0"]
        keyCheck.running = true
    }
}
