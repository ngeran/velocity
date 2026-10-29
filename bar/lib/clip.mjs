// =============================================================================
// clip.mjs — cliphist row parsing + filtering for the clipboard picker (J8)
// =============================================================================
// `cliphist list` prints one row per entry as "<id>\t<preview>". Binary
// entries preview as `[[ binary data "MIME" SIZE UNIT ]]` (cliphist's own
// wording, parsed leniently — a malformed marker degrades to a generic
// "binary" row, never a crash). Everything here is pure and node-tested.
//
// Injection rule the QML side must keep: clipboard content is arbitrary user
// data and NEVER goes through a shell string. Only the numeric id (re-parsed
// here) is ever interpolated into the paste/preview pipelines; the full row
// line travels as a single argv element.
// =============================================================================

const BINARY_RE = /^\[\[\s*binary data(?:\s+"([^"]*)")?\s*(.*)$/

// parseRows(text) → [{ id, preview, isImage, mime, size }]
// Lines without a tab separator are skipped (cliphist never emits them, but
// a partial read mid-... may) ; ids are re-parsed strictly decimal — a row
// with a non-numeric id is junk and dropped (it could never be decoded).
export function parseRows(text) {
    const rows = []
    if (typeof text !== "string") return rows
    const lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        const line = lines[i]
        if (line.length === 0) continue
        const tab = line.indexOf("\t")
        if (tab <= 0) continue
        const id = line.slice(0, tab)
        if (!/^\d+$/.test(id)) continue
        const preview = line.slice(tab + 1)
        const row = { id: id, preview: preview, isImage: false, mime: "", size: "" }
        const m = BINARY_RE.exec(preview)
        if (m) {
            row.isImage = (typeof m[1] === "string" && m[1].indexOf("image/") === 0)
            row.mime = m[1] || ""
            row.size = (m[2] || "").replace(/\s*\]\]\s*$/, "").trim()
        }
        rows.push(row)
    }
    return rows
}

// filterRows(rows, query) → case-insensitive substring match on the preview.
// Empty query passes everything through (order preserved — cliphist is
// newest-first already).
export function filterRows(rows, query) {
    if (!Array.isArray(rows)) return []
    const q = String(query || "").toLowerCase()
    if (q.length === 0) return rows.slice()
    const out = []
    for (var i = 0; i < rows.length; i++)
        if (rows[i].preview.toLowerCase().indexOf(q) !== -1) out.push(rows[i])
    return out
}

// rowLine(row) → the exact list line for this row, the form cliphist decode
// accepts as a single argument (id + tab + preview).
export function rowLine(row) {
    if (!row || !/^\d+$/.test(String(row.id))) return ""
    return row.id + "\t" + String(row.preview || "")
}

// safeId(row) → the id if it is strictly decimal, else "" (the only value
// the shell pipelines may interpolate).
export function safeId(row) {
    if (!row) return ""
    const id = String(row.id || "")
    return /^\d+$/.test(id) ? id : ""
}

// previewFile(runtimeDir, id) → the cache path for a decoded image preview.
export function previewFile(runtimeDir, id) {
    if (!/^\d+$/.test(String(id))) return ""
    return String(runtimeDir || "") + "/velocity/clip-preview-" + id + ".bin"
}
