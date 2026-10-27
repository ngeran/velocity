// =============================================================================
// settings/components/ModernDashboard.qml
// Bento Grid Dashboard — Main Layout Orchestrator (Obsidian Vertical Edition)
// =============================================================================
//
// TAB ORDER (index-significant):
//   0 Dashboard | 1 Themes | 2 Wallpapers | 3 Control | 4 Core | 5 Logs | 6 Settings
//
// PURPOSE:
//   Main container for all tabs. Delegates tab-0 (Dashboard) to
//   DashboardOverviewTab (bento grid layout), other tabs to their
//   respective modules (ThemeModule, WallpaperModule, ControlDashboard, Settings).
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
    // Key of the visible tab ("dashboard" | "themes" | …) — read-only probe
    // for IPC/tests (SettingsWindow.activeTab); tabModel order is the truth.
    readonly property string currentTabKey: {
        var model = navBar.tabModel
        return (root.currentTab >= 0 && root.currentTab < model.length)
            ? String(model[root.currentTab].key) : ""
    }

    // O1 lazy tabs: every tab's Loader turns on at its FIRST visit and stays
    // on for the session (switching back must be instant, and module state —
    // drafts, scroll, selection — survives). Tab 0 is the landing tab, so it
    // starts visited. Deep links land here too: every open path assigns
    // currentTab, and the handler below marks it.
    property var visitedTabs: [true, false, false, false, false, false, false]
    onCurrentTabChanged: {
        if (currentTab < 0 || currentTab >= visitedTabs.length) return
        if (visitedTabs[currentTab]) return
        var v = visitedTabs.slice()
        v[currentTab] = true
        visitedTabs = v
    }

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

    Component.onCompleted: {
        Services.SearchIndex.activated.connect(root._navigate)
        root._seedSearchCatalog()
        root._bootWallpaperIpc()
    }

    // O1: the WALLPAPERS tab is lazy, but WallpaperService must still come up
    // at startup — its IpcHandler ("wallpaper-service": the QA/scripting
    // surface, getCount/getList/apply/…) registers only when the singleton
    // first instantiates, and the eager WallpaperModule used to be what
    // brought it up. A member READ forces the instantiation (a bare
    // `property var x: Services.WallpaperService` did NOT — verified live,
    // getCount stayed "Target not found"); the tab's Loader reuses the same
    // instance afterwards. (It MUST be touched from this "../services" import
    // scope: shell.qml's "services" URI is a different singleton instance,
    // and its handler would lose the duplicate-target registration.)
    function _bootWallpaperIpc() {
        var ipcTouch = Services.WallpaperService.wallpaperList
    }

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

    // Seed the keyed catalog entries once, here — NOT in the tab components.
    // With O1's lazy tabs a fresh open has no tab instances, so entries that
    // used to register from ControlDashboard/CoreEngineTab/LogsTab bodies
    // would be missing until each tab's first visit; the palette (and the
    // `search` IPC probes, which assert a minimum index size) need the whole
    // catalog up front. Keyed register() dedupe keeps this idempotent against
    // any future re-registration. Row-level entries (with `item` refs —
    // SettingsModule rows) still register per instance when their tab loads.
    function _seedSearchCatalog() {
        var S = Services.SearchIndex
        // Tab-level entry points. Dashboard/themes/wallpapers had NO search
        // presence before (their rows never self-registered) — with the lazy
        // tabs they are the only way a query lands on them at all.
        S.register({ key: "tab:dashboard",  title: "Dashboard Overview", tab: "dashboard",  section: "", keywords: "home bento", item: null })
        S.register({ key: "tab:themes",     title: "Theme Switcher",    tab: "themes",     section: "", keywords: "theme color palette", item: null })
        S.register({ key: "tab:wallpapers", title: "Wallpapers",        tab: "wallpapers", section: "", keywords: "wallpaper library cycling", item: null })
        S.register({ key: "tab:control",    title: "Control",           tab: "control",    section: "", keywords: "control console", item: null })
        S.register({ key: "tab:core",       title: "Core",              tab: "core",       section: "", keywords: "core engine telemetry oled", item: null })
        S.register({ key: "tab:settings",   title: "Settings",          tab: "settings",   section: "", keywords: "preferences options", item: null })
        // Section-level entries (was: registered inside the tab bodies).
        var secs = Config.ControlConfig.sections
        for (var i = 0; i < secs.length; i++)
            S.register({ key: "control:" + secs[i].key,
                title: secs[i].label, tab: "control",
                section: secs[i].key, keywords: "control section", item: null })
        var core = Config.ControlConfig.coreSections
        for (i = 0; i < core.length; i++)
            S.register({ key: "core:" + core[i].key,
                title: core[i].label, tab: "core",
                section: core[i].key, keywords: "core telemetry", item: null })
        S.register({ key: "logs-tab", title: "System Logs", tab: "logs", section: "" })
    }

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

    // End-to-end search probe: run the query and activate the first hit —
    // exercises navigation + scroll + flash without a mouse.
    function searchIpcActivateFirst(q) {
        var hits = Services.SearchIndex.search(q)
        if (hits.length === 0) return "no hits"
        searchPalette.openPalette()
        paletteInput.text = q
        searchPalette.activateIndex(0)
        return "activated: " + hits[0].title
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
            // settingsLoader.item: the O1 lazy tab may have been created by
            // the openSettingsTab() above (synchronous) — still, guard.
            if (settingsLoader.item) {
                if (entry.section !== undefined && entry.section !== "")
                    settingsLoader.item.active = entry.section
                settingsLoader.item.scrollToItem(entry.item)   // scrolled panes: bring the row into view
            }
        } else if (tab === "control") {
            root.openControlTab(entry.section || "network")
        } else if (tab === "core") {
            root.openCoreTab(entry.section || "system")
        } else if (tab === "logs") {
            root.openLogsTab()
        } else if (tab === "themes") {
            root.openThemeTab()
        } else if (tab === "wallpapers") {
            root.openWallpapersTab()
        } else if (tab === "dashboard") {
            root.openDashboardTab()
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

    // Land on the dashboard tab (index 0). Generic opens (toggle/show/
    // openSettings) call this so the app ALWAYS starts at the dashboard —
    // the window no longer reopens on the tab you left. Deep links
    // (openControlTab/openCoreTab/…) keep their targeting.
    function openDashboardTab() {
        for (var i = 0; i < navBar.tabModel.length; i++) {
            if (navBar.tabModel[i].key === "dashboard") { root.currentTab = i; break }
        }
    }

    // Open the Control tab and switch to a specific sub-section
    function openControlTab(section) {
        // Find Control by KEY, not hardcoded index — survives future reorders.
        var idx = -1
        for (var i = 0; i < navBar.tabModel.length; i++) {
            if (navBar.tabModel[i].key === "control") { idx = i; break }
        }
        if (idx >= 0) root.currentTab = idx
        // The currentTab assignment above marks the tab visited, which
        // synchronously creates the lazy tab; guard anyway (unfound key).
        if (controlLoader.item) controlLoader.item.activeSection = section
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

    // Open the Settings tab pinned to a rail section (H3 jump links, e.g.
    // Display's read-only auto-blank row → Idle & Lock). Same lazy-tab idiom
    // as openControlTab: openSettingsTab marks the tab visited, which creates
    // settingsLoader's item synchronously — the guard covers the unfound key.
    function openSettingsSection(section) {
        openSettingsTab()
        if (settingsLoader.item) settingsLoader.item.active = section
    }

    function openThemeTab() {
        for (var i = 0; i < navBar.tabModel.length; i++) {
            if (navBar.tabModel[i].key === "themes") { root.currentTab = i; break }
        }
    }

    function openWallpapersTab() {
        for (var i = 0; i < navBar.tabModel.length; i++) {
            if (navBar.tabModel[i].key === "wallpapers") { root.currentTab = i; break }
        }
    }

    // In-app journal tab. Deep link from the header LOGS launcher (which used
    // to cross-process-toggle the bar's overlay) and the search index; the
    // stream itself gates on LogsTab.streamWanted (tab visible + window shown).
    function openLogsTab() {
        for (var i = 0; i < navBar.tabModel.length; i++) {
            if (navBar.tabModel[i].key === "logs") { root.currentTab = i; break }
        }
    }

    // =========================================================================
    // BACKGROUND
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        radius: Config.SettingsConfig.radiusMd
        // Border: on dark themes the card is background-on-backdrop (the dim
        // layer is the SAME color at 0.6) — without an edge the top rounding
        // reads as "cut off under the bar". Every inner card has a border;
        // the shell card gets one too.
        border.color: Config.ThemeConfig.colors.border
        border.width: 1
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
        height: 44
        onLogsActivated: root.openLogsTab()
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
        // O1 lazy-tab pattern (all six eager tabs below follow it): each tab
        // lives in a Loader that turns on at its first visit (sticky — see
        // visitedTabs). B11: `visible` follows the opacity animation instead
        // of currentTab, so the OUTGOING tab stays visible while it fades out
        // (the old `visible: currentTab === N` cut the exit animation dead).

        Loader {
            anchors.fill: parent
            active: root.visitedTabs[0]

            visible: opacity > 0.01
            opacity: root.currentTab === 0 ? 1.0 : 0.0
            x: root.currentTab === 0 ? 0 : -20

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            sourceComponent: Components.DashboardOverviewTab {
                anchors.fill: parent

                // Dashboard → tab deep-links (Theme Switcher CHANGE, footer CONFIG)
                onRequestTab: function(index) { root.currentTab = index }
            }
        }

        // =====================================================================
        // TAB 1: THEME SELECTION
        // =====================================================================

        Loader {
            anchors.fill: parent
            anchors.margins: 24
            active: root.visitedTabs[1]

            visible: opacity > 0.01
            opacity: root.currentTab === 1 ? 1.0 : 0.0
            x: root.currentTab === 1 ? 0 : (root.currentTab < 1 ? 20 : -20)

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            sourceComponent: Components.ThemeModule {
                anchors.fill: parent
            }
        }

        // =====================================================================
        // TAB 2: WALLPAPER MANAGEMENT
        // =====================================================================

        Loader {
            anchors.fill: parent
            active: root.visitedTabs[2]

            visible: opacity > 0.01
            opacity: root.currentTab === 2 ? 1.0 : 0.0
            x: root.currentTab === 2 ? 0 : (root.currentTab < 2 ? 20 : -20)

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            sourceComponent: Components.WallpaperModule {
                anchors.fill: parent
            }
        }

        // =====================================================================
        // TAB 3: CONTROL MODULE
        // =====================================================================

        Loader {
            id: controlLoader
            anchors.fill: parent
            active: root.visitedTabs[3]

            visible: opacity > 0.01
            opacity: root.currentTab === 3 ? 1.0 : 0.0
            x: root.currentTab === 3 ? 0 : (root.currentTab < 3 ? 20 : -20)

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            sourceComponent: Components.ControlDashboard {
                anchors.fill: parent
                dash: root   // H3: cross-tab jump links (Display → Idle & Lock)
            }
        }

        // =====================================================================
        // TAB 5: LOGS (in-app journal — LogService gates the stream on
        // visibility + window-shown, so an idle tab costs nothing)
        // =====================================================================

        Loader {
            anchors.fill: parent
            anchors.margins: 24
            active: root.visitedTabs[5]

            visible: opacity > 0.01
            opacity: root.currentTab === 5 ? 1.0 : 0.0
            x: root.currentTab === 5 ? 0 : (root.currentTab < 5 ? 20 : -20)

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            sourceComponent: Components.LogsTab {
                anchors.fill: parent
            }
        }

        // =====================================================================
        // TAB 6: SETTINGS (rail + fixed panes — SettingsModule; same
        // architecture as Control/Core. Extracted from the former inline
        // scrolling block. Settings are managed by SettingsConfigService /
        // HypridleService and persisted on every change.)
        // =====================================================================

        Loader {
            id: settingsLoader
            anchors.fill: parent
            active: root.visitedTabs[6]

            visible: opacity > 0.01
            opacity: root.currentTab === 6 ? 1.0 : 0.0
            x: root.currentTab === 6 ? 0 : 20

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            sourceComponent: Components.SettingsModule {
                anchors.fill: parent
            }
        }

        // =====================================================================
        // TAB 4: CORE ENGINE (OLED telemetry dashboard + LCD control)
        // =====================================================================
        // Lazy-loaded on BOTH gates: first visit (O1, like every tab) AND
        // window visibility — the Core tab binds to always-on telemetry
        // (CoreEngine 1s, ThermalService, GpuService) through dozens of Text
        // bindings that would re-evaluate every second even while the panel
        // is closed. Gating on SharedState.dashboardVisible destroys the
        // whole subtree when the panel is hidden, eliminating that
        // steady-state churn. While open the tab persists, so the opacity
        // fade still plays (B11 pattern, same as the tabs above).

        Loader {
            anchors.fill: parent
            active: root.visitedTabs[4] && Config.SharedState.dashboardVisible

            visible: opacity > 0.01
            opacity: root.currentTab === 4 ? 1.0 : 0.0
            x: root.currentTab === 4 ? 0 : (root.currentTab < 4 ? 20 : -20)

            Behavior on opacity {
                NumberAnimation { duration: Config.MotionConfig.animDurationNormal; easing.type: Easing.OutCubic }
            }
            Behavior on x {
                NumberAnimation { duration: Config.MotionConfig.animDurationNormal; easing.type: Easing.OutCubic }
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
        interval: Config.MotionConfig.animDurationNormal + 170   // tab slide settles
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
