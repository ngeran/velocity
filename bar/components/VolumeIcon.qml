// =============================================================================
// VolumeIcon.qml — Volume indicator with scroll control
// =============================================================================
//
// Displays volume/mute state using Nerd Font icons.
//
// ICONS (nf-md-*)
//   "󰕾" - Volume unmuted (nf-md-volume_high)
//   "󰝟" - Volume muted (nf-md-volume_off)
//
// INTERACTION
//   Scroll wheel - Adjust volume up/down
//   Click - Launch wiremix audio TUI
// =============================================================================

import QtQuick
import Quickshell.Io
import "../services" as Services
import "../config" as Config

Item {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize

    property bool muted: Services.AudioService.muted

    Text {
        anchors.centerIn: parent
        text: muted ? "󰝟" : "󰕾"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : (muted ? Config.BarConfig.colorMuted : "#ffffff")
        opacity: 1.0
        visible: true

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Component.onCompleted: {
            console.log("[VolumeIcon] text:", text, "muted:", muted)
        }

        WheelHandler {
            onWheel: function(event) {
                if (event.angleDelta.y > 0) {
                    Services.AudioService.volumeUp()
                } else {
                    Services.AudioService.volumeDown()
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                wiremixProc.command = ["kitty", "--class=wiremix-float", "wiremix"]
                wiremixProc.running = true
            }
        }
    }

    Process {
        id: wiremixProc
        command: []
    }
}
