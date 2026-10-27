// =============================================================================
// Card.qml — THE settings content card (C4 primitive, I7)
// =============================================================================
// One card, three looks — the variant picks the pair; visuals per variant are
// identical to the components it replaces:
//
//   variant      radius              tint  pad  top line            brackets
//   "core"       12                  0.55  12   gradient @ 0.25     no
//   "settings"   ControlConfig 10    0.55  16   none                no
//   "hud"        0 (sharp)           0.40  16   gradient @ 0.30     yes
//
// `accent` defaults per variant (core → primary, hud → secondary, settings →
// ControlConfig.accent, informational only). Content drops into an inner
// ColumnLayout via the default `content` alias; only implicitHeight is
// exposed so a layout may still stretch the card.
// (DashboardCard stays separate on purpose: its slot is a clipped free-form
// Item for bento-grid `anchors.fill` content, not a ColumnLayout.)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root

    default property alias content: slot.data

    property string variant: "settings"   // "core" | "settings" | "hud"
    property color accent: root.variant === "core" ? Config.ThemeConfig.colors.primary
                         : root.variant === "hud" ? Config.ThemeConfig.colors.secondary
                         : Config.ControlConfig.accent
    property color bracketColor: root.accent
    property bool showBrackets: root.variant === "hud"
    property int contentSpacing: Config.ControlConfig.space3

    readonly property int pad: root.variant === "core" ? 12 : 16

    radius: root.variant === "core" ? 12
          : root.variant === "settings" ? Config.ControlConfig.radiusCard : 0
    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, root.variant === "hud" ? 0.4 : 0.55)
    border.color: Config.ThemeConfig.colors.outlineVariant
    border.width: 1
    implicitHeight: slot.implicitHeight + 2 * root.pad

    ColumnLayout {
        id: slot
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.margins: root.pad
        spacing: root.contentSpacing
    }

    // Faint top accent gradient line (core + hud).
    Rectangle {
        visible: root.variant !== "settings"
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 1
        opacity: root.variant === "hud" ? 0.3 : 0.25
        gradient: Gradient {
            orientation: Qt.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: root.accent }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Four corner brackets (hud) — index 0=TL 1=TR 2=BL 3=BR (x/y, no anchors).
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
