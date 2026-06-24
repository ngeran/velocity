// =============================================================================
// CommandService.qml — curated terminal command parser + shared console log
// =============================================================================
//
// Owns the console scrollback (logLines ListModel) and the curated command
// vocabulary. executeCommand() trims + echoes `❯ <input>`, then dispatches by
// the first token to the matching management service.
//
// Vocabulary (network/bt/audio verbs wired up in phases 3-5):
//   help · status · clear
//   scan wifi · scan bt
//   connect <ssid> [pass]   (password is masked in the echo)
//   pair <mac> · trust <mac> · bt <mac> · disconnect bt <mac>
//   set-sink <name> · vol <0-150> · mute · toggle bt
//
// pushLog(text, kind) is reused by click handlers so clicks also narrate into
// the terminal. kind ∈ input|output|success|warning|error.
// =============================================================================

pragma Singleton

import QtQuick

Item {
    id: root
    visible: false

    // Shared console scrollback. Repeater/ListView bind directly to this.
    ListModel { id: _log }

    property ListModel logLines: _log

    Component.onCompleted: {
        _log.append({ text: "OBSIDIAN_CORE_OS control v0.4.2 — type 'help'", kind: "output" })
    }

    // -------------------------------------------------------------------------
    // PUBLIC API
    // -------------------------------------------------------------------------

    function pushLog(text, kind) {
        if (kind === undefined || kind === null) kind = "output"
        _log.append({ text: String(text), kind: String(kind) })
        if (_log.count > 200) _log.remove(0)
    }

    function clear() {
        _log.clear()
    }

    function executeCommand(input) {
        var raw = (input || "").trim()
        if (raw.length === 0) return

        var args = raw.split(/\s+/)
        var cmd = args[0].toLowerCase()

        // echo the command (mask any password for `connect <ssid> <pass>`)
        root.pushLog("❯ " + _maskEcho(cmd, args), "input")

        switch (cmd) {
            case "help":    _help(); break
            case "clear":   _log.clear(); break
            case "status":  _status(); break
            case "scan":    _scan(args); break
            case "connect": _connect(args); break
            case "pair":    _btUnary(args, "pair", 1); break
            case "trust":   _btUnary(args, "trust", 1); break
            case "bt":      _btChain(args); break
            case "disconnect": _disconnect(args); break
            case "set-sink": _setSink(args); break
            case "vol":     _vol(args); break
            case "mute":    _mute(args); break
            case "toggle":  _toggle(args); break
            default:
                root.pushLog("error: unknown command '" + cmd + "'. type 'help'", "error")
        }
    }

    // -------------------------------------------------------------------------
    // ECHO MASKING — never print a wifi password
    // -------------------------------------------------------------------------

    function _maskEcho(cmd, args) {
        if (cmd === "connect" && args.length >= 3) {
            return args[0] + " " + args[1] + " ****"
        }
        return args.join(" ")
    }

    // -------------------------------------------------------------------------
    // COMMAND HANDLERS
    // -------------------------------------------------------------------------

    function _help() {
        var lines = [
            "AVAILABLE COMMANDS",
            "  help                      show this help",
            "  status                    dump network / bluetooth / audio status",
            "  clear                     clear the console",
            "",
            "  scan wifi                 rescan wifi networks",
            "  scan bt                   scan bluetooth (8s)",
            "  connect <ssid> [pass]     connect to wifi  (password hidden)",
            "",
            "  pair <mac>                pair a bluetooth device",
            "  trust <mac>               trust a bluetooth device",
            "  bt <mac>                  pair + trust + connect (convenience)",
            "  disconnect bt <mac>       disconnect a device",
            "  toggle bt                 toggle bluetooth power",
            "",
            "  set-sink <name>           set default audio sink",
            "  vol <0-150>               set default sink volume (%)",
            "  mute                      toggle default sink mute"
        ]
        for (var i = 0; i < lines.length; i++) root.pushLog(lines[i], "output")
    }

    function _status() {
        var ns = NetworkControlService.connectionStatus
        root.pushLog("[ NETWORK ] " + (ns.connected
            ? "connected via " + ns.type + (ns.ssid ? " · " + ns.ssid : "") + (ns.ip ? " · " + ns.ip : "")
            : "disconnected"), "output")

        root.pushLog("[ BLUETOOTH ] " + (BluetoothControlService.powered
            ? "powered · " + BluetoothControlService.devices.length + " device(s)"
            : "offline"), "output")

        root.pushLog("[ AUDIO ] sink: " + (AudioControlService.defaultSink || "none")
            + " · " + AudioControlService.sinks.length + " sink(s)"
            + " · " + AudioControlService.sinkInputs.length + " stream(s)", "output")
    }

    function _scan(args) {
        if (args.length < 2) { root.pushLog("usage: scan <wifi|bt>", "warning"); return }
        var t = args[1].toLowerCase()
        if (t === "wifi") NetworkControlService.scanWifi()
        else if (t === "bt") BluetoothControlService.scanDevices()
        else root.pushLog("error: scan target must be 'wifi' or 'bt'", "error")
    }

    function _connect(args) {
        if (args.length < 2) { root.pushLog("usage: connect <ssid> [pass]", "warning"); return }
        var ssid = args[1]
        var pass = args.length >= 3 ? args.slice(2).join(" ") : ""
        NetworkControlService.connectWifi(ssid, pass)
    }

    function _btUnary(args, fn, macIdx) {
        if (args.length <= macIdx) { root.pushLog("usage: " + fn + " <mac>", "warning"); return }
        BluetoothControlService[fn](args[macIdx])
    }

    function _btChain(args) {
        if (args.length < 2) { root.pushLog("usage: bt <mac>  (pair + trust + connect)", "warning"); return }
        var mac = args[1]
        root.pushLog("chaining pair → trust → connect " + mac, "output")
        BluetoothControlService.pair(mac)
        BluetoothControlService.trust(mac)
        BluetoothControlService.connect(mac)
    }

    function _disconnect(args) {
        if (args.length < 3 || args[1].toLowerCase() !== "bt") {
            root.pushLog("usage: disconnect bt <mac>", "warning"); return
        }
        BluetoothControlService.disconnect(args[2])
    }

    function _setSink(args) {
        if (args.length < 2) { root.pushLog("usage: set-sink <name>", "warning"); return }
        AudioControlService.setDefaultSink(args.slice(1).join(" "))
    }

    function _vol(args) {
        if (args.length < 2) { root.pushLog("usage: vol <0-150>", "warning"); return }
        var pct = parseInt(args[1], 10)
        if (isNaN(pct)) { root.pushLog("error: volume must be a number", "error"); return }
        AudioControlService.setSinkVolume(AudioControlService.defaultSink, pct + "%")
    }

    function _mute(args) {
        AudioControlService.toggleSinkMute(AudioControlService.defaultSink)
    }

    function _toggle(args) {
        if (args.length < 2) { root.pushLog("usage: toggle <bt>", "warning"); return }
        if (args[1].toLowerCase() === "bt") BluetoothControlService.togglePower()
        else root.pushLog("error: toggle target must be 'bt'", "error")
    }
}
