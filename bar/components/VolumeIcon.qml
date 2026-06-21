// =============================================================================
// VolumeIcon.qml — Volume indicator with scroll control and shell-level hover popup
// =============================================================================

import QtQuick
import Quickshell.Io
import "../services" as Services
import "../config" as Config

Item {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize
    objectName: "volumeIcon"

    property bool muted: Services.AudioService.muted
    property int volume: Services.AudioService.volume
    property var shellRoot: null

    Component.onCompleted: {
        // Find ShellRoot by traversing up the parent hierarchy
        function findShellRoot(item) {
            if (!item) return null
            // Check if this item has the hoverPopupData property (ShellRoot marker)
            if (item.hoverPopupData !== undefined) return item
            if (item.parent) return findShellRoot(item.parent)
            return null
        }
        shellRoot = findShellRoot(icon.parent)
        if (!shellRoot) {
            console.log("[VolumeIcon] Could not find ShellRoot!")
        }
    }

    Text {
        anchors.centerIn: parent
        text: muted ? "󰝟" : "󰕾"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: mouseArea.containsMouse ? Config.BarConfig.colorAccent : (muted ? Config.BarConfig.colorMuted : "#ffffff")

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
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

        onEntered: {
            if (icon.shellRoot) {
                // Get the icon's position relative to the shell (screen coordinates)
                var pos = icon.parent.mapToItem(icon.shellRoot, icon.x, icon.y)
                icon.shellRoot.hoverPopupData = {
                    visible: true,
                    text: "Volume",
                    subtext: muted ? "Muted" : volume + "%",
                    details: [
                        "Scroll to adjust",
                        "Click for wiremix"
                    ],
                    x: pos.x + icon.width/2 - 60,  // Center the popup horizontally
                    y: pos.y  // Icon's Y position (popup adds bar offset)
                }
            }
        }

        onExited: {
            if (icon.shellRoot) {
                icon.shellRoot.hoverPopupData.visible = false
            }
        }
    }

    Process {
        id: wiremixProc
        command: []
    }
}
