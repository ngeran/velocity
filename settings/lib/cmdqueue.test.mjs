// cmdqueue.test.mjs — FIFO order + refresh coalescing policy.
// Run: tools/run-unit-tests (auto-discovered; plain node, no framework).
import assert from "node:assert/strict"
import { create, size, push, pushRefresh, dequeue } from "./cmdqueue.mjs"

let n = 0
function eq(got, want, msg) { n++; assert.equal(got, want, msg + ` (got ${JSON.stringify(got)}, want ${JSON.stringify(want)})`) }

// FIFO: commands run in arrival order — the old one-slot runner dropped all
// but the latest; this order is the regression that must never come back.
{
    const q = create()
    push(q, "enable-A")
    push(q, "enable-B")
    push(q, "enable-C")
    eq(size(q), 3, "three queued")
    eq(dequeue(q).cmd, "enable-A", "first in, first out")
    eq(dequeue(q).cmd, "enable-B", "second survives (old runner dropped it)")
    eq(dequeue(q).cmd, "enable-C", "third survives")
    eq(dequeue(q), null, "empty queue → null")
}

// Refresh coalescing: ≤1 queued refresh — the newest replaces the queued one
// IN ITS POSITION, and the superseded callback never fires.
{
    const q = create()
    const fired = []
    push(q, "enable-A", () => fired.push("A"))
    push(q, "mutate-B", () => fired.push("B"))
    pushRefresh(q, "refresh-1", () => fired.push("r1"))
    push(q, "mutate-C", () => fired.push("C"))
    pushRefresh(q, "refresh-2", () => fired.push("r2"))   // replaces r1 in place
    pushRefresh(q, "refresh-3", () => fired.push("r3"))   // replaces r2 in place
    eq(size(q), 4, "refreshes coalesced into one slot")
    const order = []
    let it
    while ((it = dequeue(q)) !== null) { order.push(it.cmd); if (it.cb) it.cb() }
    eq(order.join(","), "enable-A,mutate-B,refresh-3,mutate-C", "refresh keeps its position, others untouched")
    eq(fired.join(","), "A,B,r3,C", "superseded refresh callbacks never fire")
}

// A refresh with nothing queued ahead just appends; refresh-ness never leaks
// into plain pushes.
{
    const q = create()
    pushRefresh(q, "r1")
    push(q, "plain-1")
    push(q, "plain-2")
    pushRefresh(q, "r2")            // replaces r1 (still only queued refresh)
    push(q, "plain-3")
    eq(size(q), 4, "plain pushes never coalesced")
    eq(dequeue(q).cmd, "r2", "coalesced refresh at head")
    eq(dequeue(q).cmd, "plain-1", "then FIFO")
    eq(dequeue(q).cmd, "plain-2", "then FIFO")
    eq(dequeue(q).cmd, "plain-3", "then FIFO")
    eq(dequeue(q), null, "drained")
}

console.log(`cmdqueue.test.mjs: OK (${n} assertions)`)
