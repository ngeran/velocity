// =============================================================================
// WifiListRow.qml — one wifi network row
// Changes vs original:
//   • signal requestPassword(string ssid) — emitted for secured networks
//   • connecting state bound to NetworkControlService.connectingTo
//   • inUse row gets a [DISCONNECT] affordance on hover
//   • open networks connect immediately; secured networks ask for password
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    id: row
    width: parent ? parent.width : 400
    height: 22

    property var net: ({ ssid: "", signal: 0, security: "", inUse: false })

    // Emitted when a secured network is clicked and needs a password
    signal requestPassword(string ssid)

    // True while nmcli is connecting to this specific network
    readonly property bool connecting: Services.NetworkControlService.connectingTo === net.ssid

    // -------------------------------------------------------------------------
    // BACKGROUND
    // -------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: {
            if (row.net.inUse)    return Qt.rgba(0, 0.863, 0.898, 0.08)   // teal tint
            if (row.connecting)   return Qt.rgba(1, 0.78, 0, 0.06)        // amber tint
            if (ma.containsMouse) return Config.ControlConfig.accentSoft
            return "transparent"
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // Left accent bar for connected network
    Rectangle {
        visible: row.net.inUse
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
        spacing: 8

        // In-use / connecting indicator
        Text {
            width: 14
            text: {
                if (row.connecting) return "◌"
                if (row.net.inUse)  return "●"
                return "○"
            }
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 12
            color: {
                if (row.connecting) return "#ffca28"
                if (row.net.inUse)  return Config.ControlConfig.accent
                return Config.ThemeConfig.colors.border
            }

            RotationAnimator on rotation {
                running: row.connecting
                from: 0; to: 360
                duration: 900
                loops: Animation.Infinite
            }
        }

        // SSID
        Text {
            width: 180
            text: row.net.ssid
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 11
            color: {
                if (row.connecting) return "#ffca28"
                if (row.net.inUse)  return Config.ControlConfig.accent
                return Config.ThemeConfig.colors.text
            }
            elide: Text.ElideRight
        }

        // Signal bar + %
        Item {
            width: 90
            height: 14
            Rectangle {
                id: barTrack
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 60
                height: 4
                color: Config.ThemeConfig.colors.border
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, row.net.signal / 100))
                    height: parent.height
                    color: row.net.inUse ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: row.net.signal + "%"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
            }
        }

        // Security
        Text {
            text: (row.net.security && row.net.security.length > 0) ? row.net.security : "open"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }

        // [×] disconnect — only visible when row is the active connection + hovering
        Text {
            visible: row.net.inUse && ma.containsMouse
            text: "[×]"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: "#ff5555"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    mouse.accepted = true
                    Services.NetworkControlService.disconnectWifi()
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MOUSE AREA — connect on click
    // -------------------------------------------------------------------------
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (row.net.inUse || row.connecting) return
            var sec = row.net.security || ""
            var isOpen = (sec === "" || sec === "--" || sec.toLowerCase() === "open")
            if (isOpen) {
                Services.NetworkControlService.connectWifi(row.net.ssid, "")
            } else {
                row.requestPassword(row.net.ssid)
            }
        }
    }
}
