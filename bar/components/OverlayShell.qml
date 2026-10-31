// =============================================================================
// OverlayShell.qml — full-screen overlay chrome BASE (DU11)
// =============================================================================
// The shared shell of the bar's big overlays (KeybindsOverlay, Fastfetch,
// ZaiUsage, BarSettings): transparent full-anchor PanelWindow, dim backdrop
// with click-outside close, centered pure-black card (island look — pixels
// off on QD-OLED, rounded, no stroke), Esc close, 220ms hide timer.
//
// Subclasses declare their card interior as direct children — the shell's
// default property routes them into the card. Open/close side effects go in
// onAboutToOpen / onDismissed (Fastfetch's service activation, ZaiUsage's
// active flag); card size via cardWidth/cardHeight; backdrop strength via
// backdropDim.
// =============================================================================

import QtQuick
import Quickshell
import Quickshell.Wayland
import bar.config as Config

PanelWindow {
    id: root

    // Subclass content lands inside the centered card.
    default property alias content: card.data

    property bool shown: false
    property int cardWidth: 900
    property int cardHeight: 680
    property real backdropDim: 0.45
    // Subclass interiors need the card's live size (grid-repeat math etc.);
    // QML ids are not visible across component boundaries, so expose it.
    readonly property alias cardItem: card

    signal aboutToOpen()
    // NOT `closed` — PanelWindow already has that signal (duplicate-name
    // override warning, and onClosed handlers would bind the wrong one).
    signal dismissed()

    function open() {
        root.aboutToOpen()
        visible = true
        shown = true
    }
    function close() {
        shown = false
        root.dismissed()
        hideTimer.restart()
    }
    function toggle() { shown ? close() : open() }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    onShownChanged: if (!shown) hideTimer.restart()
    Timer { id: hideTimer; interval: 220; onTriggered: if (!root.shown) root.visible = false }

    // ---- dim backdrop (click-outside = close) ----
    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        opacity: root.shown ? root.backdropDim : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ---- centered card ----
    Rectangle {
        id: card
        anchors.centerIn: parent
        // ≥0 clamp: while the window is hidden the parent reports 0 size and
        // the unclamped subtraction goes negative (grid-repeat models → -2).
        width: Math.max(0, Math.min(Config.PopupMetrics.px(root.cardWidth), parent.width - Config.PopupMetrics.px(48)))
        height: Math.max(0, Math.min(Config.PopupMetrics.px(root.cardHeight), parent.height - Config.PopupMetrics.px(48)))
        // Island look: pure black (pixels off on QD-OLED), rounded, no stroke.
        color: "#000000"
        radius: Config.PopupMetrics.px(18)
        clip: true
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
        Behavior on scale { NumberAnimation { duration: Config.MotionConfig.swap; easing.type: Config.MotionConfig.ease } }

        Keys.onEscapePressed: root.close()
        MouseArea { anchors.fill: parent }   // stop click-through to the backdrop
    }
}
