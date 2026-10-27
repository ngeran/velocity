#!/usr/bin/env sh
# =============================================================================
# validate-plugin.sh — thin wrapper over `bin/velocity-plugin validate` (I7)
# =============================================================================
# The CLI is the one validator (manifest + entry files + no symlinks, driven
# by the same bar/engine/lib/manifest.mjs rules the bar loads with); this shim
# keeps the old offline-invocation path working.
# Usage: tools/validate-plugin.sh <plugin-dir|id>
# =============================================================================
exec "$(cd "$(dirname "$0")/.." && pwd)/bin/velocity-plugin" validate "$@"
