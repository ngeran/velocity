// =============================================================================
// LogsOverlay.qml — SYSTEM LOGS live journal viewer
// =============================================================================
// Full-system journal tail categorized by severity (error / warning / info),
// opened from the bar's LogsIcon, the settings dashboard header button, or
// SUPER+T (`quickshell ipc -c bar call logs toggle`).
//
// SHELL mirrors KeybindsOverlay (two-phase show/hide, dim backdrop, Esc +
// click-outside close, 900×680 sharp-corner card).
// INTERIOR mirrors FastfetchOverlay (pulsing header dot, live palette
// swatches, dim grid + corner brackets, sub-header strip, footer status
// dots + clock).
//
// DATA + FILTERING live in Services.LogService / LogModel.js — this file is
// pure layout. The journalctl child runs only while this overlay is shown
// (LogService.open/close); filtering is entirely client-side (delegate
// height-collapse + debounced match scan), so no user input ever reaches a
// shell command.
//
// PERF NOTES
//   - Filter = delegate height-collapse (matches ? 22 : 0). New appends
//     while following cost nothing extra; filter changes re-evaluate only
//     instantiated delegates (ListView virtualization; ≤ maxEntries rows).
//     If severity filtering ever janks, the documented fallback is an
//     overlay-side display ListModel rebuilt by matchTimer — same slot.
//   - "MATCHED n / m" is a debounced (200ms) + coalesced (250ms) scan so a
//     500-line backfill triggers ONE pass, not 500.
//   - Auto-scroll sticks to the bottom ONLY when the view is already at the
//     bottom — scrolling up is never yanked by incoming lines.
// =============================================================================

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls   // TextField only — LoginScreen precedent
import "../config" as Config
import "../services" as Services

PanelWindow {
    id: root

    property bool shown: false
    property string clockText: "--:--:--"

    // ---- view state (filtering is client-side, here — not in the service) ----
    property string sevFilter: "all"        // all | error | warn | info
    property string searchText: ""
    property int matchCount: 0

    visible: false
    function open() {
        visible = true
        shown = true
        Services.LogService.open()
        clockTimer.restart()
    }
    function close() {
        shown = false
        hideTimer.restart()
        Services.LogService.close()
    }
    function toggle() { shown ? close() : open() }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    onShownChanged: if (!shown) hideTimer.restart()
    Timer { id: hideTimer; interval: 220; onTriggered: if (!root.shown) root.visible = false }

    // ---- theme palette (same alias block idiom as FastfetchOverlay) ----
    readonly property color cBg:        Config.ThemeConfig.colors.background
    readonly property color cText:      Config.ThemeConfig.colors.text
    readonly property color cDim:       Config.ThemeConfig.colors.textDim
    readonly property color cBorder:    Config.ThemeConfig.colors.border
    readonly property color cOutline:   Config.ThemeConfig.colors.outlineVariant
    readonly property color cSurface:   Config.ThemeConfig.colors.surfaceVariant
    readonly property color cSecondary: Config.ThemeConfig.colors.secondary   // header glyph / brackets
    readonly property color cPrimary:   Config.ThemeConfig.colors.primary
    readonly property color cSuccess:   Config.ThemeConfig.colors.success     // LIVE state
    readonly property color cWarn:      Config.ThemeConfig.colors.warning     // warnings / PAUSED
    readonly property color cErr:       Config.ThemeConfig.colors.error       // errors / stream failure
    readonly property color cInfo:      Config.ThemeConfig.colors.info
    readonly property color cAccent2:   Config.ThemeConfig.colors.accent
    readonly property string fontM:     Config.BarConfig.fontFamily
    readonly property string fontN:     Config.BarConfig.fontNerd

    function sevColor(sev) {
        if (sev === "error") return cErr
        if (sev === "warn") return cWarn
        if (sev === "info") return cInfo
        return cDim
    }
    function swatchAt(i) {
        var a = [cSecondary, cPrimary, cSuccess, cWarn, cErr, cInfo, cAccent2]
        return a[i] || cBorder
    }

    // =========================================================================
    // DIM BACKDROP (click-outside = close)
    // =========================================================================
    Rectangle {
        anchors.fill: parent
        color: root.cBg
        opacity: root.shown ? 0.55 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // =========================================================================
    // CENTERED CARD (900×680 — same as FastfetchOverlay / KeybindsOverlay)
    // =========================================================================
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 900
        height: 680
        color: root.cBg
        border.color: root.cBorder
        border.width: 1
        clip: true
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: root.close()
        MouseArea { anchors.fill: parent }   // swallow clicks so they don't close the overlay

        // ----- (decoration) dim grid background -----
        Item {
            anchors.fill: parent
            opacity: 0.22; z: 0
            Repeater {
                model: Math.floor(card.width / 40)
                Rectangle { width: 1; height: card.height; x: index * 40; color: root.cBorder }
            }
            Repeater {
                model: Math.floor(card.height / 40)
                Rectangle { height: 1; width: card.width; y: index * 40; color: root.cBorder }
            }
        }

        // ----- (decoration) corner brackets -----
        Repeater {
            model: 4
            Item {
                width: 14; height: 14; opacity: 0.55; z: 0
                x: (index === 0 || index === 2) ? 0 : (card.width - 14)
                y: (index === 0 || index === 1) ? 0 : (card.height - 14)
                property bool isRight: (index === 1 || index === 3)
                property bool isBottom: (index === 2 || index === 3)
                Rectangle { width: 14; height: 2; color: root.cSecondary; y: parent.isBottom ? 12 : 0 }
                Rectangle { width: 2; height: 14; color: root.cSecondary; x: parent.isRight ? 12 : 0 }
            }
        }

        // ----- CONTENT -----
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 12
            z: 10

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: Services.LogService.unreadable ? root.cErr
                         : Services.LogService.following ? root.cSuccess : root.cWarn
                    Layout.alignment: Qt.AlignVCenter
                    SequentialAnimation on opacity {
                        running: root.shown; loops: Animation.Infinite
                        NumberAnimation { from: 0.4; to: 1; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: "󰗋"
                    color: root.cSecondary
                    font.family: root.fontN
                    font.pixelSize: 18
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "SYSTEM LOGS"
                    color: root.cText
                    font.family: root.fontM
                    font.pixelSize: 18
                    font.bold: true
                    font.letterSpacing: 3
                    Layout.alignment: Qt.AlignVCenter
                }
                // live palette swatches (drawn from the active theme, not hard-coded)
                Row {
                    spacing: 4
                    Layout.leftMargin: 10
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: 7
                        Rectangle {
                            width: 9; height: 9; radius: 2
                            color: root.swatchAt(index)
                            border.color: root.cBorder; border.width: 1
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "JOURNAL"
                        color: root.cDim
                        font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: Services.LogService.hostName || "—"
                        color: root.cSecondary
                        font.family: root.fontM; font.pixelSize: 11; font.bold: true
                    }
                }
                Text {
                    text: "ESC"
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: 9
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8
                }
            }

            // ---- sub-header strip ----
            Text {
                Layout.fillWidth: true
                text: "LIVE TAIL  //  journalctl -f -o json  //  CAP " + Services.LogService.maxEntries +
                      "  //  SYS + USER + KERNEL"
                color: root.cDim
                font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

            // ---- severity chips + action buttons ----
            // 4 hardcoded chips (no Repeater/model — the repo's delegate-init
            // gotchas don't apply to plain literals).
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                component SevChip: Rectangle {
                    id: chip
                    property string label: ""
                    property string sev: "all"
                    property int count: 0
                    readonly property bool active: root.sevFilter === chip.sev
                    readonly property color tint: root.sevColor(chip.sev === "all" ? "" : chip.sev)
                    height: 22
                    width: chipLabel.implicitWidth + 16
                    color: active ? Qt.rgba(tint.r, tint.g, tint.b, 0.12) : "transparent"
                    border.color: active ? Qt.rgba(tint.r, tint.g, tint.b, 0.35) : root.cBorder
                    border.width: 1
                    Text {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: chip.label + " " + chip.count
                        color: chip.active ? chip.tint : root.cDim
                        font.family: root.fontM; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setFilter(chip.sev)
                    }
                }

                SevChip { label: "ALL";  sev: "all";  count: Services.LogService.entries.count }
                SevChip { label: "ERR";  sev: "error"; count: Services.LogService.countErr }
                SevChip { label: "WARN"; sev: "warn";  count: Services.LogService.countWarn }
                SevChip { label: "INFO"; sev: "info";  count: Services.LogService.countInfo }

                Item { Layout.fillWidth: true }

                component ActionChip: Rectangle {
                    id: btn
                    property string label: ""
                    signal activated()
                    height: 22
                    width: btnLabel.implicitWidth + 16
                    color: btnMouse.containsMouse ? Qt.rgba(root.cSecondary.r, root.cSecondary.g, root.cSecondary.b, 0.10) : "transparent"
                    border.color: btnMouse.containsMouse ? root.cSecondary : root.cBorder
                    border.width: 1
                    Text {
                        id: btnLabel
                        anchors.centerIn: parent
                        text: btn.label
                        color: btnMouse.containsMouse ? root.cSecondary : root.cDim
                        font.family: root.fontM; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                    }
                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btn.activated()
                    }
                }

                ActionChip {
                    label: Services.LogService.following ? "󰏤 PAUSE" : "󰐊 RESUME"
                    onActivated: Services.LogService.following ? Services.LogService.pause()
                                                               : Services.LogService.resume()
                }
                ActionChip { label: "󰑐 REFRESH"; onActivated: Services.LogService.refresh() }
                ActionChip { label: "󰀍 CLEAR";   onActivated: Services.LogService.clear() }
            }

            // ---- search field + matched count ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 280; height: 26
                    color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.4)
                    border.color: searchField.activeFocus ? root.cSecondary : root.cOutline
                    border.width: 1
                    Controls.TextField {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: 4
                        background: null
                        placeholderText: "SEARCH — UNIT OR MESSAGE"
                        color: root.cText
                        placeholderTextColor: Qt.rgba(root.cDim.r, root.cDim.g, root.cDim.b, 0.6)
                        selectionColor: root.cSecondary
                        selectedTextColor: root.cBg
                        font.family: root.fontM
                        font.pixelSize: 10
                        selectByMouse: true
                        onTextChanged: searchDebounce.restart()
                        // Esc closes the overlay, not just the keyboard focus.
                        Keys.onEscapePressed: root.close()
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "MATCHED " + root.matchCount + " / " + Services.LogService.entries.count
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

            // ---- log list ----
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 0                    // visual gap lives INSIDE the 22px row
                    boundsBehavior: Flickable.StopAtBounds
                    model: Services.LogService.entries

                    // Stick to the newest line only when already at the bottom.
                    onCountChanged: {
                        if (atYEnd || contentHeight <= height + 4)
                            Qt.callLater(function() { list.positionViewAtEnd() })
                    }

                    delegate: Rectangle {
                        width: list.width
                        // FILTER = height-collapse (see header PERF NOTES)
                        height: Services.LogService.rowMatches(model.severity, model.message, model.unit,
                                                               root.sevFilter, root.searchText.toLowerCase())
                                ? 22 : 0
                        visible: height > 0
                        color: "transparent"

                        Rectangle {
                            x: 12; width: 2; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.sevColor(model.severity)
                        }
                        Row {
                            x: 20
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Text {
                                text: model.timeLabel
                                color: root.cDim
                                font.family: root.fontM; font.pixelSize: 10
                            }
                            Text {
                                width: 190
                                text: model.unit + (model.pid ? "[" + model.pid + "]" : "")
                                color: root.sevColor(model.severity)
                                font.family: root.fontM; font.pixelSize: 10; font.bold: true
                                elide: Text.ElideMiddle
                            }
                            Text {
                                width: list.width - 20 - 190 - 80 - 40
                                text: model.message
                                color: model.severity === "error" ? root.cErr
                                     : model.severity === "warn"  ? root.cWarn : root.cText
                                font.family: root.fontM; font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // ---- named empty states (one visible at a time) ----
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        z: 5
                        visible: Services.LogService.unreadable ||
                                 Services.LogService.entries.count === 0 ||
                                 root.matchCount === 0

                        // 1. journalctl itself failed (sticky until refresh)
                        ColumnLayout {
                            spacing: 4
                            visible: Services.LogService.unreadable
                            Layout.alignment: Qt.AlignHCenter
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰅖"
                                font.family: root.fontN; font.pixelSize: 26
                                color: root.cErr
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "JOURNALCTL UNREADABLE"
                                color: root.cErr
                                font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "check journal access / group membership — REFRESH to retry"
                                color: root.cDim
                                font.family: root.fontM; font.pixelSize: 9; font.italic: true
                            }
                        }
                        // 2. stream alive but nothing ingested yet
                        ColumnLayout {
                            spacing: 4
                            visible: !Services.LogService.unreadable &&
                                     Services.LogService.entries.count === 0
                            Layout.alignment: Qt.AlignHCenter
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰔛"
                                font.family: root.fontN; font.pixelSize: 26
                                color: root.cDim
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "WAITING FOR JOURNAL ENTRIES"
                                color: root.cDim
                                font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                            }
                        }
                        // 3. entries exist, none match severity/search
                        ColumnLayout {
                            spacing: 4
                            visible: !Services.LogService.unreadable &&
                                     Services.LogService.entries.count > 0 &&
                                     root.matchCount === 0
                            Layout.alignment: Qt.AlignHCenter
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰍉"
                                font.family: root.fontN; font.pixelSize: 26
                                color: root.cDim
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "NO ENTRIES MATCH FILTER"
                                color: root.cDim
                                font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "adjust severity or search — CLEAR search resets the view"
                                color: root.cDim
                                font.family: root.fontM; font.pixelSize: 9; font.italic: true
                            }
                        }
                    }
                }
            }

            // ---- footer ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                opacity: 0.7
                RowLayout {
                    spacing: 6
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: Services.LogService.unreadable ? root.cErr
                             : Services.LogService.following  ? root.cSuccess : root.cWarn
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: Services.LogService.unreadable ? "STREAM ERROR"
                             : Services.LogService.following  ? "LIVE" : "PAUSED"
                        color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
                    }
                }
                Text {
                    text: (Services.LogService.entries.count || 0) + " ENTRIES"
                    color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
                }
                Text {
                    text: Services.LogService.following ? "" : "RESUME RE-TAILS THE JOURNAL"
                    color: root.cDim; font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "[ " + (Services.LogService.hostName || "host") + " ]"
                    color: root.cDim; font.family: root.fontM; font.pixelSize: 9
                }
                Text {
                    text: root.clockText
                    color: root.cSecondary; font.family: root.fontM; font.pixelSize: 9; font.bold: true
                }
            }
        }
    }

    // ---- support objects ----

    // Search: debounce keystrokes before touching searchText (re-evaluating
    // every instantiated delegate per keypress would jank).
    Timer {
        id: searchDebounce
        interval: 200
        onTriggered: {
            root.searchText = searchField.text
            root.recomputeMatches()
        }
    }

    // Coalesce model bursts: a 500-line backfill = ONE match scan (~4/s max
    // while following).
    Timer {
        id: matchTimer
        interval: 250
        onTriggered: root.recomputeMatches()
    }
    Connections {
        target: Services.LogService.entries
        function onCountChanged() { matchTimer.restart() }
    }

    // ---- live clock (1s, runs only while shown) ----
    Timer {
        id: clockTimer
        interval: 1000
        repeat: true
        running: root.shown
        onTriggered: {
            var d = new Date()
            var hh = d.getHours(); if (hh < 10) hh = "0" + hh
            var mm = d.getMinutes(); if (mm < 10) mm = "0" + mm
            var ss = d.getSeconds(); if (ss < 10) ss = "0" + ss
            root.clockText = hh + ":" + mm + ":" + ss
        }
        triggeredOnStart: true
    }

    // ---- helpers ----
    function setFilter(sev) {
        sevFilter = sev
        recomputeMatches()
        Qt.callLater(function() { list.positionViewAtBeginning() })
    }

    function recomputeMatches() {
        var m = Services.LogService.entries
        // Fast path: no filtering active → everything matches.
        if (sevFilter === "all" && (searchText === null || searchText.length === 0)) {
            matchCount = m.count
            return
        }
        var n = 0
        var q = (searchText || "").toLowerCase()
        for (var i = 0; i < m.count; i++) {
            var r = m.get(i)
            if (Services.LogService.rowMatches(r.severity, r.message, r.unit, sevFilter, q))
                n++
        }
        matchCount = n
    }
}
