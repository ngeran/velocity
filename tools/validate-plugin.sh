#!/usr/bin/env sh
# =============================================================================
# validate-plugin.sh — offline manifest/layout check for nikos plugins
# =============================================================================
# Usage: tools/validate-plugin.sh <plugin-dir>
# Checks (the same bar/engine/lib/manifest.mjs rules the bar loads with):
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

# Contract checks come from the SAME module the bar host loads
# (bar/engine/lib/manifest.mjs), so offline and load-time rules can't drift.
# HOST_API must track PluginRegistry.apiVersion (bar/engine/PluginRegistry.qml).
LIB="$(cd "$(dirname "$0")/../bar/engine/lib" && pwd)/manifest.mjs"
HOST_API="${VELOCITY_HOST_API:-2}"
node --input-type=module -e '
import { readFileSync, existsSync } from "node:fs";
const [lib, dir, hostApi] = process.argv.slice(1);
const { parseManifest } = await import("file://" + lib);
const r = parseManifest(readFileSync(dir + "/manifest.json", "utf8"),
    { hostApi: Number(hostApi), fileExists: f => existsSync(dir + "/" + f) });
if (!r.ok) { r.errors.forEach(e => console.error("✗ " + e)); process.exit(1); }
console.log("✓ manifest ok: " + r.plugin.id + " [" + r.plugin.kinds.join(", ") + "]");
' "$LIB" "$DIR" "$HOST_API" || FAIL=1

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
