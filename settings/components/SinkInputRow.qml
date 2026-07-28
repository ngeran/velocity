// =============================================================================
// SinkInputRow.qml — one active stream row (tactical HUD)
// =============================================================================
// Reads `stream`: { id, app, volume(0-100), mute } from
// AudioControlService.sinkInputs. Behaviour:
//   • click bar  → setSinkInputVolume(stream.id, "NN%")   (positional seek)
//   • click mute → toggleSinkInputMute(stream.id)
// Streams are not default-able, so there is no left accent bar — hover bg tint
// only. The name column appends the routed sink label ("  → <sink>") when the
// `_sinkLabel` resolver returns non-empty (kept from the previous impl).
//
// NOTE on click handling: the row MouseArea covers the whole row for hover,
// so the bar / mute sub-areas would be shadowed. `propagateComposedEvents`
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
    property var stream: ({ id: "", app: "", volume: 0, mute: false })

    // ── resolve routed sink index → human label (preserved from prev impl) ────
    property string _sinkLabel: {
        if (!row.stream.sink || row.stream.sink.length === 0) return ""
        var idx = parseInt(row.stream.sink)
        var sinks = Services.AudioControlService.sinks
        for (var i = 0; i < sinks.length; i++) {
            if (sinks[i].index === idx) return sinks[i].desc || sinks[i].name
        }
        return "#" + row.stream.sink
    }

    // ── Background tint (hover only — no default state for streams) ───────────
    Rectangle {
        anchors.fill: parent
        color: ma.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
                                : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ── Content ─────────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8; anchors.rightMargin: 6
        spacing: 8

        // (1) Stream marker — dim bullet (a stream, not a sink/source).
        Text {
            Layout.preferredWidth: 20; Layout.alignment: Qt.AlignVCenter
            text: "•"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            color: Config.ThemeConfig.colors.textDim
        }

        // (2) App name + routed sink ("  → <sink>" when resolved). Elided.
        Text {
            Layout.fillWidth: true
            text: row.stream.app + (row._sinkLabel.length > 0 ? "  → " + row._sinkLabel : "")
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
            color: Config.ThemeConfig.colors.text
            elide: Text.ElideRight
        }

        // (3) Per-stream volume bar — click to seek (positional). Fill dims when muted.
        Rectangle {
            id: lvl
            Layout.preferredWidth: 120; Layout.preferredHeight: 6
            Layout.alignment: Qt.AlignVCenter
            color: Config.ThemeConfig.colors.border
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, row.stream.volume / 100))
                height: parent.height
                color: row.stream.mute ? Config.ThemeConfig.colors.textDim
                                       : Config.ControlConfig.accent
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var pct = Math.round(Math.max(0, Math.min(1, mouseX / lvl.width)) * 100)
                    Services.AudioControlService.setSinkInputVolume(row.stream.id, pct + "%")
                }
            }
        }

        // (4) Volume % (right-aligned mono).
        Text {
            Layout.preferredWidth: 32; Layout.alignment: Qt.AlignVCenter
            text: row.stream.volume + "%"
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
            border.color: row.stream.mute ? Config.ThemeConfig.colors.error
                                          : Config.ThemeConfig.colors.border
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: row.stream.mute ? "󰝟" : "󰕾"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                color: row.stream.mute ? Config.ThemeConfig.colors.error
                                       : Config.ThemeConfig.colors.textDim
            }
            MouseArea {
                id: muteMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.AudioControlService.toggleSinkInputMute(row.stream.id)
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
