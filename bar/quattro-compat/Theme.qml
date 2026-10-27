// =============================================================================
// quattro-compat/Theme.qml (was qs.Commons/Theme) — palette reader for the compat layer
// =============================================================================
// Reads ~/.cache/theme/colors.json directly (the canonical source the bar's
// ThemeConfig also reads) so the compat layer is theme-reactive WITHOUT
// importing the host's config dirs — a cross-directory singleton import would
// fork instances and desync colors. The intake PATTERN therefore stays
// duplicated by necessity, but the seed and the math do not: both come from
// the shared theme-core module (same file bar/lib/theme-core.mjs that
// ThemeService and the bar's ThemeConfig use — DU4), so this palette can no
// longer drift from the canonical one:
//   • seed      = ThemeCore.DEFAULT_BUNDLE (was a divergent Tokyo Night set
//                 that only showed while colors.json was missing)
//   • normalize = ThemeCore.normalizeBundle (missing tokens fall back to the
//                 seed instead of rendering as undefined/black)
//   • clamp     = ThemeCore.clampOLED when the payload's metadata.oledClamp
//                 says so — without this the compat layer rendered BRIGHT
//                 surfaces the bar itself had clamped (QD-OLED doctrine gap).
// =============================================================================
pragma Singleton
import QtQuick
import Qt.labs.platform
import Quickshell.Io
import Quickshell
import "../lib/theme-core.mjs" as ThemeCore

// Item root (not QtObject): the FileView + Timer need the default child
// property, which QtObject does not provide.
Item {
    id: root
    visible: false

    readonly property string themeFilePath: (StandardPaths.writableLocation(StandardPaths.HomeLocation).toString() + "/.cache/theme/colors.json").replace("file://", "")
    property string _lastRaw: ""

    property var colors: ThemeCore.DEFAULT_BUNDLE

    function ingest(raw) {
        var text = (raw || "").trim()
        if (text.length === 0 || text === _lastRaw) return
        _lastRaw = text
        try {
            var data = JSON.parse(text)
            if (data && data.colors) {
                var next = ThemeCore.normalizeBundle(data.colors, ThemeCore.DEFAULT_BUNDLE)
                if (data.metadata && data.metadata.oledClamp !== undefined)
                    ThemeCore.clampOLED(next, !!data.metadata.oledClamp, ThemeCore.DEFAULT_BUNDLE)
                colors = next
            }
        } catch (e) { /* keep previous */ }
    }

    // QtObject has no default property — the poll timer must be an explicit
    // property, not a child object.
    // Slow backstop (60s, matching ThemeConfig's cadence): only matters for
    // external writers that tmp+mv without a nudge (theme CLI, matugen) —
    // watchChanges covers same-inode writes and the settings nudge covers
    // its own writes.
    property Timer ticker: Timer {
        interval: 60000
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
