// =============================================================================
// WorkspaceButton.qml — Single workspace button
// =============================================================================

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: button

    property int workspaceId: 1
    property bool isActive: false
    property bool isOccupied: false

    signal clicked()

    width: 24
    height: 24
    radius: 4
    color: "transparent"

    // Active highlight
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: isActive ? "#00dce5" : "transparent"
        opacity: isActive ? 0.3 : 1.0
    }

    // Workspace number
    Text {
        anchors.centerIn: parent
        text: button.workspaceId
        color: isActive ? "#ffffff" : isOccupied ? "#e0e0e0" : "#4a4a4a"
        font.pixelSize: 11
        font.family: "JetBrains Mono, monospace"
    }

    // Hover
    MouseArea {
        anchors.fill: parent
        onClicked: button.clicked()
        hoverEnabled: true
        onEntered: button.color = "#111111"
        onExited: button.color = "transparent"
    }
}
