/** Version: 1.0 - Gated live system-monitor telemetry for the monitor overlay **/
// =============================================================================
// SystemMonitorService.qml — live system-monitor data backbone
// =============================================================================
// Feeds the System Monitor overlay (process table + rates + temps). The overlay
// sets `active = true` on open and `false` on close; EVERY poll Process is gated
// on that flag via the timers' `running: root.active`, so nothing forks while
// the overlay is hidden (mirrors bar/services/SystemInfoService.qml active/
// liveTimer idiom and settings/services/SysInfoService.qml Process + SplitParser
// + Timer idiom).
//
//   STATIC (once, Component.onCompleted)
//     cpuModel + coreCount       grep /proc/cpuinfo
//   POLLS (only while active)
//     processes      2s          ps -eo ... --sort=-%cpu | head -15  → ListModel
//                                       (+ rolling cpuPct history[6] per pid)
//     ramCachedGB    2s          /proc/meminfo Cached:
//     perCoreClock   2s          /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq
//     processCount   5s          ps -e --no-headers | wc -l
//     perCoreTemp    5s          /sys/class/hwmon/*/temp*_input (Core N labels)
//     disks          5s          df -x tmpfs … --output=pcent,target (cap 4)
//     netDown/Up     1s (delta)  /proc/net/dev   (sum rx/tx, excl. lo)
//     diskReadRate   1s (delta)  /proc/diskstats (sectors_read × 512 → MiB/s)
//
// Every parse degrades gracefully (|| 0 / try-catch) — a missing or oddly
// shaped source never crashes the overlay. perCoreTemp + perCoreClock are always
// length == coreCount (fall back to ThermalService.cpuTemp / CoreEngineService.cpuGhz
// replicated) so the overlay's Repeaters stay stable.
//
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    // =========================================================================
    // PUBLIC CONTRACT  (overlay binds to these names — do not rename)
    // =========================================================================
    property bool active: false             // overlay drives this with shown-state
    property string cpuModel: ""            // "AMD Ryzen 7 7700X 8-Core Processor"
    property int coreCount: 0               // logical core count
    property var processes: processListModel  // ListModel: pid/user/comm/args/cpuPct/memPct/history
    property int processCount: 0            // total runnable processes
    property real netDownRate: 0            // bytes/sec
    property real netUpRate: 0              // bytes/sec
    property real diskReadRate: 0           // MiB/sec
    property real ramCachedGB: 0
    property var perCoreTemp: []            // array of °C ints, length == coreCount
    property var perCoreClock: []           // array of GHz reals, length == coreCount
    property var disks: diskListModel       // ListModel: mount(string)/pct(int), cap 4

    // =========================================================================
    // BACKING STATE
    // =========================================================================
    property real _netPrevRx: -1            // -1 = "no previous sample yet"
    property real _netPrevTx: -1
    property real _diskPrevSectors: -1
    property var _procHistory: ({})         // pid → rolling [cpuPct…] (max 6) for processes

    ListModel { id: processListModel }
    ListModel { id: diskListModel }         // disks contract: mount(string) + pct(int)

    Component.onCompleted: {
        // Static profile — read once, regardless of `active`.
        cpuModelProc.running = true
        coreCountProc.running = true
        console.log("[SystemMonitor] Service loaded")
    }

    // =========================================================================
// STATIC — CPU model name + logical core count (one-shot, Component.onCompleted)
    // =========================================================================
    Process {
        id: cpuModelProc
        command: ["sh", "-c", "grep -m1 '^model name' /proc/cpuinfo"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { cpuModelProc.buffer += data } }
        onRunningChanged: {
            if (!running && cpuModelProc.buffer.length > 0) {
                // Line looks like: "model name\t: AMD Ryzen 7 7700X 8-Core Processor"
                var raw = cpuModelProc.buffer.trim()
                var idx = raw.indexOf(":")
                if (idx >= 0) {
                    var name = raw.substring(idx + 1).trim()
                    if (name.length > 0) root.cpuModel = name
                }
                cpuModelProc.buffer = ""
            }
        }
    }

    Process {
        id: coreCountProc
        command: ["sh", "-c", "grep -c '^processor' /proc/cpuinfo"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { coreCountProc.buffer += data } }
        onRunningChanged: {
            if (!running && coreCountProc.buffer.trim().length > 0) {
                var n = parseInt(coreCountProc.buffer.trim(), 10)
                if (!isNaN(n) && n > 0) root.coreCount = n
                coreCountProc.buffer = ""
            }
        }
    }

    // =========================================================================
    // processes (2s) — top 15 by CPU%. Rebuild ListModel each cycle so it re-sorts.
    // =========================================================================
    Process {
        id: processesProc
        command: ["sh", "-c",
            "ps -eo pid,user,comm,%cpu,%mem,args --sort=-%cpu --no-headers | head -15"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { processesProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                var lines = processesProc.buffer.split("\n")
                processesProc.buffer = ""
                processListModel.clear()
                var currentPidSet = {}
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.length === 0) continue
                    var f = line.split(/\s+/)
                    if (f.length < 5) continue
                    var pid = (f[0] || "").trim()
                    var user = (f[1] || "").trim()
                    var comm = (f[2] || "").trim()
                    var cpuPct = parseFloat(f[3])
                    var memPct = parseFloat(f[4])
                    cpuPct = isNaN(cpuPct) ? 0 : cpuPct
                    memPct = isNaN(memPct) ? 0 : memPct
                    // args = remainder joined with spaces (contains spaces)
                    var args = f.length >= 6 ? f.slice(5).join(" ").trim() : ""
                    if (pid.length === 0) continue
                    // Per-process CPU history — rolling window of 6 samples.
                    var h = root._procHistory[pid] || []
                    h.push(cpuPct)
                    if (h.length > 6) h.shift()
                    root._procHistory[pid] = h
                    currentPidSet[pid] = true
                    processListModel.append({
                        pid: pid,
                        user: user,
                        comm: comm,
                        args: args,
                        cpuPct: cpuPct,
                        memPct: memPct,
                        history: h
                    })
                }
                // Prune stale pids so _procHistory can't grow unbounded.
                for (var k in root._procHistory) {
                    if (!(k in currentPidSet)) delete root._procHistory[k]
                }
            }
        }
    }

    // =========================================================================
    // ramCachedGB (2s) — /proc/meminfo Cached: kB → GB ÷ 1048576
    // =========================================================================
    Process {
        id: meminfoProc
        command: ["sh", "-c", "grep '^Cached:' /proc/meminfo"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { meminfoProc.buffer += data } }
        onRunningChanged: {
            if (!running && meminfoProc.buffer.length > 0) {
                // "Cached:          2614012 kB"
                var m = meminfoProc.buffer.match(/Cached:\s+(\d+)/)
                if (m) {
                    var kb = parseInt(m[1], 10)
                    if (!isNaN(kb) && kb >= 0)
                        root.ramCachedGB = Math.round(kb / 1048576 * 100) / 100
                }
                meminfoProc.buffer = ""
            }
        }
    }

    // =========================================================================
    // perCoreClock (2s) — /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq
    // kHz ÷ 1e6 → GHz (2 decimals). Padded/tiled to coreCount; falls back to
    // CoreEngineService.cpuGhz replicated when no readings exist. Length always
    // == coreCount (or [] when coreCount == 0) for Repeater stability.
    // =========================================================================
    Process {
        id: clockProc
        command: ["sh", "-c", "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { clockProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                var lines = clockProc.buffer.split("\n")
                clockProc.buffer = ""
                var cc = root.coreCount
                if (cc <= 0) { root.perCoreClock = []; return }
                var vals = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.length === 0) continue
                    var khz = parseInt(line, 10)
                    if (isNaN(khz) || khz <= 0) continue
                    vals.push(Math.round(khz / 1e6 * 100) / 100)
                }
                if (vals.length === 0) {
                    // No per-core readings — pad with CoreEngineService.cpuGhz.
                    var fb = 0
                    try { fb = CoreEngineService.cpuGhz || 0 } catch (e) { fb = 0 }
                    var rep = []
                    for (var j = 0; j < cc; j++) rep.push(fb)
                    root.perCoreClock = rep
                    return
                }
                // Pad (repeat last) or truncate to coreCount.
                var out = []
                for (var k = 0; k < cc; k++) {
                    out.push(k < vals.length ? vals[k] : vals[vals.length - 1])
                }
                root.perCoreClock = out
            }
        }
    }

    // 2s poll — processes + cached RAM + per-core clocks
    Timer {
        id: slowTimer
        interval: 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            processesProc.running = true
            meminfoProc.running = true
            clockProc.running = true
        }
    }

    // =========================================================================
    // processCount (5s) — ps -e --no-headers | wc -l
    // =========================================================================
    Process {
        id: processCountProc
        command: ["sh", "-c", "ps -e --no-headers | wc -l"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { processCountProc.buffer += data } }
        onRunningChanged: {
            if (!running && processCountProc.buffer.trim().length > 0) {
                var n = parseInt(processCountProc.buffer.trim(), 10)
                if (!isNaN(n) && n >= 0) root.processCount = n
                processCountProc.buffer = ""
            }
        }
    }

    // =========================================================================
    // perCoreTemp (5s) — best-effort per-core hwmon read.
    // Collects coretemp "Core N" labels (Intel); k10temp (AMD) exposes none, so
    // the per-core parse usually returns nothing and we fall back to
    // ThermalService.cpuTemp replicated coreCount times. perCoreTemp length is
    // always == coreCount (or [] when coreCount == 0) for Repeater stability.
    // =========================================================================
    Process {
        id: tempProc
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do " +
            "n=$(cat \"$d/name\" 2>/dev/null); " +
            "case \"$n\" in coretemp|k10temp) " +
            "for i in $(seq 1 32); do " +
            "l=$(cat \"$d/temp${i}_label\" 2>/dev/null); " +
            "v=$(cat \"$d/temp${i}_input\" 2>/dev/null); " +
            "case \"$l\" in 'Core '*) [ -n \"$v\" ] && printf '%s %s\\n' \"${l#Core }\" \"$v\";; esac; " +
            "done;; esac; done"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { tempProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                var lines = tempProc.buffer.split("\n")
                tempProc.buffer = ""
                // Collect {idx, value} pairs from "N milliC" lines.
                var pairs = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.length === 0) continue
                    var f = line.split(/\s+/)
                    if (f.length < 2) continue
                    var idx = parseInt(f[0], 10)
                    var milli = parseInt(f[1], 10)
                    if (isNaN(idx) || isNaN(milli)) continue
                    pairs.push({ idx: idx, value: Math.round(milli / 1000) })
                }
                root._applyPerCoreTemp(pairs)
            }
        }
    }

    // Resolve perCoreTemp from collected pairs; fall back to ThermalService.cpuTemp
    // replicated. Always emits length == coreCount (or [] when coreCount == 0).
    function _applyPerCoreTemp(pairs) {
        var cc = root.coreCount
        if (cc <= 0) { root.perCoreTemp = []; return }

        // Sort by core index so the array is in physical order.
        pairs.sort(function (a, b) { return a.idx - b.idx })

        if (pairs.length >= cc) {
            // Have at least coreCount per-core readings — take first cc.
            var out = []
            for (var i = 0; i < cc; i++) out.push(pairs[i].value)
            root.perCoreTemp = out
            return
        }
        if (pairs.length > 0) {
            // Partial set (e.g. SMT box reports only physical cores) — tile to cc.
            var tiled = []
            for (var j = 0; j < cc; j++) tiled.push(pairs[j % pairs.length].value)
            root.perCoreTemp = tiled
            return
        }

        // No per-core readings (typical on AMD k10temp) → fall back to package temp.
        var fb = 0
        try { fb = Math.round(ThermalService.cpuTemp || 0) } catch (e) { fb = 0 }
        var rep = []
        for (var k = 0; k < cc; k++) rep.push(fb)
        root.perCoreTemp = rep
    }

    // =========================================================================
    // disks (5s) — df filesystem usage. Excludes pseudo fs types, skips virtual
    // mount points (/run, /dev, /proc, /sys, /var/lib/docker, /boot/efi), caps
    // at 4 entries. Each row: { mount: short-label, pct: int }.
    // =========================================================================
    Process {
        id: diskUsageProc
        command: ["sh", "-c",
            "df -x tmpfs -x devtmpfs -x squashfs -x overlay --output=pcent,target -l 2>/dev/null"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { diskUsageProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                var lines = diskUsageProc.buffer.split("\n")
                diskUsageProc.buffer = ""
                diskListModel.clear()
                var count = 0
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.length === 0) continue
                    // Expected: "NN% /mount" (skip the "Use% Mounted on" header).
                    var m = line.match(/^(\d+)%\s+(.+)$/)
                    if (!m) continue
                    var pct = parseInt(m[1], 10)
                    if (isNaN(pct)) pct = 0
                    var mount = (m[2] || "").trim()
                    if (mount.length === 0) continue
                    // Skip pseudo / virtual mount points.
                    if (/^\/(run|dev|proc|sys)(\/|$)/.test(mount)) continue
                    if (mount.indexOf("/var/lib/docker") === 0) continue
                    if (mount.indexOf("/boot/efi") === 0) continue
                    if (count >= 4) break
                    // Short label: "/" → ROOT, else basename uppercased (~8 chars).
                    var label
                    if (mount === "/") {
                        label = "ROOT"
                    } else {
                        var base = mount.substring(mount.lastIndexOf("/") + 1) || mount
                        label = base.toUpperCase()
                        if (label.length > 8) label = label.substring(0, 8)
                    }
                    diskListModel.append({ mount: label, pct: pct })
                    count++
                }
            }
        }
    }

    // 5s poll — process count + per-core temps + disk usage
    Timer {
        id: infoTimer
        interval: 5000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            processCountProc.running = true
            tempProc.running = true
            diskUsageProc.running = true
        }
    }

    // =========================================================================
    // net rates (1s, DELTA) — /proc/net/dev summed across ifaces except lo.
    // First sample just primes _netPrevRx/_netPrevTx; rates stay 0.
    // =========================================================================
    Process {
        id: netProc
        command: ["sh", "-c", "cat /proc/net/dev"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { netProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                var lines = netProc.buffer.split("\n")
                netProc.buffer = ""
                var rxTot = 0, txTot = 0
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    var c = line.indexOf(":")
                    if (c < 0) continue
                    var iface = line.substring(0, c).trim()
                    if (!iface || iface === "lo") continue
                    var f = line.substring(c + 1).trim().split(/\s+/)
                    if (f.length < 16) continue
                    var rx = parseInt(f[0], 10)
                    var tx = parseInt(f[8], 10)
                    rxTot += isNaN(rx) ? 0 : rx
                    txTot += isNaN(tx) ? 0 : tx
                }
                if (root._netPrevRx < 0 || root._netPrevTx < 0) {
                    root.netDownRate = 0
                    root.netUpRate = 0
                } else {
                    var dr = rxTot - root._netPrevRx
                    var du = txTot - root._netPrevTx
                    root.netDownRate = dr > 0 ? dr : 0
                    root.netUpRate = du > 0 ? du : 0
                }
                root._netPrevRx = rxTot
                root._netPrevTx = txTot
            }
        }
    }

    // =========================================================================
    // diskReadRate (1s, DELTA) — /proc/diskstats sectors_read summed across all
    // whole block devices (excludes partitions nvme0n1p1, sda1, …, and loop/ram/
    // zram/fd/sr/md/dm). delta_sectors × 512 bytes → MiB/s.
    // =========================================================================
    Process {
        id: diskProc
        command: ["sh", "-c", "cat /proc/diskstats"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { diskProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                var lines = diskProc.buffer.split("\n")
                diskProc.buffer = ""
                var sectors = 0
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.length === 0) continue
                    var f = line.split(/\s+/)
                    if (f.length < 6) continue
                    var name = (f[2] || "")
                    // Skip virtual / removable / software-RAID devices.
                    if (/^(loop|ram|zram|fd|sr|md|dm)/.test(name)) continue
                    // Skip partitions: nvme0n1p1, mmcblk0p1, sda1, sdb12, …
                    if (/p\d+$/.test(name)) continue
                    if (/^sd[a-z]+\d+$/.test(name)) continue
                    var s = parseInt(f[5], 10)
                    sectors += isNaN(s) ? 0 : s
                }
                if (root._diskPrevSectors < 0) {
                    root.diskReadRate = 0
                } else {
                    var dSec = sectors - root._diskPrevSectors
                    if (dSec > 0) {
                        var bytes = dSec * 512
                        root.diskReadRate = Math.round(bytes / 1048576 * 100) / 100
                    } else {
                        root.diskReadRate = 0
                    }
                }
                root._diskPrevSectors = sectors
            }
        }
    }

    // 1s poll — network rates + disk read rate (deltas, ~1s cadence)
    Timer {
        id: fastTimer
        interval: 1000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netProc.running = true
            diskProc.running = true
        }
    }
}
