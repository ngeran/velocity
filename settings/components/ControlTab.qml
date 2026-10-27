// =============================================================================
// ControlTab.qml — top-level layout of the terminal command dashboard
// =============================================================================
//
// Owns `activeSection` (network | bluetooth | audio | display). Anchor-based
// frame: AppBar (top), CommandInputBar (bottom), ControlSectionNav (left), content area
// = StatusCardRow + TerminalBody. ScanlineOverlay sits above everything.
//
// shell.qml's ControlWindow.open(section) writes activeSection; ControlSectionNav writes
// it on click. Section content swaps inside TerminalBody.
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    id: root
    property string activeSection: "network"
    property var dash: null   // the SettingsWindowShell root — cross-tab jump links (H3)

    onActiveSectionChanged: {
        // Publish the active section so services can section-gate their polls
        // (NetworkControlService's wifi scans only run on the network section).
        Config.SharedState.controlSection = activeSection
        // Nudge the active section's service to refresh (no-ops until phases 3-5).
        if (activeSection === "network")   Services.NetworkControlService.refreshStatus()
        else if (activeSection === "audio") {}   // AudioControlService polls on its own
        else if (activeSection === "display") Services.MonitorService.refresh()
    }

    // The section INITIAL value ("network") is set at construction — no change
    // signal fires — so publish it here too, or the section-gated wifi polls
    // never start when the Control tab opens straight to the default section.
    // (The control:* search entries are seeded once in SettingsWindowShell's
    // _seedSearchCatalog — with O1's lazy tabs the index must be whole before
    // this tab is ever visited.)
    Component.onCompleted: {
        Config.SharedState.controlSection = root.activeSection
    }

    Rectangle {
        id: baseBg
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
    }

    ControlSectionNav {
        id: sideNav
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        // Compact breakpoint (<1440 logical) collapses the rail to icon-only.
        width: Config.UIScale.compact ? 56 : Config.ControlConfig.sidenavWidth
        activeSection: root.activeSection
        onSectionSelected: function(key) { root.activeSection = key }
    }

    TerminalBody {
        id: terminalBody
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: sideNav.right
        anchors.right: parent.right
        anchors.topMargin: Config.ControlConfig.padding
        anchors.leftMargin: Config.ControlConfig.padding
        anchors.rightMargin: Config.ControlConfig.padding
        anchors.bottomMargin: Config.ControlConfig.padding
        activeSection: root.activeSection
        dash: root.dash
    }
}
