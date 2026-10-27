// =============================================================================
// qs.Ui/Switch.qml — stateless on/off switch for plugin views (api 2)
// =============================================================================
// Bare track + sliding knob, no label — pair it with your own Text. The
// caller owns the value: bind `checked` and flip it in `onToggled()`.
// Ui imports no engine/service/config singletons (D13): colours come in as
// properties, defaulted from `ctx.theme` when a plugin ctx is set, else from
// neutral literals. Sizes are overridable (default 36×20, knob = H−6).
// =============================================================================

import QtQuick

Item {
    id: root

    property var ctx: null
    property bool checked: false
    property bool interactive: true

    property int trackWidth: 36
    property int trackHeight: 20
    readonly property int knobSize: trackHeight - 6

    property color onTrackColor: ctx && ctx.theme ? ctx.theme.colors.secondary : "#00dce5"
    property color offTrackColor: ctx && ctx.theme ? ctx.theme.colors.surfaceVariant : "#222222"
    property color offBorderColor: ctx && ctx.theme ? ctx.theme.colors.outline : "#2a2a2a"
    // QD-OLED: the knob goes DARK when on (a bright dot inside a lit track
    // would be a static burn-in candidate); dim text colour when off.
    property color knobOnColor: "#000000"
    property color knobOffColor: ctx && ctx.theme ? ctx.theme.colors.textDim : "#555555"

    signal toggled()

    implicitWidth: trackWidth
    implicitHeight: trackHeight

    Rectangle {
        id: track
        anchors.centerIn: parent
        width: root.trackWidth
        height: root.trackHeight
        radius: height / 2
        color: root.checked ? root.onTrackColor : root.offTrackColor
        border.width: 1
        border.color: root.checked ? "transparent" : root.offBorderColor
        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
            width: root.knobSize
            height: root.knobSize
            radius: width / 2
            x: root.checked ? track.width - width - 2 : 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.checked ? root.knobOnColor : root.knobOffColor
            Behavior on x { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: 100 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
