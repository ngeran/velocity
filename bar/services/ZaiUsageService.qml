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
//           A revoked, expired or bogus key still answers HTTP 200, with
//           {"code":1000,…} or {"code":401,"msg":"token expired or incorrect"}
//           — surfaced as "API KEY REJECTED".
//
// API KEY   Read from ~/.config/secrets/zai_usage_key (a sibling dir, OUTSIDE
//           this repo, so it's GitHub-safe). The curl command reads the file
//           itself so the secret never appears in argv (ps) or in QML JS memory;
//           an optional $ZAI_API_KEY env override wins if set. NB: nix
//           home.sessionVariables do NOT reach the bar (Hyprland exec_cmd child),
//           so the key is read from the file directly rather than via env.
//           PASTE & SAVE (installKeyFromClipboard, from the ai-bot panel)
//           installs a new key: ONE sh process reads the clipboard, checks it
//           against the endpoint, and only then writes the file (0600, tmp+mv).
//           The key is never in argv, in QML JS memory or in any log — the
//           process prints one status word.
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
//   errorTitle   : string  — headline of the error card: "CONNECTION ERROR"
//                             (default), "API KEY REJECTED" (Z.ai code 1000 or 401)
//                             or "NO API KEY" (key file missing)
//   errorMessage : string
//   hasKeyError  : bool    — the error is about the key (missing or rejected):
//                             PASTE & SAVE is the fix, not a network retry
//   lastUpdated  : string
//   keyConfigured: bool
//   isInstallingKey: bool    — a PASTE & SAVE check is in flight
//   keyInstallMessage : string — last PASTE & SAVE outcome ("" = none)
//
// Window roles: "session" (5h tokens), "weekly" (7d tokens), "search"
// (TIME_LIMIT) or "other". burnPerHour/etaLabel come from an in-memory
// per-window sample history (60 polls max), so they are "—" until the second
// poll after a reset.
//
// SIGNALS
//   thresholdAlert(var info)  — {windowName, pct, urgency, resetLabel}
//                               ONE per window per poll, and only from the
//                               copy holding the alert role (alertRole);
//                               announced thresholds survive reloads on disk
//   dataRefreshed()           — new data in; overlays re-paint sparkline
//
// FUNCTIONS
//   installKeyFromClipboard() — PASTE & SAVE; see API KEY above
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell
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
    property string errorTitle: "CONNECTION ERROR"
    property string errorMessage: ""
    property string lastUpdated: ""
    property bool keyConfigured: false
    property bool active: false             // overlay drives this with shown-state
    property bool isInstallingKey: false      // PASTE & SAVE check in flight
    property string keyInstallMessage: ""   // last PASTE & SAVE outcome

    // True while the error is about the key (missing or rejected) rather than
    // the network — the panel offers PASTE & SAVE for exactly those two.
    readonly property bool hasKeyError: hasError
        && (errorTitle === "API KEY REJECTED" || errorTitle === "NO API KEY")

    // ---- threshold re-arm state per window, keyed by window.key ----
    //   { <key>: { reset: <epochMs|null>, notified: [<thresholds>] } }
    // A new reset cycle (nextResetTime change) re-arms all thresholds for that
    // window. This is the ONE piece of state the service keeps on disk (every
    // other service is stateless): held in memory only, every start, restart
    // and config reload began with `notified: []` and re-announced each
    // threshold the quota had already passed.
    property var _threshState: ({})
    readonly property string threshStateFile: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state"))
        + "/velocity/zai-thresholds.json"

    // Only the copy wired to ZaiAlertBridge evaluates thresholds and owns the
    // state file above. The shell instantiates this singleton under two URL
    // roots (its config VFS, and the plugin host's file:// tree) — the same
    // split the ownership pin in shell.qml describes — so "the copy that
    // alerts" has to be claimed explicitly.
    property bool alertRole: false
    function claimAlertRole() { root.alertRole = true; return true }

    // Same FileView contract as LauncherFrecency: blockLoading makes the boot
    // read synchronous, atomicWrites keeps crash-writes clean.
    FileView {
        id: threshStore
        path: root.threshStateFile
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onSaveFailed: console.warn("[ZaiUsageService] threshold state save failed — passed thresholds may be re-announced")
    }

    // Rolling samples per window key for burn-rate/ETA: [{t, pct, reset}],
    // capped at 60 polls. Process memory only — unlike _threshState, samples
    // are not worth a file.
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
                root._setError("NO API KEY",
                               "No Z.ai API key saved. Copy the key from z.ai, then PASTE & SAVE.")
                root.keyInstallMessage = ""
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
                    root._setError("CONNECTION ERROR", "No response from Z.ai")
                }
                return
            }
            try {
                root._handleJson(JSON.parse(trimmed))
            } catch (e) {
                // don't clobber a real "unconfigured" error with a parse noise message
                if (root.keyConfigured) {
                    root._setError("CONNECTION ERROR", "Bad response from Z.ai")
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

    // =========================================================================
    // PASTE & SAVE — install a new key from the clipboard
    // =========================================================================
    // ONE sh process does everything, so the key never enters QML JS memory or
    // any argv: wl-paste is read INSIDE the shell, checked against the
    // endpoint (the same curl --config - trick as the poll), and only a key
    // Z.ai accepts is written — 0600 via umask, tmp+mv so a crashed write
    // cannot leave a half file or loosen the mode. The process prints exactly
    // one status word:
    //   EMPTY        clipboard empty / wl-paste failed
    //   REJECTED     Z.ai refused the key (401 "token expired or incorrect", or the 10xx family — both seen live)
    //   NO_RESPONSE  curl timed out / network down — the key was NOT judged
    //   BAD_RESPONSE Z.ai answered something else (5xx, HTML page)
    //   WRITE_FAILED the file could not be written
    //   OK           saved
    // curl's --max-time (10s) sits under the 15s bound, so a slow check is
    // reported by the script rather than dropped by the limit.
    BoundedProcess {
        id: keyInstaller
        command: []
        timeoutMs: 15000
        onDone: function(out) {
            root.isInstallingKey = false
            var status = (out || "").trim()
            if (status === "OK") {
                root.keyInstallMessage = "KEY SAVED · SYNCED " + root._clock()
                root.keyConfigured = true
                root.refresh()
                return
            }
            console.warn("[ZaiUsageService] key install: " + status)
            root.keyInstallMessage =
                status === "REJECTED"     ? "Z.ai rejected the clipboard key — copy the API key itself." :
                status === "EMPTY"        ? "Clipboard is empty — copy the API key first." :
                status === "NO_RESPONSE"  ? "No response from Z.ai — nothing was saved. Try again." :
                status === "BAD_RESPONSE" ? "Z.ai answered unexpectedly — nothing was saved. Try again." :
                status === "WRITE_FAILED" ? "Could not write " + root.keyFile + " — nothing was saved." :
                                            "Key check failed — nothing was saved."
        }
        // onDone is not called when the bound trips — without this the
        // panel's button would stay disabled forever.
        onLimit: function(reason) {
            root.isInstallingKey = false
            root.keyInstallMessage = reason === "overflow"
                ? "Key check hit its output limit — nothing was saved."
                : "Key check timed out — nothing was saved."
            console.warn("[ZaiUsageService] key install limit: " + reason)
        }
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

    // -------------------------------------------------------------------------
    // PASTE & SAVE (the panel button). Guards against a double click; the
    // outcome lands in keyInstallMessage, a saved key triggers a fresh poll.
    function installKeyFromClipboard() {
        if (root.isInstallingKey) return
        root.isInstallingKey = true
        root.keyInstallMessage = "CHECKING WITH Z.AI…"
        keyInstaller.command = root._installCommand()
        keyInstaller.run()
    }

    // $1 = key file, $2 = endpoint. The key lives only in the shell variable
    // KEY (never exported) and in curl's stdin config — never in argv.
    function _installCommand() {
        return ["sh", "-c", root._installScript, "sh", root.keyFile, root.apiUrl]
    }

    // The statements are joined with a space. Every quote in the shell text is
    // a double quote (the JS delimiters are single quotes); printf's "\042"
    // is a literal double quote, so the needles need no nested quoting.
    // The EXIT trap removes the tmp file if the process is killed between
    // mktemp and mv — otherwise a valid key copy would stay on disk.
    readonly property string _installScript: [
        'TMP=""; trap "[ -n \\"\\$TMP\\" ] && rm -f \\"\\$TMP\\"" EXIT;',
        'KEY="$(wl-paste --no-newline 2>/dev/null | tr -d "[:space:]")";',
        '[ -n "$KEY" ] || { echo EMPTY; exit 0; };',
        'BODY="$(printf "header = \\"Authorization: Bearer %s\\"\\n" "$KEY" | curl -s --max-time 10 --config - "$2")";',
        '[ -n "$BODY" ] || { echo NO_RESPONSE; exit 0; };',
        'PAT="$(printf "\\042success\\042:true")"; REJ="$(printf "\\042code\\042:401")"; REJ2="$(printf "\\042code\\042:10")";',
        'case "$(printf "%s" "$BODY" | tr -d "[:space:]")" in *"$PAT"*) ;; *"$REJ"*) echo REJECTED; exit 0 ;; *"$REJ2"[0-9][0-9]*) echo REJECTED; exit 0 ;; *) echo BAD_RESPONSE; exit 0 ;; esac;',
        'umask 077;',
        'TMP="$(mktemp "$1.XXXXXX")" || { echo WRITE_FAILED; exit 0; };',
        'printf "%s\\n" "$KEY" > "$TMP" && mv -f "$TMP" "$1" || { echo WRITE_FAILED; exit 0; };',
        'echo OK'
    ].join(" ")

    // =========================================================================
    // RESPONSE HANDLING
    // =========================================================================
    function _handleJson(payload) {
        if (!payload || !payload.success || !payload.data || !payload.data.limits) {
            // 1000 ("authentication failed", seen live on a revoked key) and
            // 401 ("token expired or incorrect", seen live on a bogus key)
            // are Z.ai's auth failures: the key is dead, not the network —
            // say so, the panel offers PASTE & SAVE right under this message.
            if (payload && (payload.code === 1000 || payload.code === 401)) {
                console.warn("[ZaiUsageService] API key rejected by Z.ai (code " + payload.code + ")")
                root.keyInstallMessage = ""
                root._setError("API KEY REJECTED",
                               "Z.ai rejected the saved key. Copy a new one and PASTE & SAVE.")
            } else {
                root._setError("CONNECTION ERROR", "Z.ai usage response unsuccessful.")
            }
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
            root._setError("CONNECTION ERROR", "No quota limits in Z.ai response.")
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

    // Fire ONE notification per window per poll: every threshold the window
    // has freshly passed collapses into the highest of them (that one sets
    // the urgency) and all of them are marked notified. Re-arms every
    // threshold when the window's reset cycle changes. Only the alert-role
    // copy evaluates (see alertRole), and a change is written to disk so a
    // reload or restart never repeats an announcement.
    function _checkThresholds(wins) {
        if (!root.alertRole) return
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
            var top = -1
            for (var t = 0; t < root.thresholds.length; t++) {
                var th = root.thresholds[t]
                if (win.pct >= th && cyc.notified.indexOf(th) < 0) {
                    cyc.notified.push(th)
                    top = th
                    changed = true
                }
            }
            if (top >= 0) {
                root.thresholdAlert({
                    windowName: win.label,
                    pct: win.pct,
                    urgency: top >= 90 ? 2 : (top >= 75 ? 1 : 0),
                    resetLabel: win.resetLabel
                })
            }
        }
        if (changed) {
            root._threshState = st
            root._persistThreshState()
        }
    }

    function _persistThreshState() {
        threshStore.setText(JSON.stringify({ v: 1, windows: root._threshState }))
    }

    // Disk shape { v: 1, windows: { <key>: { reset, notified: [...] } } }.
    // Anything else — missing, empty, corrupt, another version — starts
    // clean: a bad file costs one re-announce, never a crash.
    function _loadThreshState(raw) {
        var parsed
        try {
            parsed = JSON.parse(String(raw || ""))
        } catch (e) {
            return {}
        }
        if (!parsed || parsed.v !== 1 || !parsed.windows) return {}
        var out = {}
        var keys = Object.keys(parsed.windows)
        for (var i = 0; i < keys.length; i++) {
            var c = parsed.windows[keys[i]]
            if (!c || !Array.isArray(c.notified)) continue
            out[keys[i]] = { reset: (c.reset === undefined ? null : c.reset),
                             notified: c.notified }
        }
        return out
    }

    // ---- helpers ----
    // Every error goes through here so the card's title and message always
    // describe the same failure (a rejected key is not a connection error).
    function _setError(title, message) {
        root.hasError = true
        root.errorTitle = title
        root.errorMessage = message
    }

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
        root._threshState = root._loadThreshState(threshStore.text())
        keyCheck.command = ["sh", "-c", 'test -f "$1" && echo 1 || echo 0', "sh", root.keyFile]
        keyCheck.run()
    }
}
