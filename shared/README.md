# shared/ — canonical cross-shell files

Since P2.1 the bar and the settings dashboard run in ONE process, but they
remain **two import worlds**: the settings tree is loaded via file:// and
must not `import "../bar/…"` (a directory imported under two specifiers
yields two singleton instances — the import-split law). So these files are
still **synced into each tree, not imported across trees** (only file://-
loaded plugin code crosses roots, and plugins stay self-contained anyway).

- `MotionConfig.qml`, `DebugConfig.qml` → synced to `bar/config/` and
  `settings/config/` (byte-identical; the root whose config json gets watched
  is derived from the copy's own location).
- `BoundedProcess.qml` → synced to `bar/services/` and `settings/services/`
  (no per-tree divergence — pure primitive).
- `LogService.qml` + `LogModel.js` → synced to `bar/services/` and
  `settings/services/` (the bar's SUPER+T overlay and the dashboard's LOGS
  tab each run their own copy — one journal stream per import world; the
  copies' `import "../config"` resolves to each tree's own DebugConfig).
- `tz.mjs` → synced to `settings/lib/` and into the `nikos.timezones` and
  `nikos.clock` plugins' `lib/` (plugins stay self-contained).

## Workflow

Edit the file HERE, then:

```sh
tools/sync-shared        # copy canonical → every registered target
tools/check-shared       # gate: nonzero exit on drift (also in check-all)
```

Editing a root copy directly will fail `tools/check-shared` — that is the
point: one source of truth, enforced. The per-root file names/paths and the
qmldir singleton entries never change, so syncing is invisible to imports.
