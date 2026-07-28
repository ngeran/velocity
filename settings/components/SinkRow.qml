// =============================================================================
// SinkRow.qml — one output sink row (tactical HUD)
// =============================================================================
// Reads `sink`: { id, name, desc, isDefault, volume(0-100), mute } from
// AudioControlService.sinks. Behaviour:
//   • isDefault row → left accent bar + accent glyph + bold accent name
//   • click name    → setDefaultSink(sink.id)
//   • click bar     → setSinkVolume(sink.id, "NN%")   (positional seek)
//   • click mute    → toggleSinkMute(sink.id)
//
// NOTE on click handling: the row MouseArea covers the whole row for hover,
// so the name / bar / mute sub-areas would be shadowed. `propagateComposedEvents`
// lets the row decline the click (mouse.accepted = false) so it falls through
// to the targets beneath — same trick as BtDeviceRow / WifiListRow. All colours
// are live ThemeConfig tokens; none are hardcoded.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: row
    width: parent ? parent.width : 400
    height: 28

    // ── INTERFACE (instantiated by the list view) ──────────────────────────────
    property var sink: ({ id: "", name: "", desc: "", isDefault: false, volume: 0, mute: false })

    // ── Background tint by state ──────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: ma.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
                                : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ── Left accent bar (default sink) ────────────────────────────────────────
    Rectangle {
        visible: row.sink.isDefault
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 2
        color: Config.ControlConfig.accent
    }

    // ── Content ─────────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8; anchors.rightMargin: 6
        spacing: 8

        // (1) Speaker glyph — accent when default, else dim.
        Text {
            Layout.preferredWidth: 20; Layout.alignment: Qt.AlignVCenter
            text: "󰕾"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            color: row.sink.isDefault ? Config.ControlConfig.accent
                                      : Config.ThemeConfig.colors.textDim
        }

        // (2) Name (click → set default). Bold + accent on the default row.
        Text {
            Layout.fillWidth: true
            text: row.sink.desc || row.sink.name
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
            font.bold: row.sink.isDefault
            color: row.sink.isDefault ? Config.ControlConfig.accent
                                      : Config.ThemeConfig.colors.text
            elide: Text.ElideRight
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.AudioControlService.setDefaultSink(row.sink.id)
            }
        }

        // (3) Volume bar — click to seek (positional). Fill dims when muted.
        Rectangle {
            id: lvl
            Layout.preferredWidth: 120; Layout.preferredHeight: 6
            Layout.alignment: Qt.AlignVCenter
            color: Config.ThemeConfig.colors.border
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, row.sink.volume / 100))
                height: parent.height
                color: row.sink.mute ? Config.ThemeConfig.colors.textDim
                                     : Config.ControlConfig.accent
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var pct = Math.round(Math.max(0, Math.min(1, mouseX / lvl.width)) * 100)
                    Services.AudioControlService.setSinkVolume(row.sink.id, pct + "%")
                }
            }
        }

        // (4) Volume % (right-aligned mono).
        Text {
            Layout.preferredWidth: 32; Layout.alignment: Qt.AlignVCenter
            text: row.sink.volume + "%"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            horizontalAlignment: Text.AlignRight
        }

        // (5) Mute toggle — bordered square; border + glyph go error-red when muted.
        Rectangle {
            Layout.preferredWidth: 30; Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            color: muteMa.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.border, 0.6)
                                        : "transparent"
            border.color: row.sink.mute ? Config.ThemeConfig.colors.error
                                        : Config.ThemeConfig.colors.border
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: row.sink.mute ? "󰝟" : "󰕾"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                color: row.sink.mute ? Config.ThemeConfig.colors.error
                                     : Config.ThemeConfig.colors.textDim
            }
            MouseArea {
                id: muteMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.AudioControlService.toggleSinkMute(row.sink.id)
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
