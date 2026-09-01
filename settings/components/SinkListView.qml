// =============================================================================
// SinkListView.qml — AUDIO section view (viewport-fit, NO SCROLLING)
// =============================================================================
// Fixed composition per SKILL.md §6.1:
//   header row (badge · counts)
//   body = left column: ENGINE card + INPUT DEVICES (SourceListView, fills)
//          right column: OUTPUT DEVICES (fills, clamped) + ACTIVE STREAMS
//          (clamped). Rows show visible-of-total; default device is priority.
//
// Backed by Services.AudioControlService (native PipeWire). All colours are
// live ThemeConfig tokens. Set-default/volume/mute logic unchanged.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: view
    spacing: Config.ControlConfig.space3

    // -------------------------------------------------------------------------
    // DERIVED STATE — master volume / mute = the default sink's, else 0/false.
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

    readonly property string defaultDesc: {
        var sk = Services.AudioControlService.sinks
        var def = Services.AudioControlService.defaultSink
        for (var i = 0; i < sk.length; i++) {
            if (sk[i].id === def || sk[i].isDefault) return sk[i].desc || sk[i].name
        }
        return ""
    }

    // Priority order for the visible capacity: default first.
    readonly property var sortedSinks: {
        var arr = Services.AudioControlService.sinks.slice(0)
        arr.sort(function(a, b) {
            if (a.isDefault !== b.isDefault) return a.isDefault ? -1 : 1
            return (b.volume || 0) - (a.volume || 0)
        })
        return arr
    }
    readonly property int sinkCapacity: Math.max(2, Math.floor(sinkViewport.height / 36))
    // Count only — rows clamp by visibility, never model slicing (fresh
    // arrays destroy delegates mid-interaction; see WifiListView).
    readonly property int visibleSinkCount: Math.min(view.sortedSinks.length, view.sinkCapacity)

    // =========================================================================
    // 1. HEADER ROW
    // =========================================================================
    SectionHeader {
        Layout.fillWidth: true
        title: "AUDIO"

        StatusBadge {
            Layout.alignment: Qt.AlignVCenter
            label: view.hasOutput ? "PIPEWIRE" : "NO OUTPUT"
            kind: view.hasOutput ? "ok" : "err"
        }

        Item { Layout.fillWidth: true }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Services.AudioControlService.sinks.length + " outs · "
                  + Services.AudioControlService.sinkInputs.length + " streams"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }
    }

    // =========================================================================
    // 2. BODY — engine+inputs column | outputs+streams column (viewport-fit)
    // =========================================================================
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Config.ControlConfig.space3

        // ── Left: engine summary + input devices ──────────────────────────────
        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.maximumWidth: 340
            Layout.fillHeight: true
            spacing: Config.ControlConfig.space3

            SettingsCard {
                Layout.fillWidth: true
                accent: Config.ThemeConfig.colors.primary

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.ControlConfig.space2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "ENGINE"
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                            color: Config.ThemeConfig.colors.textDim
                        }
                        Item { Layout.fillWidth: true }

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

                    Text {
                        Layout.fillWidth: true
                        text: view.defaultDesc.length > 0 ? view.defaultDesc : "NO OUTPUT DEVICE"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 18; font.bold: true
                        color: view.hasOutput ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight
                    }

                    // Segmented master-volume meter: 20 bars, click to jump.
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
                                        radius: 1
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

                        Text {
                            text: view.masterVol + "%"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 12; font.bold: true
                            color: Config.ControlConfig.accent
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }

            // INPUT DEVICES (SourceListView) fills the left column's remainder
            SourceListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        // ── Right: outputs (fills, clamped) + streams (clamped) ───────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Config.ControlConfig.space3

            SettingsCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                accent: Config.ThemeConfig.colors.primary
                contentSpacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.topMargin: 2
                        spacing: 6
                        Text {
                            text: "OUTPUT DEVICES"
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                            color: Config.ThemeConfig.colors.text
                        }
                        Text {
                            text: Services.AudioControlService.sinks.length > 0
                                  ? (view.visibleSinkCount + " / " + Services.AudioControlService.sinks.length) : "0"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                            color: view.visibleSinkCount < Services.AudioControlService.sinks.length
                                   ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.primary
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.25) }
                    }

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

                    Item {
                        id: sinkViewport
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            Repeater {
                                model: view.sortedSinks
                                delegate: AudioDeviceRow {
                                    width: parent.width
                                    visible: index < view.sinkCapacity
                                    device: modelData; deviceType: "sink"
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: Services.AudioControlService.sinks.length === 0
                            text: "// no audio output devices detected"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                            color: Config.ThemeConfig.colors.textDim
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: view.visibleSinkCount < Services.AudioControlService.sinks.length
                        Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.bottomMargin: 2
                        text: "+ " + (Services.AudioControlService.sinks.length - view.visibleSinkCount) + " more outputs hidden"
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight
                    }
                }
            }

            SettingsCard {
                id: streamsCard
                Layout.fillWidth: true
                accent: Config.ThemeConfig.colors.secondary
                contentSpacing: 0

                readonly property int cap: Math.max(1, Math.floor(streamViewport.height / 36))
                // Count only — rows clamp by visibility, never model slicing.
                readonly property int visibleCount: Math.min(Services.AudioControlService.sinkInputs.length, cap)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.topMargin: 2
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

                    Item {
                        id: streamViewport
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(Services.AudioControlService.sinkInputs.length, 3) * 36
                        clip: true

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            Repeater {
                                model: Services.AudioControlService.sinkInputs
                                delegate: AudioDeviceRow {
                                    width: parent.width
                                    visible: index < streamsCard.cap
                                    device: modelData; deviceType: "stream"
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: Services.AudioControlService.sinkInputs.length === 0
                            text: "// no active audio streams"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                            color: Config.ThemeConfig.colors.textDim
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
