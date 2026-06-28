// =============================================================================
// BtDeviceListView.qml — known + scanned devices for the BLUETOOTH section
// Changes vs original:
//   • Power toggle button (shows ON/OFF state)
//   • [ SCAN ] button with 8-second live countdown from scanSecondsLeft
//   • Device list refreshes every second during scan (picks up new devices live)
//   • Column headers matching WifiListView style
//   • Separate empty states for adapter-off vs no-devices
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 6

    // -------------------------------------------------------------------------
    // TOOLBAR — power toggle + scan
    // -------------------------------------------------------------------------
    Row {
        width: parent.width
        height: 26
        spacing: 10

        // Power toggle button
        Rectangle {
            width: powerLabel.implicitWidth + 18
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            color: powerMA.containsMouse
                   ? (Services.BluetoothControlService.powered ? "#ff5555" : Config.ControlConfig.accent)
                   : "transparent"
            border.color: Services.BluetoothControlService.powered
                          ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
            border.width: 1

            Text {
                id: powerLabel
                anchors.centerIn: parent
                text: Services.BluetoothControlService.powered ? "[ BT  ON ]" : "[ BT OFF ]"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                font.bold: true
                color: powerMA.containsMouse
                       ? Config.ThemeConfig.colors.background
                       : Services.BluetoothControlService.powered
                         ? Config.ControlConfig.accent
                         : Config.ThemeConfig.colors.textDim
            }
            MouseArea {
                id: powerMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.BluetoothControlService.togglePower()
            }
        }

        // [ SCAN ] button — disabled when adapter is off or scan is running
        Rectangle {
            width: scanLabel.implicitWidth + 18
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            enabled: Services.BluetoothControlService.powered && !Services.BluetoothControlService.scanning
            opacity: enabled ? 1.0 : 0.4
            color: scanMA.containsMouse && enabled ? Config.ControlConfig.accent : "transparent"
            border.color: Services.BluetoothControlService.scanning
                          ? Config.ThemeConfig.colors.border
                          : Config.ControlConfig.accent
            border.width: 1

            Text {
                id: scanLabel
                anchors.centerIn: parent
                text: "[ SCAN ]"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                font.bold: true
                color: scanMA.containsMouse && parent.enabled
                       ? Config.ThemeConfig.colors.background
                       : Config.ControlConfig.accent
            }
            MouseArea {
                id: scanMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (parent.enabled) Services.BluetoothControlService.scanDevices()
                }
            }
        }

        // Countdown / device count
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (Services.BluetoothControlService.scanning)
                    return "scanning  " + Services.BluetoothControlService.scanSecondsLeft + "s"
                var n = Services.BluetoothControlService.devices.length
                if (n === 0) return ""
                var connected = 0
                var devs = Services.BluetoothControlService.devices
                for (var i = 0; i < devs.length; i++) if (devs[i].connected) connected++
                return n + " devices" + (connected > 0 ? "  ·  " + connected + " connected" : "")
            }
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: Services.BluetoothControlService.scanning
                   ? "#ffca28"
                   : Config.ThemeConfig.colors.textDim
        }
    }

    // -------------------------------------------------------------------------
    // OFFLINE STATE
    // -------------------------------------------------------------------------
    Text {
        visible: !Services.BluetoothControlService.powered
        text: "// adapter offline — toggle power above"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
    }

    // -------------------------------------------------------------------------
    // COLUMN HEADERS (only when adapter is on)
    // -------------------------------------------------------------------------
    Row {
        visible: Services.BluetoothControlService.powered
        x: 4
        spacing: 8

        Text { width: 14;  text: "";        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; color: Config.ThemeConfig.colors.textDim }
        Text { width: 150; text: "NAME";    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
        Text { width: 120; text: "MAC";     font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
        Text { width: 52;  text: "STATE";   font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
        Text {             text: "ACTION";  font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
    }

    // -------------------------------------------------------------------------
    // DEVICE LIST
    // -------------------------------------------------------------------------
    Repeater {
        model: Services.BluetoothControlService.devices
        delegate: BtDeviceRow {
            visible: Services.BluetoothControlService.powered
            width: view.width
            dev: modelData
        }
    }

    // Empty state (adapter on, no devices yet)
    Text {
        visible: Services.BluetoothControlService.powered
                 && Services.BluetoothControlService.devices.length === 0
                 && !Services.BluetoothControlService.scanning
        text: "// no devices found — press [ SCAN ] to search"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
    }

    // Scanning empty state
    Text {
        visible: Services.BluetoothControlService.powered
                 && Services.BluetoothControlService.devices.length === 0
                 && Services.BluetoothControlService.scanning
        text: "// scanning for nearby devices..."
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: "#ffca28"
    }
}
