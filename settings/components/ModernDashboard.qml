// =============================================================================
// settings/components/ModernDashboard.qml
// Bento Grid Dashboard — Main Layout Orchestrator (Obsidian Vertical Edition)
// =============================================================================
//
// TAB ORDER (index-significant):
//   0 Dashboard | 1 Themes | 2 Wallpapers | 3 Control | 4 Core | 5 Settings
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

    // Window-visibility funnel (injected from shell.qml). CRITICAL: this file,
    // like every service, imports "../config", while shell.qml imports "config"
    // — different import URIs, which Quickshell treats as separate singleton
    // instances. shell.qml's own `SharedState.dashboardVisible = shown` write
    // therefore never reached the services' poll-timer gates and all
    // dashboard-gated polling silently never ran. Writing the value from HERE
    // (property injection, Omarchy's fix for the same relative-import trap)
    // puts it on the instance the services actually read.
    property bool windowShown: false
    onWindowShownChanged: Config.SharedState.dashboardVisible = windowShown

    // Persisted Core-tab sub-section (processors/gpu/memoryenv/lcd). The Core
    // tab is lazy-loaded (destroyed when the panel hides), so without this its
    // `active` selection would reset to "processors" on every reopen.
    property string coreActiveSection: "processors"

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

    function openCoreTab(section) {
        var idx = -1
        for (var i = 0; i < navBar.tabModel.length; i++) {
            if (navBar.tabModel[i].key === "core") { idx = i; break }
        }
        if (idx >= 0) root.currentTab = idx
        root.coreActiveSection = section || "processors"
    }

    function openSettingsTab() {
        for (var i = 0; i < navBar.tabModel.length; i++) {
            if (navBar.tabModel[i].key === "settings") { root.currentTab = i; break }
        }
    }

    // =========================================================================
    // BACKGROUND
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        radius: Config.SettingsConfig.radiusMd
        // No-op MouseArea: stops clicks on empty card areas from falling through
        // to the shell.qml dim backdrop (which would close the window).
        MouseArea { anchors.fill: parent }
    }

    // =========================================================================
    // SIDEBAR NAVIGATION (was a horizontal TopNavBar across the top; the
    // control-console mockup calls for a 64px vertical sidebar instead)
    // =========================================================================

    Components.SidebarNav {
        id: navBar
        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
        }
        currentIndex: root.currentTab
        onTabSelected: function(index) {
            root.currentTab = index
        }
    }

    // =========================================================================
    // SHARED HEADER — Clock + Identity, spans every tab (not just Dashboard)
    // =========================================================================

    Components.Header {
        id: dashboardHeader
        anchors {
            top: parent.top
            left: navBar.right
            right: parent.right
        }
        height: 72
    }

    // =========================================================================
    // MAIN CONTENT AREA — below the shared header, right of the sidebar
    // =========================================================================

    Item {
        id: contentArea
        anchors {
            top: dashboardHeader.bottom
            left: navBar.right
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

            // Dashboard → tab deep-links (Theme Switcher CHANGE, footer CONFIG)
            onRequestTab: function(index) { root.currentTab = index }

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
        // TAB 5: SETTINGS (rail + fixed panes — SettingsModule; same
        // architecture as Control/Core. Extracted from the former inline
        // scrolling block. Settings are managed by SettingsConfigService /
        // HypridleService and persisted on every change.)
        // =====================================================================

        Item {
            id: settingsTab

            visible: root.currentTab === 5
            opacity: root.currentTab === 5 ? 1.0 : 0.0
            x: root.currentTab === 5 ? 0 : 20
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

            Components.SettingsModule {
                anchors.fill: parent
            }
        }

        // =====================================================================
        // TAB 4: CORE ENGINE (OLED telemetry dashboard + LCD control)
        // =====================================================================
        // Lazy-loaded: the Core tab binds to always-on telemetry (CoreEngine 1s,
        // ThermalService, GpuService) through dozens of Text bindings that would
        // re-evaluate every second even while the panel is closed. Gating the
        // Loader on SharedState.dashboardVisible destroys the whole subtree when
        // the panel is hidden, eliminating that steady-state churn. While open
        // the tab persists, so the opacity/x slide animation still works.
        // (coreEngineTab had an unreferenced id — dropped.)

        Loader {
            anchors.fill: parent
            active: Config.SharedState.dashboardVisible

            visible: root.currentTab === 4
            opacity: root.currentTab === 4 ? 1.0 : 0.0
            x: root.currentTab === 4 ? 0 : (root.currentTab < 4 ? 20 : -20)

            Behavior on opacity {
                NumberAnimation { duration: Config.SettingsConfig.animDurationNormal; easing.type: Easing.OutCubic }
            }
            Behavior on x {
                NumberAnimation { duration: Config.SettingsConfig.animDurationNormal; easing.type: Easing.OutCubic }
            }

            sourceComponent: Component {
                Components.CoreEngineTab {
                    anchors.fill: parent
                    // Restore the persisted sub-section (the tab is recreated on
                    // each reopen) and keep it in sync as the user navigates.
                    Component.onCompleted: active = root.coreActiveSection
                    onActiveChanged: root.coreActiveSection = active
                }
            }
        }
    }
}
