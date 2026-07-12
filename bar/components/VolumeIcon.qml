// VolumeIcon.qml — tray glyph; emits trayRequested on click + scroll adjusts volume.
// The shared TrayCard (in shell.qml) shows the volume slider.
import QtQuick
import "../services" as Services
import "../config" as Config

Item {
    id: root
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.barHeight

    property bool isActive: false
    signal trayRequested()

    Text {
        anchors.centerIn: parent
        text: Services.AudioService.muted ? "󰝟"
              : (Services.AudioService.volume > 50 ? "󰕾" : "󰕿")
        font.family: Config.BarConfig.fontNerd
        font.pixelSize: Config.BarConfig.fontSizeIcon
        color: root.isActive ? Config.BarConfig.colorAccent : Config.BarConfig.colorText
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.trayRequested()
    }

    // Scroll to change volume even when the card is closed.
    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y > 0) Services.AudioService.volumeUp()
            else Services.AudioService.volumeDown()
        }
    }
}
