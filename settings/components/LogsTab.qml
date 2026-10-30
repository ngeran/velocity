// =============================================================================
// settings/components/LogsTab.qml — LOGS tab: live journal inside the app
// =============================================================================
// The settings-side home for the system journal (user ask, 2026-10-21: the
// header LOGS launcher used to cross-process-toggle the BAR's overlay; now it
// deep-links here — same data, one surface). Since P2.4 the bar overlay
// (SUPER+T) and this tab are two views over the ONE in-process HostBridge.log
// instance (synced from shared/LogService.qml) — open/close are tag-refcounted
// ("overlay" vs "tab"), so one view closing never kills the other's stream.
//
// Interior mirrors bar/components/LogsOverlay (severity chips + height-collapse
// filtering + debounced match scan + stick-to-bottom), restyled for the
// settings card: PopupMetrics scaling → plain px, no backdrop/Esc chrome, no
// footer clock (the dedupe doctrine — the bar owns time). The journalctl child
// runs while either view holds its tag; hiding the window or leaving the tab
// releases ours (LogService's active gating).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls   // TextField only (LogsOverlay pattern)
import "../config" as Config
import "../services" as Services

Item {
    id: root

    // ---- view state (filtering is client-side, here — not in the service) ----
    property string sevFilter: "all"        // all | error | warn | info
    property string searchText: ""
    property int matchCount: 0

    // ---- stream gating: tab visible AND window shown ----
    readonly property bool streamWanted: visible && Config.SharedState.dashboardVisible
    onStreamWantedChanged: streamWanted ? Services.HostBridge.log.open("tab")
                                        : Services.HostBridge.log.close("tab")
    Component.onCompleted: {
        if (streamWanted) Services.HostBridge.log.open("tab")
        // (the logs-tab search entry is seeded once in SettingsWindowShell's
        // _seedSearchCatalog — with O1's lazy tabs the index must be whole
        // before this tab is ever visited.)
    }
    Component.onDestruction: if (Services.HostBridge.log) Services.HostBridge.log.close("tab")

    readonly property string fontM: Config.ControlConfig.fontMono
    readonly property string fontN: Config.ControlConfig.fontNerd

    function sevColor(sev) {
        if (sev === "error") return Config.ThemeConfig.colors.error
        if (sev === "warn") return Config.ThemeConfig.colors.warning
        if (sev === "info") return Config.ThemeConfig.colors.info
        return Config.ThemeConfig.colors.textDim
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ---- header row ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                width: 8; height: 8; radius: 4
                color: Services.HostBridge.log.unreadable ? Config.ThemeConfig.colors.error
                     : Services.HostBridge.log.following  ? Config.ThemeConfig.colors.success
                     : Config.ThemeConfig.colors.warning
                Layout.alignment: Qt.AlignVCenter
                SequentialAnimation on opacity {
                    running: root.visible; loops: Animation.Infinite
                    NumberAnimation { from: 0.4; to: 1; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                }
            }
            Text {
                text: "󰗋"
                color: Config.ThemeConfig.colors.secondary
                font.family: root.fontN; font.pixelSize: 16
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: "SYSTEM LOGS"
                color: Config.ThemeConfig.colors.text
                font.family: Config.SettingsConfig.fontFamily
                font.pixelSize: 15; font.bold: true; font.letterSpacing: 2
                Layout.alignment: Qt.AlignVCenter
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "JOURNAL · " + (Services.HostBridge.log.hostName || "—")
                color: Config.ThemeConfig.colors.textDim
                font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // ---- sub-header strip ----
        Text {
            Layout.fillWidth: true
            text: "LIVE TAIL  //  journalctl -f -o json  //  CAP " + Services.HostBridge.log.maxEntries +
                  "  //  SYS + USER + KERNEL"
            color: Config.ThemeConfig.colors.textDim
            font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.border }

        // ---- severity chips + action chips (plain literals — no models) ----
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
                color: active ? Config.ThemeConfig.tint(tint, 0.12) : "transparent"
                border.color: active ? Config.ThemeConfig.tint(tint, 0.35)
                                     : Config.ThemeConfig.colors.border
                border.width: 1
                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: chip.label + " " + chip.count
                    color: chip.active ? chip.tint : Config.ThemeConfig.colors.textDim
                    font.family: root.fontM; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setFilter(chip.sev)
                }
            }

            SevChip { label: "ALL";  sev: "all";   count: Services.HostBridge.log.entries.count }
            SevChip { label: "ERR";  sev: "error"; count: Services.HostBridge.log.countErr }
            SevChip { label: "WARN"; sev: "warn";  count: Services.HostBridge.log.countWarn }
            SevChip { label: "INFO"; sev: "info";  count: Services.HostBridge.log.countInfo }

            Item { Layout.fillWidth: true }

            component ActionChip: Rectangle {
                id: btn
                property string label: ""
                signal activated()
                height: 22
                width: btnLabel.implicitWidth + 16
                color: btnMouse.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.10)
                                              : "transparent"
                border.color: btnMouse.containsMouse ? Config.ThemeConfig.colors.secondary
                                                     : Config.ThemeConfig.colors.border
                border.width: 1
                Text {
                    id: btnLabel
                    anchors.centerIn: parent
                    text: btn.label
                    color: btnMouse.containsMouse ? Config.ThemeConfig.colors.secondary
                                                  : Config.ThemeConfig.colors.textDim
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
                label: Services.HostBridge.log.following ? "󰏤 PAUSE" : "󰐊 RESUME"
                onActivated: Services.HostBridge.log.following ? Services.HostBridge.log.pause()
                                                           : Services.HostBridge.log.resume()
            }
            ActionChip { label: "󰑐 REFRESH"; onActivated: Services.HostBridge.log.refresh() }
            ActionChip { label: "󰀍 CLEAR";   onActivated: Services.HostBridge.log.clear() }
        }

        // ---- search field + matched count ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 280; height: 26
                color: "transparent"
                border.color: searchField.activeFocus ? Config.ThemeConfig.colors.secondary
                                                      : Config.ThemeConfig.colors.outlineVariant
                border.width: 1
                Controls.TextField {
                    id: searchField
                    anchors.fill: parent
                    anchors.margins: 4
                    background: null
                    placeholderText: "SEARCH — UNIT OR MESSAGE"
                    color: Config.ThemeConfig.colors.text
                    placeholderTextColor: Config.ThemeConfig.tint(Config.ThemeConfig.colors.textDim, 0.6)
                    selectionColor: Config.ThemeConfig.colors.secondary
                    selectedTextColor: Config.ThemeConfig.colors.background
                    font.family: root.fontM
                    font.pixelSize: 10
                    selectByMouse: true
                    onTextChanged: searchDebounce.restart()
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "MATCHED " + root.matchCount + " / " + Services.HostBridge.log.entries.count
                color: Config.ThemeConfig.colors.textDim
                font.family: root.fontM; font.pixelSize: 9; font.letterSpacing: 1
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.border }

        // ---- log list ----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: Services.HostBridge.log.entries

                // Stick to the newest line only when already at the bottom.
                onCountChanged: {
                    if (atYEnd || contentHeight <= height + 4)
                        Qt.callLater(function() { list.positionViewAtEnd() })
                }

                delegate: Rectangle {
                    width: list.width
                    // FILTER = height-collapse (LogsOverlay PERF NOTES)
                    height: Services.HostBridge.log.rowMatches(model.severity, model.message, model.unit,
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
                            color: Config.ThemeConfig.colors.textDim
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
                            width: list.width - 20 - 190 - 80
                            text: model.message
                            color: model.severity === "error" ? Config.ThemeConfig.colors.error
                                 : model.severity === "warn"  ? Config.ThemeConfig.colors.warning
                                 : Config.ThemeConfig.colors.text
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
                    visible: Services.HostBridge.log.unreadable ||
                             Services.HostBridge.log.entries.count === 0 ||
                             root.matchCount === 0

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Services.HostBridge.log.unreadable ? "󰅖"
                             : Services.HostBridge.log.entries.count === 0 ? "󰔛" : "󰍉"
                        font.family: root.fontN; font.pixelSize: 24
                        color: Services.HostBridge.log.unreadable ? Config.ThemeConfig.colors.error
                             : Config.ThemeConfig.colors.textDim
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Services.HostBridge.log.unreadable ? "JOURNALCTL UNREADABLE"
                             : Services.HostBridge.log.entries.count === 0 ? "WAITING FOR JOURNAL ENTRIES"
                             : "NO ENTRIES MATCH FILTER"
                        color: Services.HostBridge.log.unreadable ? Config.ThemeConfig.colors.error
                             : Config.ThemeConfig.colors.textDim
                        font.family: Config.SettingsConfig.fontFamily
                        font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: Services.HostBridge.log.unreadable || root.matchCount === 0
                        text: Services.HostBridge.log.unreadable
                              ? "check journal access / group membership — REFRESH to retry"
                              : "adjust severity or search — CLEAR search resets the view"
                        color: Config.ThemeConfig.colors.textDim
                        font.family: Config.SettingsConfig.fontFamily
                        font.pixelSize: 9; font.italic: true
                    }
                }
            }
        }

        // ---- footer status ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            opacity: 0.7
            Text {
                text: Services.HostBridge.log.unreadable ? "STREAM ERROR"
                     : Services.HostBridge.log.following  ? "LIVE" : "PAUSED"
                color: Services.HostBridge.log.unreadable ? Config.ThemeConfig.colors.error
                     : Services.HostBridge.log.following  ? Config.ThemeConfig.colors.success
                     : Config.ThemeConfig.colors.warning
                font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
            }
            Text {
                text: (Services.HostBridge.log.entries.count || 0) + " ENTRIES"
                color: Config.ThemeConfig.colors.textDim
                font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
            }
            Text {
                text: Services.HostBridge.log.following ? "" : "RESUME RE-TAILS THE JOURNAL"
                color: Config.ThemeConfig.colors.textDim
                font.family: root.fontM; font.pixelSize: 8; font.letterSpacing: 1
            }
            Item { Layout.fillWidth: true }
        }
    }

    // ---- support objects (same shapes as LogsOverlay) ----

    Timer {
        id: searchDebounce
        interval: 200
        onTriggered: {
            root.searchText = searchField.text
            root.recomputeMatches()
        }
    }

    Timer {
        id: matchTimer
        interval: 250
        onTriggered: root.recomputeMatches()
    }
    Connections {
        target: Services.HostBridge.log.entries
        function onCountChanged() { matchTimer.restart() }
    }

    function setFilter(sev) {
        sevFilter = sev
        recomputeMatches()
        Qt.callLater(function() { list.positionViewAtBeginning() })
    }

    function recomputeMatches() {
        var m = Services.HostBridge.log.entries
        if (sevFilter === "all" && (searchText === null || searchText.length === 0)) {
            matchCount = m.count
            return
        }
        var n = 0
        var q = (searchText || "").toLowerCase()
        for (var i = 0; i < m.count; i++) {
            var r = m.get(i)
            if (Services.HostBridge.log.rowMatches(r.severity, r.message, r.unit, sevFilter, q))
                n++
        }
        matchCount = n
    }
}
