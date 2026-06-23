// =============================================================================
// BtDeviceListView.qml — paired/known devices for the BLUETOOTH section
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 2

    Text {
        visible: !Services.BluetoothControlService.powered
        text: "// adapter offline — run 'toggle bt'"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
    }

    Repeater {
        model: Services.BluetoothControlService.devices
        delegate: BtDeviceRow {
            width: view.width
            dev: modelData
        }
    }

    Text {
        visible: Services.BluetoothControlService.powered && Services.BluetoothControlService.devices.length === 0
        text: "// no devices — 'scan bt' then 'pair <mac>'"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
    }
}
