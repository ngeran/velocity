// =============================================================================
// TerminalBody.qml — scrollable terminal canvas
// =============================================================================
//
// Renders the active section's header + section view (phases 3-5 swap the
// placeholder for WifiListView / BtDeviceListView / SinkListView) followed by
// the live console log from CommandService.
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Rectangle {
    id: body
    property string activeSection: "network"

    color: Config.ThemeConfig.colors.background
    radius: Config.ControlConfig.radius
    clip: true

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 12
        contentWidth: width
        contentHeight: content.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            width: flick.width
            spacing: 10

            // --- Section header ---
            Text {
                text: "[ " + body.activeSection.toUpperCase() + "_DATA ]"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 11
                font.bold: true
                color: Config.ControlConfig.accent
            }

            // --- Section views (populated per phase) ---
            // Each fades in when its section becomes active (smooth swap).
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

            BrightnessControlView {
                visible: body.activeSection === "display"
                width: content.width
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            // --- Console log ---
            Item { width: 1; height: 6 }

            Text {
                text: "[ CONSOLE ]"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 11
                font.bold: true
                color: Config.ControlConfig.accent
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
