// =============================================================================
// SinkListView.qml — AUDIO output section view (tactical HUD)
// =============================================================================
// Mirrors BtDeviceListView.qml's structure (Column shell, HUD header, HudCard
// sections, column-header geometry pinned to the row, empty states).
// Stack (scrolls with the parent Flickable, ~440px wide):
//   1. Header         — title + engine-state pill + outs/streams count
//   2. Status card    — HudCard: ENGINE label + master mute toggle + default
//                       sink desc + segmented 20-bar master-volume meter
//                       (or NO_OUTPUT_DEVICE when no default sink exists)
//   3. OUTPUT_NODES   — HudCard: NAME | LEVEL | MUTE + sink rows
//   4. ACTIVE_STREAMS — HudCard: same geometry, sink-input (app) rows
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
    spacing: Config.ControlConfig.space4

    // -------------------------------------------------------------------------
    // DERIVED STATE — master volume / mute = the default sink's, else 0/false.
    // Re-evaluates when `sinks` (reassigned fresh each poll) or `defaultSink`
    // changes. Loops `sinks` to find the entry whose id matches defaultSink
    // (or the one flagged isDefault as a fallback).
    // -------------------------------------------------------------------------
    readonly property bool hasOutput: Services.AudioControlService.defaultSink !== ""

    readonly property int masterVol: {
        var sk = Services.AudioControlService.sinks
        var def = Services.AudioControlService.defaultSink
        for (var i = 0; i < sk.length; i++) {
            if (sk[i].id === def || sk[i].isDefault) return sk[i].volume
        }
        return 0
    }

    readonly property bool masterMuted: {
        var sk = Services.AudioControlService.sinks
        var def = Services.AudioControlService.defaultSink
        for (var i = 0; i < sk.length; i++) {
            if (sk[i].id === def || sk[i].isDefault) return sk[i].mute
        }
        return false
    }

    // Default sink's desc (or "" when none) — drives the status card headline.
    readonly property string defaultDesc: {
        var sk = Services.AudioControlService.sinks
        var def = Services.AudioControlService.defaultSink
        for (var i = 0; i < sk.length; i++) {
            if (sk[i].id === def || sk[i].isDefault) return sk[i].desc || sk[i].name
        }
        return ""
    }

    // =========================================================================
    // 1. HEADER
    // =========================================================================
    SectionHeader {
        title: "AUDIO"

        // Engine-state badge — PIPEWIRE when a default sink exists, else NO OUTPUT
        StatusBadge {
            Layout.alignment: Qt.AlignVCenter
            label: view.hasOutput ? "PIPEWIRE" : "NO OUTPUT"
            kind: view.hasOutput ? "ok" : "err"
        }

        Item { Layout.fillWidth: true }

        // Sink + stream count
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Services.AudioControlService.sinks.length + " outs · "
                  + Services.AudioControlService.sinkInputs.length + " streams"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }
    }

    // Hero-row status caption
    Text {
        Layout.fillWidth: true
        Layout.topMargin: -6
        text: "AUDIO · " + (view.hasOutput ? "PIPEWIRE" : "NO OUTPUT") + " · " + Services.AudioControlService.sinks.length + " OUTS · " + Services.AudioControlService.sinkInputs.length + " STREAMS"
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 10
        font.letterSpacing: 0.3
        color: Config.ThemeConfig.colors.textDim
        opacity: 0.75
    }

    // Error surface (audio device errors)
    Text {
        Layout.fillWidth: true
        visible: false  // TODO: Bind to service error property when available
        text: "⚠ Audio device error"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 9
        color: Config.ThemeConfig.colors.error
        wrapMode: Text.Wrap
        Layout.topMargin: 4
    }

    // =========================================================================
    // 2. STATUS CARD — master volume + mute for the default sink
    // =========================================================================
    SettingsCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.primary

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.ControlConfig.space2

            // Top row: ENGINE label + master mute toggle
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "ENGINE"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                    color: Config.ThemeConfig.colors.textDim
                }
                Item { Layout.fillWidth: true }

                // Master mute toggle — toggles the default sink (toggleMute()).
                // Dimmed when no default sink exists (the service no-ops anyway).
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: muteLbl.implicitWidth + 14; height: 24
                    radius: Config.ControlConfig.radiusSmall
                    opacity: view.hasOutput ? 1.0 : 0.5
                    color: muteMA.containsMouse && view.hasOutput
                           ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
                           : "transparent"
                    border.color: Config.ThemeConfig.colors.outlineVariant
                    border.width: 1
                    Text {
                        id: muteLbl; anchors.centerIn: parent
                        text: view.masterMuted ? "󰝟" : "󰕾"
                        font.family: Config.ControlConfig.fontNerd; font.pixelSize: 12
                        color: view.masterMuted ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.text
                    }
                    MouseArea {
                        id: muteMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: view.hasOutput ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (view.hasOutput) Services.AudioControlService.toggleMute()
                    }
                }
            }

            // Big line: default sink desc (or NO OUTPUT DEVICE when none)
            Text {
                Layout.fillWidth: true
                text: view.defaultDesc.length > 0 ? view.defaultDesc : "NO OUTPUT DEVICE"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 18; font.bold: true
                color: view.hasOutput ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.textDim
                elide: Text.ElideRight
            }

            // Segmented master-volume meter (the signature visual): 20 thin
            // vertical bars, each lit when its 5% bucket is below masterVol.
            // Click anywhere on the meter to jump the default sink volume.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item {
                    id: meterItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: 2

                        Repeater {
                            model: 20
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 14
                                Layout.alignment: Qt.AlignBottom
                                color: index < Math.round(view.masterVol / 5)
                                       ? (view.masterMuted ? Config.ThemeConfig.colors.textDim : Config.ControlConfig.accent)
                                       : Config.ThemeConfig.colors.border
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: view.hasOutput ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!view.hasOutput) return
                            var pct = Math.round(Math.max(0, Math.min(1, mouseX / meterItem.width)) * 100)
                            Services.AudioControlService.setSinkVolume(Services.AudioControlService.defaultSink, pct + "%")
                        }
                    }
                }

                // Master volume % readout
                Text {
                    text: view.masterVol + "%"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 12; font.bold: true
                    color: Config.ControlConfig.accent
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    // =========================================================================
    // 3. OUTPUT_NODES — sink list
    // =========================================================================
    SettingsCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.primary
        contentSpacing: 0

        // Header label row: title + [ count ] + thin accent line on the right
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "OUTPUT DEVICES"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                color: Config.ThemeConfig.colors.text
            }
            Text {
                text: "[ " + Services.AudioControlService.sinks.length + " ]"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: Config.ThemeConfig.colors.primary
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.25) }
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

        // Sink rows
        Repeater {
            model: Services.AudioControlService.sinks
            delegate: AudioDeviceRow { width: parent.width; device: modelData; deviceType: "sink" }
        }

        // Empty state
        Text {
            Layout.fillWidth: true
            visible: Services.AudioControlService.sinks.length === 0
            text: "// no audio output devices detected"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            Layout.topMargin: 8; Layout.bottomMargin: 6
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // =========================================================================
    // 4. ACTIVE_STREAMS — sink-input (per-app) list
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
                text: "ACTIVE STREAMS"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                color: Config.ThemeConfig.colors.text
            }
            Text {
                text: "[ " + Services.AudioControlService.sinkInputs.length + " ]"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: Config.ThemeConfig.colors.secondary
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.25) }
        }

        // Column header — SAME pinned geometry as the outputs card (no radio for streams).
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10; Layout.rightMargin: 6
            spacing: 8
            Item { Layout.preferredWidth: 20 }
            Item { Layout.preferredWidth: 0 }
            Text { text: "NAME";  Layout.fillWidth: true;    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
            Text { text: "LEVEL"; Layout.preferredWidth: 120; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
            Item { Layout.preferredWidth: 32 }
            Text { text: "MUTE";  Layout.preferredWidth: 30;  font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        // Sink-input rows
        Repeater {
            model: Services.AudioControlService.sinkInputs
            delegate: AudioDeviceRow { width: parent.width; device: modelData; deviceType: "stream" }
        }

        // Empty state
        Text {
            Layout.fillWidth: true
            visible: Services.AudioControlService.sinkInputs.length === 0
            text: "// no active audio streams"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            Layout.topMargin: 8; Layout.bottomMargin: 6
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
