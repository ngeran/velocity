// =============================================================================
// ControlDashboard.qml — top-level layout of the terminal command dashboard
// =============================================================================
//
// Owns `activeSection` (network | bluetooth | audio | system). Anchor-based
// frame: AppBar (top), CommandInputBar (bottom), SideNav (left), content area
// = StatusCardRow + TerminalBody. ScanlineOverlay sits above everything.
//
// shell.qml's ControlWindow.open(section) writes activeSection; SideNav writes
// it on click. Section content swaps inside TerminalBody.
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    id: root
    property string activeSection: "network"

    onActiveSectionChanged: {
        // Nudge the active section's service to refresh (no-ops until phases 3-5).
        if (activeSection === "network")   Services.NetworkControlService.refreshStatus()
        else if (activeSection === "audio") {}   // AudioControlService polls on its own
    }

    Rectangle {
        id: baseBg
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
    }

    AppBar {
        id: appBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.ControlConfig.appbarHeight
    }

    CommandInputBar {
        id: commandBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.ControlConfig.commandBarHeight
    }

    SideNav {
        id: sideNav
        anchors.top: appBar.bottom
        anchors.bottom: commandBar.top
        anchors.left: parent.left
        width: Config.ControlConfig.sidenavWidth
        activeSection: root.activeSection
        onSectionSelected: function(key) { root.activeSection = key }
    }

    StatusCardRow {
        id: statusRow
        anchors.top: appBar.bottom
        anchors.left: sideNav.right
        anchors.right: parent.right
        anchors.topMargin: Config.ControlConfig.padding
        anchors.leftMargin: Config.ControlConfig.padding
        anchors.rightMargin: Config.ControlConfig.padding
        height: Config.ControlConfig.statusCardHeight
    }

    TerminalBody {
        id: terminalBody
        anchors.top: statusRow.bottom
        anchors.bottom: commandBar.top
        anchors.left: sideNav.right
        anchors.right: parent.right
        anchors.topMargin: Config.ControlConfig.padding
        anchors.leftMargin: Config.ControlConfig.padding
        anchors.rightMargin: Config.ControlConfig.padding
        anchors.bottomMargin: Config.ControlConfig.padding
        activeSection: root.activeSection
    }

    ScanlineOverlay {
        anchors.fill: parent
        z: 1000
    }
}
