// =============================================================================
// Dropdown.qml — compact styled select: closed shows the current value; open
// shows an option list card below. Emits selected(value). Theme-aware.
// =============================================================================
import QtQuick
import "../config" as Config

Item {
    id: root

    property string label: ""
    property var options: []            // [{ label, value }]
    property string value: ""
    property bool open: false
    property int listWidth: 0           // 0 = match the control width

    signal selected(var value)

    implicitWidth: 180
    implicitHeight: 26

    Rectangle {
        id: control
        anchors.fill: parent
        radius: Config.ControlConfig.radiusSmall
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.7)
        border.color: root.open || controlMa.containsMouse
                      ? Config.ThemeConfig.colors.accent : Config.ThemeConfig.colors.outlineVariant
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 100 } }

        Text {
            anchors.left: parent.left; anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.value !== "" ? root.value : (root.label || "—")
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: 10
            font.bold: root.value !== ""
            color: root.value !== "" ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
        }

        Text {
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.open ? "▲" : "▼"
            font.pixelSize: 8
            color: Config.ThemeConfig.colors.textDim
        }

        MouseArea {
            id: controlMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    // Option list card
    Rectangle {
        id: listCard
        visible: root.open
        anchors.top: control.bottom
        anchors.topMargin: 4
        anchors.left: control.left
        anchors.right: control.right
        height: Math.min(listCol.implicitHeight + 8, 220)
        radius: Config.ControlConfig.radiusSmall
        color: Config.ThemeConfig.colors.background
        border.color: Config.ThemeConfig.colors.accent
        border.width: 1
        z: 100

        Column {
            id: listCol
            anchors.fill: parent
            anchors.margins: 4
            spacing: 1

            Repeater {
                model: root.options

                Rectangle {
                    required property var modelData
                    width: parent ? parent.width : 0
                    height: 20
                    radius: Config.ControlConfig.radiusSmall
                    color: optMa.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.accent, 0.14) : "transparent"

                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: 10
                        color: Config.ThemeConfig.colors.text
                    }
                    MouseArea {
                        id: optMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.open = false
                            root.selected(modelData.value)
                        }
                    }
                }
            }
        }
    }
}
