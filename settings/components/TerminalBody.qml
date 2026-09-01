// =============================================================================
// TerminalBody.qml — fixed-composition content pane (NO SCROLLING)
// =============================================================================
// Per ui-refresh SKILL.md §1.7/§6.1 the pane is a fixed composition:
// header card → active section view (fills the remaining height, viewport-fit
// pattern). The old ACTIVITY console strip (CommandService tail) was removed:
// every logged action already has inline feedback (scan spinner, badges,
// state chips) and the strip cost each section ~60px of pane height.
// Header strings are read-only bindings; state stays in the services.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: body
    property string activeSection: "network"

    color: Config.ThemeConfig.colors.background
    radius: Config.ControlConfig.radiusCard
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.ControlConfig.space4
        spacing: Config.ControlConfig.space3

        // --- Section header card ---
        SettingsHeaderCard {
            Layout.fillWidth: true
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

        // --- Section views (exactly one visible; it fills the pane) ---
        WifiListView {
            visible: body.activeSection === "network"
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        BtDeviceListView {
            visible: body.activeSection === "bluetooth"
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        SinkListView {
            visible: body.activeSection === "audio"
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        DisplayControlView {
            visible: body.activeSection === "display"
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
    }
}
