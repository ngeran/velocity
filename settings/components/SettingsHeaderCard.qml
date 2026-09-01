// =============================================================================
// SettingsHeaderCard.qml — section headline card (Shibumi refresh)
// =============================================================================
// Eyebrow ("CONTROLS · NETWORK") + Inter headline + live subtitle, with an
// optional right-aligned badge slot. Pure presentation — the caller owns all
// strings/state; nothing here touches services.
//
//   SettingsHeaderCard {
//       eyebrow: "CONTROLS · NETWORK"; title: "Network"
//       subtitle: Services.NetworkControlService.ssid
//       StatusBadge { label: "CONNECTED"; kind: "ok" }
//   }
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

ColumnLayout {
    id: root

    property string eyebrow: ""
    property string title: ""
    property string subtitle: ""
    default property alias badge: badgeSlot.data

    spacing: 2

    Text {
        visible: root.eyebrow !== ""
        text: root.eyebrow
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Config.ThemeConfig.colors.textDim
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.ControlConfig.space3

        Text {
            text: root.title
            font.family: Config.ControlConfig.fontSans
            font.pixelSize: 20
            font.bold: true
            color: Config.ThemeConfig.colors.text
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Right-aligned badge slot (StatusBadge and friends)
        RowLayout {
            id: badgeSlot
            spacing: Config.ControlConfig.space2
        }
    }

    Text {
        visible: root.subtitle !== ""
        text: root.subtitle
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
        elide: Text.ElideRight
        Layout.fillWidth: true
    }
}
