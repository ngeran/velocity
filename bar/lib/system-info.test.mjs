// system-info.test.mjs — pure parsers extracted from SystemInfoService (I8)
import * as M from "./system-info.mjs"

let n = 0
function ok(cond, label) {
    n++
    if (!cond) { console.error("FAIL: " + label); process.exitCode = 1 }
}
function close(a, b, label) {
    n++
    if (Math.abs(a - b) > 1e-9) { console.error(`FAIL: ${label} (${a} != ${b})`); process.exitCode = 1 }
}

// ── formatters ──────────────────────────────────────────────────────────────
ok(M.formatGiB(2 * 1073741824) === "2.00 GiB", "formatGiB exact GiB")
ok(M.formatGiB(1536 * 1048576) === "1.50 GiB", "formatGiB fraction")
ok(M.formatGiB(undefined) === "0.00 GiB", "formatGiB null-safe")
ok(M.formatBest(3 * 1099511627776) === "3.00 TiB", "formatBest TiB branch")
ok(M.formatBest(500 * 1073741824) === "500.00 GiB", "formatBest GiB branch")
ok(M.formatUptime(45) === "45s", "uptime seconds")
ok(M.formatUptime(125) === "2m 5s", "uptime minutes")
ok(M.formatUptime(7322) === "2h 2m", "uptime hours")
ok(M.formatUptime(90061) === "1d 1h", "uptime days")
ok(M.formatUptime(-5) === "0s", "uptime clamps negative")

// ── board identity ──────────────────────────────────────────────────────────
ok(M.cleanBoardName("To Be Filled By O.E.M.") === "", "junk board filtered")
ok(M.cleanBoardName("Default string") === "", "default-string board filtered")
ok(M.cleanBoardName("TUF GAMING B650-E WIFI") === "TUF GAMING B650-E WIFI", "real board kept")
ok(M.parseChipset("TUF GAMING B650-E WIFI") === "B650E", "chipset AMD with E suffix")
ok(M.parseChipset("ROG STRIX X870E") === "X870E", "chipset X870E")
ok(M.parseChipset("PRO B550-AM") === "B550", "chipset plain B550")
ok(M.parseChipset("Z790 AORUS") === "Z790", "chipset Intel Z790")
ok(M.parseChipset("some random board") === "", "chipset absent")
ok(M.parseBoard("ASUS|TUF GAMING B650-E WIFI") !== null, "board patch parses")
const bp = M.parseBoard("ASUS|To be filled by o.e.m.")
ok(bp.vendor === "ASUS" && bp.name === undefined && bp.chipset === undefined, "board junk name dropped")
ok(M.parseBoard("") === null, "board empty → null")

// ── fastfetch profile ───────────────────────────────────────────────────────
const FF = JSON.stringify([
    { type: "Title", result: { userName: "nikos", hostName: "nixos-btw" } },
    { type: "CPU", result: { cpu: "Ryzen 9 7950X", cores: { logical: 32 }, frequency: { max: 5750.0 } } },
    { type: "GPU", result: [{ name: "RTX 4090", driver: "580.1", type: "Discrete", vendor: "NVIDIA" }] },
    { type: "Memory", result: { total: 33460707328 } },           // 31.17 GiB
    { type: "OS", result: { name: "NixOS", codename: "yarara", versionID: "26.05" } },
    { type: "Kernel", result: { name: "Linux", release: "7.1.3", architecture: "x86_64" } },
    { type: "Packages", result: { all: 1834, nixSystem: 1700, nixUser: 134 } },
    { type: "Disk", result: [
        { mountpoint: "/", mountFrom: "/dev/nvme0n1p2", volumeType: ["Regular"],
          bytes: { used: 429496729600, total: 1020054732800 }, createTime: "2026-07-04T10:00:00" },
        { mountpoint: "/nix/store", mountFrom: "/dev/nvme0n1p2", volumeType: ["Read-only"],
          bytes: { used: 42949672960, total: 1020054732800 } },
        { mountpoint: "/boot", mountFrom: "/dev/nvme0n1p1", volumeType: ["Regular"],
          bytes: { used: 104857600, total: 1073741824 } }
    ] }
])
const NOW = Date.UTC(2026, 9, 28)   // 2026-10-28
const ff = M.parseFastfetch(FF, NOW)
ok(ff.userName === "nikos" && ff.hostName === "nixos-btw", "ff title")
ok(ff.cpuModel === "Ryzen 9 7950X" && ff.cpuThreads === 32, "ff cpu model/threads")
close(ff.cpuMaxGhz, 5.75, "ff cpu max GHz")
ok(ff.gpuName === "RTX 4090" && ff.gpuType === "Discrete", "ff gpu")
close(ff.memTotalGiB, 31.16, "ff memory GiB")
ok(ff.osName === "NixOS" && ff.osVersion === "26.05", "ff os")
ok(ff.kernelName === "Linux" && ff.arch === "x86_64", "ff kernel")
ok(ff.pkgAll === 1834 && ff.pkgSystem === 1700 && ff.pkgUser === 134, "ff packages")
ok(ff.disks.length === 2, "ff read-only volume skipped")
ok(ff.disks[0].dev === "/dev/nvme0n1p2" && ff.disks[0].mount === "/", "ff disk dev prefers mountFrom")
ok(ff.disks[0].usedLabel === "400.00 GiB" && ff.disks[0].totalLabel === "950.00 GiB", "ff disk labels")
ok(ff.disks[0].pct === 42, "ff disk pct rounds")
ok(ff.installDate === "2026-07-04", "ff install date from / createTime")
ok(ff.osAgeDays === 116, "ff os age in UTC days")
ok(ff.disks[1].totalLabel === "1.00 GiB", "ff disk label GiB branch")
let threw = false
try { M.parseFastfetch("not json{", NOW) } catch (e) { threw = true }
ok(threw, "ff throws on garbage (caller's catch decides)")

// minimal profile: absent blocks stay undefined (service keeps old values)
const ffMin = M.parseFastfetch(JSON.stringify([{ type: "OS", result: { name: "NixOS" } }]), NOW)
ok(ffMin.osName === "NixOS" && ffMin.cpuModel === undefined && ffMin.disks === undefined, "ff absent blocks undefined")

// ── live metrics ────────────────────────────────────────────────────────────
const LIVE = [
    "MemTotal:       32768000 kB",
    "MemAvailable:   16384000 kB",
    "12345.67 23456.78",
    "cpu  100 0 100 300 50 10 10 10 0 0",
    "/dev/nvme0n1p2 102005473 428657860 586926376 42% /"
].join("\n")
const l1 = M.parseLiveMetrics(LIVE, 0, 0)          // first tick: no baseline
ok(l1.cpuPct === undefined, "live first tick publishes no pct")
ok(l1.prevBusy === 230 && l1.prevTotal === 580, "live first tick stores baseline")
close(l1.memTotalGiB, 31.25, "live mem total")
close(l1.memUsedGiB, 15.63, "live mem used")
ok(l1.memPct === 50, "live mem pct")
ok(l1.uptimeSeconds === 12345.67 && l1.uptimeStr === "3h 25m", "live uptime")
ok(l1.diskUsedB === 428657860 * 1024 && l1.diskTotalB === 102005473 * 1024, "live df kB→B")

const l2 = M.parseLiveMetrics(LIVE, 230, 580)      // second tick, no counter movement
ok(l2.cpuPct === undefined, "live zero-delta tick publishes no pct")
const LIVE2 = LIVE.replace("cpu  100 0 100 300", "cpu  110 0 100 340")
const l3 = M.parseLiveMetrics(LIVE2, 230, 580)     // busy +10 of +50 total (idle +40)
ok(l3.cpuPct === 20, "live busy delta 10/50 → 20%")
const LIVE3 = LIVE.replace("cpu  100 0 100 300", "cpu  1200 0 100 200")
const l4 = M.parseLiveMetrics(LIVE3, 230, 580)
ok(l4.cpuPct === 100, "live pct clamps to 100")
ok(M.parseLiveMetrics("MemTotal: 0 kB", 0, 0).memTotalGiB === undefined, "live zero memtotal skipped")

// ── nvidia-smi CSV ──────────────────────────────────────────────────────────
const g1 = M.parseNvidiaSmi("61, 12, 2048, 24564, 143.52, 30, 2535")
ok(g1.tempC === 61 && g1.usagePct === 12 && g1.memUsedMiB === 2048 && g1.memTotalMiB === 24564, "smi basic fields")
close(g1.powerW, 143.52, "smi power keeps 2 decimals")
ok(g1.fanPct === 30 && g1.clockMHz === 2535 && g1.seen === true, "smi fan/clock/seen")
const g2 = M.parseNvidiaSmi("[N/A], 12, [N/A], [N/A], [N/A], [N/A], [N/A]")
ok(g2.tempC === undefined && g2.memTotalMiB === undefined && g2.usagePct === 12, "smi N/A fields dropped")
ok(g2.seen === false, "smi seen needs temp or memTotal (usage alone is not seen)")
ok(M.parseNvidiaSmi("[N/A], [N/A], [N/A], [N/A], [N/A], [N/A], [N/A]").seen === false, "smi all-N/A unseen")
ok(M.parseNvidiaSmi("") === null, "smi empty → null")

// ── gpu compute apps ────────────────────────────────────────────────────────
const APPS = [
    "1234,/usr/bin/blender,8192",
    "99,/opt/nvidia,16384",
    "77,ollama,4096",
    "",
    "bad-row"
].join("\n")
const apps = M.parseGpuApps(APPS)
ok(apps.length === 3 && apps[0].name === "nvidia" && apps[0].memMiB === 16384, "apps sorted desc, basename")
ok(apps[1].pid === 1234 && apps[1].name === "blender", "apps pid + path basename")
ok(apps.every(a => a.memMiB > 0), "apps non-numeric mem dropped")
ok(M.parseGpuApps("123,x,notanumber").length === 0, "apps NaN mem dropped")
ok(M.parseGpuApps("").length === 0, "apps empty output → empty list")
const many = Array.from({ length: 9 }, (_, i) => `${i},p${i},${i + 1}`).join("\n")
ok(M.parseGpuApps(many).length === 6, "apps capped at 6")

// ── geo ─────────────────────────────────────────────────────────────────────
const geo = M.parseGeo('{"city":"Athens","country":"Greece","countryCode":"GR"}')
ok(geo.city === "Athens" && geo.country === "Greece", "geo parse")
ok(M.parseGeo('{"error":true}') === null, "geo error flag → null")
ok(M.parseGeo("rate limited") === null, "geo garbage → null")
ok(M.parseGeo('{"city":"X"}') !== null && M.parseGeo('{"city":"X"}').country === "", "geo country optional")

// ── metrics payload ─────────────────────────────────────────────────────────
const payload = JSON.parse(M.buildMetricsPayload({
    gpuSeen: false, gpuUsagePct: 0, gpuMemUsedMiB: 0, gpuMemTotalMiB: 0,
    gpuTempC: 0, gpuPowerW: 0, gpuFanPct: 0, gpuClockMHz: 0, gpuProcesses: [],
    cpuPct: 12, memUsedGiB: 8, memTotalGiB: 32, diskUsedB: 100.4, diskTotalB: 200.6
}, 1234))
ok(payload.schema === 1 && payload.ts === 1234, "payload schema/ts")
ok(payload.cpu.pct === 12 && payload.gpu === null, "payload cpu + null gpu")
ok(payload.mem.usedB === 8589934592 && payload.disk.usedB === 100, "payload byte rounding")
const gp = JSON.parse(M.buildMetricsPayload({
    gpuSeen: true, gpuUsagePct: 5, gpuMemUsedMiB: 1, gpuMemTotalMiB: 2,
    gpuTempC: 60, gpuPowerW: 10, gpuFanPct: 20, gpuClockMHz: 3000,
    gpuProcesses: [{ pid: 1, name: "x", memMiB: 1 }],
    cpuPct: 0, memUsedGiB: 0, memTotalGiB: 0, diskUsedB: 0, diskTotalB: 0
}, 1)).gpu
ok(gp.memUsedB === 1048576 && gp.processes.length === 1 && gp.tempC === 60, "payload gpu block when seen")

console.log(`system-info.test: ${n} asserts`)
