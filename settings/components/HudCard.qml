// =============================================================================
// HudCard.qml — tactical HUD card (Core section redesign primitive)
// =============================================================================
// Sharp zero-radius border + 4 corner brackets (the signature HUD element) +
// a subtle theme-tinted glass fill + a faint top accent gradient line. Content
// drops straight into an inner ColumnLayout via the default `content` alias —
// same shape as CoreCard, so a module is just `HudCard { ...children... }`.
//
// Brackets are positioned by x/y (no anchors) to avoid conditional-anchor
// quirks. All colours are live ThemeConfig tokens; `accent` drives the bracket
// colour and the top gradient line. clip stays false so brackets render on the
// 1px border edge.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root
    default property alias content: slot.data

    property color accent: Config.ThemeConfig.colors.secondary
    property color bracketColor: root.accent
    property bool showBrackets: true
    property int contentSpacing: 12

    radius: 0
    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
    border.color: Config.ThemeConfig.colors.outlineVariant
    border.width: 1
    // Size to content (16px top + 16px bottom padding), mirroring CoreCard.
    implicitHeight: slot.implicitHeight + 32
    height: implicitHeight

    // Inner content column.
    ColumnLayout {
        id: slot
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.topMargin: 16
        spacing: root.contentSpacing
    }

    // Faint top accent gradient line.
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 1; opacity: 0.3
        gradient: Gradient {
            orientation: Qt.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: root.accent }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Four corner brackets — index 0=TL 1=TR 2=BL 3=BR (x/y only, no anchors).
    Repeater {
        model: root.showBrackets ? 4 : 0
        Item {
            width: 12; height: 12; opacity: 0.7
            x: (index === 0 || index === 2) ? -1 : (root.width - 11)
            y: (index === 0 || index === 1) ? -1 : (root.height - 11)
            property bool isRight: (index === 1 || index === 3)
            property bool isBottom: (index === 2 || index === 3)
            Rectangle { width: 12; height: 2; color: root.bracketColor; y: parent.isBottom ? 10 : 0 }
            Rectangle { width: 2; height: 12; color: root.bracketColor; x: parent.isRight ? 10 : 0 }
        }
    }
}
