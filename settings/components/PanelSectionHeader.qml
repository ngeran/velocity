// =============================================================================
// PanelSectionHeader.qml — card-local eyebrow + live value row
// =============================================================================
// Shibumi eyebrow idiom: uppercase tracked sans label ("MODE") followed by a
// live mono value ("3840×2160"). API-compatible with the previous version.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

RowLayout {
    id: root

    property string label: ""
    property string value: ""
    property color color: Config.ThemeConfig.colors.textDim

    spacing: Config.ControlConfig.space2

    Text {
        text: root.label
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.0
        font.capitalization: Font.AllUppercase
        color: Config.ThemeConfig.colors.textDim
    }

    Text {
        visible: root.value !== ""
        text: root.value
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 10
        font.bold: true
        color: root.color
        elide: Text.ElideRight
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
    }
}
