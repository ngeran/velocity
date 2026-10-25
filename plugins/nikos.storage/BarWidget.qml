// =============================================================================
// nikos.storage — RIGHT-slot plugin (plugin api 2)
// =============================================================================
// Drive pill: nerd drive glyph at rest, used-% slides out on hover; click
// toggles the STORAGE panel (upstream-Ryoku StoragePanel adaptation). Pill
// tint follows the root used-% past the warnThreshold setting (error at 95).
// =============================================================================
import QtQuick
import QtQuick.Layouts
import qs.Ui
import "lib/storage.mjs" as St
import "." as Storage

Item {
    id: root

    property var ctx: null

    // Panel opens funnel the singleton's 30 s gate (multi-monitor dedupe).
    Connections {
        target: panel
        function onOpenedChanged() { if (panel.opened) Storage.StorageService.panelOpened() }
    }

    // Host IPC (plugins summon/hide) routes through these.
    function toggle() { panel.toggle() }
    function open()   { panel.open() }
    function close()  { panel.close() }

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.height

    BarPill {
        id: pill
        ctx: root.ctx
        icon: St.nerdFor("hdd")
        label: Storage.StorageService.percent >= 0
               ? Storage.StorageService.percent + "%" : "—"
        active: panel.opened
        restColor: {
            if (!root.ctx) return "#888"
            var c = root.ctx.theme.colors
            var p = Storage.StorageService.percent
            if (p < 0) return root.ctx.bar.colorText
            if (p >= 95) return c.error
            if (p >= Storage.StorageService.warnThreshold) return c.warning
            return root.ctx.bar.colorText
        }
        onClicked: function(button) { if (button === Qt.LeftButton) panel.toggle() }
    }

    // ── STORAGE POPUP — upstream StoragePanel adaptation ────────────────────
    PluginPopup {
        id: panel
        ctx: root.ctx
        anchorItem: root
        title: "STORAGE"
        icon: St.nerdFor("hdd")
        contentWidth: 564

        Loader {
            id: panelLoader
            // The LOADER is the layout child — stretch it here or the body
            // computes its rows from a stale intrinsic width.
            Layout.fillWidth: true
            active: root.ctx !== null
            source: Qt.resolvedUrl("StoragePanel.qml")
            onLoaded: item.ctx = root.ctx
            onStatusChanged: if (status === Loader.Error) console.log("[nikos.storage] panel failed to load")
        }
    }
}
