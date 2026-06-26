// =============================================================================
// CommandInputBar.qml — ❯ prompt + text input + Execute button
// =============================================================================
//
// Enter or Execute dispatches the typed line to CommandService.executeCommand,
// then clears the field. Uses the TextInput's native cursor.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: bar
    color: Config.ThemeConfig.colors.background

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Config.ThemeConfig.colors.border
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "❯"
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 16
            font.bold: true
            color: Config.ControlConfig.accent
        }

        Rectangle {
            id: field
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 30
            radius: Config.ControlConfig.radius
            color: Config.ThemeConfig.colors.surface
            border.width: 1
            border.color: input.activeFocus ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
            Behavior on border.color { ColorAnimation { duration: 120 } }

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 12
                color: Config.ThemeConfig.colors.text
                focus: true

                Text {
                    visible: input.text.length === 0
                    text: "enter command (type 'help')"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 12
                }

                onAccepted: {
                    Services.CommandService.executeCommand(input.text)
                    input.text = ""
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 72
            Layout.preferredHeight: 30
            radius: Config.ControlConfig.radius
            color: execMa.containsMouse ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.text
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "EXEC"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
                color: Config.ThemeConfig.colors.background
            }

            MouseArea {
                id: execMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Services.CommandService.executeCommand(input.text)
                    input.text = ""
                    input.forceActiveFocus()
                }
            }
        }
    }
}
