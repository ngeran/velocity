// artcraft.test.mjs — pure status/progress normalization + row state.
import { strict as assert } from "node:assert"
import {
    normalizeStatus,
    normalizeProgress,
    appProgress,
    rowState,
    phaseLabel,
    versionLabel,
    relativeTime,
    formatPercent,
    clampPct
} from "./artcraft.mjs"

let n = 0
const ok = (name, fn) => { fn(); n++; console.log("  ok " + name) }

ok("normalizeStatus tolerates junk", () => {
    const s = normalizeStatus(null)
    assert.deepEqual(s.apps, [])
    assert.deepEqual(s.outdated, [])
    assert.equal(s.count, 0)
    assert.equal(s.checked, 0)
})

ok("normalizeStatus keeps app rows and count", () => {
    const s = normalizeStatus({
        checked: 100,
        count: 1,
        errors: 2,
        error: "one repo failed",
        apps: [{ app: "photocraft", displayName: "PhotoCraft", installed: "1", latest: "2", state: "outdated" }],
        outdated: [{ app: "photocraft", installed: "1", latest: "2" }]
    })
    assert.equal(s.count, 1)
    assert.equal(s.errors, 2)
    assert.equal(s.apps[0].displayName, "PhotoCraft")
    assert.equal(s.outdated[0].app, "photocraft")
})

ok("normalizeProgress coerces phase/percent and ignores junk", () => {
    const p = normalizeProgress({
        running: true,
        active: "photocraft",
        overall: 142,
        apps: { photocraft: { phase: "download", percent: 41.7 }, bad: null }
    })
    assert.equal(p.running, true)
    assert.equal(p.overall, 100)
    assert.equal(p.apps.photocraft.phase, "download")
    assert.equal(p.apps.photocraft.percent, 42)
    assert.equal(p.apps.bad.phase, "pending")
})

ok("appProgress returns null for unknown app", () => {
    assert.equal(appProgress(normalizeProgress({}), "photocraft"), null)
    assert.equal(appProgress(normalizeProgress({ apps: { photocraft: { phase: "done" } } }), "photocraft").phase, "done")
})

ok("rowState prefers live progress over status", () => {
    const app = { app: "photocraft", state: "outdated" }
    assert.equal(rowState(app, {}), "update")
    assert.equal(rowState(app, { apps: { photocraft: { phase: "download" } } }), "download")
    assert.equal(rowState(app, { apps: { photocraft: { phase: "done" } } }), "done")
    assert.equal(rowState({ app: "x", state: "current" }, {}), "current")
    assert.equal(rowState({ app: "x", state: "waiting" }, {}), "waiting")
    assert.equal(rowState({ app: "x", state: "error" }, {}), "error")
})

ok("phaseLabel covers every wire phase", () => {
    assert.equal(phaseLabel("download"), "DOWNLOADING")
    assert.equal(phaseLabel("switch"), "REBUILDING")
    assert.equal(phaseLabel("done"), "DONE")
    assert.equal(phaseLabel("nonsense"), "")
})

ok("versionLabel blanks render as an em dash", () => {
    assert.equal(versionLabel(""), "—")
    assert.equal(versionLabel("0.20.1"), "0.20.1")
    assert.equal(versionLabel(null), "—")
})

ok("relativeTime boundaries", () => {
    assert.equal(relativeTime(0, 1000), "never")
    assert.equal(relativeTime(1000, 1000), "just now")
    assert.equal(relativeTime(1000, 1000 + 60), "1m ago")
    assert.equal(relativeTime(1000, 1000 + 3600), "1h ago")
    assert.equal(relativeTime(1000, 1000 + 86400), "1d ago")
})

ok("percent helpers clamp", () => {
    assert.equal(clampPct(-5), 0)
    assert.equal(clampPct(105), 100)
    assert.equal(clampPct("42.6"), 43)
    assert.equal(formatPercent(42.6), "43%")
})

console.log(`artcraft.test: ${n} passed`)
