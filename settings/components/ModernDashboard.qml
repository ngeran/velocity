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

    // Core-tab deep-link: IPC openCore(section) sets these; the Core wrapper
    // consumes them on its next entry, so a plain Core click lands on SYSTEM.
    property string coreActiveSection: "system"
    property bool coreDeepLink: false

    // ── SEARCH — palette navigation funnel ────────────────────────────────
    // Rows self-register in SearchIndex (see the service); picking a result
    // lands here: switch to the entry's tab + sub-section, then flash the
    // row once the tab-slide settles. (Fixed panes don't scroll — showing
    // the pane IS showing the row, §6.1.)
    //
    // Search IPC bridge — the handlers LIVE in shell.qml (check-ipc extracts
    // declared IPC only from the shell roots; see ipc-surface.txt) but must
    // run against THIS file's SearchIndex instance: "../services" vs
    // shell.qml's "services" is two singletons (the SharedState trap above).
    // shell.qml calls these through.
    Component.onCompleted: Services.SearchIndex.activated.connect(root._navigate)

    function searchIpcQuery(q) {
        var hits = Services.SearchIndex.search(q)
        var out = []
        for (var i = 0; i < hits.length; i++)
            out.push({ title: hits[i].title, tab: hits[i].tab, section: hits[i].section })
        return JSON.stringify(out)
    }

    function searchIpcOpen(q) {
        searchPalette.openPalette()
        paletteInput.text = q
    }

    function searchIpcList() {
        return "entries=" + Services.SearchIndex.entries.length + " " +
               JSON.stringify(Services.SearchIndex.entries.map(function(e) {
                   return { title: e.title, tab: e.tab, section: e.section }
               }))
    }

    function _navigate(entry) {
        var tab = String(entry.tab || "")
        if (tab === "settings") {
            root.openSettingsTab()
            if (entry.section !== undefined && entry.section !== "")
                settingsModule.active = entry.section
        } else if (tab === "control") {
            root.openControlTab(entry.section || "network")
        } else if (tab === "core") {
            root.openCoreTab(entry.section || "system")
        } else if (tab === "theme") {
            root.openThemeTab()
        }
        if (entry.item) {
            flashTimer.target = entry.item
            flashTimer.restart()
        }
    }

    function _flashItem(item) {
        if (!item) return
        var p = item.mapToItem(root, 0, 0)
        rowFlash.x = p.x - 5
        rowFlash.y = p.y - 5
        rowFlash.width = item.width + 10
        rowFlash.height = item.height + 10
        rowFlash.visible = true
        flashAnim.restart()
    }

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
        root.coreActiveSection = section || "system"
        root.coreDeepLink = true
    }

    function openSettingsTab() {
        for (var i = 0; i < navBar.tabModel.length; i++) {
            if (navBar.tabModel[i].key === "settings") { root.currentTab = i; break }
        }
    }

    function openThemeTab() {
        for (var i = 0; i < navBar.tabModel.length; i++) {
            if (navBar.tabModel[i].key === "theme") { root.currentTab = i; break }
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
        onSearchRequested: searchPalette.openPalette()
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
                id: settingsModule
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
                    id: coreTab
                    anchors.fill: parent
                    // Entering Core always lands on SYSTEM. An IPC openCore()
                    // deep-link overrides that entry exactly once (fires on the
                    // visible transition, so it also works at creation time).
                    onVisibleChanged: {
                        if (!visible) return
                        if (root.coreDeepLink) {
                            coreTab.active = root.coreActiveSection
                            root.coreDeepLink = false
                        } else {
                            coreTab.active = "system"
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // SEARCH PALETTE — opened from the sidebar magnifier chip. Input + ranked
    // results over the content; Esc / click-away closes, arrows + Enter run it
    // keyboard-first. Results come from SearchIndex (rows self-registered).
    // =========================================================================

    // click-away layer (under the palette, over everything else)
    MouseArea {
        anchors.fill: parent
        z: 39
        enabled: searchPalette.open
        visible: searchPalette.open
        onClicked: searchPalette.closePalette()
    }

    Rectangle {
        id: searchPalette
        property bool open: false
        property var results: []
        property int activeIndex: 0

        function openPalette() {
            open = true
            results = []
            activeIndex = 0
            paletteInput.text = ""
            paletteInput.forceActiveFocus()
        }
        function closePalette() {
            open = false
            paletteInput.focus = false
        }
        function refresh() {
            results = Services.SearchIndex.search(paletteInput.text)
            activeIndex = 0
        }
        function activateIndex(i) {
            if (i < 0 || i >= results.length) return
            var e = results[i]
            closePalette()
            Services.SearchIndex.activate(e)
        }

        z: 40
        anchors.top: parent.top
        anchors.topMargin: 84   // just under the 72px shared header
        anchors.horizontalCenter: parent.horizontalCenter
        width: 440
        height: open ? 47 + Math.min(results.length, 8) * 34 : 0
        visible: open
        color: Config.ThemeConfig.colors.background
        border.color: paletteInput.activeFocus ? Config.ThemeConfig.colors.secondary
                                               : Config.ThemeConfig.colors.border
        border.width: 1
        radius: Config.SettingsConfig.radiusMd
        Behavior on height { NumberAnimation { duration: 80 } }

        ColumnLayout {
            id: paletteBody
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            // ---- input row ----
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 46

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"
                    font.family: Config.ControlConfig.fontNerd
                    font.pixelSize: 14
                    color: Config.ThemeConfig.colors.textDim
                }
                TextInput {
                    id: paletteInput
                    anchors.left: parent.left
                    anchors.leftMargin: 40
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Config.ThemeConfig.colors.text
                    font.family: Config.SettingsConfig.fontFamily
                    font.pixelSize: 14
                    selectByMouse: true
                    clip: true
                    onTextChanged: searchPalette.refresh()
                    Keys.onEscapePressed: searchPalette.closePalette()
                    Keys.onDownPressed: searchPalette.activeIndex =
                        Math.min(searchPalette.activeIndex + 1, searchPalette.results.length - 1)
                    Keys.onUpPressed: searchPalette.activeIndex =
                        Math.max(searchPalette.activeIndex - 1, 0)
                    Keys.onReturnPressed: searchPalette.activateIndex(searchPalette.activeIndex)

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: paletteInput.text === ""
                        text: "search settings…"
                        color: Config.ThemeConfig.colors.textDim
                        font.family: Config.SettingsConfig.fontFamily
                        font.pixelSize: 14
                        opacity: 0.55
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Config.ThemeConfig.colors.border
                visible: searchPalette.results.length > 0
            }

            // ---- results ----
            Repeater {
                model: searchPalette.open ? searchPalette.results.slice(0, 8) : []

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    color: index === searchPalette.activeIndex
                           ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.10)
                           : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: modelData.title
                            color: Config.ThemeConfig.colors.text
                            font.family: Config.SettingsConfig.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: String(modelData.tab).toUpperCase() +
                                  (modelData.section !== "" ? " · " + String(modelData.section).toUpperCase() : "")
                            color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                    }

                    MouseArea {
                        id: resultArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: searchPalette.activeIndex = index
                        onClicked: searchPalette.activateIndex(index)
                    }
                }
            }
        }
    }

    // ---- row highlight flash (search navigation lands here) ----
    Timer {
        id: flashTimer
        interval: Config.SettingsConfig.animDurationNormal + 170   // tab slide settles
        property var target: null
        onTriggered: root._flashItem(target)
    }
    Rectangle {
        id: rowFlash
        z: 50
        visible: false
        opacity: 0
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.10)
        border.color: Config.ThemeConfig.colors.secondary
        border.width: 2
        radius: 6
        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: rowFlash; property: "opacity"; to: 1; duration: 90 }
            PauseAnimation { duration: 620 }
            NumberAnimation { target: rowFlash; property: "opacity"; to: 0; duration: 260 }
            onStopped: rowFlash.visible = false
        }
    }
}
