// =============================================================================
// ZaiUsageService.qml — Z.ai GLM Coding Plan quota monitor
// =============================================================================
// Polls the (undocumented) Z.ai subscription quota endpoint every 60s via curl
// (python3 isn't on PATH under NixOS, so this is pure QML — Process +
// SplitParser). Surfaced state is read by the ai-bot panel
// (components/ZaiUsagePanel.qml); threshold crossings are emitted as
// `thresholdAlert`, bridged into NotificationService by ZaiAlertBridge (mounted
// once in shell.qml — no notify-send/mako on this box —
// the repo's own NotificationService is the single notification sink).
//
// ENDPOINT  GET https://api.z.ai/api/monitor/usage/quota/limit
//           Bearer auth. data.limits[] entries:
//             TOKENS_LIMIT — unit/number identity ((3,5)=5h session,
//               (6,1)=weekly), percentage, nextResetTime.
//             TIME_LIMIT   — the search quota: usage/currentValue/remaining,
//               percentage, nextResetTime, usageDetails[] per tool.
//
// API KEY   Read from ~/.config/secrets/zai_usage_key (a sibling dir, OUTSIDE
//           this repo, so it's GitHub-safe). The curl command reads the file
//           itself so the secret never appears in argv (ps) or in QML JS memory;
//           an optional $ZAI_API_KEY env override wins if set. NB: nix
//           home.sessionVariables do NOT reach the bar (Hyprland exec_cmd child),
//           so the key is read from the file directly rather than via env.
//
// PROPERTIES
//   windows      : var[]   — {key,type,unit,number,role,label,pct,remaining,
//                             usage,currentValue,usageDetails,resetMs,
//                             resetLabel,resetAbsLabel,tier,statusWord,
//                             burnPerHour,etaLabel}
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
// Window roles: "session" (5h tokens), "weekly" (7d tokens), "search"
// (TIME_LIMIT) or "other". burnPerHour/etaLabel come from an in-memory
// per-window sample history (60 polls max), so they are "—" until the second
// poll after a reset.
//
// SIGNALS
//   thresholdAlert(var info)  — {windowName, pct, urgency, resetLabel}
//   dataRefreshed()           — new data in; overlays re-paint sparkline
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

Item {
    id: root
    visible: false

    // ---- endpoint + cadence ----
    readonly property string apiUrl: "https://api.z.ai/api/monitor/usage/quota/limit"
    // Absolute (B7 corollary — the "~" form only ever worked inside shell
    // strings; the argv keyCheck passes the path literally).
    readonly property string keyFile: ("" + StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "") + "/.config/secrets/zai_usage_key"
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
    property bool active: false             // overlay drives this with shown-state

    // ---- threshold re-arm state per window, keyed by window.key ----
    //   { <key>: { reset: <epochMs|null>, notified: [<thresholds>] } }
    // In-memory only (stateless like every other service); a new reset cycle
    // (nextResetTime change) re-arms all thresholds for that window.
    property var _threshState: ({})

    // Rolling samples per window key for burn-rate/ETA: [{t, pct, reset}],
    // capped at 60 polls. Same lifetime as _threshState (process memory only).
    property var _history: ({})

    signal thresholdAlert(var info)
    signal dataRefreshed()

    // =========================================================================
    // API KEY PRESENCE CHECK (one-shot on startup)
    // =========================================================================
    // We only check existence here — the curl Process reads the file itself at
    // call time (see _pollCommand), so the secret stays out of QML/argv. This
    // just gives us a useful "not configured" error state.
    BoundedProcess {
        id: keyCheck
        command: []
        timeoutMs: 3000
        onDone: function(out) {
            root.keyConfigured = (out.trim() === "1")
            if (!root.keyConfigured) {
                root.hasError = true
                root.errorMessage = "No Z.ai API key. Put it at " + root.keyFile
            } else {
                root.refresh()   // first poll immediately once we know we're configured
            }
        }
    }

    // =========================================================================
    // POLL (curl via sh -c; key read from file inside the shell)
    // =========================================================================
    // External API — the hang risk BoundedProcess exists for: a stuck curl
    // dies at the 8s timeout instead of stopping the poll cadence forever.
    BoundedProcess {
        id: poll
        command: []
        timeoutMs: 8000
        maxBytes: 262144
        onDone: function(out) {
            root.loading = false
            var trimmed = (out || "").trim()
            if (trimmed.length === 0) {
                // T7.4: curl timeout / network blip — loading is cleared
                // above; surface a SOFT error instead of silently looking
                // alive on stale data (the next good poll clears it).
                if (root.keyConfigured) {
                    root.hasError = true
                    root.errorMessage = "No response from Z.ai"
                }
                return
            }
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

    Timer {
        interval: root.pollIntervalMs
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // -------------------------------------------------------------------------
    function refresh() {
        if (!root.keyConfigured) return
        poll.command = root._pollCommand()
        root.loading = true
        poll.run()
    }

    // Read the key from the file (no secret in the sh -c argv), honour an env
    // override, then feed it to curl via stdin (--config -) so it's not in
    // curl's argv either. tr strips any stray whitespace/newline.
    function _pollCommand() {
        var cmd = "KEY=$(cat " + root.keyFile + " 2>/dev/null | tr -d '[:space:]'); " +
                  "printf 'header = \"Authorization: Bearer %s\"\\n' \"${ZAI_API_KEY:-$KEY}\" | " +
                  "curl -s --max-time 10 --config - " + root.apiUrl
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
                unit: lim.unit,
                number: lim.number,
                role: root._windowRole(lim.type, lim.unit, lim.number),
                label: root._windowLabel(lim.type, lim.unit, lim.number),
                pct: pct,
                remaining: remaining,
                usage: (lim.usage != null) ? Number(lim.usage) : null,
                currentValue: (lim.currentValue != null) ? Number(lim.currentValue) : null,
                usageDetails: Array.isArray(lim.usageDetails) ? lim.usageDetails : [],
                resetMs: lim.nextResetTime || null,
                resetLabel: root._formatReset(lim.nextResetTime),
                resetAbsLabel: root._formatResetAbs(lim.nextResetTime),
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

        root._attachTelemetry(wins)
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
    function _windowRole(type, unit, number) {
        if (type === "TOKENS_LIMIT" && unit === 3 && number === 5) return "session"
        if (type === "TOKENS_LIMIT" && unit === 6 && number === 1) return "weekly"
        if (type === "TIME_LIMIT" && unit === 5 && number === 1) return "search"
        return "other"
    }

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

    // Rolling burn-rate/ETA per window, computed from the in-memory samples.
    // A reset cycle change (nextResetTime differs from the last sample) clears
    // that window's history so pre-reset burn never leaks into the new cycle.
    function _attachTelemetry(wins) {
        var hist = root._history
        var now = Date.now()
        for (var i = 0; i < wins.length; i++) {
            var win = wins[i]
            var samples = hist[win.key] || []
            if (samples.length > 0 && samples[samples.length - 1].reset !== win.resetMs)
                samples = []
            samples.push({ t: now, pct: win.pct, reset: win.resetMs })
            while (samples.length > 60) samples.shift()
            hist[win.key] = samples
            win.burnPerHour = root._burnRate(samples)
            win.etaLabel = root._etaLabel(win, samples)
        }
        root._history = hist
    }

    function _burnRate(samples) {
        if (!samples || samples.length < 2) return null
        var first = samples[0], last = samples[samples.length - 1]
        var hours = (last.t - first.t) / 3600000
        if (!(hours > 0)) return null
        return Math.max(0, (last.pct - first.pct) / hours)
    }

    function _etaLabel(win, samples) {
        if (win.pct >= 100) return "NOW"
        var rate = root._burnRate(samples)
        if (rate === null) return "—"
        if (rate <= 0.01) return "STABLE"
        var etaH = (100 - win.pct) / rate
        if (win.resetMs) {
            var toResetH = (win.resetMs - Date.now()) / 3600000
            if (toResetH > 0 && etaH > toResetH) return "RESET FIRST"
        }
        if (etaH >= 24) return (etaH / 24).toFixed(1) + "D"
        if (etaH >= 1) return etaH.toFixed(1) + "H"
        return Math.max(1, Math.round(etaH * 60)) + "M"
    }

    function _formatResetAbs(epochMs) {
        if (!epochMs) return "—"
        var d = new Date(epochMs)
        var now = new Date()
        var dayTag = d.toDateString() === now.toDateString()
            ? "TODAY"
            : ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][d.getDay()]
        return dayTag + " " + root._pad2(d.getHours()) + ":" + root._pad2(d.getMinutes())
    }

    function _pad2(n) { return (n < 10 ? "0" : "") + n }

    // Plain-JS HH:MM:SS (avoids Qt.locale()/toLocaleTimeString portability quirks).
    function _clock() {
        var d = new Date()
        return root._pad2(d.getHours()) + ":" + root._pad2(d.getMinutes()) + ":" + root._pad2(d.getSeconds())
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================
    Component.onCompleted: {
        console.log("[ZaiUsageService] started")
        keyCheck.command = ["sh", "-c", 'test -f "$1" && echo 1 || echo 0', "sh", root.keyFile]
        keyCheck.run()
    }
}
