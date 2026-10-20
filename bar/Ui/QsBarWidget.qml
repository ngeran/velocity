// =============================================================================
// qs.Ui/BarWidget.qml — compat BASE for Quattro bar-widget plugins.
// =============================================================================
// Derived plugin files declare `BarWidget { id: root; moduleName: "…" }` and
// get: setting(key, default) backed by a per-module JSON store, the `bar`
// identity object (colors/fonts/run()) their bodies reference, and a
// `settings` bucket. Self-contained: reads ~/.cache/theme/colors.json
// directly for theme reactivity (documented duplication of ThemeConfig).
// =============================================================================
import QtQuick
import Qt.labs.platform
import Quickshell
import Quickshell.Io
import "../Commons" as CT

Item {
    id: root

    property string moduleName: ""
    // Injected by the engine (api 2); shell verbs route through it.
    property var ctx: null
    property var settings: ({})
    property bool vertical: false

    readonly property var bar: barObj
    // Same per-module store QsPanel writes (qs-compat/<moduleName>.json).
    readonly property string _cacheDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.cache/quickshell"
    readonly property bool _storable: /^[A-Za-z0-9._-]+$/.test(moduleName)
    property var _store: ({})
    property bool _storeReady: false

    function setting(key, def) {
        return root._store[key] !== undefined ? root._store[key] : def
    }

    FileView {
        id: storeFile
        path: root._storable ? root._cacheDir + "/qs-compat/" + root.moduleName + ".json" : ""
        watchChanges: true
        printErrors: false
        onLoaded: {
            try { root._store = JSON.parse(text() || "{}") } catch (e) { root._store = {} }
            root._storeReady = true
        }
        onFileChanged: reload()
    }
    onModuleNameChanged: storeFile.reload()
    Component.onCompleted: storeFile.reload()

    QtObject {
        id: barObj
        readonly property color barForeground: CT.Theme.colors.text
        readonly property color foreground: CT.Theme.colors.text
        readonly property string fontFamily: "monospace"
        readonly property int fontSize: 12
        property bool centerHoverRevealSuppressed: false
        function run(cmd) {
            barRunProc.command = ["sh", "-c", cmd]
            barRunProc.running = true
        }
        // `bar.shell` — the omarchy surface converted bar-widgets call into
        // (xray: `bar.shell.toggle(moduleName, "{}")` from its launcher
        // button). Routed through the host's summon registries, which cover
        // widget plugins AND overlay plugins with one verb.
        readonly property var shell: shellObj
    }

    QtObject {
        id: shellObj
        // Routed through ctx (engine state is never touched from qs.Ui).
        function toggle(id, payload) { return root.ctx ? root.ctx.summon(id, payload || "{}") : "no ctx" }
        function summon(id, payload) { return root.ctx ? root.ctx.summon(id, payload || "{}") : "no ctx" }
        function hide(id) { return root.ctx ? root.ctx.hide(id) : "no ctx" }
    }

    Process {
        id: barRunProc
        command: []; running: false
    }
}
