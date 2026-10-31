// =============================================================================
// NotificationCenter.qml — slide-in notification panel (right edge)
// =============================================================================
// A full-screen, click-to-dismiss overlay (like the settings dashboard) with a
// pure-black panel sliding in from the right edge. Theme tokens come from the
// bar's ThemeConfig (live/OLED-safe). Notifications come from
// NotificationService (a ListModel fed by IPC).
//
// Open it from the bar: NotificationButton flips `shown`. Outside-click, Esc,
// or the Clear All button dismiss it.
//
// Modernized: bell + title header with an icon-first Clear-All action, a thin
// accent hairline at the panel's top edge while unread items exist, a cleaner
// empty state, and a footer summary line ("3 unread").
// =============================================================================

import Quickshell
import Quickshell.Wayland
import QtQuick
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
        if (root.shown) Services.NotificationService.markAllRead()   // viewing clears the badge; tier clock starts
        if (!shown) hideTimer.restart()
    }
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

    // ── grouped-by-app view (P4.6) ───────────────────────────────────────────
    // The canonical ListModel stays arrival-ordered (the service's ordering
    // invariant) — grouping is a VIEW: a view-local ListModel holding the
    // same rows with each app's rows made CONTIGUOUS (newest group first,
    // newest row first within the group), fed to the ListView with
    // section.property: "appName" so each app renders one header. A ListModel
    // (not a JS array) because delegates read `model.<role>` — a JS-array
    // ListView exposes only modelData, which would blank every card field.
    // Frozen-slice law: the model refills only when membership or a read-mark
    // changes (keyed diff); rows are snapshotted plain (ListModel.get()
    // results go stale once their model is mutated).
    property ListModel groupsModel: ListModel {}
    property string _flatKey: ""

    function _regroup() {
        const m = Services.NotificationService.model
        let key = ""
        const groups = []   // [[rows]] in first-seen (= newest) app order
        const at = {}       // app name → index in groups
        for (let i = 0; i < m.count; i++) {
            const r = m.get(i)
            key += r.id + ":" + (r.read ? 1 : 0) + ";"
            let g = at[r.appName]
            if (g === undefined) {
                g = groups.length
                at[r.appName] = g
                groups.push([])
            }
            // Native extras are copied ONLY when the source row carries them:
            // the card's guards test `!== undefined`, and ListModel turns an
            // always-present array role into a nested-list accessor (no
            // .filter) — the plain-IPC rows must keep having NO actions role,
            // exactly as in the canonical model.
            const snap = {
                id: r.id, clickId: r.clickId || 0,
                appName: String(r.appName || ""), appIcon: r.appIcon || "",
                glyph: r.glyph || "", summary: String(r.summary || ""), body: String(r.body || ""),
                urgency: r.urgency, timestamp: r.timestamp || 0, read: r.read === true
            }
            if (r.actions !== undefined) snap.actions = r.actions
            if (r.image !== undefined && r.image !== "") snap.image = r.image
            if (r.progress !== undefined && r.progress >= 0) snap.progress = r.progress
            groups[g].push(snap)
        }
        if (key === root._flatKey) return
        root._flatKey = key
        groupsModel.clear()
        for (let k = 0; k < groups.length; k++)
            for (let j = 0; j < groups[k].length; j++) groupsModel.append(groups[k][j])
    }

    // Rows currently under one app (the section header's live count).
    function sectionCount(name) {
        let n = 0
        for (let i = 0; i < groupsModel.count; i++)
            if (groupsModel.get(i).appName === name) n++
        return n
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

        // unread accent dot rule — top edge reads "there's something new"
        // (P6.2: dotted accent instead of a solid 2 px bar — the signal stays
        // transient-only, and the ~30 % dot fill is far kinder to the panel)
        DotRule {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Config.PopupMetrics.px(2)
            dotSize: Config.PopupMetrics.px(2)
            dotColor: Config.BarConfig.colorAccent
            visible: root.unreadCount > 0
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ----- header -----
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Config.PopupMetrics.px(52)

                RowLayout {
                    anchors.left: parent.left; anchors.leftMargin: Config.PopupMetrics.px(16)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Config.PopupMetrics.px(8)

                    Text {
                        text: "󰂚"
                        font.family: Config.BarConfig.fontNerd
                        font.pixelSize: Config.PopupMetrics.px(14)
                        color: Config.BarConfig.colorAccent
                    }
                    Text {
                        text: "Notifications"
                        color: Config.ThemeConfig.colors.text
                        font.pixelSize: Config.PopupMetrics.px(14)
                        font.bold: true
                        font.family: Config.BarConfig.fontFamily
                    }

                    // Do-Not-Disturb toggle (same-process; persisted by NotificationService)
                    Rectangle {
                        Layout.preferredWidth: Config.PopupMetrics.px(48)
                        Layout.preferredHeight: Config.PopupMetrics.px(20)
                        radius: Config.PopupMetrics.px(10)
                        color: Services.NotificationService.dnd ? Config.BarConfig.colorAccent : "transparent"
                        border.color: Services.NotificationService.dnd ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.border
                        border.width: root.hair
                        Text {
                            anchors.centerIn: parent
                            text: "DND"
                            color: Services.NotificationService.dnd ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.textDim
                            font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                            font.family: Config.BarConfig.fontFamily
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.NotificationService.setDnd(!Services.NotificationService.dnd)
                        }
                    }
                }

                // Clear All — icon-first action button
                RowLayout {
                    anchors.right: parent.right; anchors.rightMargin: Config.PopupMetrics.px(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Config.PopupMetrics.px(5)
                    opacity: Services.NotificationService.model.count === 0 ? 0.35 : 1.0

                    Text {
                        text: "󰎟"
                        font.family: Config.BarConfig.fontNerd
                        font.pixelSize: Config.PopupMetrics.px(11)
                        color: clearMa.containsMouse
                               ? Config.ThemeConfig.colors.error
                               : Config.ThemeConfig.colors.textDim
                        Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
                    }
                    Text {
                        id: clearLabel
                        text: "Clear all"
                        color: clearMa.containsMouse
                               ? Config.ThemeConfig.colors.error
                               : Config.ThemeConfig.colors.textDim
                        font.pixelSize: Config.PopupMetrics.px(10)
                        font.bold: true
                        font.family: Config.BarConfig.fontFamily
                        Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: Services.NotificationService.model.count > 0
                        onClicked: Services.NotificationService.clearAll()
                    }
                }

                // header divider
                DotRule {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    dotColor: Config.ThemeConfig.colors.outlineVariant
                }
            }

            // ----- list (grouped by app — one header per app, P4.6) -----
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Config.PopupMetrics.px(12)
                clip: true
                spacing: Config.PopupMetrics.px(8)
                model: root.groupsModel
                section.property: "appName"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    id: secHead
                    required property string section
                    width: list.width
                    height: secRow.implicitHeight + Config.PopupMetrics.px(4)
                    Row {
                        id: secRow
                        anchors.bottom: parent.bottom
                        spacing: Config.PopupMetrics.px(6)
                        Text {
                            text: Services.NotificationService.appGlyph(secHead.section, "")
                            font.family: Config.BarConfig.fontNerd
                            font.pixelSize: Config.PopupMetrics.px(10)
                            color: Config.BarConfig.colorTextDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: secHead.section
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                            font.letterSpacing: 1.2
                            font.capitalization: Font.AllUppercase
                            font.family: Config.BarConfig.fontFamily
                            opacity: 0.7
                        }
                        Text {
                            text: "· " + root.sectionCount(secHead.section)
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                            font.family: Config.BarConfig.fontFamily
                            opacity: 0.45
                        }
                    }
                }
                delegate: StaggerIn {
                    index: model.index
                    // UX U5: the ryoku-port toast card in full mode (compact
                    // false — full body, no countdown). The row is handed over
                    // as an object: the card reads n(), not model roles.
                    NotificationToastCard {
                        compact: false
                        notif: ({
                            id: model.id, clickId: model.clickId,
                            appName: model.appName, glyph: model.glyph,
                            summary: model.summary, body: model.body,
                            urgency: model.urgency, timestamp: model.timestamp,
                            actions: model.actions !== undefined ? model.actions : [],
                            image: model.image !== undefined ? model.image : "",
                            progress: model.progress !== undefined ? model.progress : -1
                        })
                    }
                }

                // empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: Services.NotificationService.model.count === 0
                    spacing: Config.PopupMetrics.px(6)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰂛"
                        font.family: Config.BarConfig.fontNerd
                        font.pixelSize: Config.PopupMetrics.px(30)
                        color: Config.ThemeConfig.colors.textDim
                        opacity: 0.45
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "All caught up"
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: Config.PopupMetrics.px(12)
                        font.bold: true
                        font.family: Config.BarConfig.fontFamily
                        opacity: 0.7
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Services.NotificationService.clearedCount > 0
                              ? Services.NotificationService.clearedCount + " cleared — restore below"
                              : "No new notifications"
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: Config.PopupMetrics.px(10)
                        font.family: Config.BarConfig.fontFamily
                        opacity: 0.45
                    }
                }
            }

            // ----- history: rows archived on expiry (in-memory, capped) -----
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: Config.PopupMetrics.px(12)
                spacing: Config.PopupMetrics.px(6)
                visible: Services.NotificationService.history.count > 0

                DotRule {
                    Layout.fillWidth: true
                    dotColor: Config.ThemeConfig.colors.outlineVariant
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: Config.PopupMetrics.px(8)
                    Text {
                        text: "RECENTLY EXPIRED · " + Services.NotificationService.history.count
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                        font.letterSpacing: 1.2
                        font.family: Config.BarConfig.fontFamily
                        opacity: 0.7
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "CLEAR"
                        color: histClearMa.containsMouse ? Config.ThemeConfig.colors.error
                                                         : Config.ThemeConfig.colors.textDim
                        font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                        font.family: Config.BarConfig.fontFamily
                        opacity: 0.7
                        Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
                        MouseArea {
                            id: histClearMa
                            anchors.fill: parent; anchors.margins: -6
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Services.NotificationService.clearHistory()
                        }
                    }
                }

                Repeater {
                    model: Services.NotificationService.history
                    RowLayout {
                        Layout.fillWidth: true; spacing: Config.PopupMetrics.px(8)
                        Text {
                            text: model.appName
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                            font.capitalization: Font.AllUppercase
                            font.family: Config.BarConfig.fontFamily
                            opacity: 0.6
                        }
                        Text {
                            Layout.fillWidth: true
                            text: model.summary
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: Config.PopupMetrics.px(10)
                            font.family: Config.BarConfig.fontFamily
                            elide: Text.ElideRight
                            opacity: 0.55
                        }
                    }
                }
            }

            // ----- footer summary + soft-clear restore -----
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
