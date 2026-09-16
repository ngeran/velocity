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
    property var settings: ({})
    property bool vertical: false

    readonly property var bar: barObj
    property var _store: ({})
    property bool _storeReady: false

    function setting(key, def) {
        return root._store[key] !== undefined ? root._store[key] : def
    }

    FileView {
        id: storeFile
        path: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.cache/quickshell/qs-compat-store.json"
        watchChanges: false
        printErrors: false
        onLoaded: {
            try { root._store = JSON.parse(text() || "{}") } catch (e) { root._store = {} }
            root._storeReady = true
        }
    }
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
    }

    Process {
        id: barRunProc
        command: []; running: false
    }
}
