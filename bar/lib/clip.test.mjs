// clip.test.mjs — cliphist row parsing + filtering (J8)
import * as Clip from "./clip.mjs"

let n = 0
function ok(cond, label) {
    n++
    if (!cond) { console.error("FAIL: " + label); process.exitCode = 1 }
}
function eqv(got, want, label) {
    n++
    if (JSON.stringify(got) !== JSON.stringify(want)) {
        console.error("FAIL: " + label + "\n  got:  " + JSON.stringify(got) +
                      "\n  want: " + JSON.stringify(want))
        process.exitCode = 1
    }
}

// ── parseRows ───────────────────────────────────────────────────────────────
const text = [
    "42\tquickshell commit message draft",
    "41\t[[ binary data \"image/png\" 15.61 KiB ]]",
    "40\tpath: /etc/nixos/configuration.nix",
    "39\t[[ binary data \"text/x-keepass\" 2.1 KiB ]]",
    "38\t[[ binary data ]]",
].join("\n")
const rows = Clip.parseRows(text)
eqv(rows.length, 5, "five rows parsed")
eqv(rows[0].id, "42", "id before the tab")
eqv(rows[0].preview, "quickshell commit message draft", "preview after the tab")
ok(rows[0].isImage === false && rows[1].isImage === true, "image flag on image/ mime only")
eqv(rows[1].mime, "image/png", "mime extracted")
eqv(rows[1].size, "15.61 KiB", "size extracted, ]] stripped")
ok(rows[3].isImage === false, "non-image binary is not flagged image")
ok(rows[3].mime === "text/x-keepass", "non-image binary keeps its mime")
ok(rows[4].isImage === false && rows[4].mime === "" && rows[4].size === "",
   "marker without mime/size degrades to generic binary")

eqv(Clip.parseRows("no-tab-line\n\n:weird-start\tjunk\n99\tok").map((r) => r.id), ["99"],
    "tabless + non-numeric-id lines dropped")
eqv(Clip.parseRows(""), [], "empty text → no rows")
eqv(Clip.parseRows(null), [], "null → no rows")
const embed = Clip.parseRows("7\tmulti\tline")
eqv(embed.length, 1, "one row despite an embedded tab")
eqv(embed[0].preview, "multi\tline", "split at the FIRST tab only — preview keeps the rest")

// ── filterRows ──────────────────────────────────────────────────────────────
eqv(Clip.filterRows(rows, "commit").map((r) => r.id), ["42"], "substring match")
eqv(Clip.filterRows(rows, "COMMIT").map((r) => r.id), ["42"], "case-insensitive")
eqv(Clip.filterRows(rows, "binary").map((r) => r.id), ["41", "39", "38"], "order preserved")
eqv(Clip.filterRows(rows, "").length, 5, "empty query passes everything")
eqv(Clip.filterRows(rows, "zzz"), [], "no match → empty")
eqv(Clip.filterRows(null, "x"), [], "junk rows arg → empty")

// ── rowLine / safeId ────────────────────────────────────────────────────────
eqv(Clip.rowLine(rows[0]), "42\tquickshell commit message draft", "rowLine round-trips the list line")
eqv(Clip.rowLine({ id: "x", preview: "p" }), "", "non-numeric id → empty line")
eqv(Clip.safeId(rows[1]), "41", "safeId passes decimal")
eqv(Clip.safeId({ id: "4 rm -rf", preview: "" }), "", "safeId rejects decorated id")
eqv(Clip.safeId(null), "", "safeId null → empty")

// ── previewFile ─────────────────────────────────────────────────────────────
eqv(Clip.previewFile("/run/user/1000", "41"), "/run/user/1000/velocity/clip-preview-41.bin",
    "preview path layout")
eqv(Clip.previewFile("/run/user/1000", "../etc"), "", "path traversal refused")
eqv(Clip.previewFile("", "41"), "/velocity/clip-preview-41.bin", "empty dir still yields a parseable path")

console.log("clip: " + n + " asserts OK")
