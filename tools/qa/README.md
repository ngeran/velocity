# tools/qa — live QA harness

Scenario-driven verification against the **resident** shells. Adapted from
Ryoku 1.0.3's `launcher/qa` contract (string-step DSL, evidence dirs,
no-partial-pass, BLOCKED verdicts) onto our two-process IPC setup.

    tools/qa/run                  # full suite
    tools/qa/run --only popup-controlcenter-cycle
    tools/qa/run --list           # ids + names, run nothing
    QA_OUT=/tmp/x tools/qa/run    # evidence root (default /tmp/velocity-qa)

## The two rules that make this safe

1. **Never spawns Quickshell.** The runner talks to the resident bar/settings
   processes over `qs -c … ipc call` only. If preflight can't reach them it
   refuses (exit 2) and tells you to restart the unit. A second
   `quickshell -c` instance has frozen the session before — this harness is
   structurally incapable of causing that.
2. **No partial pass.** Asserts run only after clean steps; teardown runs
   ALWAYS and a teardown failure fails the scenario; any `-p err` journal
   line from the shells during a scenario fails it (cursor-gated, so
   concurrent activity can't cross-contaminate; `allowJournalErrors` exempts
   known-noisy lines). Every scenario leaves evidence in
   `$QA_OUT/run-<stamp>/<id>/`: `scenario.json`, `steps.log`, IPC outputs,
   screenshots, layer dumps, `results.tsv` at the run root.

## Step DSL (whitespace-split strings in `scenarios.json`)

| Step | Effect |
|------|--------|
| `ipc <bar\\|settings> <target> <fn> [args…]` | `qs -c … ipc call`; nonzero/timeout = FAIL; output → evidence |
| `ipc? …` | same, exit code tolerated (failure is data) |
| `sh <command>` | `bash -c`; nonzero = FAIL |
| `sleep <s>` | fractional ok |
| `key <wtype args…>` | wtype VERBATIM (e.g. `-M super -k k -m super`); keys land in the FOCUSED window — make that safe; scenario SKIPs if wtype absent |
| `cursor <x> <y>` | synthetic cursor via the Lua dispatcher (`movecursor` is a no-op here) |
| `shot <label>` | grim → evidence PNG |
| `layers <label>` | hyprctl layer dump + two counts (below) |

## Scenario fields

`id` `name` `covers` `steps[]` `asserts[]` (bash -c, `$QA_EV` = evidence dir,
exit 0 = pass) `teardown[]` (always runs; failure fails) `requires[]`
(missing tool → SKIP) `units[]` (journal gate scope, default both shells)
`allowJournalErrors` (ERE) `blocked` (reason — a FAIL reports as BLOCKED,
a documented defect outside the harness, without failing the run).

Verdicts: `PASS` / `FAIL` / `SKIP` / `BLOCKED`. Exit code is nonzero iff any FAIL.

## Layer counts — read this before writing popup scenarios

The `layers` op saves `<n>.json` (full dump), `<n>.count` (ALL
quickshell-namespace surfaces) and `<n>.alive` (surfaces owned by the bar
unit's live `MainPID`). **Assert on `.alive`, never `.count`**: full-height
`pid:-1` zombie layers from past restarts linger until Hyprland reaps them
asynchronously — a run can legitimately watch the raw count decay. The bar
unit's MainPID filter is the zombie-immune open/close signal.
(currently: unit-less dev `-p` mode degrades `.alive` to the raw count).

## Suite inventory (10)

| Scenario | What it proves |
|----------|----------------|
| `bar-resident-health` | ping; plugins.list invariants (unique ids, clock present, id/name strings); layout shape |
| `settings-resident-health` | wallpaper getters coherent (`getList` line count == `getCount`); engine status JSON; search index ≥10 |
| `plugins-layout-noop-roundtrip` | save path + Layout.prune + rescan leave the layout byte-identical (place at live position) |
| `plugins-settings-roundtrip` | settings schema serves; noop `setSetting` replies ok; a bad enum value is rejected by the schema; values byte-identical — the transport the Plugins pane form uses |
| `keyboard-layout-status` | nikos.keyboard status serves ≥1 layout |
| `popup-controlcenter-cycle` | Control Center maps exactly one alive surface and closes clean; screenshot evidence; journal silence |
| `overlay-keybinds-cycle` | same contract for the keybinds overlay (toggleOverlay family) |
| `wallpaper-noop-set` | re-setting the current wallpaper is a render exercise with zero state drift |
| `settings-search-index` | search index serves well-formed query hits (title/tab/section) |
| `keybinds-via-keybind` | the REAL SUPER+K keybind end-to-end through the compositor — **SKIPs until wtype lands in the flake** |

## Adding scenarios

Add an object to `scenarios.json`. Rules of thumb: start from the state you
expect (the suite assumes all popups closed); capture a `layers before` as
teardown baseline; restore in `teardown` anything a step mutated, using the
same verb that mutated it (teardown failure = FAIL is the enforcement); never
mutate user state without restoring it (why there is no notifications
add/clear scenario yet — the service has add/clear/restore but no per-item
remove, so a test notification cannot be removed without touching real ones).

## Deliberately not in `check-all`

The gates are headless-fast (~4s) and must run on every commit; this harness
drives the LIVE desktop (toggles real popups, re-sets wallpapers, takes
screenshots) and takes ~40s. Run it explicitly — especially after engine/
plugin/style changes and before commits that touch surfaces a scenario
covers. Post-rebuild candidates: wallpaper-engine scenarios (engine status
is `{}` until the Nix rebuild lands the engine binary), island-style popup
embedding (suite assumes vector-style layer behavior for screenshots).
