// =============================================================================
// settings/components/shared/SettingsPage.qml — Shared Page Scaffold
// =============================================================================
//
// Shared page scaffold with consistent padding, scrolling, and structure.
// All tab content should use this for uniform layout.
//
// Usage:
//   SettingsPage {
//       // Your content here - automatically gets padding and scroll
//       Column {
//           SectionHeader { text: "SECTION" }
//           // Content...
//       }
//   }
//
// =============================================================================

import QtQuick
import QtQuick.Controls
import "../config" as Config

ScrollView {
    id: root

    // =========================================================================
    // LAYOUT
    // =========================================================================

    clip: true
    scrollBar.horizontal.policy: ScrollBar.AlwaysOff

    // Content wrapper with consistent padding
    Item {
        id: content
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height

        // Default padding for all pages
        anchors {
            topMargin: 32
            leftMargin: 24
            rightMargin: 24
            bottomMargin: 24
        }

        width: root.width - anchors.leftMargin - anchors.rightMargin

        // Content slot - children go here
        default property alias content: contentContainer.children

        Column {
            id: contentContainer
            spacing: 0
            width: content.width
        }
    }
}
