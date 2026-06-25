// =============================================================================
// settings/components/ModernDashboard.qml
// Bento Grid Dashboard — Main Layout Orchestrator (Obsidian Vertical Edition)
// =============================================================================
//
// TAB ORDER (index-significant):
//   0 Dashboard | 1 Themes | 2 Wallpapers | 3 Control | 4 Settings
// (Control and Settings were swapped to match user request.)
//
// PURPOSE:
//   Main container for all tabs. Delegates tab-0 (Dashboard) to
//   DashboardOverviewTab (bento grid layout), other tabs to their
//   respective modules (ThemeModule, WallpaperModule, ControlModule, Settings).
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "." as Components
import "../config" as Config
import "../services" as Services

Item {
    id: root

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    property int currentTab: 0

    // =========================================================================
    // PUBLIC FUNCTIONS
    // =========================================================================

    // Open the Control tab and switch to a specific sub-section
    function openControlTab(section) {
        // Find Control by KEY, not hardcoded index — survives future reorders.
        var idx = -1
        for (var i = 0; i < navBar.tabModel.length; i++) {
            if (navBar.tabModel[i].key === "control") { idx = i; break }
        }
        if (idx >= 0) root.currentTab = idx
        controlModule.activeSection = section
    }

    // =========================================================================
    // BACKGROUND
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        radius: 0
    }

    // =========================================================================
    // TOP NAVIGATION HEADER
    // =========================================================================

    Components.TopNavBar {
        id: navBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: parent.height * (1.0 / 12.0)
        currentIndex: root.currentTab
        onTabSelected: function(index) {
            root.currentTab = index
        }
    }

    // =========================================================================
    // MAIN CONTENT AREA
    // =========================================================================

    Item {
        id: contentArea
        anchors {
            top: navBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        // =====================================================================
        // TAB 0: DASHBOARD OVERVIEW
        // =====================================================================

        Components.DashboardOverviewTab {
            id: overviewTab
            visible: root.currentTab === 0
            anchors.fill: parent
        }

        // =====================================================================
        // TAB 1: THEME SELECTION
        // =====================================================================

        Components.ThemeModule {
            id: themeTab
            visible: root.currentTab === 1
            anchors.fill: parent
            anchors.margins: 24
        }

        // =====================================================================
        // TAB 2: WALLPAPER MANAGEMENT
        // =====================================================================

        Components.WallpaperModule {
            id: wallpaperTab
            visible: root.currentTab === 2
            anchors.fill: parent
        }

        // =====================================================================
        // TAB 3: CONTROL MODULE
        // =====================================================================

        Components.ControlModule {
            id: controlModule
            visible: root.currentTab === 3
            anchors.fill: parent

            // Expose activeSection for IPC deep-link
            property alias activeSection: controlModule.activeSection
        }

        // =====================================================================
        // TAB 4: SETTINGS
        // =====================================================================

        Item {
            id: settingsTab
            visible: root.currentTab === 4
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 24

                // Header
                Text {
                    text: "QUICK SETTINGS"
                    font.pixelSize: 11
                    font.family: "JetBrains Mono"
                    font.letterSpacing: 2.5
                    font.weight: Font.Bold
                    color: Config.ThemeConfig.colors.textDim
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Config.ThemeConfig.colors.border
                }

                // Settings content placeholder
                Text {
                    text: "Settings panel content will be added here."
                    font.pixelSize: 12
                    font.family: "Inter"
                    color: Config.ThemeConfig.colors.textDim
                }
            }
        }
    }
}
