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
    // Optional live value after the title (right-aligned mono) — absorbed
    // PanelSectionHeader's role (I7), so one eyebrow component remains.
    property string value: ""
    property color valueColor: Config.ThemeConfig.colors.text

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

    // Live value (right-aligned mono), when set
    Text {
        visible: root.value !== ""
        text: root.value
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 10
        font.bold: true
        color: root.valueColor
        elide: Text.ElideRight
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        Layout.alignment: Qt.AlignVCenter
    }

    // Right-side content slot (status pills, counts, buttons)
}
