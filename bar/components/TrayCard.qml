// =============================================================================
// TrayCard.qml — shared dropdown card for the bar's tray icons.
// =============================================================================
// One card, anchored to the right under the bar. Its header + body swap based
// on `activeTray` ("network" | "bluetooth" | "volume" | "" = hidden). Single
// theme, single animation, single position — uniform info presentation.
//
// Owned by shell.qml: activeTray drives visibility/content; closeRequested is
// wired back to clear activeTray.

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

    anchors.top: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    margins.top: Config.BarConfig.barHeight
    margins.right: 0

    implicitWidth: 300
    implicitHeight: 248
    color: "transparent"

    property string activeTray: ""
    signal closeRequested()

    readonly property string headerIcon: {
        if (activeTray === "network")
            return Services.NetworkService.isConnected
                ? (Services.NetworkService.connectionType === "wifi" ? "󰖩" : "󰈀") : "󰖪"
        if (activeTray === "bluetooth")
            return Services.BluetoothService.powered ? "󰂯" : "󰂲"
        if (activeTray === "volume")
            return Services.AudioService.muted ? "󰝟" : "󰕾"
        if (activeTray === "power")
            return Services.BatteryService.glyph
        return ""
    }
    readonly property string headerTitle: {
        if (activeTray === "network")   return "NETWORK"
        if (activeTray === "bluetooth") return "BLUETOOTH"
        if (activeTray === "volume")    return "VOLUME"
        if (activeTray === "power")     return "POWER"
        return ""
    }

    Item {
        anchors.fill: parent
        clip: true
        opacity: card.visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        transform: Translate {
            y: card.visible ? 0 : -16
            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        // Top-left + both bottom corners rounded; top-right square (flush
        // with the screen edge where the card meets the bar).
        Shape {
            anchors.fill: parent
            smooth: true
            layer.enabled: true
            ShapePath {
                fillColor: Config.BarConfig.colorBackground
                strokeWidth: 0
                startX: 14; startY: 0
                PathLine { x: 300; y: 0 }                                   // top edge → top-right (square)
                PathLine { x: 300; y: 234 }                                 // right edge
                PathArc { x: 286; y: 248; radiusX: 14; radiusY: 14 }        // bottom-right round
                PathLine { x: 14; y: 248 }                                  // bottom edge
                PathArc { x: 0; y: 234; radiusX: 14; radiusY: 14 }          // bottom-left round
                PathLine { x: 0; y: 14 }                                    // left edge
                PathArc { x: 14; y: 0; radiusX: 14; radiusY: 14 }           // top-left round
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: card.headerIcon
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: 16
                    color: Config.BarConfig.colorAccent
                }
                Text {
                    text: card.headerTitle
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 2.0
                    color: Config.BarConfig.colorText
                    Layout.fillWidth: true
                }
                Text {
                    text: "✕"
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: 14
                    color: closeArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.closeRequested()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Config.BarConfig.colorBorder }

            // Body — swaps by activeTray
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: card.activeTray === "bluetooth" ? 1
                    : (card.activeTray === "volume" ? 2
                    : (card.activeTray === "power"  ? 3 : 0))

                // ── Network ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    // Top row: type badge + filled status badge
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // WIFI / ETH / NONE type badge — outline only
                        Rectangle {
                            width: typeBadgeLabel.implicitWidth + 12
                            height: 20
                            color: Services.NetworkService.isConnected
                                ? Qt.rgba(0, 220, 229, 0.10)
                                : Qt.rgba(255,255,255,0.04)
                            border.color: Services.NetworkService.isConnected
                                ? Qt.rgba(0, 220, 229, 0.40)
                                : Config.BarConfig.colorBorder
                            border.width: 1
                            radius: 0
                            Text {
                                id: typeBadgeLabel
                                anchors.centerIn: parent
                                text: !Services.NetworkService.isConnected ? "NONE"
                                    : (Services.NetworkService.connectionType === "wifi" ? "WIFI" : "ETH")
                                font.family: Config.BarConfig.fontFamily
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                                color: Services.NetworkService.isConnected
                                    ? Config.BarConfig.colorAccent
                                    : Config.BarConfig.colorTextDim
                            }
                        }

                        // CONNECTED filled badge / DISCONNECTED muted outline — rounded
                        Rectangle {
                            width: statusBadgeLabel.implicitWidth + 16
                            height: 20
                            color: Services.NetworkService.isConnected
                                ? Config.BarConfig.colorAccent
                                : Qt.rgba(255,255,255,0.04)
                            border.color: Services.NetworkService.isConnected
                                ? Config.BarConfig.colorAccent
                                : Config.BarConfig.colorMuted
                            border.width: 1
                            radius: 10
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Text {
                                id: statusBadgeLabel
                                anchors.centerIn: parent
                                text: Services.NetworkService.isConnected ? "CONNECTED" : "DISCONNECTED"
                                font.family: Config.BarConfig.fontFamily
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                                color: Services.NetworkService.isConnected
                                    ? Config.BarConfig.colorBackground
                                    : Config.BarConfig.colorMuted
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Item { height: 12 }

                    // SSID row — hidden when disconnected
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        visible: Services.NetworkService.isConnected
                        Text {
                            text: "SSID"
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                            color: Config.BarConfig.colorTextDim
                            Layout.preferredWidth: 44
                        }
                        Text {
                            text: Services.NetworkService.ssid
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 12; font.bold: true
                            color: Config.BarConfig.colorText
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                    }

                    Item { height: 8 }

                    // IP row — hidden when disconnected (no placeholder text)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        visible: Services.NetworkService.isConnected
                        Text {
                            text: "IP"
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                            color: Config.BarConfig.colorTextDim
                            Layout.preferredWidth: 44
                        }
                        Text {
                            text: Services.NetworkService.ipAddress
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 12
                            color: Config.BarConfig.colorText
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // ── Bluetooth ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    // Power status badge row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // POWERED ON filled / POWERED OFF outline badge
                        Rectangle {
                            width: btStatusLabel.implicitWidth + 12
                            height: 20
                            color: Services.BluetoothService.powered
                                ? Config.BarConfig.colorAccent
                                : Qt.rgba(255,255,255,0.04)
                            border.color: Services.BluetoothService.powered
                                ? Config.BarConfig.colorAccent
                                : Config.BarConfig.colorMuted
                            border.width: 1
                            radius: 0
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Text {
                                id: btStatusLabel
                                anchors.centerIn: parent
                                text: Services.BluetoothService.powered ? "POWERED ON" : "POWERED OFF"
                                font.family: Config.BarConfig.fontFamily
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                                color: Services.BluetoothService.powered
                                    ? Config.BarConfig.colorBackground
                                    : Config.BarConfig.colorMuted
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Item { height: 10 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.BarConfig.colorBorder }
                    Item { height: 8 }

                    // Device count label
                    Text {
                        text: Services.BluetoothService.deviceCount + " DEVICE"
                            + (Services.BluetoothService.deviceCount !== 1 ? "S" : "") + " CONNECTED"
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                        color: Config.BarConfig.colorTextDim
                    }

                    Item { height: 6 }

                    // Device list — one row per device
                    Repeater {
                        model: Services.BluetoothService.connectedDeviceList
                            ? Services.BluetoothService.connectedDeviceList.split(",") : []
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            required property string modelData
                            required property int index

                            Text {
                                text: "󰂱"
                                font.family: Config.BarConfig.fontNerd
                                font.pixelSize: 11
                                color: Config.BarConfig.colorAccent
                            }
                            Text {
                                text: modelData.trim()
                                font.family: Config.BarConfig.fontFamily
                                font.pixelSize: 11
                                color: Config.BarConfig.colorText
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }
                    }

                    // Empty state
                    Text {
                        visible: Services.BluetoothService.deviceCount === 0
                        text: "No devices connected"
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: 11
                        color: Config.BarConfig.colorTextDim
                        font.italic: true
                    }

                    Item { Layout.fillHeight: true }

                    // Full-width action button at bottom
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        color: Services.BluetoothService.powered
                            ? Qt.rgba(255,255,255,0.05)
                            : Qt.rgba(0, 220, 229, 0.12)
                        border.color: Services.BluetoothService.powered
                            ? Config.BarConfig.colorBorder
                            : Config.BarConfig.colorAccent
                        border.width: 1
                        radius: 0
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: Services.BluetoothService.powered ? "󰂲" : "󰂯"
                                font.family: Config.BarConfig.fontNerd
                                font.pixelSize: 13
                                color: Services.BluetoothService.powered
                                    ? Config.BarConfig.colorTextDim
                                    : Config.BarConfig.colorAccent
                            }
                            Text {
                                text: Services.BluetoothService.powered ? "DISABLE BLUETOOTH" : "ENABLE BLUETOOTH"
                                font.family: Config.BarConfig.fontFamily
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                                color: Services.BluetoothService.powered
                                    ? Config.BarConfig.colorTextDim
                                    : Config.BarConfig.colorAccent
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.BluetoothService.togglePower()
                        }
                    }
                }

                // ── Volume ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    // Large percentage display
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // Glyph — 3-state
                        Text {
                            text: Services.AudioService.muted ? "󰝟"
                                : (Services.AudioService.volume > 66 ? "󰕾"
                                : (Services.AudioService.volume > 33 ? "󰕿" : "󰕿"))
                            font.family: Config.BarConfig.fontNerd
                            font.pixelSize: 20
                            color: Services.AudioService.muted
                                ? Config.BarConfig.colorMuted
                                : Config.BarConfig.colorAccent
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        // Percentage — dimmed when muted
                        Text {
                            text: Math.round(Services.AudioService.volume) + "%"
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 26; font.bold: true
                            color: Services.AudioService.muted
                                ? Config.BarConfig.colorTextDim
                                : Config.BarConfig.colorText
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Item { height: 12 }

                    // Slider
                    Slider {
                        id: volSlider
                        Layout.fillWidth: true
                        orientation: Qt.Horizontal
                        from: 0; to: 100
                        value: Services.AudioService.volume
                        onMoved: Services.AudioService.setVolume(value)

                        background: Rectangle {
                            y: volSlider.topPadding + volSlider.availableHeight / 2 - 2
                            implicitHeight: 4
                            width: volSlider.availableWidth
                            radius: 0
                            color: Config.BarConfig.colorBorder
                            Rectangle {
                                height: parent.height
                                width: volSlider.visualPosition * parent.width
                                color: Services.AudioService.muted
                                    ? Config.BarConfig.colorTextDim
                                    : Config.BarConfig.colorAccent
                                radius: 0
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                        handle: Rectangle {
                            x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                            width: 12; height: 12; radius: 0
                            color: Services.AudioService.muted
                                ? Config.BarConfig.colorTextDim
                                : Config.BarConfig.colorText
                            border.color: Services.AudioService.muted
                                ? Config.BarConfig.colorTextDim
                                : Config.BarConfig.colorAccent
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Full-width mute toggle button at bottom
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        color: Services.AudioService.muted
                            ? Qt.rgba(0, 220, 229, 0.12)
                            : Qt.rgba(255,255,255,0.05)
                        border.color: Services.AudioService.muted
                            ? Config.BarConfig.colorAccent
                            : Config.BarConfig.colorBorder
                        border.width: 1
                        radius: 0
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: Services.AudioService.muted ? "󰕾" : "󰝟"
                                font.family: Config.BarConfig.fontNerd
                                font.pixelSize: 13
                                color: Services.AudioService.muted
                                    ? Config.BarConfig.colorAccent
                                    : Config.BarConfig.colorTextDim
                            }
                            Text {
                                text: Services.AudioService.muted ? "UNMUTE" : "MUTE"
                                font.family: Config.BarConfig.fontFamily
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                                color: Services.AudioService.muted
                                    ? Config.BarConfig.colorAccent
                                    : Config.BarConfig.colorTextDim
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.AudioService.toggleMute()
                        }
                    }
                }

                // ── Power ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    // Status badge row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Laptop: CHARGING / ON BATTERY / FULLY CHARGED
                        // Desktop: AC POWER
                        Rectangle {
                            width: powerStatusLabel.implicitWidth + 16
                            height: 20
                            color: {
                                if (!Services.BatteryService.hasBattery)
                                    return Qt.rgba(0, 220, 229, 0.10)
                                if (Services.BatteryService.charging)
                                    return Qt.rgba(104, 211, 145, 0.15)   // green tint
                                if (Services.BatteryService.percentage <= 20)
                                    return Qt.rgba(248, 113, 113, 0.15)   // red tint
                                return Qt.rgba(255,255,255,0.04)
                            }
                            border.color: {
                                if (!Services.BatteryService.hasBattery)
                                    return Config.BarConfig.colorAccent
                                if (Services.BatteryService.charging)
                                    return "#68d391"
                                if (Services.BatteryService.percentage <= 20)
                                    return "#f87171"
                                return Config.BarConfig.colorBorder
                            }
                            border.width: 1
                            radius: 10
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Text {
                                id: powerStatusLabel
                                anchors.centerIn: parent
                                text: Services.BatteryService.stateLabel
                                font.family: Config.BarConfig.fontFamily
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                                color: {
                                    if (!Services.BatteryService.hasBattery)
                                        return Config.BarConfig.colorAccent
                                    if (Services.BatteryService.charging)
                                        return "#68d391"
                                    if (Services.BatteryService.percentage <= 20)
                                        return "#f87171"
                                    return Config.BarConfig.colorTextDim
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Item { height: 12 }

                    // Battery percentage row — laptop only
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        visible: Services.BatteryService.hasBattery
                        Text {
                            text: "CHARGE"
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                            color: Config.BarConfig.colorTextDim
                            Layout.preferredWidth: 56
                        }
                        Text {
                            text: Services.BatteryService.percentage + "%"
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 12; font.bold: true
                            color: {
                                if (Services.BatteryService.charging)      return "#68d391"
                                if (Services.BatteryService.percentage <= 20) return "#f87171"
                                if (Services.BatteryService.percentage <= 50) return "#fbbf24"
                                return Config.BarConfig.colorText
                            }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    Item { height: 8; visible: Services.BatteryService.hasBattery }

                    // Source row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "SOURCE"
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                            color: Config.BarConfig.colorTextDim
                            Layout.preferredWidth: 56
                        }
                        Text {
                            text: Services.BatteryService.onAc ? "AC / Wall power" : "Battery"
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 12
                            color: Config.BarConfig.colorText
                        }
                    }

                    // Low battery warning — laptop only, shown when ≤ 20 %
                    Item { height: 8; visible: Services.BatteryService.hasBattery && Services.BatteryService.percentage <= 20 }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: Services.BatteryService.hasBattery && Services.BatteryService.percentage <= 20
                        Text {
                            text: "󰀦"
                            font.family: Config.BarConfig.fontNerd
                            font.pixelSize: 13
                            color: "#f87171"
                        }
                        Text {
                            text: "LOW BATTERY"
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                            color: "#f87171"
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
