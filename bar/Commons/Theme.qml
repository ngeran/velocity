// =============================================================================
// qs.Commons/Theme.qml — self-contained palette reader for the compat layer
// =============================================================================
// Reads ~/.cache/theme/colors.json directly (the canonical source the bar's
// ThemeConfig also reads) so the compat layer is theme-reactive WITHOUT
// importing the host's config dirs — a cross-directory singleton import would
// fork instances and desync colors. Deliberately duplicates ThemeConfig's
// intake pattern (watchChanges + forced reload).
// =============================================================================
pragma Singleton
import QtQuick
import Qt.labs.platform
import Quickshell.Io
import Quickshell

// Item root (not QtObject): the FileView + Timer need the default child
// property, which QtObject does not provide.
Item {
    id: root
    visible: false

    readonly property string themeFilePath: (StandardPaths.writableLocation(StandardPaths.HomeLocation).toString() + "/.cache/theme/colors.json").replace("file://", "")
    property string _lastRaw: ""

    property var colors: ({
        "background": "#000000", "surface": "#0a0a0a", "surfaceVariant": "#111111",
        "text": "#c0caf5", "textDim": "#a9b1d6", "border": "#292e42",
        "outline": "#414868", "outlineVariant": "#16161e",
        "primary": "#7aa2f7", "secondary": "#bb9af7", "accent": "#e75a50",
        "success": "#9ece6a", "warning": "#c5564a", "error": "#4a6b80",
        "info": "#7dcfff"
    })

    function ingest(raw) {
        var text = (raw || "").trim()
        if (text.length === 0 || text === _lastRaw) return
        _lastRaw = text
        try {
            var data = JSON.parse(text)
            if (data && data.colors) colors = data.colors
        } catch (e) { /* keep previous */ }
    }

    // QtObject has no default property — the poll timer must be an explicit
    // property, not a child object.
    property Timer ticker: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            themeFile.reload()
            root.ingest(themeFile.text())
        }
    }

    FileView {
        id: themeFile
        path: root.themeFilePath
        watchChanges: true
        printErrors: false
        onFileChanged: root.ingest(themeFile.text())
        onTextChanged: root.ingest(text())
        Component.onCompleted: root.ingest(themeFile.text())
    }
}
