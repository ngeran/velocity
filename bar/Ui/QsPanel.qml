// =============================================================================
// qs.Ui/Panel.qml — compat panel BASE for Quattro-style panel plugins.
// =============================================================================
// Full-screen transparent overlay window. Derived plugin files extend this
// (`Panel { ... }` after the import rewrite) and place their own card
// inside. Provides the API surface their
// bodies reference: opened, open/close/toggle, controller{show,hide},
// setting(key, default), fittedContentWidth/Height, bar identity.
// The backdrop closes the panel on click-outside.
// =============================================================================
import QtQuick
import Qt.labs.platform
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../Commons"

PanelWindow {
    id: panelRoot

    property string moduleName: ""
    property string ipcTarget: ""
    property bool manageIpc: false

    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: 26
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    WlrLayershell.namespace: "qs-panel-" + moduleName
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: opened || fading
    property bool opened: false
    // Upstream had an internal `card` id to fade; the compat QsPanel has no
    // card — derived panels place their own — so there is nothing to fade
    // and the popup hides instantly. (Referencing `card` here used to throw
    // "card is not defined" at every panel creation.)
    readonly property bool fading: false

    // ── compat bar identity ──────────────────────────────────────────────────
    // Writable: derived widgets' injectPanel() assigns `target.bar = root.bar`
    // back onto this object (identity swap) — readonly made that throw.
    property var bar: compatBar
    QtObject {
        id: compatBar
        readonly property color foreground: Theme.colors.text
        readonly property color barForeground: Theme.colors.text
        readonly property string fontFamily: "monospace"
        readonly property int fontSize: 12
        property bool centerHoverRevealSuppressed: false
        function run(cmd) {
            barRunner.command = ["sh", "-c", cmd]
            barRunner.running = true
        }
    }

    // ── lifecycle ────────────────────────────────────────────────────────────
    function open() {
        opened = true
        if (typeof refresh === "function") refresh()
    }
    function close() { opened = false }
    function toggle() { opened = !opened }

    // Quattro panels route their open()/close() through the controller.
    readonly property QtObject controller: QtObject {
        function show() { panelRoot.open() }
        function hide() { panelRoot.close() }
    }

    // ── sizing helpers (Quattro panel API) ───────────────────────────────────
    function fittedContentWidth(w) { return w + 24 }
    function fittedContentHeight(h) { return h + 24 }

    // ── per-module settings store ────────────────────────────────────────────
    // `settings` is the upstream in-memory map widgets inject onto the panel
    // (their persist functions write it); setting() prefers it over the JSON
    // store so toggles take effect immediately in the live binding.
    property var settings: ({})
    // One file per module (qs-compat/<moduleName>.json, flat key → value):
    // the old shared qs-compat-store.json was rewritten whole from each
    // panel's snapshot, so panels clobbered each other's keys. The legacy
    // file is still read once as a fallback for values saved before.
    readonly property string _cacheDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.cache/quickshell"
    readonly property bool _storable: /^[A-Za-z0-9._-]+$/.test(moduleName)
    property var _store: ({})
    property var _legacy: ({})
    function setting(key, def) {
        if (settings !== null && settings[key] !== undefined) return settings[key]
        if (_store[key] !== undefined) return _store[key]
        return _legacy[key] !== undefined ? _legacy[key] : def
    }
    function persistSetting(key, value) {
        if (!_storable) return
        var next = Object.assign({}, _store)
        next[key] = value
        _store = next
        var path = _cacheDir + "/qs-compat/" + moduleName + ".json"
        // Path + JSON ride as argv (no quoting); tmp + mv = atomic replace.
        storeWriter.command = ["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"',
            "sh", path, JSON.stringify(next)]
        storeWriter.running = true
    }
    FileView {
        id: storeFile
        path: panelRoot._storable ? panelRoot._cacheDir + "/qs-compat/" + panelRoot.moduleName + ".json" : ""
        watchChanges: false
        printErrors: false
        onLoaded: {
            try { panelRoot._store = JSON.parse(text() || "{}") } catch (e) { panelRoot._store = {} }
        }
    }
    FileView {
        id: legacyStoreFile
        path: panelRoot._cacheDir + "/qs-compat-store.json"
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                var j = JSON.parse(text() || "{}")
                panelRoot._legacy = (j && j[panelRoot.moduleName]) || {}
            } catch (e) { panelRoot._legacy = {} }
        }
    }
    onModuleNameChanged: { storeFile.reload(); legacyStoreFile.reload() }
    Component.onCompleted: { storeFile.reload(); legacyStoreFile.reload() }
    Process {
        id: storeWriter
        command: []; running: false
    }

    // Backdrop: click anywhere outside their content closes the panel.
    MouseArea { anchors.fill: parent; onClicked: panelRoot.close() }
}
