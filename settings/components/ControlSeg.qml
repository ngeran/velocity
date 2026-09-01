// =============================================================================
// ControlSeg.qml — Unified segmented control button (Shibumi pill pattern)
// =============================================================================
// Replaces Seg + FilterSeg. Provides two usage patterns:
//   • Signal mode: set chosen() callback, emits on click when not active
//   • Direct mode: set value property, onTarget + targetProperty for direct
//                 assignment (e.g. onTarget: view, targetProperty: "minSignal")
//
// Styling (Shibumi pattern):
//   • Selected: tint(accent, 0.16) bg + accent text + accent border
//   • Hover: tint(text, 0.06) bg + outlineVariant border
//   • Idle: tint(surface, 0.4) bg + outlineVariant border
//   • Pill radius 8, 26px tall, 100ms transitions
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: root

    // -------------------------------------------------------------------------
    // PUBLIC API
    // -------------------------------------------------------------------------
    property string text: ""           // Label text (use this, not "label")
    property bool active: false        // Selected state
    property int value: 0              // Optional: value for direct assignment

    // Signal mode: emitted when clicked (only if not active)
    signal chosen()

    // Direct mode: target object + property to assign on click
    property var onTarget: null        // Target object (e.g. view)
    property string targetProperty: "" // Property name (e.g. "minSignal")

    // Optional accent color override (defaults to ControlConfig.accent)
    property color accent: Config.ControlConfig.accent
    property color segColor: accent  // Alias for compatibility with DisplayControlView

    // -------------------------------------------------------------------------
    // DIMENSIONS
    // -------------------------------------------------------------------------
    height: 26
    width: segLbl.implicitWidth + 20

    // -------------------------------------------------------------------------
    // APPEARANCE (Shibumi pill pattern)
    // -------------------------------------------------------------------------
    radius: Config.ControlConfig.radiusPill

    color: root.active
           ? Config.ThemeConfig.tint(root.accent, 0.16)
           : (segMA.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.06)
                                  : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4))

    border.color: root.active ? root.accent : Config.ThemeConfig.colors.outlineVariant
    border.width: 1

    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 100 } }

    // -------------------------------------------------------------------------
    // LABEL
    // -------------------------------------------------------------------------
    Text {
        id: segLbl
        anchors.centerIn: parent
        text: root.text
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 10
        font.bold: root.active
        font.letterSpacing: 0.4
        color: root.active ? root.accent : Config.ThemeConfig.colors.text
    }

    // -------------------------------------------------------------------------
    // INTERACTION
    // -------------------------------------------------------------------------
    MouseArea {
        id: segMA
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.active) return

            // Signal mode: emit chosen()
            root.chosen()

            // Direct mode: assign value to target property
            if (root.onTarget && root.targetProperty !== "") {
                root.onTarget[root.targetProperty] = root.value
            }
        }
    }
}
