# bar — the top-bar process

One Quickshell process (`quickshell -c bar`) rendering the Hyprland top bar.
Everything on it is a plugin; the styles (`vector`, `notch`, `ryoku`,
`island`) swap live from the Control Center's BAR page (or the settings app).

**Real docs live one level up — start here:**

- `../CLAUDE.md` — architecture: host shell → style Scene → `engine/`
  (PluginRegistry, PluginSlot, BarSection), services, three-layer separation,
  deployment modes
- `../plugins/README.md` + `../bin/velocity-plugin` — writing and managing
  plugins (`velocity-plugin place/move/enable/…`)
- `../settings/` — the dashboard views; hosted in THIS process since P2.1 (SettingsHostWindow)

## Quick reference

```bash
systemctl --user restart quickshell-bar      # sanctioned restart
qs -c bar ipc call plugins layout            # current section layout
qs -c bar ipc call plugins list              # discovered plugins + state
```

Never launch a second `quickshell -c bar` to "test" — IPC targets and layer
space are per-config singletons. Verify live via `qs ipc` and
`journalctl --user -u quickshell-bar`.

Gates: `tools/check-all` (qmldir / plugins / engine / ipc / bounded +
`tools/run-unit-tests`).
