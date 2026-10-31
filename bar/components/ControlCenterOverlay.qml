// =============================================================================
// ControlCenterOverlay.qml — the Control Center as a floating panel (UX U1)
// =============================================================================
// Replaces the TrayCard "control" popup (user call, 2026-10-31: the popup
// "sucks"): a full-screen dim backdrop with a centered pure-black card hosting
// ControlCenterBody — the same body the tray card hosted, same pages ("main",
// "bar"), same tile grammar. Outside-click and ESC dismiss it.
//
// Tile drills leave the overlay so only one popup surface stays up:
// "notifications" opens the notification center; network/bluetooth/volume open
// their tray cards (shell.openTrayBody) — the same cards the bar pills open.
//
// Reached from: the gear's left click, SUPER+A, SUPER+N, `controlCenter`
// IPC (toggle / page bar). The settings dashboard keeps the gear's RIGHT
// click (no keybind — SUPER+A was retargeted).
// =============================================================================

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

PanelWindow {
    id: root

    property var shellApi: null   // the bar ShellRoot (same shape TrayCard gets)

    // ---- visibility control (mirrors NotificationCenter) ----
    property bool shown: false
    visible: false
    function open()  {
        visible = true
        shown = true
        // Open-gated probes (brightnessctl/ddcutil + powerprofilesctl sweeps) —
        // the tray card's control branch used to fire these on open.
        Services.BrightnessService.refresh()
        Services.PowerProfileService.refresh()
    }
    function close() { shown = false; hideTimer.restart() }
    function toggle() { shown ? close() : open() }

    // Deep page entry (controlCenter.page "bar"): applies immediately when the
    // body is warm, parks until onLoaded otherwise.
    property string _pendingPage: ""
    property bool _bodyWarm: false
    function openPage(name) {
        open()
        if (bodyLoader.item) bodyLoader.item.page = name
        else _pendingPage = name
    }

    // full-screen overlay so any click outside the card dismisses it
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    // defer visible=false until the fade-out finishes (so it can animate)
    onShownChanged: if (!shown) hideTimer.restart()
    Timer {
        id: hideTimer
        interval: 220
        onTriggered: if (!root.shown) root.visible = false
    }

    // ---- dim backdrop (click-outside = close) ----
    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        opacity: root.shown ? 0.35 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ---- the centered panel ----
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Config.PopupMetrics.px(430), parent.width - Config.PopupMetrics.px(48))
        height: Math.min(
            bodyCol.implicitHeight + Config.PopupMetrics.px(24),
            parent.height - Config.PopupMetrics.px(80))
        // Pure black (pixels off on QD-OLED) like every ephemeral card.
        color: "#000000"
        radius: Config.PopupMetrics.px(18)
        clip: true
        focus: root.shown
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.98
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
        Behavior on scale { NumberAnimation { duration: Config.MotionConfig.swap; easing.type: Config.MotionConfig.ease } }
        Keys.onEscapePressed: root.close()

        MouseArea { anchors.fill: parent }   // stop click-through to the backdrop

        ColumnLayout {
            id: bodyCol
            anchors.fill: parent
            anchors.margins: Config.PopupMetrics.px(12)
            spacing: 0

            Loader {
                id: bodyLoader
                Layout.fillWidth: true
                active: root.shown || root._bodyWarm   // warm after first open
                sourceComponent: ControlCenterBody {
                    shellApi: root.shellApi
                    onDrill: function(tray) { root._drill(tray) }
                    onDone: root.close()
                }
                onLoaded: {
                    root._bodyWarm = true
                    if (root._pendingPage !== "") {
                        item.page = root._pendingPage
                        root._pendingPage = ""
                    }
                }
            }
        }
    }

    function _drill(tray) {
        if (tray === "notifications") {
            root.close()
            if (root.shellApi) root.shellApi.toggleNotificationCenter()
            return
        }
        root.close()
        if (root.shellApi) root.shellApi.openTrayBody(tray)
    }
}
