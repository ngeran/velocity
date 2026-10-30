// network-control-model.test.mjs — nmcli stderr → stable failure key/label
import { strict as assert } from "node:assert"
import { connectFailureReason } from "./network-control-model.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

ok("wrong-password beats every other pattern (checked first)", () => {
    // a stderr mentioning BOTH secrets and timeout must still class as password
    assert.deepEqual(connectFailureReason("Connection attempt timed out\nSecrets were required"), { key: "wrong-password", label: "Wrong password" })
})

ok("network-gone: not found / in range variants", () => {
    assert.equal(connectFailureReason("No network found").key, "network-gone")
    assert.equal(connectFailureReason("network is no longer in range").key, "network-gone")
    assert.equal(connectFailureReason("Not found").label, "Network disappeared")
})

ok("timeout", () => {
    assert.deepEqual(connectFailureReason("Connection attempt timed out."), { key: "timeout", label: "Timed out" })
})

ok("fallback: first non-empty stderr line, truncated to 80 chars", () => {
    assert.deepEqual(connectFailureReason("\n  IP configuration failed  \nsecond line"), { key: "failed", label: "IP configuration failed" })
    const long = "x".repeat(200)
    assert.equal(connectFailureReason(long).label.length, 80)
})

ok("empty / null stderr → generic failed", () => {
    assert.deepEqual(connectFailureReason(""), { key: "failed", label: "Connect failed" })
    assert.deepEqual(connectFailureReason(null), { key: "failed", label: "Connect failed" })
})

console.log(`network-control-model.test.mjs: ${n} ok`)
