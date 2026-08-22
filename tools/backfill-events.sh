#!/usr/bin/env bash
# =============================================================================
# backfill-events.sh — seed events.jsonl from journald + system generations
# =============================================================================
# Rebuilds the event history EventService only records from "now" onward:
# every GPU Xid/NVRM line and filesystem error across ALL retained boots,
# one boot event per boot (with that boot's kernel version), and one
# nix-switch event per system generation (basename embeds the nixpkgs
# version — the "what changed" axis of the 2026-08-22 incident post-mortem).
#
# Idempotent-ish by design: regenerates the WHOLE file from sources of
# truth (journal + generations), then appends nothing. Live events that
# EventService wrote since are re-derived from the journal tail anyway
# (kernel events) or lost (in-session switch events already covered by
# the generation list). Safe to re-run any time; run it after big
# journal-retention growth or before showing the dashboard off.
#
# Output: ./events.jsonl (chronological, oldest first)
# =============================================================================
# NOTE: no pipefail on purpose — every pipe here is a read-once stream where
# SIGPIPE (grep -m1 / head closing early) and grep's no-match exit would
# abort the run under set -e otherwise.
set -eu
cd "$(dirname "$0")/.."

OUT="events.jsonl"
TMP="$(mktemp)"

esc() {  # lossy-but-safe JSON string escaping for the data field
    sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/'/ /g" | cut -c1-160
}

emit() {  # emit <iso-ts> <sev> <type> <data>
    printf '{"ts":"%s","sev":"%s","type":"%s","data":"%s"}\n' \
        "$1" "$2" "$3" "$(printf '%s' "$4" | esc)" >> "$TMP"
}

# ── kernel events across every retained boot ────────────────────────────────
while read -r boot_index _boot_id first_ts _rest; do
    # boot event: first kernel line's timestamp + that boot's kernel version
    first_line="$(journalctl -b "$boot_index" -k --no-pager -o short-iso 2>/dev/null | head -1 || true)"
    [ -z "$first_line" ] && continue
    ts="${first_line%% *}"
    kver="$(journalctl -b "$boot_index" -k --no-pager 2>/dev/null \
            | grep -oE 'Linux version [^ ]+' | head -n1 | awk '{print $3}')"
    kver="$(printf '%s' "$kver" | head -n1)"
    [ -n "$kver" ] || kver="?"
    emit "$ts" "info" "boot" "boot — kernel ${kver}"

    # GPU / filesystem events in this boot. sda is the MSI monitor's ghost
    # USB storage (see ghost-drive.nix) — its endless I/O errors are KNOWN
    # noise, excluded so real disk events aren't drowned.
    journalctl -b "$boot_index" -k --no-pager -o short-iso 2>/dev/null \
    | grep -E 'NVRM: Xid|NVRM: .*(error|timeout|fall|locked)|EXT4-fs error|I/O error' \
    | grep -v 'dev sda' \
    | while IFS= read -r line; do
        ts="${line%% *}"
        # one strip through "kernel: " — removes ts + hostname + prefix in
        # one step (double space-stripping first would break this pattern:
        # the hostname count varies, "kernel: " does not)
        msg="${line#*kernel: }"
        case "$msg" in
            "NVRM: Xid"*) emit "$ts" "crit" "gpu-xid" "${msg#NVRM: }" ;;
            NVRM:*)       emit "$ts" "crit" "gpu-nvrm" "${msg#NVRM: }" ;;
            *)            emit "$ts" "crit" "fs-error" "$msg" ;;
        esac
    done
done < <(journalctl --list-boots --no-pager 2>/dev/null | awk '{print $1, $2, $3}')

# ── system generations (nixos-rebuild switch history) ───────────────────────
for link in /nix/var/nix/profiles/system-*-link; do
    [ -e "$link" ] || continue
    gen="$(basename "$(readlink -f "$link")")"
    ts="$(date -d "@$(stat -c %Y "$link")" --iso-8601=seconds)"
    emit "$ts" "info" "nix-switch" "system switched → ${gen}"
done

# ── chronological, dedupe exact repeats, publish ────────────────────────────
sort -t'"' -k4 "$TMP" | awk '!seen[$0]++' > "$OUT"
rm -f "$TMP"
echo "backfilled $(wc -l < "$OUT") events → $OUT"
