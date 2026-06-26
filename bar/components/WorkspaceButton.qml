// =============================================================================
// WorkspaceButton.qml — Single workspace button
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: button

    property int workspaceId: 1
    property bool isActive: false
    property bool isOccupied: false
    property bool isHovered: false

    signal clicked()

    width: 24
    height: 24
    radius: 4
    color: isHovered ? "#111111" : "transparent"

    // Active highlight
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: isActive ? Config.BarConfig.colorAccent : "transparent"
        opacity: isActive ? 0.3 : 1.0
    }

    // Workspace number
    Text {
        anchors.centerIn: parent
        text: button.workspaceId
        color: isActive ? Config.BarConfig.colorText : isOccupied ? Config.BarConfig.colorText : Config.BarConfig.colorTextDim
        font.pixelSize: 11
        font.family: "JetBrains Mono, monospace"
    }

    // Hover
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: button.clicked()
        onEntered: button.isHovered = true
        onExited: button.isHovered = false
    }
}
