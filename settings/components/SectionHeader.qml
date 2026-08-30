// =============================================================================
// SectionHeader.qml — Unified section header component
// =============================================================================
// Replaces 4 header copies across the control views. Provides:
//   • 3×16 accent bar
//   • Title text (mono, 13px, bold)
//   • Optional right-side content slot (status pills, counts, etc.)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

RowLayout {
    id: root

    property string title: "SECTION"

    width: parent ? parent.width : 400
    spacing: 8

    // Accent bar (3×16)
    Rectangle {
        width: 3
        height: 16
        color: Config.ControlConfig.accent
        Layout.alignment: Qt.AlignVCenter
    }

    // Title
    Text {
        text: root.title
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 13
        font.bold: true
        color: Config.ThemeConfig.colors.text
        Layout.alignment: Qt.AlignVCenter
    }

    // Right-side content slot (status pills, counts, etc.)
    // Child components can add their own elements here
}
