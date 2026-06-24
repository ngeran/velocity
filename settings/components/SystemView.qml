// =============================================================================
// SystemView.qml — dedicated event/error log for the SYSTEM section
// =============================================================================
// All actions (connect, pair, set-sink, …) and their success/error lines are
// pushed to CommandService.logLines. This is the ONLY place they render, so the
// network / bluetooth / audio screens stay clean.
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 4

    Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: "// network / bluetooth / audio actions & errors are logged here"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 10
        color: Config.ThemeConfig.colors.textDim
    }

    // header row with a CLEAR button
    Item {
        width: parent.width
        height: 20

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "[ EVENT_LOG ]"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1
            color: Config.ControlConfig.accent
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            height: 18
            radius: Config.ControlConfig.radius
            color: clearMa.containsMouse ? Config.ControlConfig.accentSoft : "transparent"
            border.color: Config.ThemeConfig.colors.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "CLEAR"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9
                font.bold: true
                color: Config.ThemeConfig.colors.textDim
            }

            MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.CommandService.clear()
            }
        }
    }

    Repeater {
        model: Services.CommandService.logLines
        delegate: TerminalLogLine {
            width: view.width
            text: model.text
            kind: model.kind
        }
    }

    Text {
        visible: Services.CommandService.logLines.count === 0
        text: "// log is empty"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
    }
}
