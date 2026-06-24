// =============================================================================
// WifiListView.qml — visible-networks list for the NETWORK section
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 2

    // Column header (aligned with WifiListRow's inner Row at x:4)
    Row {
        x: 4
        spacing: 8

        Text { width: 14;  text: "";          font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; color: Config.ThemeConfig.colors.textDim }
        Text { width: 180; text: "SSID";      font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
        Text { width: 90;  text: "SIGNAL";    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
        Text {             text: "SECURITY";  font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
    }

    Repeater {
        model: Services.NetworkControlService.wifiNetworks
        delegate: WifiListRow {
            width: view.width
            net: modelData
        }
    }

    Text {
        visible: Services.NetworkControlService.wifiNetworks.length === 0
        text: "// no networks visible — run 'scan wifi'"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
    }
}
