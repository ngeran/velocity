// =============================================================================
// CardToggle.qml — the ONE card on/off switch (track + knob, no label)
// =============================================================================
// CANONICAL FILE — lives in shared/, synced byte-identical into
//   bar/components/CardToggle.qml       (tray-card bodies, Control Center)
//   settings/components/CardToggle.qml  (hosted pages that embed card toggles)
// by tools/sync-shared; drift fails tools/check-shared. Edit here only.
//
// Synced into roots with different singleton import URIs → imports nothing
// from either config tree; colors/scale arrive as properties (bar callers:
// `uiScale: Config.PopupMetrics.scale` + themed colors).
//
// The caller owns the value: bind `checked` to real state and flip it in
// response to `toggled()`. `busy` marks an operation in flight and swallows
// further clicks while leaving hover intact. `dimmed` = 0.4 opacity (an inert
// control must stop looking live).
// =============================================================================

import QtQuick

Item {
    id: root

    property bool checked: false
    property bool busy: false
    property bool interactive: true
    property bool dimmed: false
    property real uiScale: 1.0
    property bool hasCursor: mouse.containsMouse

    signal toggled()

    // Theme hooks (defaults = the bar's dark tokens; bind over them).
    property color accentColor: "#00dce5"
    property color textColor: "#e8edf0"
    property color outlineColor: "#22282b"

    readonly property int trackHeight: Math.round(20 * root.uiScale)
    readonly property int trackWidth: Math.round(36 * root.uiScale)
    readonly property int knobSize: Math.round(14 * root.uiScale)
    readonly property int knobInset: Math.round(3 * root.uiScale)

    implicitWidth: trackWidth
    implicitHeight: trackHeight
    opacity: root.dimmed ? 0.4 : 1.0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Rectangle {
        id: track
        anchors.centerIn: parent
        width: root.trackWidth
        height: root.trackHeight
        radius: height / 2
        color: root.checked ? Qt.rgba(root.accentColor.r, root.accentColor.g,
                                      root.accentColor.b, 0.30)
                            : Qt.rgba(root.textColor.r, root.textColor.g,
                                      root.textColor.b, 0.10)
        border.color: root.checked ? root.accentColor
                                   : (mouse.containsMouse ? root.textColor : root.outlineColor)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Rectangle {
            width: root.knobSize
            height: root.knobSize
            radius: width / 2
            x: root.checked ? track.width - width - root.knobInset : root.knobInset
            anchors.verticalCenter: parent.verticalCenter
            color: root.checked ? root.accentColor : root.textColor

            Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive && !root.busy
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
