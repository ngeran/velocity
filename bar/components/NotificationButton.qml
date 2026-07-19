// =============================================================================
// NotificationButton.qml — bar trigger for the Notification Center
// =============================================================================
// Bell glyph + overlapping count badge (icon-first, not a raw number pill).
// Sits in the bar's right-side icon row. Emits centerRequested() on click;
// shell.qml wires that to NotificationCenter.toggle().
//
// States:
//   count == 0  → dim bell outline                 (nothing new)
//   count  1..9 → bell (brighter) + filled badge with number
//   count  10+  → badge shows "9+"
//   panel open  → bell tints accent + thin accent underline
//   new arrival → one-shot pulse ring behind the bell
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    id: root
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.barHeight

    property bool isActive: false
    signal centerRequested()

    readonly property int _count: Services.NotificationService.unreadCount
    readonly property bool _hasUnread: _count > 0

    // ---- one-shot pulse when unread count increases ----
    on_CountChanged: if (_count > 0) pulse.restart()

    Rectangle {
        id: pulseRing
        anchors.centerIn: bellIcon
        width: 20; height: 20
        radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: Config.BarConfig.colorAccent
        opacity: 0
        scale: 0.6

        SequentialAnimation {
            id: pulse
            NumberAnimation { target: pulseRing; property: "opacity"; to: 0.85; duration: 80 }
            ParallelAnimation {
                NumberAnimation { target: pulseRing; property: "scale"; to: 1.6; duration: 420; easing.type: Easing.OutCubic }
                NumberAnimation { target: pulseRing; property: "opacity"; to: 0; duration: 420; easing.type: Easing.OutCubic }
            }
            onStopped: pulseRing.scale = 0.6
        }
    }

    // ---- bell glyph (the button's core visual) ----
    Text {
        id: bellIcon
        anchors.centerIn: parent
        text: root._hasUnread ? "󰂚" : "󰂜"
        font.family: Config.BarConfig.fontNerd
        font.pixelSize: Config.BarConfig.fontSizeIcon
        color: (root.isActive || hoverMa.containsMouse)
               ? Config.BarConfig.colorAccent
               : (root._hasUnread ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim)
        scale: hoverMa.containsMouse ? 1.08 : 1.0
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    // ---- active-state cue: thin accent underline (replaces the old ring) ----
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        width: root.isActive ? 12 : 0
        height: 2
        color: Config.BarConfig.colorAccent
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    // ---- unread badge, overlapping the glyph's top-right ----
    Rectangle {
        id: badge
        visible: root._hasUnread
        implicitWidth: Math.max(14, badgeLabel.implicitWidth + 6)
        height: 14
        radius: height / 2
        color: Config.BarConfig.colorAccent
        border.color: Config.ThemeConfig.colors.background
        border.width: 1.5
        anchors.right: bellIcon.right
        anchors.top: bellIcon.top
        anchors.rightMargin: -8
        anchors.topMargin: -6
        Behavior on implicitWidth { NumberAnimation { duration: 120 } }

        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: root._count > 9 ? "9+" : root._count
            color: Config.ThemeConfig.colors.background
            font.pixelSize: 9
            font.bold: true
            font.family: Config.BarConfig.fontFamily
        }
    }

    MouseArea {
        id: hoverMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.centerRequested()
    }
}
