// =============================================================================
// ToggleSwitch.qml — bare on/off switch: track + sliding knob, no label.
// =============================================================================
// The caller owns the value: bind `checked` to real state and flip it in
// response to `toggled()`. `busy` marks an operation in flight and swallows
// further clicks while leaving hover intact. Sharp corners per bar design.
// =============================================================================
import QtQuick
import "../config" as Config

Item {
    id: root

    property bool checked: false
    property bool busy: false
    property bool interactive: true
    property bool hasCursor: mouse.containsMouse

    signal toggled()

    readonly property int trackHeight: 20
    readonly property int trackWidth: 36
    readonly property int knobSize: 14
    readonly property int knobInset: 3

    implicitWidth: trackWidth
    implicitHeight: trackHeight

    // Track
    Rectangle {
        id: track
        anchors.centerIn: parent
        width: root.trackWidth
        height: root.trackHeight
        radius: root.height / 2
        color: root.checked ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.30)
                            : Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.10)
        border.color: root.checked ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.outlineVariant
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        // Knob
        Rectangle {
            width: root.knobSize
            height: root.knobSize
            radius: width / 2
            x: root.checked ? track.width - width - root.knobInset : root.knobInset
            anchors.verticalCenter: parent.verticalCenter
            color: root.checked ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.textDim

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
