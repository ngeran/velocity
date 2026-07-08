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
    onShownChanged: if (!shown) hideTimer.restart()
    Timer {
        id: hideTimer
        interval: 280   // matches the slide duration
        onTriggered: if (!root.shown) root.visible = false
    }

    readonly property int panelWidth: 380
    readonly property int unreadCount: Services.NotificationService.unreadCount

    // ---- dim backdrop (click-outside = dismiss) ----
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        opacity: root.shown ? 0.45 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ---- the panel itself (slides + fades) ----
    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.panelWidth
        color: Config.ThemeConfig.colors.background          // pure black (OLED-safe)
        border.color: Config.ThemeConfig.colors.border       // subtle structure
        border.width: 1
        clip: true
        opacity: root.shown ? 1.0 : 0.0
        // slide from off-screen-right to flush-right
        x: root.shown ? (parent.width - width) : parent.width
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // stop clicks inside the panel from reaching the backdrop
        MouseArea { anchors.fill: parent }

        Keys.onEscapePressed: root.close()

        // unread accent hairline — top edge reads "there's something new"
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: Config.BarConfig.colorAccent
            visible: root.unreadCount > 0
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ----- header -----
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 52

                RowLayout {
                    anchors.left: parent.left; anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: "󰂚"
                        font.family: Config.BarConfig.fontNerd
                        font.pixelSize: 14
                        color: Config.BarConfig.colorAccent
                    }
                    Text {
                        text: "Notifications"
                        color: Config.ThemeConfig.colors.text
                        font.pixelSize: 14
                        font.bold: true
                        font.family: Config.BarConfig.fontFamily
                    }
                }

                // Clear All — icon-first action button
                RowLayout {
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    opacity: Services.NotificationService.model.count === 0 ? 0.35 : 1.0

                    Text {
                        text: "󰎟"
                        font.family: Config.BarConfig.fontNerd
                        font.pixelSize: 11
                        color: clearMa.containsMouse
                               ? Config.ThemeConfig.colors.error
                               : Config.ThemeConfig.colors.textDim
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        id: clearLabel
                        text: "Clear all"
                        color: clearMa.containsMouse
                               ? Config.ThemeConfig.colors.error
                               : Config.ThemeConfig.colors.textDim
                        font.pixelSize: 10
                        font.bold: true
                        font.family: Config.BarConfig.fontFamily
                        Behavior on color { ColorAnimation { duration: 120 } }
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
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Config.ThemeConfig.colors.border
                    opacity: 0.6
                }
            }

            // ----- list -----
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 10
                clip: true
                spacing: 8
                model: Services.NotificationService.model
                delegate: NotificationCard {}

                // empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: Services.NotificationService.model.count === 0
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰂛"
                        font.family: Config.BarConfig.fontNerd
                        font.pixelSize: 30
                        color: Config.ThemeConfig.colors.textDim
                        opacity: 0.45
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "All caught up"
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: 12
                        font.bold: true
                        font.family: Config.BarConfig.fontFamily
                        opacity: 0.7
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No new notifications"
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: 10
                        font.family: Config.BarConfig.fontFamily
                        opacity: 0.45
                    }
                }
            }

            // ----- footer summary -----
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                visible: Services.NotificationService.model.count > 0

                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: Config.ThemeConfig.colors.border
                    opacity: 0.6
                }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.unreadCount > 0
                          ? root.unreadCount + " unread · " + Services.NotificationService.model.count + " total"
                          : Services.NotificationService.model.count + " total"
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: 10
                    font.family: Config.BarConfig.fontFamily
                    opacity: 0.7
                }
            }
        }
    }
}
