// =============================================================================
// TrayCard.qml
// Natural extension of the bar — same background, no border.
// All corners are sharp (radius 0).
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../services" as Services
import "../config" as Config

PanelWindow {
    id: card
    visible: activeTray !== ""

    // Full-screen transparent overlay. A click landing anywhere outside the
    // dropdown closes it — the same click-outside dismissal the
    // Fastfetch/ZaiUsage/Keybinds overlays use. The card itself is drawn above
    // the backdrop and swallows clicks so interacting with it stays put.
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Config.BarConfig.barHeight   // leave the bar itself interactive
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    property string activeTray: ""
    signal closeRequested()

    readonly property string headerIcon: {
        if (activeTray === "network")
            return Services.NetworkService.isConnected
                ? (Services.NetworkService.connectionType === "wifi" ? "󰖩" : "󰈀") : "󰖪"
        if (activeTray === "bluetooth") return Services.BluetoothService.powered ? "󰂯" : "󰂲"
        if (activeTray === "volume")    return Services.AudioService.muted ? "󰝟" : "󰕾"
        if (activeTray === "power")     return Services.BatteryService.glyph
        return ""
    }
    readonly property string headerTitle: {
        if (activeTray === "network")   return "NETWORK"
        if (activeTray === "bluetooth") return "BLUETOOTH"
        if (activeTray === "volume")    return "VOLUME"
        if (activeTray === "power")     return "POWER"
        return ""
    }

    // Click-catcher spanning the whole screen. Only clicks that miss the card
    // land here (the card is stacked above it) → close.
    MouseArea {
        anchors.fill: parent
        onClicked: card.closeRequested()
    }

    // -------------------------------------------------------------------------
    // DROPDOWN CARD — pinned under the bar, top-right. Sharp corners (radius 0).
    // -------------------------------------------------------------------------
    Rectangle {
        id: dropdown
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 0   // overlay already starts below the bar
        width: 260
        height: 220
        color: Config.BarConfig.colorBackground
        radius: 0   // sharp corners

        // Swallow clicks inside the card so they don't bubble to the backdrop.
        MouseArea { anchors.fill: parent }

    // -------------------------------------------------------------------------
    // CONTENT
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 0

        // ── HEADER ──
        Item {
            Layout.fillWidth: true
            height: 34

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: card.headerIcon
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: 14
                    color: Config.BarConfig.colorAccent
                }
                Text {
                    text: card.headerTitle
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 2.5
                    color: Config.BarConfig.colorText
                    Layout.fillWidth: true
                }
                Text {
                    text: "✕"
                    font.pixelSize: 11
                    color: closeArea.containsMouse
                           ? Config.BarConfig.colorAccent
                           : Config.BarConfig.colorTextDim
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: card.closeRequested()
                    }
                }
            }
        }

        // Subtle separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        // ── BODY ──
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: {
                if (card.activeTray === "bluetooth") return 1
                if (card.activeTray === "volume")    return 2
                if (card.activeTray === "power")     return 3
                return 0
            }

            // ── Network ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 12
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Rectangle {
                        width: typeLbl.implicitWidth + 12; height: 18
                        radius: 0
                        color: Services.NetworkService.isConnected ? Qt.rgba(0,220,229,0.10) : Qt.rgba(255,255,255,0.04)
                        border.color: Services.NetworkService.isConnected ? Config.BarConfig.colorAccent : Config.BarConfig.colorBorder
                        border.width: 1
                        Text { id: typeLbl; anchors.centerIn: parent
                            text: !Services.NetworkService.isConnected ? "NONE" : (Services.NetworkService.connectionType === "wifi" ? "WIFI" : "ETH")
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                            color: Services.NetworkService.isConnected ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim }
                    }
                    Rectangle {
                        width: connLbl.implicitWidth + 14; height: 18
                        radius: 0
                        color: Services.NetworkService.isConnected ? Config.BarConfig.colorAccent : Qt.rgba(255,255,255,0.04)
                        border.color: Services.NetworkService.isConnected ? Config.BarConfig.colorAccent : Config.BarConfig.colorBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { id: connLbl; anchors.centerIn: parent
                            text: Services.NetworkService.isConnected ? "CONNECTED" : "DISCONNECTED"
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                            color: Services.NetworkService.isConnected ? Config.BarConfig.colorBackground : Config.BarConfig.colorTextDim }
                    }
                    Item { Layout.fillWidth: true }
                }
                Item { height: 14 }
                RowLayout { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; spacing: 0
                    Text { text: "SSID"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 40 }
                    Text { text: Services.NetworkService.ssid; font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; font.bold: true; color: Config.BarConfig.colorText; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                Item { height: 8; visible: Services.NetworkService.isConnected }
                RowLayout { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; spacing: 0
                    Text { text: "IP"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 40 }
                    Text { text: Services.NetworkService.ipAddress; font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; color: Config.BarConfig.colorText; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                Item { Layout.fillHeight: true }
            }

            // ── Bluetooth ──
            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 0
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Rectangle {
                        width: btLbl.implicitWidth + 12; height: 18
                        radius: 0
                        color: Services.BluetoothService.powered ? Config.BarConfig.colorAccent : Qt.rgba(255,255,255,0.04)
                        border.color: Services.BluetoothService.powered ? Config.BarConfig.colorAccent : Config.BarConfig.colorBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { id: btLbl; anchors.centerIn: parent; text: Services.BluetoothService.powered ? "ON" : "OFF"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Services.BluetoothService.powered ? Config.BarConfig.colorBackground : Config.BarConfig.colorTextDim }
                    }
                    Item { Layout.fillWidth: true }
                }
                Item { height: 10 }
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.07) }
                Item { height: 8 }
                Text { text: Services.BluetoothService.deviceCount + " DEVICE" + (Services.BluetoothService.deviceCount !== 1 ? "S" : "") + " CONNECTED"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim }
                Item { height: 6 }
                Repeater {
                    model: Services.BluetoothService.connectedDeviceList ? Services.BluetoothService.connectedDeviceList.split(",") : []
                    delegate: RowLayout { Layout.fillWidth: true; spacing: 6
                        required property string modelData
                        Text { text: "󰂱"; font.family: Config.BarConfig.fontNerd; font.pixelSize: 11; color: Config.BarConfig.colorAccent }
                        Text { text: modelData.trim(); font.family: Config.BarConfig.fontFamily; font.pixelSize: 11; color: Config.BarConfig.colorText; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                }
                Text { visible: Services.BluetoothService.deviceCount === 0; text: "No devices connected"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 10; color: Config.BarConfig.colorTextDim; font.italic: true }
                Item { Layout.fillHeight: true }
                Rectangle {
                    Layout.fillWidth: true; height: 26
                    radius: 0
                    color: Services.BluetoothService.powered ? Qt.rgba(255,255,255,0.03) : Qt.rgba(0,220,229,0.08)
                    border.color: Services.BluetoothService.powered ? Config.BarConfig.colorBorder : Config.BarConfig.colorAccent
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout { anchors.centerIn: parent; spacing: 6
                        Text { text: Services.BluetoothService.powered ? "󰂲" : "󰂯"; font.family: Config.BarConfig.fontNerd; font.pixelSize: 12; color: Services.BluetoothService.powered ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent }
                        Text { text: Services.BluetoothService.powered ? "DISABLE" : "ENABLE"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Services.BluetoothService.powered ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Services.BluetoothService.togglePower() }
                }
            }

            // ── Volume ──
            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 0
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Text {
                        text: Services.AudioService.muted ? "󰝟" : (Services.AudioService.volume > 66 ? "󰕾" : "󰕿")
                        font.family: Config.BarConfig.fontNerd; font.pixelSize: 22
                        color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        text: Math.round(Services.AudioService.volume) + "%"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 30; font.bold: true
                        color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorText
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Item { Layout.fillWidth: true }
                }
                Item { height: 14 }
                Slider {
                    id: volSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28        // generous vertical click band
                    hoverEnabled: true
                    from: 0; to: 100
                    value: Services.AudioService.volume
                    onMoved: Services.AudioService.setVolume(value)
                    background: Rectangle {
                        x: volSlider.leftPadding
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitHeight: 6; width: volSlider.availableWidth; radius: 0
                        color: Qt.rgba(1,1,1,0.10)
                        Rectangle {
                            height: parent.height
                            width: volSlider.visualPosition * parent.width
                            radius: 0
                            color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                    handle: Rectangle {
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        width: 18; height: 18; radius: 0
                        color: Config.BarConfig.colorBackground
                        border.color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent
                        border.width: 2
                        // Grow on hover / press so the grab target reads as interactive.
                        scale: volSlider.pressed ? 1.15 : (volSlider.hovered ? 1.1 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }
                }
                Item { height: 12 }
                Rectangle {
                    Layout.fillWidth: true; height: 26
                    radius: 0
                    color: Services.AudioService.muted ? Qt.rgba(0,220,229,0.08) : Qt.rgba(255,255,255,0.03)
                    border.color: Services.AudioService.muted ? Config.BarConfig.colorAccent : Config.BarConfig.colorBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout { anchors.centerIn: parent; spacing: 6
                        Text { text: Services.AudioService.muted ? "󰕾" : "󰝟"; font.family: Config.BarConfig.fontNerd; font.pixelSize: 12; color: Services.AudioService.muted ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim }
                        Text { text: Services.AudioService.muted ? "UNMUTE" : "MUTE"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Services.AudioService.muted ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Services.AudioService.toggleMute() }
                }
            }

            // ── Power ──
            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 0
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Rectangle {
                        width: pwrLbl.implicitWidth + 16; height: 18
                        radius: 0
                        color: {
                            if (!Services.BatteryService.hasBattery)      return Qt.rgba(0,220,229,0.10)
                            if (Services.BatteryService.charging)          return Qt.rgba(104,211,145,0.15)
                            if (Services.BatteryService.percentage <= 20)  return Qt.rgba(248,113,113,0.15)
                            return Qt.rgba(255,255,255,0.04)
                        }
                        border.color: {
                            if (!Services.BatteryService.hasBattery)      return Config.BarConfig.colorAccent
                            if (Services.BatteryService.charging)          return "#68d391"
                            if (Services.BatteryService.percentage <= 20)  return "#f87171"
                            return Config.BarConfig.colorBorder
                        }
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Text { id: pwrLbl; anchors.centerIn: parent; text: Services.BatteryService.stateLabel
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                            color: { if (!Services.BatteryService.hasBattery) return Config.BarConfig.colorAccent; if (Services.BatteryService.charging) return "#68d391"; if (Services.BatteryService.percentage <= 20) return "#f87171"; return Config.BarConfig.colorTextDim }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
                Item { height: 14 }
                RowLayout { visible: Services.BatteryService.hasBattery; Layout.fillWidth: true; spacing: 0
                    Text { text: "CHARGE"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 52 }
                    Text { text: Services.BatteryService.percentage + "%"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 13; font.bold: true
                        color: { if (Services.BatteryService.charging) return "#68d391"; if (Services.BatteryService.percentage <= 20) return "#f87171"; if (Services.BatteryService.percentage <= 50) return "#fbbf24"; return Config.BarConfig.colorText }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
                Item { height: 8; visible: Services.BatteryService.hasBattery }
                RowLayout { Layout.fillWidth: true; spacing: 0
                    Text { text: "SOURCE"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 52 }
                    Text { text: Services.BatteryService.onAc ? "AC / Wall" : "Battery"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; color: Config.BarConfig.colorText }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
    }   // dropdown Rectangle
}
