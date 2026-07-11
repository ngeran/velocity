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
            read: false
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
}
