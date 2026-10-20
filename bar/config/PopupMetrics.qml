// =============================================================================
// bar/config/PopupMetrics.qml — popup/dashboard scale token singleton
// =============================================================================
//
// px(n) applies uiScale and rounds, so every migrated value equals its old
// literal at the default scale 1.0 — migrating a popup (TrayCard,
// NotificationCenter, overlays) means replacing its pixel literals with
// Pm.px(n) (one-off derivations may use `Pm.s` directly). Optional key
// "uiScale" (0.75–2.0) is read from bar-config.json through the same
// zero-fork FileView intake MotionConfig uses — same file, so one write
// updates both.
//
// Bounded popups (unlike the bar strip) are where extra DPI headroom pays
// off; the bar itself scales through BarConfig._contentScale instead.
//
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

Item {
    id: root
    visible: false

    property real uiScale: 1.0
    // Shorthand for bindings: `width: Pm.s * 320` etc. Read-only mirror.
    readonly property real s: root.uiScale

    function px(n) {
        return Math.round((Number(n) || 0) * root.uiScale)
    }

    // Hairlines snap to whole device pixels: a logical 1px line at a fractional
    // scale (1.25 / 1.5) straddles two device pixels and anti-aliases into a
    // soft band, while 1/dpr is the thinnest crisp line the output can draw.
    // Falls back to exactly 1 when the item has no screen (unmounted window)
    // or the scale is integral, so 1.0-scale rendering is unchanged. `item` is
    // any Item the hairline lives in (all items in a window share one screen).
    function hairline(item) {
        var dpr = 0
        if (item && item.Screen) dpr = item.Screen.devicePixelRatio
        return (isFinite(dpr) && dpr > 0) ? 1 / dpr : 1
    }

    // ── optional user keys from bar-config.json (zero-fork intake) ──────────
    readonly property string configPath: (StandardPaths.writableLocation(StandardPaths.HomeLocation).toString() + "/.config/quickshell/bar-config.json").replace("file://", "")
    property string _lastRaw: ""

    function ingestPopupText(raw) {
        var text = (raw || "").trim()
        if (text.length === 0 || text === root._lastRaw) return
        root._lastRaw = text
        try {
            var data = JSON.parse(text)
            if (data.uiScale !== undefined) {
                var s = Number(data.uiScale)
                if (isFinite(s) && s >= 0.75 && s <= 2.0) root.uiScale = s
            }
        } catch (e) {
            // mid-write or foreign JSON — keep current values
        }
    }

    FileView {
        id: popupFile
        path: root.configPath
        watchChanges: true
        printErrors: false
        onFileChanged: root.ingestPopupText(popupFile.text())
        onTextChanged: root.ingestPopupText(text())
        Component.onCompleted: root.ingestPopupText(popupFile.text())
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            popupFile.reload()
            root.ingestPopupText(popupFile.text())
        }
    }
}
