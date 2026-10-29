// velocity.clipboard — built-in overlay, a lazy wrapper over components/ClipboardPicker.qml.
// The window is built on FIRST open and kept warm (overlay contract:
// shown / open / close / toggle — the plugin host claims the popup slot).
// Reached via `qs -c bar ipc call clipboard toggle` (thin forwarder in
// shell.qml) or `plugins call velocity.clipboard toggle ""`.
//
// Tool probe: one `cliphist list` at mount (exit 0 = present AND the store
// opens; 127 = absent). Missing cliphist/wl-clipboard → the picker never
// instantiates and every verb no-ops, logged once — the fastfetch/
// powerprofilesctl degrade, not a wired-but-dead feature.
//
// Capture watcher: `wl-paste --watch cliphist store` arms here on the FIRST
// open and lives for the bar session (a store that only ran while the picker
// was open would only capture copies made while the picker was open — the
// J8 ledger documents this deviation from the spec's letter). Arming lives
// in the wrapper, not the picker, so capture is plugin-lifecycle, not
// window-instance, state.
import QtQuick
import Quickshell.Io
import "../../components" as Components

Item {
    id: root
    property var ctx: null

    // tool probe: one-shot at mount; without cliphist/wl-paste the overlay is inert
    property bool supported: false

    readonly property bool shown: loader.item ? loader.item.shown : false
    property bool _wanted: false

    function open()   { if (!root.supported) return; root._arm(); if (loader.item) loader.item.open(); else root._wanted = true }
    function close()  { if (loader.item) loader.item.close() }
    function toggle() {
        if (!root.supported) return
        root._arm()
        if (loader.item) loader.item.toggle(); else root._wanted = true
    }
    function _arm() { if (!watcher.running) watcher.running = true }

    Process {   // unbounded-ok: one-shot tool probe at mount
        id: probe
        command: ["sh", "-c", "cliphist list >/dev/null 2>&1 && wl-paste --help >/dev/null 2>&1"]
        running: true
        onExited: function(code, status) {
            root.supported = (code === 0)
            if (code !== 0)
                console.log("[velocity.clipboard] cliphist/wl-paste not found — picker disabled " +
                            "(add wl-clipboard + cliphist in omni-nix)")
        }
    }

    Process {   // unbounded-ok: long-lived clipboard capture watcher, armed at first open
        id: watcher
        command: ["wl-paste", "--watch", "cliphist", "store"]
        running: false
        onExited: function(code, status) {
            if (code !== 0 && root.supported)   // probe passed, so a nonzero exit is real damage
                console.warn("[velocity.clipboard] store watcher exited " + code +
                             " — capture stopped until the picker is reopened")
        }
    }

    Loader {
        id: loader
        active: root._wanted
        sourceComponent: Component { Components.ClipboardPicker { } }
        onLoaded: item.open()
    }
}
