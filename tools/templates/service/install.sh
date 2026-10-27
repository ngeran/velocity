#!/usr/bin/env bash
# {{ID}} runtime installer — run by ServiceRoot.qml on enable, and via the
# `setup` IPC verb. Contract:
#   serialized         — flock on a state lock; a second run waits, then no-ops
#   skip-if-unchanged  — a marker records a checksum over runtime/; identical
#                        content skips straight to exit 0
#   --force            — re-run the install steps even when unchanged
#   logged             — ServiceRoot.qml redirects stdout+stderr to
#                        $XDG_STATE_HOME/velocity/plugins/{{ID}}/install.log
# Hygiene for anything this script edits OUTSIDE the plugin dir:
#   backup-once  — "<target>.{{ID}}.bak" is created once, never overwritten
#   validate     — run a checker (luac -p, hyprctl configerrors, …) and exit
#                  non-zero BEFORE the marker is written, or a broken install
#                  counts as done
set -euo pipefail

ID="{{ID}}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME="$HERE/runtime"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/velocity/plugins/$ID"
LOCK="$STATE/install.lock"
MARKER="$STATE/installed"

mkdir -p "$STATE"
exec 9>"$LOCK"
flock -w 120 9 || { echo "another install holds the lock"; exit 1; }

# Checksum over the payload, stable order, no external hash tool needed.
hash_runtime() {
  find "$RUNTIME" -type f -print0 2>/dev/null | sort -z \
    | xargs -0 -r cksum | cksum | cut -d' ' -f1
}

if [ "${1:-}" != "--force" ] && [ -f "$MARKER" ] \
   && [ "$(cat "$MARKER")" = "$(hash_runtime)" ]; then
  echo "runtime unchanged — skipping (setup verb with 'force' re-runs the steps)"
  exit 0
fi

echo "=== {{ID}} install start $(date -Is) ==="

# ── your install steps ─────────────────────────────────────────────────────
# Copy payload files somewhere real, patch a config, restart a unit — all idempotent.
#
#   TARGET="$HOME/.config/hypr/look-and-feel.lua"
#   if [[ -f $TARGET && ! -f "$TARGET.$ID.bak" ]]; then
#     cp -- "$TARGET" "$TARGET.$ID.bak"                      # backup-once
#   fi
#   install -Dm755 -T "$RUNTIME/helper" "$HOME/.local/share/$ID/helper"
#
# Validate before declaring success — a non-zero exit here leaves the marker
# unwritten, so the next run (or re-enable) retries instead of skipping:
#
#   luac -p "$HOME/.local/share/$ID/helper.lua"
# ──────────────────────────────────────────────────────────────────────────

echo "install steps: none yet — edit install.sh (runtime payload lives in ./runtime)"

hash_runtime > "$MARKER"
echo "=== {{ID}} install done $(date -Is) ==="
