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

    // "now" ticks every 30s so cards can render relative timestamps ("5m ago")
    // without each card owning its own timer.
    property real now: Date.now()
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: root.now = Date.now()
    }

    // Do-Not-Disturb: when on, new notifications arrive silently (read) so the
    // badge never bumps. Persisted to ~/.config/quickshell/dnd.flag across restarts.
    property bool dnd: false
    property bool panelOpen: false   // set by NotificationCenter — suppresses reaping while open
    readonly property string _dndFlag: "~/.config/quickshell/dnd.flag"

    property Process _dndReader: Process {
        command: []; running: false
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { _dndReader.buffer += data } }
        onRunningChanged: if (!running) { root.dnd = (_dndReader.buffer.trim() === "1"); _dndReader.buffer = "" }
    }
    function setDnd(on) {
        root.dnd = on
        var w = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        w.command = ["sh", "-c", "printf '%s' '" + (on ? "1" : "0") + "' > " + root._dndFlag]
        w.running = true
    }

    // Auto-dismiss: every 3s drop notifications older than 10s so the center
    // doesn't linger forever — but never while the panel is open (user is reading).
    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: {
            if (root.panelOpen) return
            var cutoff = Date.now() - 10000
            for (var i = root.model.count - 1; i >= 0; i--) {
                if (root.model.get(i).timestamp < cutoff) root.model.remove(i)
            }
            root._recount()
        }
    }

    function _recount() {
        var n = 0
        for (var i = 0; i < root.model.count; i++) {
            if (!root.model.get(i).read) n++
        }
        root.unreadCount = n
    }

    // -------------------------------------------------------------------------
    // PUBLIC API
    // -------------------------------------------------------------------------
    // urgency: 0 = low, 1 = normal, 2 = critical
    function add(appName, summary, body, urgency, clickId) {
        root.model.insert(0, {
            id: root.nextId,
            clickId: (clickId === undefined ? 0 : clickId),  // DBus id for ActionInvoked (0 = none)
            appName: appName || "Notification",
            appIcon: "",
            summary: summary || "",
            body: body || "",
            urgency: (urgency === undefined ? 1 : urgency),
            timestamp: Date.now(),
            read: root.dnd   // silent (no badge bump) under Do-Not-Disturb
        })
        root.nextId++
        root._recount()
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
        p.running = true
    }

    function invokeAction(clickId) { root._bridgeCall("Invoke", clickId) }
    function dismissDbus(clickId) { root._bridgeCall("Dismiss", clickId) }

    function markRead(id) {
        for (var i = 0; i < root.model.count; i++) {
            if (root.model.get(i).id === id) { root.model.setProperty(i, "read", true); break }
        }
        root._recount()
    }

    function markAllRead() {
        for (var i = 0; i < root.model.count; i++) root.model.setProperty(i, "read", true)
        root._recount()
    }

    function remove(id) {
        for (var i = 0; i < root.model.count; i++) {
            if (root.model.get(i).id === id) { root.model.remove(i); break }
        }
        root._recount()
    }

    function clearAll() {
        root.model.clear()
        root.unreadCount = 0
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
            root.add(d.appName, d.summary, d.body, d.urgency, d.clickId)
        }

        function clear() { root.clearAll() }
    }

    Component.onCompleted: {
        _dndReader.command = ["sh", "-c", "cat " + root._dndFlag + " 2>/dev/null || true"]
        _dndReader.running = true
    }
}
