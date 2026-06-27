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
    implicitHeight: 220
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
        return ""
    }
    readonly property string headerTitle: {
        if (activeTray === "network") return "NETWORK"
        if (activeTray === "bluetooth") return "BLUETOOTH"
        if (activeTray === "volume") return "VOLUME"
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
                PathLine { x: 300; y: 206 }                                 // right edge
                PathArc { x: 286; y: 220; radiusX: 14; radiusY: 14 }        // bottom-right round
                PathLine { x: 14; y: 220 }                                  // bottom edge
                PathArc { x: 0; y: 206; radiusX: 14; radiusY: 14 }          // bottom-left round
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
                currentIndex: card.activeTray === "bluetooth" ? 1 : (card.activeTray === "volume" ? 2 : 0)

                // ── Network ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: Services.NetworkService.ssid
                        color: Config.BarConfig.colorText
                        font.pixelSize: 15; font.bold: true
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.BarConfig.colorBorder }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: Services.NetworkService.isConnected ? "Connected" : "Disconnected"
                            color: Services.NetworkService.isConnected ? Config.BarConfig.colorAccent : Config.BarConfig.colorMuted
                            font.pixelSize: 11
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Services.NetworkService.ipAddress
                            color: Config.BarConfig.colorText; font.pixelSize: 12; font.bold: true
                        }
                    }
                    Item { Layout.fillHeight: true }
                }

                // ── Bluetooth ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: Services.BluetoothService.powered ? "Powered On" : "Powered Off"
                        color: Services.BluetoothService.powered ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
                        font.pixelSize: 13; font.bold: true
                    }
                    Text {
                        text: "Devices: " + Services.BluetoothService.deviceCount
                        color: Config.BarConfig.colorText; font.pixelSize: 11
                    }
                    Text {
                        text: Services.BluetoothService.connectedDeviceList
                        color: Config.BarConfig.colorTextDim; font.pixelSize: 10
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true; Layout.minimumHeight: 4 }
                    Button {
                        id: btToggle
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 120; Layout.preferredHeight: 30
                        contentItem: Text {
                            text: Services.BluetoothService.powered ? "Disable" : "Enable"
                            color: "#ffffff"
                            font.pixelSize: 11; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: Services.BluetoothService.powered ? "#3d3d3d" : Config.BarConfig.colorAccent
                            radius: 6
                        }
                        onClicked: Services.BluetoothService.togglePower()
                    }
                }

                // ── Volume ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: Services.AudioService.muted ? "󰝟" : "󰕾"
                            font.family: Config.BarConfig.fontNerd
                            font.pixelSize: 22
                            color: Services.AudioService.muted ? Config.BarConfig.colorMuted : Config.BarConfig.colorAccent
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Services.AudioService.toggleMute() }
                        }
                        Text {
                            text: Math.round(Services.AudioService.volume) + "%"
                            color: Config.BarConfig.colorText
                            font.pixelSize: 18; font.bold: true
                            Layout.fillWidth: true
                        }
                    }

                    Slider {
                        id: volSlider
                        Layout.fillWidth: true
                        orientation: Qt.Horizontal
                        from: 0; to: 100
                        value: Services.AudioService.volume
                        onMoved: Services.AudioService.setVolume(value)

                        background: Rectangle {
                            y: volSlider.topPadding + volSlider.availableHeight / 2 - 3
                            implicitHeight: 6
                            width: volSlider.availableWidth
                            radius: 3
                            color: Config.BarConfig.colorBorder
                            Rectangle {
                                height: parent.height
                                width: volSlider.visualPosition * parent.width
                                color: Config.BarConfig.colorAccent
                                radius: 3
                            }
                        }
                        handle: Rectangle {
                            x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                            width: 16; height: 16; radius: 8
                            color: Config.BarConfig.colorText
                            border.color: Config.BarConfig.colorAccent
                            border.width: 1
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
