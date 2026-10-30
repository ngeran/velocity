// =============================================================================
// BrightnessService.qml — display brightness for the Control Center (P4.4)
// =============================================================================
// OUTPUTS MODEL: one bounded probe sweep builds `outputs` —
//   [{ id, kind: "backlight"|"ddc", name, percent }]
//   backlight — `brightnessctl -m -c backlight` (CSV: name,type,cur,max,pct;
//               percent computed here from cur/max)
//   ddc       — `ddcutil detect --brief` display indices (+ model when the
//               output carries one), percent filled per display by
//               `ddcutil --display N getvcp 10 --brief` ("VCP 10 C cur max")
// `primary` = outputs[0]; percent/setPercent stay primary-facing — the CC
// slider binds the primary output (one output today: HDMI-A-1 DDC).
// No tool / no device (also: i2c-dev module absent) → outputs empty,
// `available` false, the slider hides. Zero idle cost: probes run only on
// refresh() (Control Center open); writes are debounced per settle.
// =============================================================================

pragma Singleton

import QtQuick

Item {
    id: root
    visible: false

    property string backend: ""          // "" = not probed yet; "none" after a dead sweep
    property var outputs: []             // [{ id, kind, name, percent(-1 = unread) }]
    readonly property bool available: outputs.length > 0
    readonly property var primary: outputs.length > 0 ? outputs[0] : null
    // Primary-facing alias (CC slider + qa): clamped so an unread DDC (-1)
    // never drives the control below its range.
    property int percent: primary ? Math.max(0, Math.min(100, primary.percent)) : 50

    function refresh() {
        sweep.run()
    }

    function setPercent(p) {
        if (primary) setOutputPercent(primary.id, p)
    }

    function setOutputPercent(id, p) {
        const o = _byId(id)
        if (!o) return
        const v = Math.max(1, Math.min(100, Math.round(p)))
        _pendingId = String(id)
        _pendingVal = v
        _echoPercent(_pendingId, v)   // local echo — DDC writes are slow
        writeDebounce.restart()
    }

    // ── internals ────────────────────────────────────────────────────────────
    property string _pendingId: ""
    property int _pendingVal: 0

    function _byId(id) {
        for (let i = 0; i < root.outputs.length; i++)
            if (String(root.outputs[i].id) === String(id)) return root.outputs[i]
        return null
    }

    // Reassign (new array) so the percent bindings re-fire (nested-var rule).
    function _echoPercent(id, v) {
        const rows = []
        for (let i = 0; i < root.outputs.length; i++) {
            const o = root.outputs[i]
            rows.push(String(o.id) === String(id)
                ? { id: o.id, kind: o.kind, name: o.name, percent: v } : o)
        }
        root.outputs = rows
    }

    function _absorb(rows, line) {
        const f = line.split("|")
        if (f.length < 4) return
        if (f[0] === "backlight") {
            const cur = Number(f[2]), max = Number(f[3])
            rows.push({
                id: f[1], kind: "backlight", name: f[1],
                percent: max > 0 ? Math.round(cur * 100 / max) : -1
            })
        } else if (f[0] === "ddc") {
            rows.push({
                id: f[1], kind: "ddc",
                name: f.slice(2).join("|") !== "" ? f.slice(2).join("|") : "DDC " + f[1],
                percent: -1
            })
        }
    }

    // ── SWEEP — one bounded probe builds the whole list ──────────────────────
    // Guarded: the ddcutil leg only runs when /dev/i2c-* exists (the module
    // i2c-dev missing must fail fast, not spin).
    BoundedProcess {
        id: sweep
        command: ["sh", "-c",
            "if command -v brightnessctl >/dev/null 2>&1; then " +
            "brightnessctl -m -c backlight 2>/dev/null | grep -v '^Device name' | " +
            "while IFS=, read -r nm ty cur mx pc; do " +
            "[ \"$ty\" = 'backlight' ] && echo \"backlight|$nm|$cur|$mx\"; done; fi; " +
            "if command -v ddcutil >/dev/null 2>&1 && ls /dev/i2c-* >/dev/null 2>&1; then " +
            "ddcutil detect --brief 2>/dev/null | awk " +
            "'/^[Dd]isplay [0-9]+/ { n=$NF; order[++c]=n; models[n]=\"\"; next } " +
            "tolower($0) ~ /model/ { split($0, a, \":\"); models[n]=a[2] } " +
            "END { for (i=1; i<=c; i++) { gsub(/^ +| +$/, \"\", models[order[i]]); " +
            "print \"ddc|\" order[i] \"|\" (models[order[i]]==\"\" ? \"DDC \" order[i] : models[order[i]]) } }'; fi"]
        timeoutMs: 10000
        onDone: function(out, err, code) {
            const rows = []
            const lines = out.split("\n")
            for (let i = 0; i < lines.length; i++) root._absorb(rows, lines[i].trim())
            root.outputs = rows   // ONE reassignment → notifies once
            let kinds = []
            for (let j = 0; j < root.outputs.length; j++)
                if (kinds.indexOf(root.outputs[j].kind) === -1) kinds.push(root.outputs[j].kind)
            root.backend = kinds.length > 0 ? kinds.join("+") : "none"
            // Fill unread DDC percents in one follow-up call (skips sh -c when
            // there is nothing to read).
            let idxs = []
            for (let k = 0; k < root.outputs.length; k++)
                if (root.outputs[k].kind === "ddc") idxs.push(root.outputs[k].id)
            if (idxs.length > 0) {
                let cmd = "for d in " + idxs.join(" ") + "; do " +
                    "ddcutil --display $d getvcp 10 --brief 2>/dev/null | " +
                    "awk -v d=$d '/^VCP 10/ { print \"pct|\" d \"|\" $4 \"/\" $5 }'; done"
                ddcRead.command = ["sh", "-c", cmd]
                ddcRead.run()
            }
            console.log("[BrightnessService] sweep: backend=" + root.backend +
                        " outputs=" + JSON.stringify(root.outputs))
        }
        onLimit: function() { root.backend = "none"; root.outputs = [] }
    }

    // Per-display DDC percent read: lines "pct|<display>|<cur>/<max>"
    BoundedProcess {
        id: ddcRead
        timeoutMs: 20000   // ddcutil is slow per call (~1s/display)
        onDone: function(out, err, code) {
            if (code !== 0) return
            const lines = out.split("\n")
            for (let i = 0; i < lines.length; i++) {
                const f = lines[i].trim().split("|")
                if (f.length !== 3 || f[0] !== "pct") continue
                const pair = f[2].split("/")
                const cur = Number(pair[0]), max = Number(pair[1])
                if (max > 0) root._echoPercent(f[1], Math.round(cur * 100 / max))
            }
        }
    }

    // ── WRITES — debounced per settle, one command for the pending output ────
    Timer {
        id: writeDebounce
        interval: 250
        onTriggered: {
            const o = root._byId(root._pendingId)
            if (!o) return
            writer.command = o.kind === "ddc"
                ? ["ddcutil", "--display", String(o.id), "setvcp", "10", String(root._pendingVal)]
                : ["brightnessctl", "-q", "-c", "backlight", "--device=" + o.id,
                   "set", root._pendingVal + "%"]
            writer.run()
        }
    }
    BoundedProcess {
        id: writer
        timeoutMs: 8000
    }
}
