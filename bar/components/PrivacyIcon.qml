// PrivacyIcon.qml — privacy pill; visible ONLY while something is active.
// Zero-width when idle (the rail collapses the slot margin for empty slots —
// "nothing on the bar that isn't clickable or working"). Click opens the
// privacy tray body in the shared TrayCard, same contract as NetworkIcon.
import QtQuick
import Quickshell.Services.Pipewire
import "../config" as Config
import "../services" as Services

Item {
    id: root

    readonly property bool active: Services.PrivacyService.hasActive
    property bool isActive: false          // tray body open
    signal trayRequested()

    visible: active
    implicitWidth: active ? iconRow.implicitWidth : 0
    height: Config.BarConfig.barHeight
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    readonly property bool expanded: mouseArea.containsMouse

    Row {
        id: iconRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.expanded ? 6 : 3

        Text {
            text: "󰍍"
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.BarConfig.fontSizeIcon
            color: (mouseArea.containsMouse || root.isActive)
                   ? Config.ThemeConfig.colors.accent : Config.ThemeConfig.colors.primary
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // One red dot per active KIND — mic / camera / screen.
        Row {
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: root.active ? [
                    Services.PrivacyService.appsFor("mic").length > 0,
                    Services.PrivacyService.appsFor("camera").length > 0,
                    Services.PrivacyService.appsFor("screen").length > 0
                ] : []

                Rectangle {
                    required property bool modelData
                    visible: modelData
                    width: 4; height: 4; radius: 2
                    color: Config.ThemeConfig.colors.error
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Text {
            visible: root.expanded
            text: "PRIVACY"
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
