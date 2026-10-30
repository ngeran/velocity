// =============================================================================
// SettingsHostWindow.qml — the settings dashboard window, hosted INSIDE the
// bar process (P2.1). Moved verbatim from settings/shell.qml minus the IPC
// handlers (those live on bar/shell.qml now and forward into this root's
// functions) and minus the process-lifetime singleton pins (those live in
// SettingsBootstrap).
//
// This file sits in components/ ON PURPOSE: it imports "../services" and
// "../config" — the exact specifiers every view uses — so the singletons it
// touches are the same instances the views see (import-split law; "services"
// from a settings/-root file would be a SECOND instance).
//
// Root is an invisible Item so the PanelWindow, the power menu and the bar
// failure banner (each their own window) all live in one Loader-loadable tree.
// The loader never deactivates once active — closing the dashboard only sets
// panelWindow.visible = false (same lifecycle as the notification center).
// =============================================================================

import Quickshell
import Quickshell.Io
import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    id: hostRoot

    width: 0
    height: 0

    // =========================================================================
    // STATE
    // =========================================================================

    property bool shown: false

    // Screen-adaptive sizing — scale based on available window dimensions.
    // PanelWindow spans the full screen, so its width/height map to the screen.
    readonly property real availableWidth: panelWindow.width || 1920
    readonly property real availableHeight: panelWindow.height || 1080

    // Base design size (1100×640) — the perfect size on the 4K OLED. On smaller
    // screens each dimension is capped to a fraction of the panel so the card
    // never swamps the display; floors keep it usable on tiny screens.
    readonly property real cardWidth:  Math.max(720, Math.min(1100, availableWidth  * 0.60))
    readonly property real cardHeight: Math.max(480, Math.min(640,  availableHeight * 0.75))

    // Shibumi UI-scale — feed the singleton our live logical width (a binding,
    // so output changes propagate). Singletons can't use the Screen attached
    // property (not part of a scene), so the window injects it instead.
    Component.onCompleted: {
        Config.UIScale.sourceWidth = Qt.binding(function() { return hostRoot.availableWidth })
    }

    // =========================================================================
    // HIDE TIMER — defer visible=false until slide-up completes
    // =========================================================================
    Timer {
        id: hideTimer
        interval: Config.MotionConfig.animDurationSlow

        onTriggered: {
            if (!hostRoot.shown) {
                panelWindow.visible = false
            }
        }
    }

    // Trigger hide timer when shown becomes false
    onShownChanged: {
        // Broadcast open/close so background services can gate their poll timers
        // (see SharedState.dashboardVisible). Every shown mutation funnels here.
        Config.SharedState.dashboardVisible = hostRoot.shown
        if (!shown) {
            hideTimer.restart()
        }
    }

    // =========================================================================
    // WORKSPACE WATCHER — auto-close when the user switches workspace.
    // Event-driven via Hyprland's socket2 (no polling latency). `nc -U` streams
    // events line-by-line; we dismiss on workspace>> / workspacev2>> /
    // focusedmon>> (focus to another monitor ≈ switch).
    // =========================================================================
    Process {
        id: workspaceWatcher
        command: ["sh", "-c", "nc -U \"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\""]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var ev = "" + line
                if (ev.indexOf("workspace>>") === 0
                    || ev.indexOf("workspacev2>>") === 0
                    || ev.indexOf("focusedmon>>") === 0) {
                    if (hostRoot.shown) hostRoot.shown = false
                }
            }
        }
    }

    // =========================================================================
    // BAR FAILURE BANNER — "the bar is down and here's why" (BarWatch feeds
    // it; auto-shows on bar death, auto-hides on recovery).
    // =========================================================================
    BarFailureBanner { }

    // =========================================================================
    // PUBLIC API — the bar's IpcHandler targets forward here (same function
    // bodies the old settings/shell.qml handlers carried).
    // =========================================================================

    function toggle() {
        if (panelWindow.visible && !hostRoot.shown) {
            // Already hiding — do nothing
            return
        }
        // Every generic open lands on the dashboard — the window no
        // longer reopens on the tab you left. Only when actually opening
        // (not on the close half of the toggle).
        if (!hostRoot.shown) dashboard.openDashboardTab()
        hostRoot.shown = !hostRoot.shown
        panelWindow.visible = true
    }

    function show() {
        dashboard.openDashboardTab()
        hostRoot.shown = true
        panelWindow.visible = true
    }

    function hide() {
        hostRoot.shown = false
    }

    // Read-only probe: key of the visible top-level tab (dashboard |
    // themes | …). Makes the dashboard-start behavior scriptable.
    function activeTab(): string { return dashboard.currentTabKey }

    // Deep-link to Control tab sections (one function per section, as before)
    function openControlNetwork() {
        hostRoot.shown = true
        panelWindow.visible = true
        dashboard.openControlTab("network")
    }

    function openControlBluetooth() {
        hostRoot.shown = true
        panelWindow.visible = true
        dashboard.openControlTab("bluetooth")
    }

    function openControlAudio() {
        hostRoot.shown = true
        panelWindow.visible = true
        dashboard.openControlTab("audio")
    }

    // Deep-link to the Display control section (live mode/HDR/VRR/scale)
    function openControlDisplay() {
        hostRoot.shown = true
        panelWindow.visible = true
        dashboard.openControlTab("display")
    }

    // Deep-link to the plugin manager (Control ▸ Plugins)
    function openControlPlugins() {
        hostRoot.shown = true
        panelWindow.visible = true
        dashboard.openControlTab("plugins")
    }

    // Generic "open the settings app" verb — lands on the dashboard like
    // every generic open; the SETTINGS tab stays reachable from the sidebar.
    function openSettings() {
        dashboard.openDashboardTab()
        hostRoot.shown = true
        panelWindow.visible = true
    }

    // Deep-link to the Theme tab (presets + custom palettes + editor)
    function openThemeTab() {
        hostRoot.shown = true
        panelWindow.visible = true
        dashboard.openThemeTab()
    }

    // Deep-link to the Core tab (defaults to Processors; section keys:
    // processors | gpu | memoryenv | lcd | events)
    function openCore(section: string) {
        hostRoot.shown = true
        panelWindow.visible = true
        dashboard.openCoreTab(section || "system")
    }

    // Power menu overlay toggle (forwarded from the bar's powerMenu IPC target)
    function powerToggle() {
        powerMenu.showing = !powerMenu.showing
    }

    // Dashboard search (scripting / truth probes / deep-link). These run
    // through the dashboard's bridges — the SearchIndex singleton lives under
    // the components' "../services" import (import-split law).
    function searchQuery(q: string): string { return dashboard.searchIpcQuery(q) }
    function searchOpen(q: string) { dashboard.searchIpcOpen(q) }
    function searchActivateFirst(q: string) { return dashboard.searchIpcActivateFirst(q) }
    function searchList(): string { return dashboard.searchIpcList() }

    // =========================================================================
    // PANEL WINDOW — transparent full-width top stage
    // =========================================================================
    PanelWindow {
        id: panelWindow

        // Full-screen overlay so ANY click outside the card closes the window.
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // Transparent stage — backdrop + card provide the visuals
        color: "transparent"

        // Don't reserve screen space
        exclusionMode: ExclusionMode.Ignore

        // Stay above other windows
        aboveWindows: true

        // Allow keyboard focus (Escape to close)
        focusable: true

        // Start hidden
        visible: false

        // Dim backdrop — also makes the surface input-solid so clicks register
        // anywhere outside the card. Fades in/out with the card.
        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: Config.ThemeConfig.colors.background
            opacity: hostRoot.shown ? 0.6 : 0.0
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation { duration: Config.MotionConfig.animDurationSlow }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: hostRoot.shown = false
            }

            // Key handler — Escape closes. Lives on the backdrop (OverlayShell
            // card pattern): a Keys attached property on the PanelWindow root
            // can't attach — the window is not an Item (P1.11 journal fix).
            Keys.onEscapePressed: {
                hostRoot.shown = false
            }
        }

        // =====================================================================
        // DASHBOARD CARD — centered, animates down from bar
        // =====================================================================
        SettingsWindowShell {
            id: dashboard

            // Injected so SettingsWindowShell can funnel visibility into the
            // SharedState instance the services read (see its windowShown).
            windowShown: hostRoot.shown

            z: 1   // paint above the dim backdrop
            width: hostRoot.cardWidth
            height: hostRoot.cardHeight

            // Center horizontally, animate vertically
            anchors.horizontalCenter: parent.horizontalCenter

            // Hidden: y = barHeight - height (above stage)
            // Shown:  y = barHeight (top edge flush with bar bottom)
            // H10: the live mirror (ingested from bar-config.json).
            y: hostRoot.shown ? Services.SettingsConfigService.barHeight
                              : (Services.SettingsConfigService.barHeight - height)

            // Smooth slide animation
            Behavior on y {
                NumberAnimation {
                    duration: Config.MotionConfig.animDurationSlow
                    easing.type: Easing.OutCubic
                }
            }

            // Focus handling — close when losing focus to outside
            focus: true

            Keys.onEscapePressed: {
                hostRoot.shown = false
            }
        }
    }

    // =========================================================================
    // POWER MENU — full-screen overlay (bar's powerMenu IPC target → powerToggle)
    // =========================================================================
    PowerMenu {
        id: powerMenu
    }
}
