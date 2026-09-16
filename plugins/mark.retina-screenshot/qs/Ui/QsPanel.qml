// =============================================================================
// qs.Ui/Panel.qml — compat panel BASE for Quattro-style panel plugins.
// =============================================================================
// Full-screen transparent overlay window. Derived plugin files extend this
// (`Panel { ... }` after the import rewrite) and place their own card
// (usually compat KeyboardPanel) inside. Provides the API surface their
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
    property string _storeRaw: "{}"
    function setting(key, def) {
        try {
            var j = JSON.parse(_storeRaw)
            var v = j && j[moduleName] ? j[moduleName][key] : undefined
            return v === undefined ? def : v
        } catch (e) { return def }
    }
    function persistSetting(key, value) {
        try {
            var j = JSON.parse(_storeRaw || "{}")
            if (!j[moduleName]) j[moduleName] = {}
            j[moduleName][key] = value
            _storeRaw = JSON.stringify(j)
            storeWriter.command = ["sh", "-c",
                "mkdir -p ~/.cache/quickshell && printf '%s' '" + _storeRaw.replace(/'/g, "'\\''") +
                "' > ~/.cache/quickshell/qs-compat-store.json"]
            storeWriter.running = true
        } catch (e) { /* ignore */ }
    }
    FileView {
        id: storeFile
        path: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.cache/quickshell/qs-compat-store.json"
        watchChanges: false
        printErrors: false
        onLoaded: panelRoot._storeRaw = text() || "{}"
    }
    Component.onCompleted: storeFile.reload()
    Process {
        id: storeWriter
        command: []; running: false
    }

    // Backdrop: click anywhere outside their content closes the panel.
    MouseArea { anchors.fill: parent; onClicked: panelRoot.close() }
}
