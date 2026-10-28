// activity-queue.test.mjs — live-activity arbitration rules (J0)
import * as Aq from "./activity-queue.mjs"

let n = 0
function ok(cond, label) {
    n++
    if (!cond) { console.error("FAIL: " + label); process.exitCode = 1 }
}
function eqv(got, want, label) {
    n++
    if (JSON.stringify(got) !== JSON.stringify(want)) { console.error("FAIL: " + label); process.exitCode = 1 }
}
const act = (over) => Aq.normalize(Object.assign({ key: "k", ttlMs: 1000 }, over), 0)

// ── normalize: valid + defaults ─────────────────────────────────────────────
const a = act({})
ok(a !== null, "minimal spec accepted")
ok(a.key === "k" && a.priority === "timer" && a.icon === "" && a.label === "",
   "defaults: timer priority, blank icon/label")
ok(a.accent === null && a.progress === undefined && a.focusedOnly === false,
   "accent/progress/focusedOnly defaults")
ok(a.expiresAt === 1000, "expiresAt = now + ttl")

// rejection
ok(act({ key: "" }) === null, "empty key rejected")
ok(act({ key: 42 }).key === "42", "numeric key coerced to a usable string key")
ok(Aq.normalize(null, 0) === null, "null spec rejected")
ok(act({ ttlMs: 0 }) === null, "ttl 0 without progress rejected")
ok(act({ ttlMs: -5 }) === null, "negative ttl without progress rejected")
ok(act({ ttlMs: "soon" }) === null, "non-numeric ttl without progress rejected")

// unknown priority degrades to timer (never up)
ok(act({ priority: "bogus" }).priority === "timer", "unknown priority → timer")
ok(act({ priority: "osd" }).priority === "osd"
   && act({ priority: "recording" }).priority === "recording"
   && act({ priority: "peek" }).priority === "peek"
   && act({ priority: "progress" }).priority === "progress", "ladder names valid")

// progress
ok(act({ progress: 42.6 }).progress === 43, "progress rounded")
ok(act({ progress: -3 }).progress === 0, "progress clamped low")
ok(act({ progress: 150 }).progress === 100, "progress clamped high")
ok(act({ progress: "nope" }).progress === undefined, "NaN progress → undefined")
ok(act({ progress: null, ttlMs: 500 }).progress === undefined, "null progress = absent")
ok(act({ ttlMs: 0, progress: 10 }) !== null, "progress present: ttl may be absent")
ok(act({ ttlMs: undefined, progress: 10 }).expiresAt === Aq.HARD_CAP_MS,
   "progress without ttl → hard cap expiry")
ok(act({ ttlMs: Aq.HARD_CAP_MS * 5 }).expiresAt === Aq.HARD_CAP_MS, "ttl clamped to hard cap")
ok(act({ ttlMs: 600 }).expiresAt === 600, "small ttl preserved")
ok(act({ ttlMs: 999.9 }).expiresAt === 999, "now/ttl fractional → floored expiry")
ok(act({ focusedOnly: 1 }).focusedOnly === true, "focusedOnly coerced")
ok(act({ accent: "#ff8800" }).accent === "#ff8800", "hex accent kept")
ok(act({ accent: "red" }).accent === null, "non-hex accent dropped")
var fn = function() {}
ok(typeof act({ activate: fn }).activate === "function", "function activate kept")
ok(act({ activate: "click" }).activate === undefined, "non-function activate dropped")
ok(act({}).activate === undefined, "activate absent by default")
ok(act({ icon: "󰕾", label: "42%" }).icon === "󰕾" && act({ icon: "󰕾", label: "42%" }).label === "42%",
   "icon/label strings kept")

// ── upsert / remove (identity discipline) ───────────────────────────────────
const e1 = act({ key: "a" })
const e2 = act({ key: "b", priority: "progress" })
let m = Aq.upsert({}, e1, 1)
ok(m.a.key === "a" && m.a.seq === 1, "upsert inserts")
m = Aq.upsert(m, e2, 2)
ok(m.a.seq === 1 && m.b.seq === 2, "seq stamped per entry")
const updated = act({ key: "a", label: "v2" })
m = Aq.upsert(m, updated, 3)
ok(Object.keys(m).length === 2 && m.a.label === "v2" && m.a.seq === 3, "same key = update in place")
const before = m
m = Aq.remove(m, "zzz")
ok(m === before, "remove of missing key returns same map (no churn)")
m = Aq.remove(m, "a")
ok(Object.keys(m).length === 1 && m.a === undefined, "remove deletes")

// ── sweep ───────────────────────────────────────────────────────────────────
let mm = Aq.upsert({}, act({ key: "old", ttlMs: 100 }), 1)
mm = Aq.upsert(mm, act({ key: "new", ttlMs: 5000 }), 2)
let r = Aq.sweep(mm, 4000)
ok(r.changed === true && r.map.old === undefined && r.map.new !== undefined, "expired swept")
r = Aq.sweep(mm, 50)
ok(r.changed === false && r.map === mm, "nothing expired → same map, changed false")
// progress entries also expire (hard cap) — update renews
const prog = Aq.normalize({ key: "p", progress: 5 }, 0)
mm = Aq.upsert(mm, prog, 3)
ok(Aq.sweep(mm, Aq.HARD_CAP_MS + 1).changed === true, "hard cap expires progress entries too")

// ── hover-hold: sweep skips keys held by any tag ────────────────────────────
let hm = Aq.upsert({}, act({ key: "held", ttlMs: 100 }), 1)
hm = Aq.upsert(hm, act({ key: "free", ttlMs: 100 }), 2)
let hr = Aq.sweep(hm, 4000, { "island:DP-1": "held" })
ok(hr.changed === true && hr.map.held !== undefined && hr.map.free === undefined,
   "held key survives expiry, unheld swept")
hr = Aq.sweep(hm, 4000, { a: "held", b: "held" })
ok(hr.map.held !== undefined && hr.changed === true, "multiple tags holding the same key")
hr = Aq.sweep(hm, 4000)
ok(hr.changed === true && Object.keys(hr.map).length === 0, "no holds → expiry normal")
hr = Aq.sweep(hm, 50, { "osd:card": "held" })
ok(hr.changed === false && hr.map === hm, "nothing expired → same map even when held")

// ── arbitrate ───────────────────────────────────────────────────────────────
ok(Aq.arbitrate({}, false) === null, "empty queue → null")
let q = Aq.upsert({}, act({ key: "t", priority: "timer" }), 1)
ok(Aq.arbitrate(q, true) === null, "open panel wins over any activity")
q = Aq.upsert(q, act({ key: "pr", priority: "progress" }), 2)
q = Aq.upsert(q, act({ key: "o", priority: "osd" }), 3)
q = Aq.upsert(q, act({ key: "rec", priority: "recording" }), 4)
q = Aq.upsert(q, act({ key: "pk", priority: "peek" }), 5)
eqv(Aq.arbitrate(q, false).key, "o", "osd tops the ladder")
q = Aq.remove(q, "o")
eqv(Aq.arbitrate(q, false).key, "rec", "recording next")
q = Aq.remove(q, "rec")
eqv(Aq.arbitrate(q, false).key, "pk", "peek next")
q = Aq.remove(q, "pk")
eqv(Aq.arbitrate(q, false).key, "pr", "progress next")
q = Aq.remove(q, "pr")
eqv(Aq.arbitrate(q, false).key, "t", "timer last")
// tie → latest seq
let tie = Aq.upsert({}, act({ key: "first", priority: "timer" }), 1)
tie = Aq.upsert(tie, act({ key: "second", priority: "timer" }), 2)
eqv(Aq.arbitrate(tie, false).key, "second", "same priority → latest update wins")
tie = Aq.upsert(tie, act({ key: "first", priority: "timer", label: "refresh" }), 3)
eqv(Aq.arbitrate(tie, false).key, "first", "re-update reclaims the slot")

console.log(`activity-queue.test: ${n} asserts`)
