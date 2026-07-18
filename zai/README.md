# Z.ai Usage Popup — integration notes

## 1. API key

The Z.ai console API key needs read access to the quota endpoint (any
active API key works). Store it either as an env var or a file:

```sh
# NixOS: export in your shell module / home-manager sessionVariables
export ZAI_API_KEY="your-key-here"
```

or, more reliably for a process spawned by Quickshell (which may not
inherit your interactive shell's env depending on how Hyprland/uwsm
launches it):

```sh
mkdir -p ~/.config/zai
echo "your-key-here" > ~/.config/zai/api_key
chmod 600 ~/.config/zai/api_key
```

The script checks `ZAI_API_KEY` / `GLM_API_KEY` first, then falls back
to that file.

## 2. Files

Drop these into your Quickshell config:

```
~/.config/quickshell/
├── scripts/
│   └── zai_usage.py          <- chmod +x, needs python3 only (stdlib)
└── modules/zai-usage/          (or wherever your other modules live)
    ├── qmldir
    ├── ZaiUsageService.qml
    ├── ZaiUsagePopup.qml
    └── UsageRow.qml
```

Adjust `scriptPath` in `ZaiUsageService.qml` if you place the script
elsewhere.

On NixOS, since python3 stdlib only is used (`urllib`, `json`,
`subprocess`, `pathlib`) there's no extra dependency to add to your
flake — just make sure `python3` is on PATH for the Quickshell process
(it already is if you use it elsewhere, e.g. `keybinds_viewer.py`).

## 3. Wire into shell.qml

```qml
import "./modules/zai-usage" as ZaiUsage

// instantiate once, anywhere in your top-level shell
ZaiUsage.ZaiUsagePopup {}
```

The singleton `ZaiUsageService` is auto-available via the qmldir once
imported; the popup references it directly by type name
(`ZaiUsageService`), matching your existing `ThemeService` pattern —
if your build doesn't resolve singletons automatically across module
boundaries, add `import "./modules/zai-usage"` at the top of files
that reference `ZaiUsageService` directly.

## 4. Hyprland keybind

```conf
# ~/.config/hypr/hyprland.conf
bind = $mainMod, Z, exec, qs -c <your-config-name> ipc call zaiUsage toggle
```

Replace `<your-config-name>` with whatever you pass to `qs -c` for
this shell config (check your existing keybinds for the pattern you
already use for other panels).

## 5. Notifications

Handled entirely by `zai_usage.py` via `notify-send`, so they go
through your existing Mako config automatically. Thresholds are
50/75/90/100% and fire once per reset cycle — state is tracked in
`~/.cache/zai-usage/state.json` keyed off the API's `nextResetTime`,
so crossing 75% repeatedly within the same 5h window won't re-notify,
but a fresh window re-arms all four thresholds.

Session (5h) and weekly (7d) windows are tracked and notified
independently, since they reset on different cycles.

## 6. Polling interval

Default poll is every 60s (`pollIntervalMs` in `ZaiUsageService.qml`).
Notifications fire on whatever cadence the popup/service polls at —
if you want tighter threshold-crossing precision, lower the interval;
30s is reasonable and won't meaningfully hammer the endpoint.

## Design notes

- Sharp zero-radius corners, OLED black (`#000000`) background, teal
  `#00dce5` accent, JetBrainsMono Nerd Font — matches Obsidian Core.
- No solid filled highlight bars (burn-in policy from your `CLAUDE.md`
  constraints) — gauges are outlined tracks with a thin animated fill,
  not solid blocks.
- Bar color shifts teal → amber (`#e5b800`) at 75% → red (`#e53e3e`)
  at 90%, both in the popup and in notification urgency levels.
- Panel is screen-proportional (22% width / 30% height), anchored
  top-right, closes on click-outside or Escape via
  `HyprlandFocusGrab`, same interaction pattern as your `PowerMenu`.
