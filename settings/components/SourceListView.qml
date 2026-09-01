// =============================================================================
// SourceListView.qml — AUDIO input section view (tactical HUD)
// =============================================================================
// Mirrors SinkListView.qml / BtDeviceListView.qml structure. A single
// INPUT_NODES HudCard — no top-level header (the card header replaces the old
// "[ INPUT_SOURCES ]" text label that used to sit above this list).
//   - INPUT_NODES HudCard: NAME | LEVEL | MUTE + source rows + empty state
//
// Backed by Services.AudioControlService (WirePlumber via wpctl). All colours
// are live ThemeConfig tokens (no hardcoded rgba).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 10

    // =========================================================================
    // INPUT_NODES — source (microphone) list
    // =========================================================================
    SettingsCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.secondary
        contentSpacing: 0

        // Header label row: title + [ count ] + thin accent line (secondary)
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "INPUT DEVICES"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                color: Config.ThemeConfig.colors.text
            }
            Text {
                text: "[ " + Services.AudioControlService.sources.length + " ]"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: Config.ThemeConfig.colors.secondary
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.25) }
        }

        // Column header — mirrors AudioDeviceRow geometry (margins 10/6,
        // spacing 8, glyph 20, radio 12, NAME fill, LEVEL 120, vol% 32, MUTE 30) so every
        // column lines up between the header and the rows beneath it.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10; Layout.rightMargin: 6
            spacing: 8
            Item { Layout.preferredWidth: 20 }
            Item { Layout.preferredWidth: 12 }
            Text { text: "NAME";  Layout.fillWidth: true;    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
            Text { text: "LEVEL"; Layout.preferredWidth: 120; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
            Item { Layout.preferredWidth: 32 }
            Text { text: "MUTE";  Layout.preferredWidth: 30;  font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        // Source rows
        Repeater {
            model: Services.AudioControlService.sources
            delegate: AudioDeviceRow { width: parent.width; device: modelData; deviceType: "source" }
        }

        // Empty state
        Text {
            Layout.fillWidth: true
            visible: Services.AudioControlService.sources.length === 0
            text: "// no input sources"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            Layout.topMargin: 8; Layout.bottomMargin: 6
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
