// =============================================================================
// TerminalBody.qml — scrollable content canvas
// =============================================================================
// Renders the active section's SettingsHeaderCard + section view (network →
// WifiListView, bluetooth → BtDeviceListView, audio → Sink/SourceListView,
// display → DisplayControlView) followed by the live console log from
// CommandService. Header strings are read-only bindings — all state stays in
// the services.
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Rectangle {
    id: body
    property string activeSection: "network"

    color: Config.ThemeConfig.colors.background
    radius: Config.ControlConfig.radiusCard
    clip: true

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Config.ControlConfig.space4
        contentWidth: width
        contentHeight: content.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            width: flick.width
            spacing: Config.ControlConfig.space4

            // --- Section header card ---
            SettingsHeaderCard {
                width: content.width
                eyebrow: "CONTROLS"
                title: body.activeSection === "network"   ? "Network"
                     : body.activeSection === "bluetooth" ? "Bluetooth"
                     : body.activeSection === "audio"     ? "Audio"
                     : body.activeSection === "display"   ? "Display"
                     : "Control"
                subtitle: body.activeSection === "network"
                          ? (Services.NetworkControlService.connectionStatus.connected
                             ? (Services.NetworkControlService.connectionStatus.ssid || "Connected")
                               + " · " + (Services.NetworkControlService.connectionStatus.ip || "no IP")
                             : "Not connected — scan below")
                          : ""
                StatusBadge {
                    visible: body.activeSection === "network"
                    label: Services.NetworkControlService.connectionStatus.connected ? "STABLE" : "OFFLINE"
                    kind: Services.NetworkControlService.connectionStatus.connected ? "ok" : "err"
                }
            }

            // --- Section views (each fades in when its section becomes active) ---
            WifiListView {
                visible: body.activeSection === "network"
                width: content.width
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            BtDeviceListView {
                visible: body.activeSection === "bluetooth"
                width: content.width
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            SinkListView {
                visible: body.activeSection === "audio"
                width: content.width
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            SourceListView {
                visible: body.activeSection === "audio"
                width: content.width
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            DisplayControlView {
                visible: body.activeSection === "display"
                width: content.width
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            // --- Console log ---
            Item { width: 1; height: 6 }

            Text {
                text: "ACTIVITY"
                font.family: Config.ControlConfig.fontSans
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
                color: Config.ThemeConfig.colors.textDim
            }

            Repeater {
                model: Services.CommandService.logLines
                onCountChanged: Qt.callLater(function() {
                    flick.contentY = Math.max(0, flick.contentHeight - flick.height)
                })
                delegate: TerminalLogLine {
                    width: content.width
                    text: model.text
                    kind: model.kind
                }
            }
        }
    }
}
