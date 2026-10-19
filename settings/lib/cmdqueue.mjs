// cmdqueue.mjs — FIFO command queue for the settings plugin manager.
// =============================================================================
// The old runner kept ONE pending slot: when the process was busy, the latest
// request replaced the queued one — enable(A) issued right before enable(B)
// silently never ran. This is a plain FIFO instead, plus one policy: refresh
// commands coalesce (≤1 queued refresh; a new queued refresh REPLACES the
// queued one IN ITS POSITION — it must not jump behind plugin commands, and
// the superseded refresh's callback must never fire).
//
// Pure; node-tested (cmdqueue.test.mjs). The QML side (PluginManagerService)
// drives the Process: dequeue() when idle, finish() when the process settles.
// =============================================================================

// Item shape: { cmd, cb, refresh } — refresh marks a coalescable poll.
export function create() {
    return { items: [] }
}

export function size(q) {
    return q.items.length
}

// Plain FIFO append (plugin mutations, installs, anything order-sensitive).
export function push(q, cmd, cb) {
    q.items.push({ cmd: cmd, cb: cb || null, refresh: false })
}

// Refresh append with coalescing: replaces an already-queued refresh in its
// position (dropping the old callback un-fired); appends otherwise.
export function pushRefresh(q, cmd, cb) {
    for (var i = 0; i < q.items.length; i++) {
        if (q.items[i].refresh) {
            q.items[i] = { cmd: cmd, cb: cb || null, refresh: true }
            return
        }
    }
    q.items.push({ cmd: cmd, cb: cb || null, refresh: true })
}

// Next command to run, or null when the queue is empty.
export function dequeue(q) {
    return q.items.length > 0 ? q.items.shift() : null
}
