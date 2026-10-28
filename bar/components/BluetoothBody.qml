// =============================================================================
// BluetoothBody.qml — TrayCard bluetooth body (I8 extraction)
// =============================================================================
// Adapter power row, connected-device cards with battery bars, DISABLE
// footer, OPEN IN SETTINGS link. Pure view — state lives in BluetoothService.
// Interface follows NetworkCardBody: the card is injected as `tray`, settings
// deep links come back through settingsRequested(verb). Instantiated lazily
// by TrayCard on the body's first open.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../config" as Config

ColumnLayout {
    id: body

    property var tray: null                    // owning TrayCard (hair, openSettings)
    signal settingsRequested(string verb)

    readonly property bool _ok: tray !== null
    readonly property real _hair: _ok ? tray.hair : 1

    Layout.fillWidth: true; spacing: 0

    // bluetoothctl absent — dim dash instead of a misleading "OFF" pill
    Text {
        visible: !Services.BluetoothService.hasBluetooth
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "—"
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: Config.PopupMetrics.px(28)
        color: Config.BarConfig.colorTextDim
    }

    // ── adapter row: ON pill · UP state · DISCOVERABLE chip ──
    RowLayout {
        visible: Services.BluetoothService.hasBluetooth
        Layout.fillWidth: true; spacing: Config.PopupMetrics.px(10)

        Rectangle {
            width: btLbl.implicitWidth + 20; height: Config.PopupMetrics.px(26)
            radius: Config.PopupMetrics.px(5)
            color: Services.BluetoothService.powered ? Config.ThemeConfig.accentTint : Config.ThemeConfig.fillRest
            border.color: Services.BluetoothService.powered ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorBorder
            border.width: _hair
            Behavior on color { ColorAnimation { duration: 150 } }
            Text { id: btLbl; anchors.centerIn: parent
                text: Services.BluetoothService.powered ? "ON" : "OFF"
                font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(9); font.bold: true; font.letterSpacing: 1.5
                color: Services.BluetoothService.powered ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorTextDim }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.BluetoothService.togglePower()
            }
        }
        Text {
            text: Services.BluetoothService.powered ? "adapter: UP" : "adapter: DOWN"
            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(10)
            color: Config.BarConfig.colorTextDim
        }
    }
    Item { height: 10; visible: Services.BluetoothService.hasBluetooth }
    Rectangle { visible: Services.BluetoothService.hasBluetooth; Layout.fillWidth: true; height: _hair; color: Config.ThemeConfig.hairline }
    Item { height: Config.PopupMetrics.px(8); visible: Services.BluetoothService.hasBluetooth }

    // ── CONNECTED section header ──
    RowLayout {
        visible: Services.BluetoothService.hasBluetooth
        Layout.fillWidth: true
        Text {
            text: Services.BluetoothService.deviceCount + " DEVICE" + (Services.BluetoothService.deviceCount !== 1 ? "S" : "") + " CONNECTED"
            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8); font.bold: true
            font.letterSpacing: 1.5
            color: Config.BarConfig.colorTextDim
        }
        Item { Layout.fillWidth: true }
        Text {
            text: "BATTERY"
            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8); font.bold: true
            font.letterSpacing: 1.5
            color: Config.BarConfig.colorTextDim
        }
    }
    Item { height: Config.PopupMetrics.px(6); visible: Services.BluetoothService.hasBluetooth }

    // ── connected device cards ──
    Repeater {
        visible: Services.BluetoothService.hasBluetooth
        model: Services.BluetoothService.connectedDevices.slice(0, 4)

        delegate: Rectangle {
            required property var modelData
            readonly property var batt: Services.BluetoothService.deviceBatteries[modelData.address]
            Layout.fillWidth: true
            Layout.preferredHeight: Config.PopupMetrics.px(46)
            Layout.bottomMargin: Config.PopupMetrics.px(8)
            radius: Config.PopupMetrics.px(6)
            color: rowHover.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
            border.color: Config.BarConfig.colorBorder; border.width: _hair
            Behavior on color { ColorAnimation { duration: 100 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Config.PopupMetrics.px(12); anchors.rightMargin: Config.PopupMetrics.px(12)
                spacing: Config.PopupMetrics.px(10)

                Text { text: modelData.icon; font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(14); color: Config.BarConfig.colorAccent }
                ColumnLayout {
                    spacing: Config.PopupMetrics.px(1)
                    Layout.fillWidth: true
                    Text {
                        text: modelData.name
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true
                        color: Config.BarConfig.colorText
                        elide: Text.ElideRight; Layout.maximumWidth: Config.PopupMetrics.px(190)
                    }
                    Text {
                        text: modelData.address
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
                        color: Config.BarConfig.colorTextDim
                        elide: Text.ElideMiddle; Layout.maximumWidth: Config.PopupMetrics.px(190)
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: batt !== undefined
                    text: batt + "%"
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true
                    color: Config.BarConfig.colorText
                }
                // battery bar (mockup) — green when healthy
                Rectangle {
                    visible: batt !== undefined
                    width: Config.PopupMetrics.px(22); height: 11; radius: Config.PopupMetrics.px(2)
                    color: Config.ThemeConfig.hairlineSoft
                    border.color: Config.BarConfig.colorBorder; border.width: _hair
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top; anchors.bottom: parent.top
                        anchors.margins: Config.PopupMetrics.px(2)
                        width: (parent.width - 4) * batt / 100
                        height: parent.height - 4
                        color: batt >= 50 ? Config.ThemeConfig.colors.success
                             : batt >= 25 ? Config.ThemeConfig.colors.warning
                             : Config.ThemeConfig.colors.error
                    }
                }
                // hover-revealed disconnect (kept from the old row)
                Text {
                    visible: rowHover.containsMouse
                    text: "✕"
                    font.pixelSize: Config.PopupMetrics.px(10)
                    color: discArea.containsMouse ? Config.ThemeConfig.colors.error : Config.BarConfig.colorTextDim
                    MouseArea {
                        id: discArea
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.BluetoothService.disconnectDevice(modelData.address)
                    }
                }
            }
            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
            }
        }
    }

    Text {
        visible: Services.BluetoothService.hasBluetooth &&
                 Services.BluetoothService.connectedDevices.length === 0
        Layout.fillWidth: true
        text: Services.BluetoothService.powered
              ? "No devices connected"
              : "Bluetooth is off"
        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(9); font.italic: true
        color: Config.BarConfig.colorTextDim
    }
    Item { height: 10; visible: Services.BluetoothService.hasBluetooth }

    // ── DISABLE / ENABLE BLUETOOTH footer (mockup full-width pill) ──
    Rectangle {
        visible: Services.BluetoothService.hasBluetooth
        Layout.fillWidth: true; height: Config.PopupMetrics.px(32)
        radius: Config.PopupMetrics.px(6)
        color: btBtnArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
        border.color: Config.BarConfig.colorBorder; border.width: _hair
        Behavior on color { ColorAnimation { duration: 150 } }
        RowLayout { anchors.centerIn: parent; spacing: Config.PopupMetrics.px(6)
            Text { text: Services.BluetoothService.powered ? "󰂲" : "󰂯"; font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(12); color: Config.BarConfig.colorTextDim }
            Text { text: Services.BluetoothService.powered ? "DISABLE BLUETOOTH" : "ENABLE BLUETOOTH"; font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8); font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorText }
        }
        MouseArea { id: btBtnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Services.BluetoothService.togglePower() }
    }
    SettingsLink { visible: Services.BluetoothService.hasBluetooth; verb: "openControlBluetooth"; onActivated: function(v) { body.settingsRequested(v) } }
}
