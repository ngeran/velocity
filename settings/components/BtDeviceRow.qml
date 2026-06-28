// =============================================================================
// BtDeviceRow.qml — one bluetooth device row
// Changes vs original:
//   • Detects unpaired / pairing / paired+disconnected / connected states
//   • Inline action button adapts: [ PAIR ] → [ CONNECT ] → [ DISCONNECT ]
//   • pairingTo / connectingTo bindings drive spinner and amber colour
//   • [×] forget button on hover for paired devices
//   • Left accent bar for connected device
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    id: row
    width: parent ? parent.width : 400
    height: 26

    property var dev: ({ mac: "", name: "", connected: false, paired: false, trusted: false, battery: -1 })

    readonly property bool pairing:    Services.BluetoothControlService.pairingTo    === dev.mac
    readonly property bool connecting: Services.BluetoothControlService.connectingTo === dev.mac
    readonly property bool busy:       pairing || connecting

    // -------------------------------------------------------------------------
    // BACKGROUND
    // -------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: {
            if (row.dev.connected) return Qt.rgba(0, 0.863, 0.898, 0.08)
            if (row.busy)          return Qt.rgba(1, 0.78, 0, 0.06)
            if (ma.containsMouse)  return Config.ControlConfig.accentSoft
            return "transparent"
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // Left accent bar for connected device
    Rectangle {
        visible: row.dev.connected
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: Config.ControlConfig.accent
    }

    // -------------------------------------------------------------------------
    // CONTENT ROW
    // -------------------------------------------------------------------------
    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        spacing: 8

        // Status indicator
        Text {
            width: 14
            text: {
                if (row.pairing)        return "◌"
                if (row.connecting)     return "◌"
                if (row.dev.connected)  return "●"
                if (row.dev.paired)     return "◎"
                return "○"
            }
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 12
            color: {
                if (row.busy)          return "#ffca28"
                if (row.dev.connected) return Config.ControlConfig.accent
                if (row.dev.paired)    return Config.ThemeConfig.colors.textDim
                return Config.ThemeConfig.colors.border
            }
            RotationAnimator on rotation {
                running: row.busy
                from: 0; to: 360
                duration: 900
                loops: Animation.Infinite
            }
        }

        // Name / MAC
        Text {
            width: 150
            text: row.dev.name || row.dev.mac
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 11
            color: {
                if (row.busy)          return "#ffca28"
                if (row.dev.connected) return Config.ControlConfig.accent
                return Config.ThemeConfig.colors.text
            }
            elide: Text.ElideRight
        }

        // MAC address
        Text {
            width: 120
            text: row.dev.mac
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 9
            color: Config.ThemeConfig.colors.textDim
            elide: Text.ElideRight
        }

        // State badges
        Text {
            width: 52
            text: row.dev.paired ? "PAIRED" : "NEW"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 9
            font.bold: true
            color: row.dev.paired
                   ? Config.ControlConfig.logSuccess
                   : "#ffca28"
        }

        Text {
            width: 56
            visible: row.dev.trusted
            text: "TRUSTED"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 9
            font.bold: true
            color: Config.ControlConfig.accent
        }

        // Battery
        Text {
            visible: row.dev.battery >= 0
            text: row.dev.battery + "%"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: row.dev.battery < 20 ? "#ff5555" : Config.ThemeConfig.colors.textDim
        }

        // Spacer
        Item { width: 1 }

        // Action button — adapts to state
        Rectangle {
            visible: !row.busy
            width: actionLabel.implicitWidth + 16
            height: 18
            color: actionMA.containsMouse
                   ? (row.dev.connected ? "#ff5555" : Config.ControlConfig.accent)
                   : "transparent"
            border.color: row.dev.connected ? "#ff5555" : Config.ControlConfig.accent
            border.width: 1

            Text {
                id: actionLabel
                anchors.centerIn: parent
                text: {
                    if (row.dev.connected) return "DISCONNECT"
                    if (row.dev.paired)    return "CONNECT"
                    return "PAIR"
                }
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9
                font.bold: true
                color: actionMA.containsMouse
                       ? Config.ThemeConfig.colors.background
                       : (row.dev.connected ? "#ff5555" : Config.ControlConfig.accent)
            }

            MouseArea {
                id: actionMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    mouse.accepted = true
                    if (row.dev.connected) {
                        Services.BluetoothControlService.disconnect(row.dev.mac)
                    } else if (row.dev.paired) {
                        Services.BluetoothControlService.connect(row.dev.mac)
                    } else {
                        // pair() internally queues pair → trust → connect
                        Services.BluetoothControlService.pair(row.dev.mac)
                    }
                }
            }
        }

        // Busy label
        Text {
            visible: row.busy
            text: row.pairing ? "PAIRING..." : "CONNECTING..."
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 9
            font.bold: true
            color: "#ffca28"
        }

        // [×] forget — only on paired devices while hovering
        Text {
            visible: row.dev.paired && ma.containsMouse && !row.busy
            text: "[×]"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: "#ff5555"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    mouse.accepted = true
                    Services.BluetoothControlService.remove(row.dev.mac)
                }
            }
        }
    }

    // Hover detection for the whole row (for background + forget button)
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        // clicks fall through to individual buttons above
        propagateComposedEvents: true
        onClicked: mouse.accepted = false
    }
}
