// =============================================================================
// PulseDot.qml — Animated Pulse Dot Component
// =============================================================================
//
// Shared animated pulse dot for status indicators.
// Used in IdentityWidget (user online status) and NetworkWidget (signal strength).
//
// PUBLIC API
//   property color dotColor — Core dot and pulse ring color (default: ThemeConfig.colors.secondary)
//   property bool animating — Enable pulse animation (default: true)
//   property real opacityMultiplier — Scale opacity (default: 1.0)
//
// ANIMATION
//   Outer ring: scale 0.3 → 1.2, opacity 1.0 → 0.0 over 1500ms, infinite loop
//   Core dot: solid 6×6, constant size
//
// CONSTRAINTS
//   radius: 0 on all Rectangles
//   layer.enabled + layer.samples on Shape elements
//   triggeredOnStart on Timer
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    id: root

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    property color dotColor: Config.ThemeConfig.colors.secondary
    property bool animating: true
    property real opacityMultiplier: 1.0

    // =========================================================================
    // OUTER PULSE RING
    // =========================================================================

    Rectangle {
        id: pulseRing
        anchors.centerIn: parent
        width: 20
        height: 20
        radius: 0
        color: "transparent"
        border.color: root.dotColor
        border.width: 1
        opacity: root.animating ? 0.0 : 0.0

        // Pulse animation: scale and opacity
        ParallelAnimation {
            id: pulseAnim
            running: root.animating
            loops: Animation.Infinite

            NumberAnimation {
                target: pulseRing
                property: "scale"
                from: 0.3
                to: 1.2
                duration: 1500
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: pulseRing
                property: "opacity"
                from: 1.0 * root.opacityMultiplier
                to: 0.0
                duration: 1500
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    // =========================================================================
    // CORE DOT (solid 6×6)
    // =========================================================================

    Rectangle {
        id: coreDot
        anchors.centerIn: parent
        width: 6
        height: 6
        radius: 0
        color: root.dotColor
        opacity: root.animating ? root.opacityMultiplier : (root.opacityMultiplier * 0.3)

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    // =========================================================================
    // DIMMED STATE (when not animating)
    // =========================================================================

    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            // Initial state set
        }
    }
}
