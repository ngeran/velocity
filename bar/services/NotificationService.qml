// =============================================================================
// NotificationService.qml — notification store (ListModel) + CRUD + counter
// =============================================================================
// Single source of truth for notifications in the bar process. The bar trigger
// (NotificationButton), the panel (NotificationCenter) and the IPC ingest all
// read/write this one model.
//
// INGEST — push a notification from anywhere on the system:
//   quickshell ipc --config bar call notifications add \
//     '{"appName":"Firefox","summary":"Download complete","body":"file.tar.gz","urgency":1}'
//   quickshell ipc --config bar call notifications clear
//
// The org.freedesktop.Notifications DBus name cannot be owned natively by
// Quickshell 0.3.0 (no QML DBus-server API), so a tiny forwarder daemon pushes
// real system notifications through the IPC above (see docs/notify-forwarder).
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    // -------------------------------------------------------------------------
    // MODEL — each row: { id, appName, appIcon, summary, body, urgency, timestamp, read }
    // -------------------------------------------------------------------------
    property ListModel model: ListModel {}
    property int unreadCount: 0
    property int nextId: 1

    // -------------------------------------------------------------------------
    // HISTORY — rows ARCHIVED ON EXPIRY (the reaper), not explicit dismissals
    // (those are intentional deletions). In-memory, capped; the promise from
    // the review was "expired → history, not void".
    // -------------------------------------------------------------------------
    property ListModel history: ListModel {}
    readonly property int historyMax: 50

    function clearHistory() { root.history.clear() }

    // -------------------------------------------------------------------------
    // SOFT CLEAR — clear-as-timestamp. `clear` HIDES rows (everything with
    // timestamp <= clearedAt) instead of destroying them: rows move to
    // clearedModel, stay on disk, keep their read-marks, and restore() brings
    // them back. clearedAt persists in notifications.cleared (one number, ms;
    // 0 = nothing hidden) so a cleared bar stays cleared across restarts —
    // and a missing/garbage file fails safe: nothing hidden.
    // -------------------------------------------------------------------------
    property real clearedAt: 0
    readonly property string clearedPath: "~/.config/quickshell/notifications.cleared"
    property ListModel clearedModel: ListModel {}
    readonly property int clearedCount: clearedModel.count

    // Per-app glyphs (nerd-font md icons), matched case-insensitively against
    // appName; an appIcon payload that is already a nerd glyph wins; the bell
    // is the fallback.
    function appGlyph(name, icon) {
        if (icon && String(icon).length > 0) return icon
        var n = (name || "").toLowerCase()
        if (n.indexOf("firefox") !== -1)    return "󰈹"
        if (n.indexOf("chrom") !== -1)      return "󰊯"
        if (n.indexOf("z.ai") !== -1)       return "󰚩"
        if (n.indexOf("discord") !== -1)    return "󰙯"
        if (n.indexOf("telegram") !== -1)   return "󰍿"
        if (n.indexOf("terminal") !== -1 || n.indexOf("kitty") !== -1) return "󰄛"
        if (n.indexOf("mail") !== -1 || n.indexOf("thunderbird") !== -1) return "󰇮"
        if (n.indexOf("music") !== -1 || n.indexOf("spotify") !== -1 || n.indexOf("mpv") !== -1) return "󰎈"
        if (n.indexOf("update") !== -1 || n.indexOf("pacman") !== -1) return "󰏖"
        if (n.indexOf("bluetooth") !== -1)  return "󰂯"
        if (n.indexOf("network") !== -1 || n.indexOf("wifi") !== -1) return "󰖩"
        if (n.indexOf("battery") !== -1 || n.indexOf("power") !== -1) return "󰁹"
        return "󰂚"
    }

    // "now" ticks every 30s so cards can render relative timestamps ("5m ago")
    // without each card owning its own timer.
    property real now: Date.now()
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: root.now = Date.now()
    }

    // Do-Not-Disturb: when on, new notifications arrive SILENTLY — no badge,
    // no pulse — but the row PERSISTS (they are not marked read: read rows
    // expire by tier, which used to destroy DnD arrivals within seconds, unseen).
    // The silent mark is persisted per-row; rows stay badge-silent even after
    // DnD turns off. Opening the panel marks them read like any other row.
    // Persisted to ~/.config/quickshell/dnd.flag across restarts.
    property bool dnd: false
    property bool panelOpen: false   // set by NotificationCenter — suppresses reaping while open
    readonly property string _dndFlag: "~/.config/quickshell/dnd.flag"

    // -------------------------------------------------------------------------
    // PERSISTENCE — notifications.jsonl through the bar's write funnel
    // (EventService._atomicWrite). The model survives bar restarts: read-marks
    // (read/readAt), DnD-silent marks and unread rows all persist (read rows
    // still expire by tier once their clock ran out before the restart).
    // Restored rows get clickId=0 — the previous session's DBus action ids
    // died with it. Disk order is OLDEST-FIRST (the reader's contract).
    // Soft-cleared rows persist on disk too — the reader routes them by
    // timestamp vs clearedAt (see SOFT CLEAR above).
    // -------------------------------------------------------------------------
    readonly property string storePath: "~/.config/quickshell/notifications.jsonl"
    readonly property int storeMax: 200
    readonly property int storeMaxBytes: 262144   // reader input cap (256 KiB)

    function _storeLine(r) {
        return JSON.stringify({
            id: r.id, appName: r.appName, summary: r.summary, body: r.body,
            urgency: r.urgency, timestamp: r.timestamp,
            read: r.read, readAt: r.readAt || 0, silent: r.silent || false
        })
    }

    function _persist() {
        var lines = []
        for (var i = root.model.count - 1; i >= 0 && lines.length < root.storeMax; i--)
            lines.push(root._storeLine(root.model.get(i)))         // oldest first on disk
        for (var j = root.clearedModel.count - 1; j >= 0 && lines.length < root.storeMax; j--)
            lines.push(root._storeLine(root.clearedModel.get(j)))  // visible rows win the cap
        EventService._atomicWrite(root.storePath, lines.join("\n") + "\n")
    }

    Process {   // unbounded-ok: one-shot 32-byte read, exits at EOF
        id: _clearedReader
        command: []
        running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { _clearedReader.buffer += data + "\n" } }
        onRunningChanged: if (!running) {
            var v = parseFloat(_clearedReader.buffer.trim())
            root.clearedAt = (isFinite(v) && v > 0) ? v : 0
            _clearedReader.buffer = ""
            // The store read ROUTES on clearedAt, so it starts here — not in
            // Component.onCompleted — to keep the two async reads ordered.
            _storeReader.command = ["sh", "-c", "head -c " + root.storeMaxBytes + " " + root.storePath + " 2>/dev/null || true"]
            _storeReader.running = true
        }
    }

    Process {   // unbounded-ok: one-shot byte-capped store read (head -c), exits at EOF
        id: _storeReader
        command: []
        running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { _storeReader.buffer += data + "\n" } }
        onRunningChanged: if (!running) {
            var lines = _storeReader.buffer.split("\n")
            _storeReader.buffer = ""
            var restored = 0, corrupt = 0, maxId = 0
            // Disk is OLDEST-FIRST (writer's contract), so a straight walk with
            // insert(0) lands the newest row at index 0 — the model's ordering
            // invariant. (The old backwards walk restored the list reversed.)
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                if (!l) continue
                var d = null
                try { d = JSON.parse(l) } catch (e) { d = null }
                // Per-line corrupt recovery: one bad line never blocks the
                // rest. It is logged in full (quarantine-by-log) and healed
                // away by the clean-store rewrite below; every other line
                // still restores. Shape-check too — JSON.parse("123") parses.
                if (!d || typeof d !== "object" || Array.isArray(d) ||
                    typeof d.id !== "number" || !(d.id >= 1) ||
                    typeof d.timestamp !== "number" || !(d.timestamp > 0)) {
                    console.warn("[NotificationService] store: corrupt line skipped:", l)
                    corrupt++
                    continue
                }
                var row = {
                    id: Math.floor(d.id), clickId: 0,
                    appName: String(d.appName || "Notification"), appIcon: "",
                    glyph: root.appGlyph(d.appName, ""),
                    summary: String(d.summary || ""), body: String(d.body || ""),
                    urgency: Math.min(2, Math.max(0, Math.floor(d.urgency === undefined ? 1 : d.urgency))),
                    timestamp: d.timestamp,
                    read: d.read === true, readAt: (typeof d.readAt === "number" && isFinite(d.readAt)) ? d.readAt : 0,
                    silent: d.silent === true
                }
                if (row.timestamp <= root.clearedAt)
                    root.clearedModel.insert(0, row)   // hidden by the soft clear
                else
                    root.model.insert(0, row)
                restored++
                if (row.id > maxId) maxId = row.id
            }
            if (maxId >= root.nextId) root.nextId = maxId + 1
            root._recount()
            if (corrupt > 0) {
                console.warn("[NotificationService] store: " + corrupt +
                             " corrupt line(s) dropped — rewriting a clean store")
                root._persist()   // heal now, not on the next unrelated write
            }
            console.log("[NotificationService] restored " + root.model.count + " notifications" +
                        (root.clearedModel.count > 0 ? " (" + root.clearedModel.count + " cleared)" : ""))
        }
    }

    Process {   // unbounded-ok: one-shot 32-byte flag read, exits at EOF
        id: _dndReader
        command: []
        running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { _dndReader.buffer += data + "\n" } }
        onRunningChanged: if (!running) { root.dnd = (_dndReader.buffer.trim() === "1"); _dndReader.buffer = "" }
    }
    function setDnd(on) {
        root.dnd = on
        var w = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        w.command = ["sh", "-c", "printf '%s' '" + (on ? "1" : "0") + "' > " + root._dndFlag]
        w.onExited.connect(function() { w.destroy() })  // free the one-shot wrapper (was leaked per toggle)
        w.running = true
    }

    // Auto-dismiss with urgency-tiered lifetimes (Omarchy pattern). READ rows
    // expire by tier; UNREAD rows never auto-expire (dropping an unseen row
    // silently drops the badge too — the user never learns it existed); CRITICAL
    // rows persist even when read until explicitly dismissed/cleared. On expiry
    // the originating app is told via the bridge (NotificationClosed semantics),
    // so it stops tracking the notification.
    //   low (0) → 6s after read · normal (1) → 12s after read · critical (2) → never
    function _lifetimeMs(urgency) {
        if (urgency >= 2) return 0
        if (urgency === 1) return 12000
        return 6000
    }

    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: {
            if (root.panelOpen) return   // user is reading
            var nowMs = Date.now()
            var removed = 0
            for (var i = root.model.count - 1; i >= 0; i--) {
                var row = root.model.get(i)
                if (!row.read) continue                    // unseen → keep (badge truth)
                var life = root._lifetimeMs(row.urgency)
                if (life === 0) continue                   // critical → keep
                if ((row.readAt || row.timestamp) + life < nowMs) {
                    if (row.clickId) root.dismissDbus(row.clickId)
                    // Archive to history before removal (expiry ≠ dismissal).
                    root.history.insert(0, {
                        appName: row.appName, summary: row.summary,
                        ts: row.timestamp, urgency: row.urgency
                    })
                    if (root.history.count > root.historyMax)
                        root.history.remove(root.history.count - 1)
                    root.model.remove(i)
                    removed++
                }
            }
            if (removed > 0) root._persist()
            root._recount()
        }
    }

    function _recount() {
        var n = 0
        for (var i = 0; i < root.model.count; i++) {
            var r = root.model.get(i)
            if (!r.read && !r.silent) n++   // DnD-silent arrivals never badge
        }
        root.unreadCount = n
    }

    // -------------------------------------------------------------------------
    // PUBLIC API
    // -------------------------------------------------------------------------
    // urgency: 0 = low, 1 = normal, 2 = critical
    function add(appName, summary, body, urgency, clickId, appIcon) {
        root.model.insert(0, {
            id: root.nextId,
            clickId: (clickId === undefined ? 0 : clickId),  // DBus id for ActionInvoked (0 = none)
            appName: appName || "Notification",
            appIcon: appIcon || "",
            glyph: root.appGlyph(appName, appIcon),
            summary: summary || "",
            body: body || "",
            urgency: (urgency === undefined ? 1 : urgency),
            timestamp: Date.now(),
            read: false,
            silent: root.dnd,  // DnD arrival: badge stays quiet, row persists
            readAt: 0          // set when marked read — tier clock starts at READ
        })
        root.nextId++
        root._recount()
        root._persist()
    }

    // Click-to-open: tell the forwarder (org.quickshell.NotifyBridge) to emit
    // ActionInvoked / NotificationClosed so the originating app (e.g. Chromium)
    // opens the content / stops tracking it. QML can't emit DBus itself, so we
    // shell out to dbus-send (no-op if clickId is 0, i.e. no actions).
    function _bridgeCall(method, clickId) {
        if (!clickId) return
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        p.command = ["dbus-send", "--session",
                     "--dest=org.freedesktop.Notifications",
                     "--type=method_call",
                     "/org/freedesktop/Notifications",
                     "org.quickshell.NotifyBridge." + method,
                     "uint32:" + clickId]
        p.onExited.connect(function() { p.destroy() })  // free the one-shot wrapper (was leaked per click)
        p.running = true
    }

    function invokeAction(clickId) { root._bridgeCall("Invoke", clickId) }
    function dismissDbus(clickId) { root._bridgeCall("Dismiss", clickId) }

    function markRead(id) {
        for (var i = 0; i < root.model.count; i++) {
            if (root.model.get(i).id === id) {
                root.model.setProperty(i, "read", true)
                root.model.setProperty(i, "readAt", Date.now())
                break
            }
        }
        root._recount()
        root._persist()
    }

    function markAllRead() {
        var nowMs = Date.now()
        for (var i = 0; i < root.model.count; i++) {
            root.model.setProperty(i, "read", true)
            root.model.setProperty(i, "readAt", nowMs)
        }
        root._recount()
        root._persist()
    }

    function remove(id) {
        for (var i = 0; i < root.model.count; i++) {
            if (root.model.get(i).id === id) { root.model.remove(i); break }
        }
        root._recount()
        root._persist()
    }

    // Soft clear: hide instead of destroy (see SOFT CLEAR above). Rows move to
    // clearedModel with their read-marks intact; nothing is deleted, no DBus
    // dismissal is sent (the rows may come back). A row stamped in the future
    // (clock skew) stays visible — only pre-clear rows hide.
    function clearAll() {
        var nowMs = Date.now()
        root.clearedAt = nowMs
        for (var i = 0; i < root.model.count; ) {
            var r = root.model.get(i)
            if ((r.timestamp || 0) <= nowMs) {
                root.clearedModel.append(root._rowCopy(r))  // copy: get() goes stale after remove
                root.model.remove(i)
            } else i++
        }
        root._recount()
        root._persist()
        root._writeCleared()
    }

    // Undo the clear: every hidden row comes back, merged newest-first.
    // Read-marks survive the round trip — a restored row resumes the tier
    // clock it already had, so read rows past their tier expire again within
    // one reaper tick, while unread and critical rows stay for good. Still-
    // unread rows re-light the badge: the clear was soft, so is the undo.
    // Rows are COPIED before the merge: ListModel.get() results go stale once
    // their model is mutated (clear/removal), and a stale object appends as a
    // row of role defaults.
    function restoreCleared() {
        if (root.clearedModel.count === 0) return
        var rows = []
        for (var i = 0; i < root.model.count; i++) rows.push(root._rowCopy(root.model.get(i)))
        for (var j = 0; j < root.clearedModel.count; j++) rows.push(root._rowCopy(root.clearedModel.get(j)))
        rows.sort(function(a, b) { return (b.timestamp || 0) - (a.timestamp || 0) })
        root.model.clear()
        for (var k = 0; k < rows.length; k++) root.model.append(rows[k])
        root.clearedModel.clear()
        root.clearedAt = 0
        root._recount()
        root._persist()
        root._writeCleared()
    }

    function _rowCopy(r) {
        return {
            id: r.id, clickId: r.clickId || 0,
            appName: String(r.appName || ""), appIcon: r.appIcon || "",
            glyph: r.glyph || "",
            summary: String(r.summary || ""), body: String(r.body || ""),
            urgency: r.urgency, timestamp: r.timestamp || 0,
            read: r.read === true, readAt: r.readAt || 0, silent: r.silent === true
        }
    }

    function _writeCleared() {
        var w = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        w.command = ["sh", "-c", "printf '%s' '" + root.clearedAt + "' > " + root.clearedPath]
        w.onExited.connect(function() { w.destroy() })
        w.running = true
    }

    // -------------------------------------------------------------------------
    // IPC INGEST — system / daemon entry point
    // -------------------------------------------------------------------------
    IpcHandler {
        target: "notifications"

        // args = single JSON string: {appName, summary, body, urgency}
        function add(json: string) {
            var d = null
            try { d = JSON.parse(json) } catch (e) {
                console.warn("[NotificationService] IPC add: bad json:", json)
                return
            }
            root.add(d.appName, d.summary, d.body, d.urgency, d.clickId, d.appIcon)
        }

        function clear() { root.clearAll() }        // soft: hides, undo with restore()

        // Bring cleared rows back (the panel footer's RESTORE does the same).
        function restore() { root.restoreCleared() }

        // Inspection / scripting hooks: mark everything read and dump the model.
        function readAll() { root.markAllRead() }
        function list(): string {
            var rows = []
            for (var i = 0; i < root.model.count; i++) rows.push(root.model.get(i))
            return JSON.stringify(rows)
        }
    }

    Component.onCompleted: {
        _dndReader.command = ["sh", "-c", "cat " + root._dndFlag + " 2>/dev/null || true"]
        _dndReader.running = true
        _clearedReader.command = ["sh", "-c", "cat " + root.clearedPath + " 2>/dev/null || true"]
        _clearedReader.running = true   // chains the store read (routing needs clearedAt)
    }
}
