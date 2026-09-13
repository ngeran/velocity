// =============================================================================
// nikos.keyboard — active XKB layout pill (plugin api 1)
// =============================================================================
// Port of the built-in KeyboardWidget + KeyboardService, merged into one
// self-contained file (omarchy-keymaps lineage):
//   state   hyprctl -j devices       → keyboards[].active_keymap / index
//   list    hyprctl getoption input:kb_layout -j
//   events  api.hypr.socketEvent ("activelayout>>", "configreloaded") — the
//           bar owns exactly ONE socket2 consumer; plugins subscribe
//   switch  hyprctl switchxkblayout <device> next (retry once as "main";
//           hyprctl exits 0 even on "device not found", so the reply TEXT
//           is the success signal)
// Host injects pluginId + api; api.hypr is the shared HyprlandService, api.osd
// the on-screen feedback. SUPER+SHIFT+SPACE routes here through the plugins
// IPC (shell.qml "keyboard" target → cycle()).
// =============================================================================
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string pluginId: ""
    property var api: null

    // ── state ────────────────────────────────────────────────────────────────
    property var layoutList: []
    property int activeIndex: 0
    property string activeKeymap: ""
    property string keyboardName: ""
    property int devicesIndex: 0

    readonly property int layoutCount: layoutList.length
    readonly property string activeCode: layoutCount > 0
        ? layoutList[Math.min(activeIndex, layoutCount - 1)] : ""
    readonly property string activeLabel: activeCode !== ""
        ? activeCode.toUpperCase() : "—"

    readonly property bool hot: mouseArea.containsMouse

    function applyIndex() {
        activeIndex = Math.min(devicesIndex, Math.max(layoutCount - 1, 0))
    }
    onLayoutListChanged: applyIndex()

    // ── bar pill (hover-reveal idiom: glyph at rest, layout code on hover) ──
    implicitWidth: layoutRow.implicitWidth
    height: api ? api.bar.barHeight : 30
    visible: layoutCount > 0
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    function cycle() { switchNext() }
    function open()   { }   // no panel — lifecycle stubs for the IPC contract
    function close()  { }

    Row {
        id: layoutRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.hot ? 6 : 0
        Text {
            text: "󰌌"   // nf-md-keyboard
            font.family: api ? api.bar.fontNerd : "monospace"
            font.pixelSize: api ? api.bar.fontSizeIcon : 13
            color: root.hot ? api.theme.colors.accent
                            : (api ? api.bar.colorText : "#888")
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            visible: root.hot
            text: root.activeLabel
            font.family: api ? api.bar.fontFamily : "monospace"
            font.pixelSize: 11
            font.weight: Font.Bold
            color: api ? api.theme.colors.text : "#aaa"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.switchNext()
    }

    // ── LAYOUT LIST — configured kb_layout ──────────────────────────────────
    Process {
        id: layoutsProc
        command: ["hyprctl", "getoption", "input:kb_layout", "-j"]
        property string buffer: ""
        stdout: SplitParser { onRead: data => layoutsProc.buffer += data }
        onRunningChanged: {
            if (!running) {
                try {
                    var parsed = JSON.parse(layoutsProc.buffer)
                    var str = String(parsed.str || "")
                    if (str === "[[EMPTY]]") str = ""
                    var list = str.split(",").map(function(s) { return s.trim() })
                                   .filter(function(s) { return s.length > 0 })
                    if (list.length > 0) root.layoutList = list
                } catch (e) { /* keep previous list */ }
                layoutsProc.buffer = ""
            }
        }
    }

    // ── DEVICES — active keymap + index of the tracked keyboard ─────────────
    Process {
        id: devicesProc
        command: ["hyprctl", "-j", "devices"]
        property string buffer: ""
        stdout: SplitParser { onRead: data => devicesProc.buffer += data }
        onRunningChanged: {
            if (!running) {
                root.parseDevices(devicesProc.buffer)
                devicesProc.buffer = ""
            }
        }
    }

    function parseDevices(raw) {
        var keyboards = []
        try { keyboards = JSON.parse(String(raw || "{}")).keyboards || [] }
        catch (e) { return }

        var candidate = null
        for (var i = 0; i < keyboards.length; i++) {
            var name = String(keyboards[i].name || "")
            if (name.indexOf("hl-virtual-keyboard") === 0) continue
            if (name === "video-bus" || name.indexOf("power-button") === 0) continue
            if (name.endsWith("-system-control") || name.endsWith("-consumer-control")) continue
            candidate = keyboards[i]
            if (keyboards[i].main) break
        }
        if (!candidate) return

        keyboardName = String(candidate.name || "")
        activeKeymap = String(candidate.active_keymap || "")
        devicesIndex = Math.max(0, Number(candidate.active_layout_index || 0))
        applyIndex()
    }

    // ── EVENT STREAM — the host's single socket2 consumer ───────────────────
    Connections {
        target: root.api ? root.api.hypr : null
        function onSocketEvent(line) {
            var ev = "" + line
            if (ev.indexOf("activelayout>>") === 0) {
                var dev = ev.slice("activelayout>>".length).split(",")[0]
                if (root.keyboardName === "" || dev === root.keyboardName) root.probe()
            } else if (ev.indexOf("configreloaded") === 0) {
                root.probe(true)   // layout list itself may have changed
            }
        }
    }

    // ── SWITCHING ────────────────────────────────────────────────────────────
    // hyprctl switchxkblayout is PER DEVICE, and this box has several XKB
    // keyboards (dongle + laptop). "main" can be a non-typing device that
    // accepts the switch with "ok" and silently does nothing (measured) —
    // so cycle every real typing keyboard (name ends with "-keyboard").
    Process {
        id: switchProc
        property string buffer: ""
        stdout: SplitParser { onRead: data => switchProc.buffer += data }
        onRunningChanged: {
            if (!running) {
                switchProc.buffer = ""
                root.probe()   // confirm/correct the optimistic flip
            }
        }
    }

    function switchNext() {
        if (switchProc.running) return
        // Optimistic flip — the activelayout events confirm it right after.
        if (layoutCount > 1)
            activeIndex = (activeIndex + 1) % layoutCount
        if (api && api.osd)
            api.osd.showLayout(activeCode !== "" ? activeCode.toUpperCase() : "")
        switchProc.command = ["sh", "-c",
            "hyprctl -j devices | tr ',' '\\n' | grep -o '\"name\": \"[^\"]*-keyboard\"' " +
            "| sed 's/\"name\": \"//;s/\"//' | while read d; do hyprctl switchxkblayout \"$d\" next; done"]
        switchProc.running = true
    }

    function probe(reloadList) {
        if (!devicesProc.running) devicesProc.running = true
        if (reloadList && !layoutsProc.running) layoutsProc.running = true
    }

    Component.onCompleted: {
        layoutsProc.running = true
        devicesProc.running = true
    }
}
