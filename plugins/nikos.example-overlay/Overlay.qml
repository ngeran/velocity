// =============================================================================
// Overlay.qml — SDK sample for the OVERLAY plugin kind.
// =============================================================================
// The host mounts this root hidden and summons it through its lifecycle
// (plugins IPC `summon <id> [payloadJson]`, or another plugin via the
// `shell` shim). The contract, in full:
//
//   property bool shown              — the host watches it for exclusivity
//   function open(payloadJson)       — payload is a JSON STRING (may be "{}")
//   function close()
//   function toggle(payloadJson)
//
//   property var ctx                 — injected by the engine (plugin api 2):
//                                      theme/bar tokens, settings, run(), log()…
//
// Plugin IPC: every verb listed in manifest.ipc is callable as
//   qs -c bar ipc call plugins call nikos.example-overlay <verb> "<arg>"
// (this sample declares "ping"). Plugins never import bar dirs by path.
// =============================================================================

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property var ctx: null

    // ---- lifecycle contract (mirrors the built-in overlays) ----
    property bool shown: false
    property string lastPayload: "{}"
    visible: false
    function open(payloadJson) {
        if (payloadJson !== undefined) lastPayload = String(payloadJson)
        visible = true
        shown = true
    }
    function close() { shown = false; visible = false }
    function toggle(payloadJson) { shown ? close() : open(payloadJson) }

    // manifest.ipc verb — returns a string to the caller.
    function ping(arg) {
        if (ctx) ctx.log("ping " + arg)
        return "pong " + arg
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    // dim backdrop — click or Esc dismisses (self-contained colours: this
    // sample demonstrates the contract, not the theme system)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.55
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 460; height: 180
        radius: 10
        color: "#0c0c0e"
        border.color: "#00dce5"
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "EXAMPLE OVERLAY"
                font.family: "monospace"
                font.pixelSize: 14; font.bold: true
                font.letterSpacing: 3
                color: "#00dce5"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "payload: " + root.lastPayload
                font.family: "monospace"
                font.pixelSize: 11
                color: "#9a9aa2"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "click anywhere or press Esc to close"
                font.family: "monospace"
                font.pixelSize: 10
                color: "#9a9aa2"
                opacity: 0.7
            }
        }
    }

    Shortcut { sequence: "Esc"; onActivated: root.close() }
}
