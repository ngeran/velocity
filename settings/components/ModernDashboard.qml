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

            // Animate opacity and position on tab change
            visible: root.currentTab === 0
            opacity: root.currentTab === 0 ? 1.0 : 0.0
            x: root.currentTab === 0 ? 0 : -20
            anchors.fill: parent

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        // =====================================================================
        // TAB 1: THEME SELECTION
        // =====================================================================

        Components.ThemeModule {
            id: themeTab

            visible: root.currentTab === 1
            opacity: root.currentTab === 1 ? 1.0 : 0.0
            x: root.currentTab === 1 ? 0 : (root.currentTab < 1 ? 20 : -20)
            anchors.fill: parent
            anchors.margins: 24

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        // =====================================================================
        // TAB 2: WALLPAPER MANAGEMENT
        // =====================================================================

        Components.WallpaperModule {
            id: wallpaperTab

            visible: root.currentTab === 2
            opacity: root.currentTab === 2 ? 1.0 : 0.0
            x: root.currentTab === 2 ? 0 : (root.currentTab < 2 ? 20 : -20)
            anchors.fill: parent

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        // =====================================================================
        // TAB 3: CONTROL MODULE
        // =====================================================================

        Components.ControlModule {
            id: controlModule

            visible: root.currentTab === 3
            opacity: root.currentTab === 3 ? 1.0 : 0.0
            x: root.currentTab === 3 ? 0 : (root.currentTab < 3 ? 20 : -20)
            anchors.fill: parent

            // Expose activeSection for IPC deep-link
            property alias activeSection: controlModule.activeSection

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        // =====================================================================
        // TAB 4: SETTINGS
        // =====================================================================

        Item {
            id: settingsTab

            visible: root.currentTab === 4
            opacity: root.currentTab === 4 ? 1.0 : 0.0
            x: root.currentTab === 4 ? 0 : 20
            anchors.fill: parent

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            // Settings content with proper layout
            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 24

                // Header
                Text {
                    text: "QUICK SETTINGS"
                    font.pixelSize: 11
                    font.family: Config.SettingsConfig.fontFamily
                    font.letterSpacing: 2.5
                    font.weight: Font.Bold
                    color: Config.ThemeConfig.colors.textDim
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Config.ThemeConfig.colors.border
                }

                // Settings content
                Item {
                    width: parent.width
                    height: parent.height - 50

                    Text {
                        anchors.centerIn: parent
                        text: "Settings panel content will be added here."
                        font.pixelSize: 12
                        font.family: Config.SettingsConfig.fontFamily
                        color: Config.ThemeConfig.colors.textDim
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
