// =============================================================================
// StorageService — plugin-internal qmldir singleton (nikos.storage)
// =============================================================================
// Drive inventory for the storage panel + the bar pill's used-%. Lives INSIDE
// the plugin (WeatherService pattern) because bar services are invisible to
// plugins — they only see ctx.
//
//   • Pure parsing lives in lib/storage.mjs (node-tested); this file is only
//     the fetch wrapper.
//   • ONE lsblk probe covers everything (per-drive class, mounts, usage) —
//     no df side-channel: upstream polls df only to refresh its pill between
//     lsblk cycles; our cadence is unified.
//   • Cold cadence: refresh at mount, on every panel open (30 s min-interval
//     gate), plus one 10-min tick from Service.qml — lsblk is a ~5 ms local
//     fork, so the pill's % and warn tint stay truthful all day for ~0.001%
//     duty (colder than the island's 30 s burn-guard precedent).
//   • No state cache: drives need no offline memory.
//
// Configured by Service.qml (entryPoints.service) — views never configure.
// Consumed by BarWidget/StoragePanel via `import "." as Storage`.
// =============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/storage.mjs" as St

Item {
    id: root

    // ── settings (pushed by Service.qml from ctx.settings) ──────────────────
    property int warnThreshold: 85

    // ── inventory state ──────────────────────────────────────────────────────
    property var drives: []
    property bool available: false
    property date lastFetch: new Date(0)
    readonly property int _minIntervalMs: 30 * 1000

    readonly property bool busy: _busy

    // ── derived, pill- and panel-facing ──────────────────────────────────────
    readonly property var rootDrive: St.findRoot(root.drives)
    readonly property int percent: rootDrive && rootDrive.percent >= 0 ? rootDrive.percent : -1
    readonly property double usedBytes:  rootDrive && rootDrive.usedBytes  >= 0 ? rootDrive.usedBytes  : 0
    readonly property double freeBytes:  rootDrive && rootDrive.freeBytes  >= 0 ? rootDrive.freeBytes  : 0
    readonly property double totalBytes: rootDrive && rootDrive.totalBytes >= 0 ? rootDrive.totalBytes : 0

    // ── public API ───────────────────────────────────────────────────────────
    function configure(values) {
        var v = values || {}
        var w = (typeof v.warnThreshold === "number") ? Math.round(v.warnThreshold) : 85
        root.warnThreshold = Math.max(50, Math.min(95, w))
    }

    // Called by the BarWidget when a storage panel opens (per-output panels
    // funnel here; the 30 s gate dedupes multi-monitor opens).
    function panelOpened() {
        if (root._busy) return
        var age = new Date() - root.lastFetch
        if (root.available && age >= 0 && age < root._minIntervalMs) return
        root.refresh()
    }

    function refresh() {
        if (root._busy) return
        root._busy = true
        root._buf = ""
        lsblkProc.command = ["lsblk", "-J", "-b",
            "-o", "NAME,TYPE,SIZE,FSTYPE,FSUSED,FSAVAIL,FSUSE%,MOUNTPOINTS,MODEL,TRAN,ROTA,RM,HOTPLUG"]
        lsblkProc.running = true
    }

    function _ingest(json) {
        var inv = St.parseInventory(json)
        root.drives = inv.drives
        root.available = inv.available
        root.lastFetch = new Date()
    }

    function _fail(reason) {
        root._busy = false
        console.log("[nikos.storage] lsblk failed: " + reason)
    }

    property bool _busy: false
    property string _buf: ""

    // ── lsblk probe ──────────────────────────────────────────────────────────
    Process {
        id: lsblkProc   // unbounded-ok: one-shot local probe, killed by a 10s watchdog

        stdout: SplitParser {
            onRead: data => { root._buf += data + "\n" }
        }

        onRunningChanged: {
            if (lsblkProc.running) { _lsblkWatch.restart(); return }
            _lsblkWatch.stop()
            if (!root._busy) return   // watchdog kill — already failed
            var json = St.parseJson(root._buf)
            root._buf = ""
            if (json) {
                root._ingest(json)
                root._busy = false
            } else {
                root._fail("lsblk returned no JSON")
            }
        }
    }

    Timer {
        id: _lsblkWatch
        interval: 10000
        onTriggered: {
            if (!lsblkProc.running) return
            root._busy = false        // onRunningChanged skips the dead fetch
            lsblkProc.running = false
            root._fail("lsblk timeout")
        }
    }
}
