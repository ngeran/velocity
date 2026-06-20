// =============================================================================
// GlassCard.qml — Modern Glass-Morphism Card Component
// =============================================================================
//
// A reusable glass-effect card component with hover states.
// Used throughout the dashboard for a cohesive modern look.
//
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: root

    // =========================================================================
    // PROPERTIES
    // =========================================================================

    property bool hovered: false
    property bool pressed: false
    property bool interactive: false

    // =========================================================================
    // APPEARANCE
    // =========================================================================

    color: {
        if (pressed) return Qt.darker(Config.SettingsConfig.surfaceLow, 1.2)
        if (hovered && interactive) return Qt.lighter(Config.SettingsConfig.surfaceLow, 1.1)
        return Config.SettingsConfig.surfaceLow
    }

    border.color: {
        if (pressed) return Qt.darker(Config.SettingsConfig.border, 1.3)
        if (hovered && interactive) return Qt.lighter(Config.SettingsConfig.border, 1.2)
        return Config.SettingsConfig.border
    }

    border.width: 1
    radius: Config.SettingsConfig.radiusLg

    // =========================================================================
    // ANIMATION
    // =========================================================================

    Behavior on color {
        ColorAnimation {
            duration: Config.SettingsConfig.animDurationNormal
            easing: Config.SettingsConfig.easingStandard
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Config.SettingsConfig.animDurationNormal
            easing: Config.SettingsConfig.easingStandard
        }
    }

    scale: {
        if (pressed && interactive) return Config.SettingsConfig.cardActiveScale
        return 1.0
    }

    Behavior on scale {
        NumberAnimation {
            duration: Config.SettingsConfig.animDurationFast
            easing: Config.SettingsConfig.easingDecelerate
        }
    }

    // =========================================================================
    // CONTENT
    // =========================================================================

    // Content children will be added here
    Item {
        anchors.fill: parent
        anchors.margins: Config.SettingsConfig.cardPadding
    }

    // =========================================================================
    // HOVER HANDLING
    // =========================================================================

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.interactive
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onPressed: root.pressed = true
        onReleased: root.pressed = false
    }
}
