#!/usr/bin/env sh
# =============================================================================
# validate-plugin.sh — offline manifest/layout check for nikos plugins
# =============================================================================
# Usage: tools/validate-plugin.sh <plugin-dir>
# Checks (mirroring PluginHostService's load-time rules):
#   1. manifest.json exists and parses as JSON (via node)
#   2. required fields: schemaVersion=1, namespaced id (omarchy.* reserved),
#      name, version, non-empty kinds, entryPoints
#   3. every declared entry point is a safe relative filename that EXISTS
#   4. no symlinks anywhere in the plugin folder
# Exit 0 = valid; 1 = problems (printed).
# =============================================================================
DIR="${1:-}"
if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
    echo "usage: $0 <plugin-dir>"; exit 1
fi
DIR="$(cd "$DIR" && pwd)"
FAIL=0

if [ ! -f "$DIR/manifest.json" ]; then
    echo "✗ manifest.json not found in $DIR"; exit 1
fi

# JSON + contract checks in one node pass (no python3 on this box)
node -e '
const fs = require("fs");
const dir = process.argv[1];
let m;
try { m = JSON.parse(fs.readFileSync(dir + "/manifest.json", "utf8")); }
catch (e) { console.error("✗ manifest is not valid JSON: " + e.message); process.exit(1); }
const errs = [];
if (m.schemaVersion !== 1) errs.push("schemaVersion must be 1");
if (m.api !== undefined && m.api !== 1) errs.push("unsupported api: " + m.api);
if (typeof m.id !== "string" || !/^[a-z][a-z0-9_]*\.[a-z][a-z0-9_-]*$/.test(m.id))
    errs.push("id must be namespaced like author.name");
if (m.id && m.id.startsWith("omarchy.")) errs.push("id omarchy.* is reserved");
if (typeof m.name !== "string" || !m.name) errs.push("name missing");
if (m.version === undefined) errs.push("version missing");
if (!Array.isArray(m.kinds) || m.kinds.length === 0) errs.push("kinds missing");
const legal = ["bar-widget", "service"];
for (const k of (m.kinds || [])) {
    if (!legal.includes(k)) { errs.push("unsupported kind: " + k); continue; }
    const key = k === "bar-widget" ? "barWidget" : k;
    const e = m.entryPoints ? m.entryPoints[key] : undefined;
    if (typeof e !== "string" || !e || e.includes("/") || e.includes(".."))
        errs.push("entryPoints." + key + " must be a safe relative filename");
    else if (!fs.existsSync(dir + "/" + e))
        errs.push("entry point file not found: " + e);
}
if (errs.length) { errs.forEach(e => console.error("✗ " + e)); process.exit(1); }
console.log("✓ manifest ok: " + m.id + " [" + m.kinds.join(", ") + "]");
' "$DIR" || FAIL=1

SYMLINKS="$(find "$DIR" -type l 2>/dev/null)"
if [ -n "$SYMLINKS" ]; then
    echo "✗ symlinks are not allowed in plugin folders:"
    echo "$SYMLINKS" | sed 's/^/    /'
    FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
    echo "✓ $DIR valid"
fi
exit $FAIL
