// =============================================================================
// InfoStatRow.qml — label + value technical spec row (Shibumi / Core)
// =============================================================================
// The requested "InfoStatRow" primitive: uppercase tracked sans label on the
// left, mono bold value right-aligned. `accentValue` colors the value with the
// theme accent (base0C convention) for figures worth attention.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

RowLayout {
    id: root

    property string label: ""
    property string value: "—"
    property bool accentValue: false

    spacing: Config.ControlConfig.space2

    Text {
        text: root.label
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.0
        font.capitalization: Font.AllUppercase
        color: Config.ThemeConfig.colors.textDim
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    Text {
        text: root.value
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        font.bold: true
        color: root.accentValue ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
        elide: Text.ElideMiddle
    }
}
