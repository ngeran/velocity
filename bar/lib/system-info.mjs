// =============================================================================
// system-info.mjs — pure parsing for SystemInfoService (I8 split)
// =============================================================================
// Every parser the SYSTEM INFO pipeline needs, as plain functions over text:
// fastfetch's --format json profile, the /proc live-metrics read, nvidia-smi
// CSV rows, DMI board identity, and the geo lookup. The service stays IO +
// state (Processes, lease, metrics file); this file owns all formatting and
// field extraction. Patches carry `undefined` for "block absent" so the
// service can keep its previous value — exactly the old inline guards.
// =============================================================================

export function formatGiB(bytes) {
    return (Math.round((bytes || 0) / 1073741824 * 100) / 100).toFixed(2) + " GiB"
}

export function formatBest(bytes) {
    var b = bytes || 0
    if (b >= 1099511627776) return (Math.round(b / 1099511627776 * 100) / 100).toFixed(2) + " TiB"
    return (Math.round(b / 1073741824 * 100) / 100).toFixed(2) + " GiB"
}

export function formatUptime(sec) {
    var s = Math.max(0, Math.floor(sec || 0))
    if (s < 60) return s + "s"
    var m = Math.floor(s / 60)
    if (m < 60) return m + "m " + (s % 60) + "s"
    var h = Math.floor(m / 60)
    if (h < 24) return h + "h " + (m % 60) + "m"
    var d = Math.floor(h / 24)
    return d + "d " + (h % 24) + "h"
}

// Filter out generic placeholder board names SMBIOS leaves when unset.
export function cleanBoardName(s) {
    if (!s) return ""
    var low = s.toLowerCase().trim()
    var junk = ["default string", "to be filled by o.e.m.",
                "to be filled by o.e.m", "base board product name",
                "system product name", "system board product name",
                "not specified", "unknown", "none"]
    if (junk.indexOf(low) >= 0) return ""
    return s.trim()
}

// Extract a chipset code: optional A/B/X/H/Z prefix, 3 digits, optional -?E
// suffix. Covers AMD (X870E, B650E, A620, X670, B550…) and Intel (Z790, B760…).
export function parseChipset(s) {
    if (!s) return ""
    var m = s.match(/[ABXHZ]\d{3}-?E?/i)
    if (!m) return ""
    return m[0].replace("-", "").toUpperCase()
}

export function findBlock(arr, type) {
    for (var i = 0; i < arr.length; i++) {
        if (arr[i].type === type) return arr[i].result
    }
    return null
}

// fastfetch --format json → profile patch. Throws on malformed JSON (the
// caller's try/catch decides what "keep old values" means). `nowMs` feeds the
// OS-age math so the function stays pure.
export function parseFastfetch(raw, nowMs) {
    var data = JSON.parse(raw)
    var patch = {}

    var title = findBlock(data, "Title")
    if (title) {
        patch.userName = title.userName || ""
        patch.hostName = title.hostName || ""
    }
    var cpu = findBlock(data, "CPU")
    if (cpu) {
        patch.cpuModel = cpu.cpu || "—"
        patch.cpuThreads = (cpu.cores && cpu.cores.logical) ? cpu.cores.logical : 0
        patch.cpuMaxGhz = (cpu.frequency && cpu.frequency.max) ? cpu.frequency.max / 1000 : 0
    }
    var gpu = findBlock(data, "GPU")
    if (gpu && gpu.length > 0) {
        patch.gpuName = gpu[0].name || "—"
        patch.gpuDriver = gpu[0].driver || ""
        patch.gpuType = gpu[0].type || ""
        patch.gpuVendor = gpu[0].vendor || ""
    }
    var mem = findBlock(data, "Memory")
    if (mem && mem.total) patch.memTotalGiB = Math.round(mem.total / 1073741824 * 100) / 100

    var os = findBlock(data, "OS")
    if (os) {
        patch.osName = os.name || ""
        patch.osCodename = os.codename || ""
        patch.osVersion = os.versionID || ""
    }
    var ker = findBlock(data, "Kernel")
    if (ker) {
        patch.kernelName = ker.name || ""
        patch.kernelRelease = ker.release || ""
        patch.arch = ker.architecture || ""
    }
    var pkgs = findBlock(data, "Packages")
    if (pkgs) {
        patch.pkgAll = pkgs.all || 0
        patch.pkgSystem = pkgs.nixSystem || 0
        patch.pkgUser = pkgs.nixUser || 0
    }

    var diskArr = findBlock(data, "Disk")
    if (diskArr && diskArr.length !== undefined) {
        var out = []
        var rootCreated = ""
        for (var i = 0; i < diskArr.length; i++) {
            var d = diskArr[i]
            // skip subvolumes / read-only (e.g. /nix/store dup of /)
            var isRegular = true
            if (d.volumeType && d.volumeType.length > 0) {
                isRegular = false
                for (var v = 0; v < d.volumeType.length; v++) {
                    if (d.volumeType[v] === "Regular") { isRegular = true; break }
                }
            }
            if (!isRegular) continue
            if (!d.bytes || !d.bytes.total) continue
            if (out.length >= 5) break   // bound the list so the card can't overflow
            var pct = Math.round(d.bytes.used / d.bytes.total * 100)
            var createdDate = d.createTime ? d.createTime.substring(0, 10) : ""
            out.push({
                dev: d.mountFrom || d.mountpoint || "—",
                mount: d.mountpoint || "",
                usedLabel: formatGiB(d.bytes.used),
                totalLabel: formatBest(d.bytes.total),
                pct: pct
            })
            if (d.mountpoint === "/" && createdDate) rootCreated = createdDate
        }
        patch.disks = out
        if (rootCreated) {
            patch.installDate = rootCreated
            var p = rootCreated.split("-")
            if (p.length === 3) {
                var createdMs = Date.UTC(+p[0], +p[1] - 1, +p[2])
                patch.osAgeDays = Math.max(0, Math.floor((nowMs - createdMs) / 86400000))
            }
        }
    }
    return patch
}

// /proc/meminfo + /proc/uptime + /proc/stat cpu line + `df -kP /` → live
// patch. prevBusy/prevTotal come from the previous tick; cpuPct publishes only
// once a baseline exists (the first tick's since-boot average must not leak
// out as a percentage), and the cumulative counters are always echoed back so
// the caller can store them for the next tick.
export function parseLiveMetrics(text, prevBusy, prevTotal) {
    var lines = text.split("\n")
    var memTotal = 0, memAvail = 0, up = 0
    var patch = { prevBusy: prevBusy, prevTotal: prevTotal }
    for (var i = 0; i < lines.length; i++) {
        var ln = lines[i]
        var mt = ln.match(/^MemTotal:\s+(\d+)/)
        if (mt) { memTotal = parseInt(mt[1], 10); continue }
        var ma = ln.match(/^MemAvailable:\s+(\d+)/)
        if (ma) { memAvail = parseInt(ma[1], 10); continue }
        var uu = ln.match(/^(\d+\.\d+)\s+\d+\.\d+/)
        if (uu) up = parseFloat(uu[1])
        // cumulative CPU jiffies (H7: cross-process cpu.pct)
        var cs = ln.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
        if (cs) {
            var user = +cs[1], nice = +cs[2], sys = +cs[3], idle = +cs[4]
            var iow = +cs[5], irq = +cs[6], sirq = +cs[7], steal = +cs[8]
            var busy = user + nice + sys + irq + sirq + steal
            var total = busy + idle + iow
            var dBusy = busy - prevBusy
            var dTotal = total - prevTotal
            // First tick after start has no baseline (prev* are 0):
            // publishing then would emit the since-boot average as cpu.pct.
            if (dTotal > 0 && prevTotal > 0)
                patch.cpuPct = Math.max(0, Math.min(100, Math.round(dBusy / dTotal * 100)))
            patch.prevBusy = busy
            patch.prevTotal = total
            continue
        }
        // root-fs capacity for the metrics file (df -kP: POSIX, kB units)
        var df = ln.match(/^[^\s]+\s+(\d+)\s+(\d+)\s+\d+\s+\d+%\s+\/$/)
        if (df) {
            patch.diskTotalB = +df[1] * 1024
            patch.diskUsedB = +df[2] * 1024
        }
    }
    // values from /proc/meminfo are kB
    if (memTotal > 0) {
        var usedKb = Math.max(0, memTotal - memAvail)
        patch.memTotalGiB = Math.round(memTotal / 1048576 * 100) / 100
        patch.memUsedGiB = Math.round(usedKb / 1048576 * 100) / 100
        patch.memPct = Math.min(100, Math.round(usedKb / memTotal * 1000) / 10)
    }
    if (up > 0) {
        patch.uptimeSeconds = up
        patch.uptimeStr = formatUptime(up)
    }
    return patch
}

// One nvidia-smi --query-gpu CSV row (may be "[N/A]" per driver) → patch of
// only the fields that parsed; `seen` marks a real GPU answer. Null on empty.
export function parseNvidiaSmi(s) {
    s = (s || "").trim()
    if (!s) return null
    var f = s.split("\n")[0].split(",")
    var patch = {}
    var t = parseInt(f[0], 10), u = parseInt(f[1], 10)
    var mu = parseInt(f[2], 10), mt = parseInt(f[3], 10)
    var p = parseFloat(f[4]), fan = parseFloat(f[5]), clk = parseFloat(f[6])
    if (!isNaN(t)) patch.tempC = t
    if (!isNaN(u)) patch.usagePct = u
    if (!isNaN(mu)) patch.memUsedMiB = mu
    if (!isNaN(mt)) patch.memTotalMiB = mt
    if (!isNaN(p)) patch.powerW = Math.round(p * 100) / 100
    if (!isNaN(fan)) patch.fanPct = fan
    if (!isNaN(clk)) patch.clockMHz = clk
    patch.seen = !isNaN(t) || !isNaN(mt)
    return patch
}

// nvidia-smi --query-compute-apps output → [{pid,name,memMiB}] sorted by mem
// desc, capped at 6. No rows is a valid answer (nothing using the GPU).
export function parseGpuApps(out) {
    var lines = (out || "").trim().split("\n")
    var procs = []
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        if (!line.trim()) continue
        var parts = line.split(",")
        if (parts.length < 3) continue
        var pid = parseInt(parts[0].trim(), 10)
        var mem = parseFloat(parts[parts.length - 1].trim())
        var pathStr = parts.slice(1, -1).join(",").trim()
        var base = pathStr ? pathStr.split("/").pop() : "process"
        if (pid && !isNaN(mem)) procs.push({ pid: pid, name: base, memMiB: mem })
    }
    procs.sort(function(a, b) { return b.memMiB - a.memMiB })
    return procs.slice(0, 6)
}

// "<sys_vendor>|<board_name>" (the boardProc printf contract) → patch with
// only the fields that survived cleaning/parse.
export function parseBoard(raw) {
    if (!raw || raw.length === 0) return null
    var parts = raw.split("|")
    var sysv = (parts[0] || "").trim()
    var name = cleanBoardName(parts[1] || "")
    var patch = {}
    if (sysv.length > 0) patch.vendor = sysv
    if (name.length > 0) patch.name = name
    var cs = parseChipset(name)
    if (cs.length > 0) patch.chipset = cs
    return patch
}

// ip-api.com JSON → {city, country} or null (offline / rate-limited / error).
export function parseGeo(out) {
    try {
        var j = JSON.parse((out || "").trim())
        if (j && !j.error && j.city) return { city: j.city, country: j.country || "" }
    } catch (e) {
        // keep "—"
    }
    return null
}

// The cross-process metrics.json payload (H7) — the ONLY repo producer.
// gpu is null until nvidia-smi has answered at least once (`gpuSeen`).
export function buildMetricsPayload(st, nowMs) {
    var gpu = null
    if (st.gpuSeen) {
        gpu = {
            pct: st.gpuUsagePct,
            memUsedB: st.gpuMemUsedMiB * 1048576,
            memTotalB: st.gpuMemTotalMiB * 1048576,
            tempC: st.gpuTempC,
            powerW: st.gpuPowerW,
            fanPct: st.gpuFanPct,
            clockMHz: st.gpuClockMHz,
            processes: st.gpuProcesses
        }
    }
    return JSON.stringify({
        schema: 1,
        ts: nowMs,
        cpu: { pct: st.cpuPct },
        mem: { usedB: Math.round(st.memUsedGiB * 1073741824),
               totalB: Math.round(st.memTotalGiB * 1073741824) },
        gpu: gpu,
        disk: { usedB: Math.round(st.diskUsedB), totalB: Math.round(st.diskTotalB) }
    })
}
