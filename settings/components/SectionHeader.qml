// =============================================================================
// SectionHeader.qml — Unified section header component
// =============================================================================
// Shibumi eyebrow idiom: small accent tick + uppercase tracked sans label.
// Keeps the original API (title + default children slot for status pills,
// counts, buttons) so existing call sites are unchanged.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

RowLayout {
    id: root

    property string title: "SECTION"

    width: parent ? parent.width : 400
    spacing: Config.ControlConfig.space2

    // Accent tick
    Rectangle {
        width: 3
        height: 14
        radius: 1.5
        color: Config.ControlConfig.accent
        Layout.alignment: Qt.AlignVCenter
    }

    // Eyebrow label
    Text {
        text: root.title
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Config.ThemeConfig.colors.textDim
        Layout.alignment: Qt.AlignVCenter
    }

    // Right-side content slot (status pills, counts, buttons)
}
