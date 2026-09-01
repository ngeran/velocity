// =============================================================================
// AudioDeviceRow.qml — Unified audio device/stream row (parametric)
// =============================================================================
// Replaces SinkRow + SourceRow + SinkInputRow (95% dup). Supports:
//   • deviceType: "sink" | "source" | "stream"
//   • Radio ●/○ default selection for sinks/sources (not streams)
//   • Click name → setDefault (sinks/sources only)
//   • Click bar → volume seek (positional)
//   • Click mute → toggle
//
// Interface:
//   property var device      // { id, name, desc, isDefault, volume, mute, app, sink }
//   property string deviceType  // "sink" | "source" | "stream"
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: row
    width: parent ? parent.width : 400
    height: 36

    property var device: ({})
    property string deviceType: "sink"

    readonly property bool isStream: deviceType === "stream"
    readonly property bool isDefault: !isStream && device.isDefault

    // ── Glyph map by type ───────────────────────────────────────────────────────
    readonly property string glyph: isStream ? "•" : (deviceType === "source" ? "󰝰" : "󰕾")
    readonly property string muteGlyph: device.mute ? "󰝟" : (isStream ? "󰕾" : (deviceType === "source" ? "󰝰" : "󰕾"))

    // ── Background tint by state ──────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Config.ControlConfig.radiusSmall
        color: ma.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ── Left accent bar (default sink/source only) — inset rounded tick ─────────
    Rectangle {
        visible: row.isDefault
        anchors.left: parent.left; anchors.leftMargin: 3
        anchors.top: parent.top; anchors.topMargin: 8
        anchors.bottom: parent.bottom; anchors.bottomMargin: 8
        width: 3
        radius: 1.5
        color: Config.ControlConfig.accent
    }

    // ── Content ─────────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10; anchors.rightMargin: 6
        spacing: 8

        // (1) Glyph — accent when default, else dim.
        Text {
            Layout.preferredWidth: 20; Layout.alignment: Qt.AlignVCenter
            text: row.glyph
            font.family: Config.ControlConfig.fontNerd; font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            color: row.isDefault ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim
        }

        // (2) Radio button for default selection (sinks/sources only)
        Text {
            visible: !row.isStream
            Layout.preferredWidth: 12; Layout.alignment: Qt.AlignVCenter
            text: row.isDefault ? "●" : "○"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: row.isDefault ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim
            horizontalAlignment: Text.AlignHCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!row.isDefault) {
                        if (row.deviceType === "sink") Services.AudioControlService.setDefaultSink(row.device.id)
                        else if (row.deviceType === "source") Services.AudioControlService.setDefaultSource(row.device.id)
                    }
                }
            }
        }

        // (3) Name (click → set default for sinks/sources). Bold + accent on default.
        Text {
            Layout.fillWidth: true
            text: {
                if (row.isStream) return row.device.app + (row.device.sink ? "  → " + row.device.sink : "")
                return row.device.desc || row.device.name
            }
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
            font.bold: row.isDefault
            color: row.isDefault ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
            elide: Text.ElideRight
            MouseArea {
                visible: !row.isStream
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (row.deviceType === "sink") Services.AudioControlService.setDefaultSink(row.device.id)
                    else if (row.deviceType === "source") Services.AudioControlService.setDefaultSource(row.device.id)
                }
            }
        }

        // (4) Volume bar — click to seek (positional). Fill dims when muted.
        Rectangle {
            id: lvl
            Layout.preferredWidth: 120; Layout.preferredHeight: 6
            Layout.alignment: Qt.AlignVCenter
            radius: 3
            color: Config.ThemeConfig.colors.border
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, row.device.volume / 100))
                height: parent.height
                radius: 3
                color: row.device.mute ? Config.ThemeConfig.colors.textDim : Config.ControlConfig.accent
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var pct = Math.round(Math.max(0, Math.min(1, mouseX / lvl.width)) * 100)
                    if (row.deviceType === "sink") Services.AudioControlService.setSinkVolume(row.device.id, pct + "%")
                    else if (row.deviceType === "source") Services.AudioControlService.setSourceVolume(row.device.id, pct + "%")
                    else Services.AudioControlService.setSinkInputVolume(row.device.id, pct + "%")
                }
            }
        }

        // (5) Volume % (right-aligned mono).
        Text {
            Layout.preferredWidth: 32; Layout.alignment: Qt.AlignVCenter
            text: row.device.volume + "%"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            horizontalAlignment: Text.AlignRight
        }

        // (6) Mute toggle — bordered pill; border + glyph go error-red when muted.
        Rectangle {
            Layout.preferredWidth: 30; Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            radius: Config.ControlConfig.radiusSmall
            color: muteMa.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.border, 0.6) : "transparent"
            border.color: row.device.mute ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.outlineVariant
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: row.muteGlyph
                font.family: Config.ControlConfig.fontNerd; font.pixelSize: 12
                color: row.device.mute ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.textDim
            }
            MouseArea {
                id: muteMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (row.deviceType === "sink") Services.AudioControlService.toggleSinkMute(row.device.id)
                    else if (row.deviceType === "source") Services.AudioControlService.toggleSourceMute(row.device.id)
                    else Services.AudioControlService.toggleSinkInputMute(row.device.id)
                }
            }
        }
    }

    // ── Row hover (drives background tint). Declines the click
    //    (mouse.accepted = false) so it falls through to the targets beneath.
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        propagateComposedEvents: true
        onClicked: mouse.accepted = false
    }
}
