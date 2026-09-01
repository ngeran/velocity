// =============================================================================
// SourceListView.qml — AUDIO input card (viewport-fit, NO SCROLLING)
// =============================================================================
// The INPUT DEVICES card. Instantiated by SinkListView inside the audio
// body's left column — sizes itself to the space it is given (fills the
// column remainder) and clamps rows to the visible capacity.
// Rows show visible-of-total; default source is priority.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

SettingsCard {
    id: view
    accent: Config.ThemeConfig.colors.secondary
    contentSpacing: 0

    // Priority order for the visible capacity: default first.
    readonly property var sortedSources: {
        var arr = Services.AudioControlService.sources.slice(0)
        arr.sort(function(a, b) {
            if (a.isDefault !== b.isDefault) return a.isDefault ? -1 : 1
            return (b.volume || 0) - (a.volume || 0)
        })
        return arr
    }
    readonly property int cap: Math.max(1, Math.floor(srcViewport.height / 36))
    readonly property var shown: sortedSources.slice(0, cap)

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        // Header label row: title + visible-of-total + thin accent line
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.topMargin: 2
            spacing: 6
            Text {
                text: "INPUT DEVICES"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                color: Config.ThemeConfig.colors.text
            }
            Text {
                text: Services.AudioControlService.sources.length > 0
                      ? (view.shown.length + " / " + Services.AudioControlService.sources.length) : "0"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: view.shown.length < Services.AudioControlService.sources.length
                       ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.secondary
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.25) }
        }

        // Column header — mirrors AudioDeviceRow geometry
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

        // Row viewport — clamped, no scrollbar
        Item {
            id: srcViewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                Repeater {
                    model: view.shown
                    delegate: AudioDeviceRow { width: parent.width; device: modelData; deviceType: "source" }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: Services.AudioControlService.sources.length === 0
                text: "// no input sources"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Text {
            Layout.fillWidth: true
            visible: view.shown.length < Services.AudioControlService.sources.length
            Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.bottomMargin: 2
            text: "+ " + (Services.AudioControlService.sources.length - view.shown.length) + " more inputs hidden"
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            elide: Text.ElideRight
        }
    }
}
