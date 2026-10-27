// Pure storage model: parses `lsblk -J -b` output into drive records and
// formats capacities. No QML and no processes here, so the StorageService
// singleton stays a thin fetch wrapper and node can exercise the parsing
// (storage.test.mjs beside the synced copy). Avoids Date.now()/Math.random()
// (both throw in the Quickshell JS engine); Math.round and the Date
// constructor are fine.
//
// Data model adapted from upstream Ryoku's qsbar Theme.qml storage parser
// (MIT). lsblk alone covers everything — per-drive media class, mount state
// and per-filesystem usage — so our side needs no df probe (upstream polls
// df only to refresh its bar pill between lsblk cycles; our cadence is
// unified).

// Kernel pseudo-devices report TYPE=disk like real hardware, so the type
// field alone is not enough: loop/ram/zram/nbd are dropped by name prefix,
// and a drive with no capacity is not a drive — which also drops an empty
// card slot or an unpopulated array.
function isRealDisk(node) {
    var name = String(node.name || "");
    return node.type === "disk"
        && (Number(node.size) || 0) > 0
        && name.indexOf("loop") !== 0
        && name.indexOf("ram") !== 0
        && name.indexOf("zram") !== 0
        && name.indexOf("nbd") !== 0;
}

function textValue(v) {
    return v === null || v === undefined ? "" : String(v).trim();
}

// Recursive walk collecting mounted filesystems: { fs, mounts[], mount,
// percent, freeBytes, usedBytes }. "[SWAP]" mounts are skipped. ALL
// mountpoints are kept — on NixOS the root fs is listed with its bind
// mounts too ("/nix/store", …) and "/" is often NOT first.
function collectVolumes(node, target) {
    var fs = textValue(node.fstype);
    var raw = node.mountpoints || [];
    var mounts = [];
    for (var m = 0; m < raw.length; m++) {
        var candidate = textValue(raw[m]);
        if (candidate !== "" && candidate !== "[SWAP]") mounts.push(candidate);
    }
    if (fs !== "") {
        var pct = parseInt(textValue(node["fsuse%"]).replace("%", ""), 10);
        var freeText = textValue(node.fsavail);
        var usedText = textValue(node.fsused);
        target.push({
            name: textValue(node.name),
            fs: fs,
            mounts: mounts,
            mount: mounts.length > 0 ? mounts[0] : "",
            percent: isNaN(pct) ? -1 : Math.max(0, Math.min(100, pct)),
            freeBytes: freeText === "" ? -1 : Math.max(0, Number(freeText) || 0),
            usedBytes: usedText === "" ? -1 : Math.max(0, Number(usedText) || 0)
        });
    }
    var children = node.children || [];
    for (var c = 0; c < children.length; c++) collectVolumes(children[c], target);
}

// Parse `lsblk -J -b` JSON into { available, drives }. Guards everything: a
// missing blockdevices array yields available:false. Head usage comes from
// the drive's root volume when it hosts one (first-mounted otherwise).
function parseInventory(json) {
    var out = { available: false, drives: [] };
    var devices = json && json.blockdevices;
    if (!Array.isArray(devices)) return out;

    for (var i = 0; i < devices.length; i++) {
        var device = devices[i];
        if (!isRealDisk(device)) continue;

        var volumes = [];
        collectVolumes(device, volumes);
        var fileSystems = [];
        var mountedAt = "", usage = -1, freeBytes = -1, usedBytes = -1;
        // Head usage comes from the drive's ROOT volume when it hosts one
        // (the pill + ROOT card speak for "/"), else the first-mounted one —
        // an EFI partition usually mounts first. The root VOLUME is found by
        // scanning its MOUNT LIST: on NixOS the root fs also carries bind
        // mounts and "/" is often not the first entry.
        for (var r = 0; r < volumes.length; r++) {
            if (volumes[r].mounts.indexOf("/") >= 0) {
                mountedAt = "/"; usage = volumes[r].percent;
                freeBytes = volumes[r].freeBytes; usedBytes = volumes[r].usedBytes;
                break;
            }
        }
        for (var v = 0; v < volumes.length && mountedAt === ""; v++) {
            if (volumes[v].mounts.length > 0) {
                mountedAt = volumes[v].mounts[0];
                usage = volumes[v].percent;
                freeBytes = volumes[v].freeBytes;
                usedBytes = volumes[v].usedBytes;
            }
        }
        for (var v2 = 0; v2 < volumes.length; v2++) {
            if (fileSystems.indexOf(volumes[v2].fs) < 0) fileSystems.push(volumes[v2].fs);
        }

        var transport = textValue(device.tran).toUpperCase();
        var removable = device.rm === true || device.hotplug === true || transport === "USB";
        var driveType = removable ? "usb"
            : transport === "NVME" ? "nvme"
            : device.rota === true ? "hdd"
            : "ssd";
        var media = removable ? "USB DRIVE"
            : transport === "NVME" ? "NVME SSD"
            : device.rota === true ? (transport !== "" ? transport + " HDD" : "HDD")
            : (transport !== "" ? transport + " SSD" : "SSD");

        out.drives.push({
            name: textValue(device.name),
            model: textValue(device.model) || textValue(device.name),
            size: Number(device.size) || 0,
            driveType: driveType,
            media: media,
            fileSystems: fileSystems.join(" + ").toUpperCase(),
            state: mountedAt !== "" ? mountedAt
                : (fileSystems.length > 0 ? "Not mounted" : "No filesystem"),
            percent: usage,
            freeBytes: freeBytes,
            usedBytes: usedBytes,
            totalBytes: usedBytes >= 0 && freeBytes >= 0 ? usedBytes + freeBytes : -1
        });
    }
    out.available = true;
    return out;
}

// The root filesystem's drive (the bar pill's percent + the panel's ROOT
// card) — the drive whose first mounted volume is "/".
function findRoot(drives) {
    if (!drives) return null;
    for (var i = 0; i < drives.length; i++)
        if (drives[i].state === "/") return drives[i];
    return null;
}

// Nerd Font glyph per drive class. These are ASTRAL PUA code points
// (U+F08AE…) — a plain "\uXXXX" escape only carries 4 hex digits and
// silently truncates them; always write "\u{…}" (or go through this
// helper) and never paste the raw glyphs, which are invisible in
// editors and diffs.
function nerdFor(driveType) {
    if (driveType === "nvme") return "\u{f08ae}";
    if (driveType === "ssd") return "\u{f0b73}";
    return "\u{f02ca}";   // hdd + usb share the drive glyph
}

// Decimal capacity label ("1.0 TB") — drive sizes are marketed decimal.
function formatBytes(bytes) {
    var v = Number(bytes) || 0;
    if (v >= 1e12) return (v / 1e12).toFixed(v >= 1e13 ? 0 : 1) + " TB";
    if (v >= 1e9) return (v / 1e9).toFixed(v >= 1e11 ? 0 : 1) + " GB";
    return (v / 1e6).toFixed(0) + " MB";
}

// Binary usage label for the metrics rows ("400.0 GiB"), like upstream's.
function formatGiB(bytes) {
    return (Math.max(0, Number(bytes) || 0) / 1073741824).toFixed(1) + " GiB";
}

// Guarded JSON.parse: null on any empty or malformed body.
function parseJson(text) {
    try {
        if (text && text.trim().length > 0) return JSON.parse(text);
    } catch (e) {}
    return null;
}

// Per-volume usage rows for settings' Core STORAGE card (H6 — replaced
// CoreEngineService's private df fork; this module is the ONE lsblk parse).
// ONE row per mounted VOLUME of every real drive — df (the old probe) lists
// each source device once even when bind-mounted all over the tree, so the
// card's row set only stays identical if the same dedupe happens here; the
// label prefers "/" when the volume hosts it (the NixOS root fs also carries
// /nix/store, /home, … and "/" is NOT always the first mountpoint). Shape is
// the df-era contract: { device, fstype, mount, usedGB, availGB, totalGB,
// pct } ("GB" = GiB, so the card and the deepcool LCD feed need no
// re-scaling). The df-era pseudo/boot skip list moves here wholesale —
// tmpfs-class fs never appear in lsblk anyway, but vfat (ESP), iso9660 and
// fuseblk do, and they were never "data" rows.
function parseFilesystems(json) {
    var SKIP = { tmpfs:1, devtmpfs:1, ramfs:1, squashfs:1, overlay:1,
        iso9660:1, efivarfs:1, vfat:1, fuseblk:1, autofs:1, mqueue:1,
        hugetlbfs:1, "9p":1, fusectl:1, configfs:1, debugfs:1, sysfs:1,
        proc:1, cgroup:1, cgroup2:1, nsfs:1, binfmt_misc:1, pstore:1,
        securityfs:1, tracefs:1, rpc_pipefs:1, devpts:1 };
    var rows = [];
    var devices = json && json.blockdevices;
    if (!Array.isArray(devices)) return rows;
    for (var i = 0; i < devices.length; i++) {
        var device = devices[i];
        if (!isRealDisk(device)) continue;
        var volumes = [];
        collectVolumes(device, volumes);
        for (var v = 0; v < volumes.length; v++) {
            var vol = volumes[v];
            if (SKIP[vol.fs]) continue;
            if (vol.mounts.length === 0) continue;
            var used = vol.usedBytes, free = vol.freeBytes;
            var total = (used >= 0 && free >= 0) ? used + free : -1;
            rows.push({
                device: vol.name,   // the fs's own node (df's source column), not the drive
                fstype: vol.fs,
                mount: vol.mounts.indexOf("/") >= 0 ? "/" : vol.mounts[0],
                usedGB: used >= 0 ? +(used / 1073741824).toFixed(1) : 0,
                availGB: free >= 0 ? +(free / 1073741824).toFixed(1) : 0,
                totalGB: total >= 0 ? +(total / 1073741824).toFixed(1) : 0,
                pct: vol.percent >= 0 ? vol.percent : 0
            });
        }
    }
    return rows;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { parseInventory, findRoot, nerdFor, formatBytes, formatGiB, parseJson, parseFilesystems };
}

export { parseInventory, findRoot, nerdFor, formatBytes, formatGiB, parseJson, parseFilesystems };
