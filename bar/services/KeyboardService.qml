// =============================================================================
// KeyboardService.qml — active XKB layout tracking + switching
// =============================================================================
// Ported from omarchy-keymaps (~/github/omarchy/omarchy-keymaps):
//   state   hyprctl -j devices       → keyboards[].active_keymap / index
//   list    hyprctl getoption input:kb_layout -j (set in look-and-feel.lua)
//   events  HyprlandService.socketEvent lines ("activelayout>>" /
//           "configreloaded") — the bar owns exactly ONE socket2 nc consumer;
//           this service subscribes instead of streaming its own
//   switch  hyprctl switchxkblayout <device> next
//
// NOTE: hyprctl exits 0 even for "device not found" — success is judged by
// the "ok" reply text, and a failed device name is retried once as "main".
//
// PROPERTIES
//   layoutList   ["us","gr"] — configured kb_layout entries
//   activeIndex  index into layoutList
//   activeLabel  "US" / "GR" — what the bar shows
//   activeKeymap "Greek" — full name as reported by hyprctl
//   keyboardName tracked real keyboard (main:true, virtual devices skipped)
//
// METHODS
//   switchNext()  cycle to the next layout
//   probe(reloadList)  re-read state from hyprctl
// =============================================================================
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var layoutList: []
    property int activeIndex: 0
    property string activeKeymap: ""
    property string keyboardName: ""

    // Raw index as reported by hyprctl; re-applied (clamped) whenever the
    // layout list changes so a stale list can never point out of range.
    property int devicesIndex: 0

    readonly property int layoutCount: layoutList.length
    readonly property string activeCode: layoutCount > 0
        ? layoutList[Math.min(activeIndex, layoutCount - 1)] : ""
    readonly property string activeLabel: activeCode !== ""
        ? activeCode.toUpperCase() : "—"

    function applyIndex() {
        activeIndex = Math.min(devicesIndex, Math.max(layoutCount - 1, 0))
    }
    onLayoutListChanged: applyIndex()

    // -------------------------------------------------------------------------
    // LAYOUT LIST — configured kb_layout ("us,gr" in look-and-feel.lua)
    // -------------------------------------------------------------------------
    Process {
        id: layoutsProc
        command: ["hyprctl", "getoption", "input:kb_layout", "-j"]
        property string buffer: ""
        stdout: SplitParser { onRead: data => layoutsProc.buffer += data }
        onRunningChanged: {
            if (!running) {
                try {
                    const parsed = JSON.parse(layoutsProc.buffer)
                    let str = String(parsed.str || "")
                    if (str === "[[EMPTY]]") str = ""
                    const list = str.split(",").map(s => s.trim()).filter(s => s.length > 0)
                    if (list.length > 0) root.layoutList = list
                } catch (e) { /* keep previous list */ }
                layoutsProc.buffer = ""
            }
        }
    }

    // -------------------------------------------------------------------------
    // DEVICES — active keymap + index of the tracked keyboard.
    // Same filter as omarchy-keymaps: skip virtual / consumer / system / video
    // devices, prefer main:true.
    // -------------------------------------------------------------------------
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
        let keyboards = []
        try { keyboards = JSON.parse(String(raw || "{}")).keyboards || [] }
        catch (e) { return }

        let candidate = null
        for (let i = 0; i < keyboards.length; i++) {
            const name = String(keyboards[i].name || "")
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

    // -------------------------------------------------------------------------
    // EVENT STREAM — subscribe to HyprlandService (the bar's single socket2
    // owner) for activelayout / configreloaded
    // -------------------------------------------------------------------------
    Connections {
        target: HyprlandService
        function onSocketEvent(line) {
            const ev = "" + line
            if (ev.indexOf("activelayout>>") === 0) {
                // activelayout>>device,layout — ignore other keyboards
                const dev = ev.slice("activelayout>>".length).split(",")[0]
                if (root.keyboardName === "" || dev === root.keyboardName) root.probe()
            } else if (ev.indexOf("configreloaded") === 0) {
                root.probe(true)   // layout list itself may have changed
            }
        }
    }

    // -------------------------------------------------------------------------
    // SWITCHING — hyprctl switchxkblayout <device> next
    // -------------------------------------------------------------------------
    Process {
        id: switchProc
        property string buffer: ""
        property string lastDevice: ""
        stdout: SplitParser { onRead: data => switchProc.buffer += data }
        onRunningChanged: {
            if (!running) {
                const ok = switchProc.buffer.trim() === "ok"
                switchProc.buffer = ""
                if (!ok && switchProc.lastDevice !== "main") {
                    // Device went away (dongle re-plug, rename): retry once
                    // against Hyprland's literal "main" keyboard.
                    switchProc.lastDevice = "main"
                    switchProc.command = ["hyprctl", "switchxkblayout", "main", "next"]
                    switchProc.running = true
                } else {
                    root.probe()   // confirm/correct the optimistic flip
                }
            }
        }
    }

    function switchNext() {
        if (switchProc.running) return
        // Optimistic flip — the activelayout event confirms it right after.
        if (layoutCount > 1)
            activeIndex = (activeIndex + 1) % layoutCount
        OsdService.showLayout(activeCode !== "" ? activeCode.toUpperCase() : "")
        switchProc.lastDevice = keyboardName !== "" ? keyboardName : "main"
        switchProc.command = ["hyprctl", "switchxkblayout", switchProc.lastDevice, "next"]
        switchProc.running = true
    }

    // -------------------------------------------------------------------------
    // PUBLIC API
    // -------------------------------------------------------------------------
    function probe(reloadList) {
        if (!devicesProc.running) devicesProc.running = true
        if (reloadList && !layoutsProc.running) layoutsProc.running = true
    }

    Component.onCompleted: {
        layoutsProc.running = true
        devicesProc.running = true
    }
}
