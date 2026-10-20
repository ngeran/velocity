# shared/ — canonical cross-shell files

The bar (`quickshell -c bar`) and the settings dashboard (`-c settings`) are
**separate config roots**. Quickshell's VFS blocks QML imports that escape
the root, so these files are **synced into each root, not imported across
roots** (only file://-loaded plugin code can cross roots).

- `MotionConfig.qml`, `DebugConfig.qml` → synced to `bar/config/` and
  `settings/config/` (byte-identical; the root whose config json gets watched
  is derived from the copy's own location).
- More canonical files may join (`BoundedProcess.qml` → `services/` dirs).

## Workflow

Edit the file HERE, then:

```sh
tools/sync-shared        # copy canonical → every registered target
tools/check-shared       # gate: nonzero exit on drift (also in check-all)
```

Editing a root copy directly will fail `tools/check-shared` — that is the
point: one source of truth, enforced. The per-root file names/paths and the
qmldir singleton entries never change, so syncing is invisible to imports.
