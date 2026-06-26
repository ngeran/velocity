// =============================================================================
// settings/components/shared/SectionHeader.qml — Shared Section Header
// =============================================================================
//
// Consistent section titles with typography, spacing, and optional controls.
// Used across all tabs for uniform visual hierarchy.
//
// Usage:
//   SectionHeader {
//       text: "WALLPAPERS"
//       // Optional: rightControl: SomeButton { }
//   }
//
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    id: root
    implicitHeight: 20
    width: parent.width

    // =========================================================================
    // API
    // =========================================================================

    property string text: ""
    property bool rightControl: false  // Whether to show right control slot
    property real letterSpacing: 2.5   // Default letter spacing for headers

    // =========================================================================
    // LAYOUT
    // =========================================================================

    Row {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: 0
        height: parent.height

        // Main header text
        Text {
            id: headerText
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: 9
            font.family: "monospace"
            font.letterSpacing: root.letterSpacing
            color: Config.ThemeConfig.colors.textDim
        }

        // Spacer
        Item { width: 8; visible: root.rightControl }

        // Right control slot (optional)
        Item {
            width: parent.width - headerText.width - (root.rightControl ? 8 : 0)
            height: parent.height
            visible: root.rightControl

            // Children can be placed here via default property
            default property alias content: contentLoader.sourceComponent

            Loader {
                id: contentLoader
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
