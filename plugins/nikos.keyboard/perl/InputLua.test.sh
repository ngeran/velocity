#!/usr/bin/env bash
# Offline tests for InputLua.pl — everything runs on sandboxed copies in a
# mktemp dir; the live look-and-feel.lua is never touched.
#
#   plugins/nikos.keyboard/perl/InputLua.test.sh
#
# Focus: the luac -p validation gate added to write/restore, plus the
# backup-rotation and scanner contracts it must not disturb.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PL="$HERE/InputLua.pl"
MAX=65536

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

LUA="$TMP/look-and-feel.lua"
BACKUPS="$TMP/backups"
mkdir -p "$BACKUPS"

FILE_HEAD='hl.config({
  input = {
    kb_layout    = "us,gr",
    kb_options   = "grp:alt_shift_toggle",
  },
})'

pass=0
fail=0
ok()   { pass=$((pass + 1)); }
bad()  { fail=$((fail + 1)); echo "FAIL: $1"; }
check_exit() {  # check_exit <want> <got> <label>
  if [ "$1" = "$2" ]; then ok; else bad "$3 (exit $2, wanted $1)"; fi
}

write_new_file() {
  printf '%s\n' "$FILE_HEAD" > "$LUA"
}

# ── 1. valid write → exit 0, content changed, exactly one backup ──────────
write_new_file
perl "$PL" write "$LUA" "$MAX" "$BACKUPS" de,gr - grp:alt_shift_toggle grp:alt_shift_toggle 2>"$TMP/err"
check_exit 0 $? "valid write"
grep -q 'kb_layout    = "de,gr"' "$LUA" && ok || bad "valid write: kb_layout not updated"
n=$(ls "$BACKUPS" | wc -l)
[ "$n" = "1" ] && ok || bad "valid write: expected 1 backup, got $n"

# ── 2. identical write → exit 0, no new backup (skip-identical) ───────────
perl "$PL" write "$LUA" "$MAX" "$BACKUPS" de,gr - grp:alt_shift_toggle grp:alt_shift_toggle 2>"$TMP/err"
check_exit 0 $? "identical write"
n=$(ls "$BACKUPS" | wc -l)
[ "$n" = "1" ] && ok || bad "identical write: backup count changed ($n)"

# ── 3. read reflects the write ────────────────────────────────────────────
out=$(perl "$PL" read "$LUA" "$MAX" 2>"$TMP/err")
check_exit 0 $? "read"
echo "$out" | grep -q '"de","gr"' && ok || bad "read: layouts not reported: $out"

# ── 4. commented-out assignment stays invisible ───────────────────────────
printf '%s\n-- kb_layout = "fr",\n' "$FILE_HEAD" > "$LUA"
out=$(perl "$PL" read "$LUA" "$MAX" 2>"$TMP/err")
check_exit 0 $? "read with comment"
echo "$out" | grep -q '"fr"' && bad "scanner saw a commented-out assignment" || ok

# ── 5. corrupt backup → restore exits 13, live file untouched ─────────────
# Truncated Lua scans fine (kb_layout found) but must fail luac -p.
write_new_file
perl "$PL" write "$LUA" "$MAX" "$BACKUPS" de,gr - grp:alt_shift_toggle grp:alt_shift_toggle 2>"$TMP/err"
good_backup="$(ls "$BACKUPS" | tail -1)"
cp "$LUA" "$TMP/live.before"
printf 'hl.config({ input = { kb_layout = "xx"' > "$BACKUPS/$good_backup"
perl "$PL" restore "$LUA" "$MAX" "$BACKUPS" "$good_backup" >"$TMP/out" 2>"$TMP/err"
check_exit 13 $? "corrupt restore"
grep -q "fails luac -p" "$TMP/err" && ok || bad "corrupt restore: no luac message in stderr"
cmp -s "$LUA" "$TMP/live.before" && ok || bad "corrupt restore: live file was modified"

# ── 6. good backup → restore still works ──────────────────────────────────
perl "$PL" write "$LUA" "$MAX" "$BACKUPS" fr - grp:alt_shift_toggle grp:alt_shift_toggle 2>"$TMP/err"
check_exit 0 $? "second valid write"
fresh="$(ls "$BACKUPS" | grep -v -F -x "$good_backup" | tail -1)"
perl "$PL" restore "$LUA" "$MAX" "$BACKUPS" "$fresh" 2>"$TMP/err"
check_exit 0 $? "good restore"
# $fresh holds the state before the fr write, i.e. the de,gr one.
grep -q '"de","gr"' <(perl "$PL" read "$LUA" "$MAX" 2>/dev/null) && ok || bad "good restore: values not restored"

# ── 7. no stray probe/temp files next to the input ────────────────────────
ls "$TMP" | grep -q "\.probe\.\|\.tmp\." && bad "temp/probe files left behind" || ok

echo "InputLua.test.sh: $pass passed, $fail failed"
[ "$fail" = "0" ]
