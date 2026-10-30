// =============================================================================
// NotificationsPane.qml — SETTINGS tab's NOTIFICATIONS pane (P4.9)
// =============================================================================
// DND toggle, clear-all (+undo) and the expired-notification history — every
// read goes through HostBridge.notifications (the bar process's one
// NotificationService; zero private state copies here). Clear is SOFT
// (clear-as-timestamp): RESTORE brings the hidden rows back, so the undo pill
// shows only while something is actually hidden. The history list is the
// reaper's archive (read notifications that expired — capped, newest first;
// rows carry appName/summary/ts/urgency).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root

    // The bar's NotificationService (HostBridge.notifications) — null until
    // the bar shell attaches barServices (null-safe throughout).
    readonly property var n: Services.HostBridge.notifications
    readonly property int _whenW: 86   // fixed time column (no elide jitter)

    function _when(ts) {
        var d = new Date(ts)
        var hhmm = (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" +
                   (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
        var today = new Date()
        if (d.toDateString() === today.toDateString()) return hhmm
        return (d.getMonth() + 1) + "/" + d.getDate() + " " + hhmm
    }

    Component.onCompleted: Services.SearchIndex.register({
        title: "Notifications", tab: "settings", section: "notifications",
        keywords: "dnd do not disturb clear history bell archive", item: null })
    Component.onDestruction: Services.SearchIndex.unregister(this)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.ControlConfig.space4
        spacing: Config.ControlConfig.space4

        SettingsHeaderCard {
            Layout.fillWidth: true
            eyebrow: "SETTINGS"; title: "Notifications"
            subtitle: root.n === null ? "bar services not attached"
                      : root.n.model.count + " active · " + root.n.unreadCount + " unread · history " + root.n.history.count + "/" + root.n.historyMax
        }

        Card {
            variant: "core"
            Layout.fillWidth: true
            accent: Config.ControlConfig.accent

            // ── DND ─────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.ControlConfig.space3

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1
                    Text {
                        text: "DO NOT DISTURB"
                        color: Config.ThemeConfig.colors.text
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 11; font.bold: true
                    }
                    Text {
                        text: root.n !== null && root.n.dnd
                              ? "popups suppressed — arrivals still land in the panel"
                              : "popups shown for every arrival"
                        color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true; Layout.minimumWidth: 0
                    }
                }
                CardToggle {
                    checked: root.n !== null && root.n.dnd
                    dimmed: root.n === null
                    accentColor: Config.ControlConfig.accent
                    textColor: Config.ThemeConfig.colors.text
                    outlineColor: Config.ThemeConfig.colors.outlineVariant
                    onToggled: if (root.n) root.n.setDnd(!root.n.dnd)
                }
            }

            // ── actions ─────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.ControlConfig.space2
                Pill {
                    text: "CLEAR ALL"
                    danger: true
                    enabled: root.n !== null && root.n.model.count > 0
                    opacity: enabled ? 1.0 : 0.4
                    onActivated: if (root.n) root.n.clearAll()
                }
                Pill {
                    // Clear is soft — this undo exists whenever rows are hidden.
                    text: "RESTORE " + (root.n !== null ? root.n.clearedCount : 0)
                    accentStyle: true
                    visible: root.n !== null && root.n.clearedCount > 0
                    onActivated: if (root.n) root.n.restoreCleared()
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "clear hides — the archive below keeps expired rows"
                    color: Config.ThemeConfig.colors.textDim; opacity: 0.7
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                }
            }
        }

        // ── history (the reaper's archive) ────────────────────────────────
        SectionHeader {
            Layout.fillWidth: true
            title: "History"
            value: root.n !== null ? root.n.history.count + " archived" : ""
        }
        Card {
            variant: "core"
            Layout.fillWidth: true
            Layout.fillHeight: true
            accent: Config.ControlConfig.accent

            // Plain-Item filler: layout-managed, so children may anchor freely.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Empty state (honest-empty house style)
                Text {
                    anchors.centerIn: parent
                    visible: root.n === null || root.n.history.count === 0
                    text: root.n === null ? "bar services not attached"
                          : "no archived notifications — read rows land here when they expire"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 11
                }

                ListView {
                    id: histList
                    anchors.fill: parent
                    spacing: 2
                    clip: true
                    model: root.n !== null ? root.n.history : null
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: ListRow {
                        glyph: root.n !== null ? root.n.appGlyph(appName, "") : ""
                        title: summary
                        detail: appName
                        dimmed: true
                        hoverable: false
                        textColor: Config.ThemeConfig.colors.text
                        detailColor: Config.ThemeConfig.colors.textDim
                        glyphColor: Config.ThemeConfig.colors.textDim
                        accentColor: Config.ControlConfig.accent

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            width: root._whenW
                            text: root._when(ts)
                            color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // Hand-rolled 3px indicator (house idiom — no Controls import).
                Rectangle {
                    visible: histList.contentHeight > histList.height + 1
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    width: 3
                    radius: 1.5
                    color: Config.ThemeConfig.colors.outlineVariant
                    opacity: 0.9
                    y: {
                        var track = histList.height - height - 4
                        var frac = histList.contentY / Math.max(1, histList.contentHeight - histList.height)
                        return 2 + Math.max(0, Math.min(track, frac * track))
                    }
                    height: Math.max(24, histList.height * (histList.height / Math.max(1, histList.contentHeight)) - 4)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "history is in-memory (capped at " + (root.n !== null ? root.n.historyMax : 50) + ") · expired = read rows the reaper archived"
            color: Config.ThemeConfig.colors.textDim; opacity: 0.7
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
        }
    }
}
