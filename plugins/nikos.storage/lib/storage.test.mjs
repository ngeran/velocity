// storage.test.mjs — node asserts for the pure storage model (no framework,
// same contract as the engine lib tests). Run via tools/run-unit-tests.
// Expected glyphs are written as \u{…} escapes (astral PUA code points are
// invisible in editors and diffs — never paste them raw).
import assert from "node:assert"
import { parseInventory, findRoot, nerdFor, formatBytes, formatGiB, parseJson } from "./storage.mjs"

let n = 0
const ok = (name, fn) => { fn(); n++; console.log("  ok " + name) }

// Synthetic capture shaped like `lsblk -J -b -o NAME,TYPE,SIZE,FSTYPE,FSUSED,
// FSAVAIL,FSUSE%,MOUNTPOINTS,MODEL,TRAN,ROTA,RM,HOTPLUG` (-b = byte counts).
const CAPTURED = {
  blockdevices: [
    { name: "loop0", type: "loop", size: 0, tran: null, rota: false, rm: false, hotplug: false, model: null },
    { name: "zram0", type: "disk", size: 16777216, tran: null, rota: false, rm: false, hotplug: false, model: null },
    { name: "nvme0n1", type: "disk", size: 1000204886016, tran: "nvme", rota: false, rm: false, hotplug: false,
      model: "Samsung SSD 990 PRO 1TB",
      children: [
        { name: "nvme0n1p1", type: "part", size: 1073741824, fstype: "vfat",
          fsused: 1048576, fsavail: 1072693248, "fsuse%": "1%", mountpoints: ["/boot"] },
        { name: "nvme0n1p2", type: "part", size: 999131627520, fstype: "btrfs",
          fsused: 429496729600, fsavail: 569634897920, "fsuse%": "43%",
          // bind mounts first — "/" is NOT the first entry (NixOS real shape)
          mountpoints: ["/nix/store", "/", "/home"] }
      ] },
    { name: "sda", type: "disk", size: 0, tran: "usb", rota: false, rm: true, hotplug: true, model: "Card Reader" },
    { name: "sdb", type: "disk", size: 320072933376, tran: "usb", rota: true, rm: true, hotplug: true,
      model: "Portable HDD",
      children: [
        { name: "sdb1", type: "part", size: 320070488064, fstype: "ntfs",
          fsused: 214748364800, fsavail: 105322568576, "fsuse%": "67%",
          mountpoints: ["/run/media/nikos/BACKUP"] }
      ] },
    { name: "sdc", type: "disk", size: 500107862016, tran: "sata", rota: true, rm: false, hotplug: false,
      model: "WDC WD5000AZLX",
      children: [
        { name: "sdc1", type: "part", size: 500105090048, fstype: "ext4",
          fsused: null, fsavail: null, "fsuse%": null, mountpoints: [null] }
      ] }
  ]
}

ok("drops loop/zram/zero-size, keeps real disks", () => {
  const inv = parseInventory(CAPTURED)
  assert.equal(inv.available, true)
  assert.deepEqual(inv.drives.map(d => d.name), ["nvme0n1", "sdb", "sdc"])
})
ok("root drive found by the / mount", () => {
  const inv = parseInventory(CAPTURED)
  const r = findRoot(inv.drives)
  assert.equal(r.name, "nvme0n1")
  assert.equal(r.state, "/")
  assert.equal(r.percent, 43)
  assert.equal(r.driveType, "nvme")
  assert.equal(r.media, "NVME SSD")
  assert.equal(r.fileSystems, "VFAT + BTRFS")
  assert.equal(r.totalBytes, 429496729600 + 569634897920)
})
ok("usb classifier beats transport/rotational", () => {
  const d = parseInventory(CAPTURED).drives[1]
  assert.equal(d.driveType, "usb")
  assert.equal(d.media, "USB DRIVE")
  assert.equal(d.percent, 67)
})
ok("sata rotational label", () => {
  const d = parseInventory(CAPTURED).drives[2]
  assert.equal(d.media, "SATA HDD")
})
ok("unmounted disk: state + usage sentinels", () => {
  const d = parseInventory(CAPTURED).drives[2]
  assert.equal(d.state, "Not mounted")
  assert.equal(d.percent, -1)
  assert.equal(d.totalBytes, -1)
  assert.equal(d.fileSystems, "EXT4")
})
ok("model falls back to the device name", () => {
  const inv = parseInventory({ blockdevices: [
    { name: "nvme1n1", type: "disk", size: 1, tran: "nvme", rota: false, rm: false, hotplug: false, model: null }
  ] })
  assert.equal(inv.drives[0].model, "nvme1n1")
})
ok("guarded parse", () => {
  assert.equal(parseInventory(null).available, false)
  assert.equal(parseInventory({}).available, false)
  assert.deepEqual(parseInventory({ blockdevices: [] }).drives, [])
})
ok("root miss -> null", () => {
  assert.equal(findRoot([]), null)
  assert.equal(findRoot(null), null)
})
ok("glyphs per class (astral PUA)", () => {
  assert.equal(nerdFor("nvme"), "\u{f08ae}")
  assert.equal(nerdFor("ssd"), "\u{f0b73}")
  assert.equal(nerdFor("hdd"), "\u{f02ca}")
  assert.equal(nerdFor("usb"), "\u{f02ca}")
  assert.equal(nerdFor(undefined), "\u{f02ca}")
})
ok("capacity + usage formats", () => {
  assert.equal(formatBytes(1000204886016), "1.0 TB")
  assert.equal(formatBytes(320072933376), "320 GB")
  assert.equal(formatBytes(0), "0 MB")
  assert.equal(formatGiB(429496729600), "400.0 GiB")
  assert.equal(formatGiB(-5), "0.0 GiB")
})
ok("guarded json", () => {
  assert.equal(parseJson(""), null)
  assert.equal(parseJson("nope"), null)
  assert.deepEqual(parseJson('{"a":1}'), { a: 1 })
})

console.log(`storage.test: ${n} assertions passed`)
