// =============================================================================
// NotificationService.qml — notification store (ListModel) + CRUD + counter
// =============================================================================
// Single source of truth for notifications in the bar process. The bar trigger
// (NotificationButton), the panel (NotificationCenter) and the IPC ingest all
// read/write this one model.
//
// INGEST — push a notification from anywhere on the system:
//   qs -c bar ipc call notifications add \
//     '{"appName":"Firefox","summary":"Download complete","body":"file.tar.gz","urgency":1}'
//   qs -c bar ipc call notifications clear
//
// INGEST PATHS (J1b) — real system notifications arrive NATIVELY: a
// NotificationServer (Loader-hosted) claims org.freedesktop.Notifications,
// tracks arrivals and maps them into the same model with real actions, image
// and progress hints — no daemon, no dbus-send forks for actions. A one-shot
// NameHasOwner probe at startup stays as the interlock: if something else
// already owns the name (a manually started mako/dunst, …) we never construct
// the server — two servers would fight — and log the stand-down; ingest for
// such setups falls back to the IPC above. Scripts keep using
// `notifications add`.
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io
import Quickshell.Services.Notifications
import "../engine/lib/activity-queue.mjs" as Aq
import "../config" as Config

Item {
    id: root
    visible: false

    // -------------------------------------------------------------------------
    // MODEL — each row: { id, appName, appIcon, summary, body, urgency, timestamp, read }
    // -------------------------------------------------------------------------
    property ListModel model: ListModel {}
    property int unreadCount: 0
    property int nextId: 1

    // Live-arrival hook. Emitted for EVERY add() — the J2 arrival peek is
    // driven by this service itself (see _peek); the signal stays public for
    // any other view that wants the raw arrival event.
    signal arrived(var row)

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
    // ABSOLUTE paths (B7 corollary): these used to be "~/.config/..." and only
    // worked because every consumer pasted them into a `sh -c` string where the
    // shell expanded the tilde. The argv forms pass them literally — so resolve
    // the home prefix here instead and keep the argv shapes safe.
    readonly property string homeDir: ("" + StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "")
    readonly property string clearedPath: root.homeDir + "/.config/quickshell/notifications.cleared"
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
    // without each card owning its own timer. Cards only render inside the
    // notification center, so it ticks only while that panel is open.
    property real now: Date.now()
    Timer {
        interval: 30000; running: root.panelOpen; repeat: true
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
    onPanelOpenChanged: if (panelOpen) root.now = Date.now()
    // True while some row can auto-expire (read, not critical) — gates the sweep.
    property bool _hasExpiring: false
    readonly property string _dndFlag: root.homeDir + "/.config/quickshell/dnd.flag"

    // -------------------------------------------------------------------------
    // PERSISTENCE — notifications.jsonl through the bar's write funnel
    // (KernelEventRecorder._atomicWrite). The model survives bar restarts: read-marks
    // (read/readAt), DnD-silent marks and unread rows all persist (read rows
    // still expire by tier once their clock ran out before the restart).
    // Restored rows get clickId=0 — the previous session's DBus action ids
    // died with it. Disk order is OLDEST-FIRST (the reader's contract).
    // Soft-cleared rows persist on disk too — the reader routes them by
    // timestamp vs clearedAt (see SOFT CLEAR above).
    // -------------------------------------------------------------------------
    readonly property string storePath: root.homeDir + "/.config/quickshell/notifications.jsonl"
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
        KernelEventRecorder._atomicWrite(root.storePath, lines.join("\n") + "\n")
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
            // tail (not head): disk is oldest-first, so the NEWEST lines live
            // at the tail — a head cap kept the oldest data and silently
            // dropped every notification past the cap. A mid-line cut at the
            // block's head lands as one tolerated corrupt row.
            _storeReader.command = ["sh", "-c", 'tail -c "$1" "$2" 2>/dev/null || true', "sh", String(root.storeMaxBytes), root.storePath]
            _storeReader.running = true
        }
    }

    Process {   // unbounded-ok: one-shot byte-capped store read (tail -c), exits at EOF
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
        w.command = ["sh", "-c", 'printf "%s" "$1" > "$2"', "sh", on ? "1" : "0", root._dndFlag]
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
        interval: 3000; running: root._hasExpiring && !root.panelOpen; repeat: true
        onTriggered: {
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
                    root._peekGone(row.id)
                    removed++
                }
            }
            if (removed > 0) root._persist()
            root._recount()
        }
    }

    function _recount() {
        var n = 0, expiring = false
        for (var i = 0; i < root.model.count; i++) {
            var r = root.model.get(i)
            if (!r.read && !r.silent) n++   // DnD-silent arrivals never badge
            if (r.read && root._lifetimeMs(r.urgency) > 0) expiring = true
        }
        root.unreadCount = n
        root._hasExpiring = expiring
    }

    // -------------------------------------------------------------------------
    // PUBLIC API
    // -------------------------------------------------------------------------
    // urgency: 0 = low, 1 = normal, 2 = critical
    function add(appName, summary, body, urgency, clickId, appIcon) {
        return root._commitRow({
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
    }

    // Shared tail of both ingest paths: id assignment, insert, badge, store,
    // arrival signal. Extra fields a row may carry (native path only, never
    // persisted — they die with the session like bridge clickIds):
    //   actions [{id,text}] · image "" · progress -1 · native true
    function _commitRow(row) {
        row.id = root.nextId
        root.model.insert(0, row)
        root.nextId++
        root._recount()
        root._persist()
        root.arrived(row)
        root._peek(row)
        return row
    }

    // ── arrival peek (J2) ───────────────────────────────────────────────
    // Arrivals surface as THE peek activity (island row on the island style,
    // floating Osd card elsewhere — never a 2nd window; the old toast
    // PanelWindow is retired, its policy lives on here):
    //   panel open → store only · DnD/silent → store only, EXCEPT critical
    //   · low 4 s / normal 6 s / critical sticky (the queue's hard cap —
    //   nothing is forever; the burn-in dim handles the rest)
    //   · newest wins: each arrival re-upserts the single "notif" slot
    //   · stack ≤ 3: the newest summary shows, "+N" (N ≤ 2) counts further
    //   unread — the panel holds the rest. unreadCount never counts silent
    //   rows, so DnD arrivals don't stack-count.
    //   · a hints.value arrival renders its track but keeps peek rank — the
    //   ladder's "progress" tier is for long-lived task progress, not cards
    // DELIVERY: this service owns the POLICY and exposes the payload as
    // data (peekSpec/peekRev); the shell forwards it into PopupCoordinator.
    // The service must NOT import ../engine itself: this singleton is
    // instantiated under a second URI (long-standing dual-instance
    // phenomenon), and that copy's ../engine resolves to a SECOND
    // PopupCoordinator no renderer reads — publishes into it vanish.
    // Click (island row): markRead retracts the peek via _peekGone, then
    // the notification's default action is invoked.
    readonly property string peekKey: "notif"
    property var peekSpec: null            // reassigned payload (or null = retract)
    property int peekRev: 0                // bump on every peekSpec change
    property int _peekRowId: 0
    function _peek(row) {
        if (root.panelOpen) return
        var critical = row.urgency === 2
        if (!critical && (root.dnd || row.silent)) return
        var rid = row.id
        var cid = row.clickId
        root._peekRowId = rid
        var more = Math.max(0, Math.min(root.unreadCount - 1, 2))
        root.peekSpec = {
            key: root.peekKey,
            priority: "peek",
            icon: row.glyph || "󰂚",
            label: (row.summary || row.appName || "Notification") + (more > 0 ? "  +" + more : ""),
            accent: critical ? Config.ThemeConfig.colors.error : null,
            progress: (row.progress !== undefined && row.progress >= 0) ? row.progress : undefined,
            ttlMs: critical ? Aq.HARD_CAP_MS : ((row.urgency === 0) ? 4000 : 6000),
            activate: function() {
                root.markRead(rid)
                root.invokeAction(cid)
            }
        }
        root.peekRev++
    }
    // The peeked row is gone (dismiss / app-side close / reaper) or seen
    // (read) — retract the peek if it was showing that row.
    function _peekGone(id) {
        if (root._peekRowId !== id) return
        root._peekRowId = 0
        if (root.peekSpec !== null) { root.peekSpec = null; root.peekRev++ }
    }

    // ── native path (J1a/J1b) ───────────────────────────────────────────────
    // One-shot bus-ownership interlock. Free (the normal case since J1b) → the
    // Loader below constructs the NotificationServer and we own the bus.
    // Owned → something ELSE is the notification server (a manually started
    // mako/dunst, …); constructing ours would make two servers fight over the
    // name, so we stand down — the active path is logged either way.
    // Unknown-until-resolved (P1.1): the pre-P1 form only resolved on a
    // well-formed reply, so a dead dbus-send (bus not up yet, binary gone)
    // left us stood down SILENTLY forever. Now exit, error and timeout all
    // resolve — an unresolved probe claims the bus (D8: velocity owns it) and
    // the outcome is logged exactly once.
    property bool _busOwned: false
    property bool _probed: false
    function _resolveProbe(owned) {
        if (_probed) return
        root._busOwned = owned
        root._probed = true
        console.log("[Notifications] " + (owned
            ? "stand-down — org.freedesktop.Notifications owned elsewhere"
            : "native NotificationServer active — owns org.freedesktop.Notifications"))
    }
    BoundedProcess {   // bounded: timeout/error/exit all resolve (P1.1)
        id: _busProbe
        timeoutMs: 5000
        command: ["dbus-send", "--print-reply", "--dest=org.freedesktop.DBus",
                  "/org/freedesktop/DBus", "org.freedesktop.DBus.NameHasOwner",
                  "string:org.freedesktop.Notifications"]
        onDone: function (out, err, code) {
            root._resolveProbe(String(out).indexOf("boolean true") !== -1)
        }
        onLimit: function (reason) {
            console.log("[Notifications] bus probe " + reason + " — assuming free")
            root._resolveProbe(false)
        }
    }

    Loader {
        id: _serverLoader
        active: root._probed && !root._busOwned
        sourceComponent: NotificationServer {
            bodySupported: true
            bodyMarkupSupported: true
            actionsSupported: true
            imageSupported: true
            keepOnReload: false
            onNotification: (n) => root._absorbNative(n)
        }
    }

    // Map a native arrival into the shared model. tracked=true keeps the
    // object alive so action invocation stays valid; the app's own close
    // (replaced/expired elsewhere) removes our row. DnD keeps our semantics:
    // the row persists silent — a critical does not badge through DnD either
    // (deliberate difference from glyph, our documented doctrine).
    function _absorbNative(n) {
        n.tracked = true
        var acts = []
        for (var i = 0; i < n.actions.length && acts.length < 4; i++)
            acts.push({ id: String(n.actions[i].identifier), text: String(n.actions[i].text) })
        var prog = -1
        var hv = n.hints ? n.hints.value : undefined
        if (hv !== undefined && hv !== null) {
            var f = Number(hv)
            if (!isNaN(f)) prog = Math.max(0, Math.min(100, Math.round(f)))
        }
        var row = root._commitRow({
            clickId: n.id,
            appName: n.appName || "Notification",
            appIcon: n.appIcon || "",
            glyph: root.appGlyph(n.appName, n.appIcon),
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency,          // enum Low/Normal/Critical = 0/1/2
            timestamp: Date.now(),
            read: false,
            silent: root.dnd,
            readAt: 0,
            actions: acts,
            image: String(n.image || ""),
            progress: prog,
            native: true
        })
        n.closed.connect(function(reason) { root._removeByClickId(n.id) })
        return row
    }

    function _nativeNotif(clickId) {
        var it = _serverLoader.item
        if (!it) return null
        var list = it.trackedNotifications.values
        for (var i = 0; i < list.length; i++)
            if (list[i].id === clickId) return list[i]
        return null
    }

    function _removeByClickId(clickId) {
        var gone = 0
        for (var i = 0; i < root.model.count; i++)
            if (root.model.get(i).clickId === clickId) {
                gone = root.model.get(i).id
                root.model.remove(i); break
            }
        if (gone) root._peekGone(gone)
        root._recount()
        root._persist()   // app-side close must not resurrect on restart
    }

    // Click-to-open (J1b): we ARE the notification server, so a card click
    // invokes the tracked notification's own action — the server side emits
    // ActionInvoked / NotificationClosed to the originating app (e.g.
    // Chromium), which opens the content / stops tracking it. Restored rows
    // (clickId 0, actions died with the session) resolve to no tracked
    // notification and no-op here.
    function invokeAction(clickId) {
        var n = root._nativeNotif(clickId)
        if (n) {
            for (var i = 0; i < n.actions.length; i++)
                if (n.actions[i].identifier === "default") { n.actions[i].invoke(); return }
            return  // tracked but actionless — the card click just marked it read
        }
    }

    function invokeActionKey(clickId, identifier) {
        var n = root._nativeNotif(clickId)
        if (n) {
            for (var i = 0; i < n.actions.length; i++)
                if (n.actions[i].identifier === identifier) { n.actions[i].invoke(); return }
        }
    }

    function dismissDbus(clickId) {
        var n = root._nativeNotif(clickId)
        if (n) n.dismiss()
    }

    function markRead(id) {
        for (var i = 0; i < root.model.count; i++) {
            if (root.model.get(i).id === id) {
                root.model.setProperty(i, "read", true)
                root.model.setProperty(i, "readAt", Date.now())
                break
            }
        }
        root._peekGone(id)   // seen → the peek retracts (its own click included)
        root._recount()
        root._persist()
    }

    function markAllRead() {
        var nowMs = Date.now()
        for (var i = 0; i < root.model.count; i++) {
            root.model.setProperty(i, "read", true)
            root.model.setProperty(i, "readAt", nowMs)
        }
        root._peekGone(root._peekRowId)   // everything just became seen → the peek retracts (no-op when none is up)
        root._recount()
        root._persist()
    }

    function remove(id) {
        for (var i = 0; i < root.model.count; i++) {
            if (root.model.get(i).id === id) { root.model.remove(i); break }
        }
        root._peekGone(id)
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
        var peekCleared = false
        for (var i = 0; i < root.model.count; ) {
            var r = root.model.get(i)
            if ((r.timestamp || 0) <= nowMs) {
                if (r.id === root._peekRowId) peekCleared = true
                root.clearedModel.append(root._rowCopy(r))  // copy: get() goes stale after remove
                root.model.remove(i)
            } else i++
        }
        // A sticky critical peek (ttl = HARD_CAP) must not survive CLEAR ALL —
        // its row is gone from the model, so the card would park for 10 min.
        // Future-stamped rows (clock skew) stay and keep their peek.
        if (peekCleared) root._peekGone(root._peekRowId)
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
        w.command = ["sh", "-c", 'printf "%s" "$1" > "$2"', "sh", String(root.clearedAt), root.clearedPath]
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

        // DnD switch (same path as the panel toggle: memory + persisted flag).
        function dnd(on: bool) { root.setDnd(on) }

        // Inspection / scripting hooks: mark everything read and dump the model.
        function readAll() { root.markAllRead() }
        function list(): string {
            var rows = []
            for (var i = 0; i < root.model.count; i++) rows.push(root.model.get(i))
            return JSON.stringify(rows)
        }
    }

    Component.onCompleted: {
        _dndReader.command = ["sh", "-c", 'cat "$1" 2>/dev/null || true', "sh", root._dndFlag]
        _dndReader.running = true
        _clearedReader.command = ["sh", "-c", 'cat "$1" 2>/dev/null || true', "sh", root.clearedPath]
        _clearedReader.running = true   // chains the store read (routing needs clearedAt)
        _busProbe.running = true        // static command — decides the ingest path (J1a)
    }
}
