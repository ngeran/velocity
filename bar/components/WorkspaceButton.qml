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

    width: Config.BarConfig.workspaceButtonSize
    height: Config.BarConfig.workspaceButtonSize
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
        font.pixelSize: Config.BarConfig.workspaceButtonFontSize
        font.family: Config.BarConfig.fontFamily
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
