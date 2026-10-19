// {{ID}} — overlay (plugin api 2). Mounted hidden; the engine summons it.
// Contract: `shown` (the bar's one-popup-at-a-time slot watches it),
// open(payloadJson) / close() / toggle(payloadJson). `ctx` is injected.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    property var ctx: null

    property bool shown: false
    property string payload: "{}"
    visible: false
    function open(payloadJson) { payload = String(payloadJson || "{}"); visible = true; shown = true }
    function close() { shown = false; visible = false }
    function toggle(payloadJson) { shown ? close() : open(payloadJson) }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.55
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 420; height: 140
        radius: 10
        color: root.ctx ? root.ctx.theme.colors.background : "#0c0c0e"
        border.color: root.ctx ? root.ctx.theme.colors.accent : "#00dce5"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "{{NAME}}\npayload: " + root.payload
            horizontalAlignment: Text.AlignHCenter
            font.family: root.ctx ? root.ctx.bar.fontFamily : "monospace"
            font.pixelSize: 12
            color: root.ctx ? root.ctx.theme.colors.text : "#e0e0e0"
        }
    }

    Shortcut { sequence: "Esc"; onActivated: root.close() }
}
