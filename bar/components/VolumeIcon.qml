// VolumeIcon.qml — volume glyph; hover reveals "VOL n%"; click opens the tray.
// Scroll adjusts volume even when the card is closed (OSD feedback kept).
import QtQuick
import "../services" as Services
import "../config" as Config

Item {
    id: root
    implicitWidth: iconRow.implicitWidth
        height: Config.BarConfig.barHeight
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration: Config.MotionConfig.move; easing.type: Config.MotionConfig.ease } }

    property bool isActive: false
    signal trayRequested()

    readonly property bool expanded: mouseArea.containsMouse

    Row {
        id: iconRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.expanded ? 6 : 0

        Text {
            text: Services.AudioService.muted ? "󰝟"
                  : (Services.AudioService.volume > 50 ? "󰕾" : "󰕿")
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.BarConfig.fontSizeIcon
            color: (mouseArea.containsMouse || root.isActive) ? Config.ThemeConfig.colors.accent : Config.BarConfig.colorText
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
        }
        Text {
            visible: root.expanded
            text: Services.AudioService.muted ? "MUTED"
                  : "VOL " + Math.round(Services.AudioService.volume) + "%"
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: 11
            color: Config.ThemeConfig.colors.text
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.trayRequested()
    }

    // Scroll to change volume even when the card is closed.
    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y > 0) Services.AudioService.volumeUp()
            else Services.AudioService.volumeDown()
            Services.OsdService.showVolume(Services.AudioService.volume, Services.AudioService.muted)
        }
    }
}
