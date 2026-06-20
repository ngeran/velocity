// =============================================================================
// WorkspaceWidget.qml — Workspace indicator (dot style)
// =============================================================================
//
// Displays workspaces as interactive dots. Active workspace is shown as
// a wider teal dot, inactive workspaces are smaller gray dots.
//
// INTERACTION
//   Click on any dot to switch to that workspace
//
// IMPLEMENTATION
//   - Uses HyprlandService for current workspace state
//   - Animates width and color changes
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../services" as Services
import "../config" as Config

Row {
    id: widget
    spacing: Config.BarConfig.iconSpacing

    // =========================================================================
    // STATE
    // =========================================================================

    property int activeWorkspace: Services.HyprlandService.activeWorkspace

    // =========================================================================
    // WORKSPACE DOTS
    // =========================================================================

    Repeater {
        model: Config.BarConfig.workspaceCount

        Item {
            width: (index + 1) === widget.activeWorkspace
                ? Config.BarConfig.workspaceDotWidthActive + 4
                : Config.BarConfig.workspaceDotWidth + 4
            height: Config.BarConfig.workspaceDotHeight + 4
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: (index + 1) === widget.activeWorkspace
                    ? Config.BarConfig.workspaceDotWidthActive
                    : Config.BarConfig.workspaceDotWidth
                height: Config.BarConfig.workspaceDotHeight
                radius: height / 2
                color: (index + 1) === widget.activeWorkspace
                    ? Config.BarConfig.colorAccent
                    : Qt.darker(Config.BarConfig.colorAccent, 1.5)

                // Smooth transitions
                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            // Click to switch workspace
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    console.log("[WorkspaceWidget] Clicked workspace:", index + 1)
                    Services.HyprlandService.switchTo(index + 1)
                }
            }
        }
    }
}
