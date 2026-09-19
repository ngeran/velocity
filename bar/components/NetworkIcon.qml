// NetworkIcon.qml — network glyph; hover reveals "NET"; click opens the tray.
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
            text: !Services.NetworkService.isConnected ? "󰖪"
                  : (Services.NetworkService.connectionType === "wifi" ? "󰖩" : "󰈀")
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.BarConfig.fontSizeIcon
            color: (mouseArea.containsMouse || root.isActive) ? Config.ThemeConfig.colors.accent : Config.BarConfig.colorText
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
        }
        Text {
            visible: root.expanded
            // Hover reveals the LIVE IP when connected (mockup), else state
            text: Services.NetworkService.isConnected
                  ? (Services.NetworkService.ipAddress !== "" ? Services.NetworkService.ipAddress : "NET")
                  : "OFFLINE"
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
}
