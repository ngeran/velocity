// =============================================================================
// settings/components/shared/ToggleSwitch.qml — Shared Toggle Switch
// =============================================================================
//
// Unified toggle component with hover and active states.
// Used across all tabs for consistent toggle behavior.
//
// Usage:
//   ToggleSwitch {
//       checked: root.someProperty
//       onCheckedChanged: { root.someProperty = checked }
//   }
//
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    id: root
    width: 44
    height: 24

    // =========================================================================
    // API
    // =========================================================================

    property bool checked: false
    property bool hovered: false

    // =========================================================================
    // TOGGLE BACKGROUND
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: root.checked ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
        border.color: root.hovered ? (root.checked ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.outline) : Config.ThemeConfig.colors.border
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
    }

    // =========================================================================
    // THUMB INDICATOR
    // =========================================================================

    Rectangle {
        id: thumb
        width: 18
        height: 18
        radius: 0
        color: root.checked ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
        anchors.verticalCenter: parent.verticalCenter

        x: root.checked ? parent.width - width - 3 : 3

        Behavior on x {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // =========================================================================
    // INTERACTION
    // =========================================================================

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.checked = !root.checked
    }
}
