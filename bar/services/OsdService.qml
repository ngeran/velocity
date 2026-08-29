// =============================================================================
// OsdService.qml — on-screen display state (volume / mute / layout / workspace)
// =============================================================================
// Pure state + auto-hide timing; the Osd window component (in shell.qml)
// renders it. Triggers call show*() right after they mutate AudioService —
// Omarchy's model: the mutator shows the OSD, nothing polls for it.
// One card, last write wins: a rapid scroll just restarts the hide timer.
// =============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property bool active: false
    property string icon: ""
    property string message: ""     // readout right of the bar ("42%") / whole text ("MUTED")
    property int value: 0           // 0-100 bar fill; ignored when hasProgress is false
    property bool hasProgress: true

    readonly property int duration: 1200

    Timer {
        id: hideTimer
        interval: root.duration
        onTriggered: root.active = false
    }

    function show(icon_, value_, hasProgress_, message_) {
        // State lands before active flips so a fresh OSD renders at its new
        // value; only updates while already open animate the bar fill.
        root.icon = icon_
        root.value = value_
        root.hasProgress = hasProgress_
        root.message = message_
        root.active = true
        hideTimer.restart()
    }

    // Volume glyph thresholds match VolumeIcon / the volume tray body.
    function volumeGlyph(v, muted) {
        if (muted) return "󰝟"
        return v > 50 ? "󰕾" : "󰕿"
    }

    function showVolume(v, muted) {
        show(volumeGlyph(v, muted), v, true, Math.round(v) + "%")
    }

    function showMute(muted) {
        show(muted ? "󰝟" : "󰕾", 0, false, muted ? "MUTED" : "UNMUTED")
    }

    // Keyboard layout switch feedback ("US" / "GR") — optimistic label from the
    // switch call; the activelayout event corrects it right after.
    function showLayout(label) {
        show("󰌌", 0, false, label || "")
    }

    // Workspace switch feedback (bar-click initiated only — compositor keybinds
    // may drive their own OSD; no double-flash).
    function showWorkspace(id, name) {
        show("󰍹", 0, false, (name && name.length > 0) ? name : ("WS " + id))
    }
}
