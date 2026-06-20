// =============================================================================
// PowerMenuItem.qml — Power Menu Item Component
// =============================================================================
//
// Individual button for the power menu with hover effects and selection.
//
// =============================================================================

import QtQuick
import "../config" as Config

Rectangle {
    id: root

    property string iconText: ""
    property string labelText: ""
    property int itemIndex: 0
    property int selectedIndex: -1

    signal itemClicked()

    color: "transparent"
    radius: 0

    readonly property bool isHovered: mouseArea.containsMouse
    readonly property bool isSelected: itemIndex === selectedIndex

    // Active/hover state
    Rectangle {
        anchors.fill: parent
        color: root.isSelected ? Qt.rgba(0, 0.87, 0.9, 0.15) : "transparent"
        border.color: root.isSelected ? Config.BarConfig.colorAccent : "transparent"
        border.width: root.isSelected ? 1 : 0

        Behavior on color { ColorAnimation { duration: 80 } }
        Behavior on border.color { ColorAnimation { duration: 80 } }
    }

    // Icon + Text
    Row {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: 12

        Item {
            width: 24
            height: 24

            Text {
                anchors.centerIn: parent
                text: root.iconText
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: root.isSelected ? Config.BarConfig.colorAccent : "#ffffff"

                Behavior on color { ColorAnimation { duration: 80 } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.labelText.toUpperCase()
            font.family: "JetBrains Mono"
            font.pixelSize: 11
            font.letterSpacing: 1.5
            color: root.isSelected ? Config.BarConfig.colorAccent : "#e0e0e0"

            Behavior on color { ColorAnimation { duration: 80 } }
        }

        Item { width: 1; height: 1 }
    }

    // Mouse interaction
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.itemClicked()
        }

        onEntered: {
            if (selectedIndex !== itemIndex) {
                selectedIndex = itemIndex
            }
        }
    }
}
