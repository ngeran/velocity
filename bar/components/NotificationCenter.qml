// =============================================================================
// NotificationCenter.qml — slide-in notification panel (right edge)
// =============================================================================
// A full-screen, click-to-dismiss overlay with a pure-black panel sliding in
// from the right edge. The LIST is the omarchy-notification-center shape
// (jankeesvw, MIT): one soft card per notification (NotificationRow) under the
// DAY it arrived on — TODAY / YESTERDAY / weekday / date — not grouped by app.
// Expired rows (the in-memory history) fold into the same day list as dimmed,
// non-interactive cards, so the panel reads as one continuous record.
//
// Open it from the settings dashboard's bell (HostBridge.ncToggle →
// shell.toggleNotificationCenter flips `shown`). Outside-click, Esc,
// or × / right-click on a card dismiss it.
//
// Clicking a card opens the notification's default action when the arrival
// still has one (live native rows); restored/IPC rows are acknowledged read
// and kept. The soft clear + RESTORE semantics are unchanged (clear-as-
// timestamp — nothing is destroyed by a click).
// =============================================================================

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

PanelWindow {
    id: root

    // ---- visibility control (mirrors the settings/shell.qml pattern) ----
    property bool shown: false
    visible: false
    function open()  { visible = true; shown = true }
    function close() { shown = false; hideTimer.restart() }
    function toggle() { shown ? close() : open() }

    // full-screen overlay so any click outside the panel dismisses it
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    // defer visible=false until the slide-out finishes (so it can animate)
    onShownChanged: {
        Services.NotificationService.panelOpen = root.shown   // suppress auto-dismiss while open
        if (root.shown) {
            // Mark against the moment BEFORE the open: the dots must survive
            // the markAllRead() that follows, or no row would ever show one.
            root.readMark = Date.now()
            Services.NotificationService.markAllRead()   // viewing clears the badge; tier clock starts
        }
        if (!shown) hideTimer.restart()
    }
    // Read-mark for the unread dots: rows that arrived after this moment.
    property real readMark: 0

    Timer {
        id: hideTimer
        interval: 330   // matches the slide duration (320ms) + a small buffer
        onTriggered: if (!root.shown) root.visible = false
    }

    // 380 logical, clamped to the output — a big uiScale on a small screen
    // must not push the card off-edge. Floor 200 keeps header/footer rows
    // intact on tiny outputs. (-10 mirrors the 5px right-edge margin.)
    readonly property int panelWidth: {
        var w = Config.PopupMetrics.px(380)
        var scr = root.screen
        if (scr && scr.width > 0) w = Math.min(w, scr.width - 10)
        return Math.max(200, w)
    }
    // Hairline width, snapped to device pixels (PopupMetrics.hairline) — one
    // read for the whole panel: every item inside shares the window's screen.
    readonly property real hair: Config.PopupMetrics.hairline(panel)
    readonly property int unreadCount: Services.NotificationService.unreadCount

    // Vertical room for the bar strip (shell.topClearance, injected by
    // shell.qml): the panel spans BETWEEN the bar edges, never across them —
    // the backdrop stays full-screen (the scrim + click-outside zone), but the
    // card itself docks under the bar instead of covering its tray side.
    property int barClearance: 0

    // The heading a notification is filed under — days, not apps. What you
    // remember about a notification you are hunting for is WHICH DAY it was;
    // within the week the weekday is the better handle ("Tuesday" is how you
    // remember it, "17 August" is how you would have to work it out).
    function dayOf(timestamp) {
        var when = new Date(timestamp)
        var today = new Date()
        var midnight = new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime()
        if (timestamp >= midnight) return "Today"
        if (timestamp >= midnight - 86400000) return "Yesterday"
        if (timestamp >= midnight - 6 * 86400000) return Qt.formatDateTime(when, "dddd")
        if (when.getFullYear() === today.getFullYear()) return Qt.formatDateTime(when, "d MMMM")
        return Qt.formatDateTime(when, "d MMMM yyyy")
    }

    // ── day-grouped view ─────────────────────────────────────────────────────
    // The canonical ListModel stays arrival-ordered (the service's ordering
    // invariant) — grouping is a VIEW: a view-local ListModel holding the same
    // rows snapshotted with a `day` role, fed to the ListView with
    // section.property: "day". History (expired rows) appends after, dimmed
    // and dead. A ListModel (not a JS array) because delegates read
    // `model.<role>`. Frozen-slice law: the model refills only when membership
    // changes (keyed diff); rows are snapshotted plain (ListModel.get()
    // results go stale once their model is mutated).
    property ListModel groupsModel: ListModel {}
    property string _flatKey: ""

    function _regroup() {
        const svc = Services.NotificationService
        const m = svc.model
        let key = ""
        const rows = []
        for (let i = 0; i < m.count; i++) {
            const r = m.get(i)
            key += r.id + ":" + (r.read ? 1 : 0) + ";"
            const snap = {
                id: r.id, clickId: r.clickId || 0,
                appName: String(r.appName || ""), appIcon: r.appIcon || "",
                glyph: r.glyph || "", summary: String(r.summary || ""), body: String(r.body || ""),
                urgency: r.urgency, timestamp: r.timestamp || 0, read: r.read === true,
                day: root.dayOf(r.timestamp || 0),
                dead: false
            }
            // Native extras are copied ONLY when the source row carries them:
            // the card's guards test `!== undefined`, and ListModel turns an
            // always-present array role into a nested-list accessor (no
            // .filter) — the plain-IPC rows must keep having NO actions role,
            // exactly as in the canonical model.
            if (r.actions !== undefined) snap.actions = r.actions
            if (r.image !== undefined && r.image !== "") snap.image = r.image
            if (r.progress !== undefined && r.progress >= 0) snap.progress = r.progress
            rows.push(snap)
        }
        // Expired rows: archived, not void — but as memory, not as mail.
        const h = svc.history
        for (let j = 0; j < h.count; j++) {
            const e = h.get(j)
            key += "h" + (e.ts || 0) + ":" + (e.summary || "") + ";"
            rows.push({
                id: 0, clickId: 0,
                appName: String(e.appName || ""), appIcon: "", glyph: "",
                summary: String(e.summary || ""), body: "",
                urgency: e.urgency !== undefined ? e.urgency : 1,
                timestamp: e.ts || 0, read: true,
                day: root.dayOf(e.ts || 0),
                dead: true
            })
        }
        if (key === root._flatKey) return
        root._flatKey = key
        groupsModel.clear()
        for (let k = 0; k < rows.length; k++) groupsModel.append(rows[k])
    }

    Component.onCompleted: root._regroup()
    Connections {
        target: Services.NotificationService
        function onRevChanged() { root._regroup() }
    }

    // ---- dim backdrop (click-outside = dismiss) ----
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        opacity: root.shown ? 0.45 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap; easing.type: Config.MotionConfig.ease } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ---- the panel itself (slides + fades, macOS Notification Center style) ----
    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right      // pinned right, 5px in — same edge gap as the tray popups
        anchors.rightMargin: Config.PopupMetrics.px(5)
        // Dock between the bar edges: under the top bar, or short of the
        // bottom one (barClearance is the strip height — 0 in the free edge).
        anchors.topMargin: Config.BarConfig.barAtBottom ? 0 : root.barClearance
        anchors.bottomMargin: Config.BarConfig.barAtBottom ? root.barClearance : 0
        width: root.panelWidth
        color: Config.ThemeConfig.colors.background          // pure black (OLED-safe)
        border.color: Config.ThemeConfig.colors.border       // subtle structure
        border.width: root.hair
        clip: true
        opacity: root.shown ? 1.0 : 0.0

        // Offset from the anchored (flush-right) position, in its own local space.
        // 0 = fully docked. +width+margin = pushed off-screen to the right.
        // Driving this instead of raw `x` avoids any left-to-right glitch that
        // can happen when `x` is computed from parent.width during layout.
        property real hiddenOffset: width + 24
        transform: Translate {
            x: root.shown ? 0 : panel.hiddenOffset
            Behavior on x {
                NumberAnimation { duration: Config.MotionConfig.move; easing.type: Easing.OutExpo }
            }
        }

        // macOS-style entrance: fast, confident deceleration, no overshoot on open;
        // slightly quicker, snappier curve on close (matches Notification Center feel).
        Behavior on opacity {
            NumberAnimation { duration: root.shown ? Config.MotionConfig.swap : Config.MotionConfig.flap; easing.type: Config.MotionConfig.ease }
        }

        // stop clicks inside the panel from reaching the backdrop
        MouseArea { anchors.fill: parent }

        Keys.onEscapePressed: root.close()

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ----- header: NOTIFICATIONS · dnd · Clear (omarchy-quiet) -----
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Config.PopupMetrics.px(48)

                Text {
                    id: title
                    anchors.left: parent.left; anchors.leftMargin: Config.PopupMetrics.px(16)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NOTIFICATIONS"
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    font.family: Config.BarConfig.fontFamily
                    opacity: 0.7
                }

                Row {
                    anchors.right: parent.right; anchors.rightMargin: Config.PopupMetrics.px(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Config.PopupMetrics.px(10)

                    // Do-Not-Disturb: a bell, crossed out while silenced — the
                    // same switch as the schedule-aware service toggle.
                    Item {
                        width: dndBell.implicitWidth
                        height: dndBell.implicitHeight
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: dndBell
                            anchors.centerIn: parent
                            // Surrogate pairs, not raw astral literals — the
                            // source survives editors that mangle PUA glyphs.
                            // U+F009A bell · U+F009B bell-off.
                            text: Services.NotificationService.dnd ? "󰂛" : "󰂚"
                            font.family: Config.BarConfig.fontNerd
                            font.pixelSize: Config.PopupMetrics.px(13)
                            color: Services.NotificationService.dnd ? Config.BarConfig.colorAccent
                                                                    : Config.ThemeConfig.colors.textDim
                            Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Config.PopupMetrics.px(4)
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.NotificationService.setDnd(!Services.NotificationService.dnd)
                        }
                    }

                    // A word rather than a glyph: this one empties the panel.
                    Text {
                        text: "Clear"
                        anchors.verticalCenter: parent.verticalCenter
                        color: clearMa.containsMouse ? Config.ThemeConfig.colors.error
                                                     : Config.ThemeConfig.colors.textDim
                        font.pixelSize: Config.PopupMetrics.px(10)
                        font.bold: true
                        font.family: Config.BarConfig.fontFamily
                        opacity: Services.NotificationService.model.count === 0 ? 0.35 : 1.0
                        Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }

                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            anchors.margins: -Config.PopupMetrics.px(5)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: Services.NotificationService.model.count > 0
                            onClicked: Services.NotificationService.clearAll()
                        }
                    }
                }

                // header divider
                DotRule {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    dotColor: Config.ThemeConfig.colors.outlineVariant
                }
            }

            // ----- list: one card per notification, under the day it arrived on -----
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Config.PopupMetrics.px(12)
                clip: true
                spacing: Config.PopupMetrics.px(8)
                model: root.groupsModel
                section.property: "day"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    id: daySection
                    required property string section
                    width: list.width
                    height: dayLabel.implicitHeight + Config.PopupMetrics.px(10)
                    Text {
                        id: dayLabel
                        anchors.left: parent.left
                        anchors.leftMargin: Config.PopupMetrics.px(2)
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Config.PopupMetrics.px(4)
                        text: daySection.section.toUpperCase()
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                        font.letterSpacing: 1.2
                        font.capitalization: Font.AllUppercase
                        font.family: Config.BarConfig.fontFamily
                        opacity: 0.7
                    }
                }
                delegate: StaggerIn {
                    index: model.index
                    // Explicit width off the list: StaggerIn's own
                    // `width: implicitWidth` reads the row's implicitWidth,
                    // which is 0 by design (the row sizes by height only) —
                    // without this the whole delegate chain sits at 0 and the
                    // rows render as icon+app-name slivers.
                    width: list.width
                    NotificationRow {
                        width: parent.width
                        x: 0
                        notif: ({
                            id: model.id, clickId: model.clickId,
                            appName: model.appName, appIcon: model.appIcon, glyph: model.glyph,
                            summary: model.summary, body: model.body,
                            urgency: model.urgency, timestamp: model.timestamp,
                            actions: model.actions !== undefined ? model.actions : [],
                            image: model.image !== undefined ? model.image : "",
                            progress: model.progress !== undefined ? model.progress : -1
                        })
                        toast: false
                        dead: model.dead
                        unread: !model.dead && model.timestamp > root.readMark

                        onClicked: {
                            if (model.dead) return
                            // A live arrival still has its action (open the
                            // page, focus the app); a restored row's action
                            // died with the session — acknowledge it instead.
                            if (model.clickId > 0)
                                Services.NotificationService.activate(model.id)
                            else
                                Services.NotificationService.markRead(model.id)
                        }
                        onRemoveRequested: if (!model.dead)
                            Services.NotificationService.dismiss(model.id)
                    }
                }
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }

            // ----- empty state -----
            Text {
                Layout.fillWidth: true
                Layout.topMargin: Config.PopupMetrics.px(22)
                Layout.bottomMargin: Config.PopupMetrics.px(22)
                visible: root.groupsModel.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: Services.NotificationService.clearedCount > 0
                      ? Services.NotificationService.clearedCount + " cleared — restore below"
                      : "Nothing has come in yet"
                wrapMode: Text.WordWrap
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: Config.PopupMetrics.px(10)
                font.family: Config.BarConfig.fontFamily
                opacity: 0.55
            }

            // ----- footer: counts + soft-clear restore -----
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Config.PopupMetrics.px(32)
                visible: Services.NotificationService.model.count > 0 ||
                         Services.NotificationService.clearedCount > 0

                DotRule {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    dotColor: Config.ThemeConfig.colors.outlineVariant
                }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: Config.PopupMetrics.px(16)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Services.NotificationService.model.count > 0
                    text: root.unreadCount > 0
                          ? root.unreadCount + " unread · " + Services.NotificationService.model.count + " total"
                          : Services.NotificationService.model.count + " total"
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: Config.PopupMetrics.px(10)
                    font.family: Config.BarConfig.fontFamily
                    opacity: 0.7
                }

                // Cleared rows are hidden, not gone — surface the undo here.
                RowLayout {
                    anchors.right: parent.right
                    anchors.rightMargin: Config.PopupMetrics.px(16)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Config.PopupMetrics.px(6)
                    visible: Services.NotificationService.clearedCount > 0

                    Text {
                        text: Services.NotificationService.clearedCount + " cleared"
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: Config.PopupMetrics.px(10)
                        font.family: Config.BarConfig.fontFamily
                        opacity: 0.7
                    }
                    Text {
                        text: "RESTORE"
                        color: restoreMa.containsMouse ? Config.ThemeConfig.colors.primary
                                                       : Config.ThemeConfig.colors.textDim
                        font.pixelSize: Config.PopupMetrics.px(10)
                        font.bold: true
                        font.family: Config.BarConfig.fontFamily
                        Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
                        MouseArea {
                            id: restoreMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.NotificationService.restoreCleared()
                        }
                    }
                }
            }
        }
    }
}
