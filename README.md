# Velocity

A QD-OLED-first Quickshell bar, settings app and plugin engine for
Hyprland on NixOS. One process renders everything: the bar strip (4 swappable styles),
the notifications center, the OSD, and the full settings app
(loaded lazily into the same process). The lock screen is the one deliberate second
process — crash isolation and a auditable PAM path.

- **Panel-safe by doctrine** — this rice runs on a QD-OLED. Pure-black fills, no static
  bright strokes, pixel-shift orbit on always-on chrome, overlays fade to black within
  1.5 s of idle (see [Burn-in doctrine](#burn-in-doctrine)).
- **Event-driven** — native Quickshell modules first (Networking, Bluetooth, Pipewire,
  UPower, Notifications, SystemTray), long-lived streams where a module doesn't exist;
  every `Process` is bounded (timeout + output cap). 0 spawns/min idle, 0.0 % idle CPU.
- **Single source of truth** — one service per domain, every surface (bar card, Control
  Center tile, settings pane) is a view of that owner.
- **Plugin engine** — sandboxed-by-layout plugins with a manifest, a qs.Ui kit, live
  layout/state IPC and a validation CLI (`bin/velocity-plugin`). See
  [plugins/README.md](plugins/README.md).

Licence: [MIT](LICENSE). Velocity is a clean-room reimplementation: its look was
inspired by the GPL-3.0 *glyph* shell, but no glyph code was read or copied — only
observed behaviour. Fonts ship from nixpkgs under the OFL.

## Install

Velocity is a flake. The checkout itself is the live config dir (`~/.config/quickshell`
is a link to this repo, so the bar can write its state files); the flake links it and
ships the units.

```nix
# flake.nix of the host (omni-nix)
{
  inputs.velocity.url = "github:ngeran/velocity"; # or a path:/git: to this checkout
  inputs.home-manager.url = "github:nix-community/home-manager";
}
```

```nix
# Home Manager
imports = [ inputs.velocity.homeManagerModules.default ];
programs.velocity = {
  enable = true;
  checkout = "/home/me/src/velocity"; # linked out of the store so it stays writable
  plugins = [ ]; # packages built with velocity.lib.mkPlugin pkgs { src; }
};
```

```nix
# NixOS (host side of the lock)
imports = [ inputs.velocity.nixosModules.default ]; # security.pam.services.velocity-lock
```

Then rebuild (`omni-apply`). On first boot the module seeds
`~/.config/velocity/plugins-state.json` with the default plugins and renders
`~/.config/hypr/velocity-binds.lua`, which the Hyprland config `require`s.

## Options (`programs.velocity`)

| Option | Type | Default | What it does |
|---|---|---|---|
| `enable` | bool | `false` | Install + run velocity (bar unit, files, binds). |
| `checkout` | `nullOr str` | `null` | Repo dir linked to `~/.config/quickshell` out of the store (stays writable). `null` = manage the link yourself (`tools/deploy-link`). |
| `plugins` | listOf package | `[ ]` | System plugins, built with `velocity.lib.mkPlugin`. |
| `quickshellPackage` | package | `pkgs.quickshell` | The Quickshell to run (0.3.0 or newer). |
| `runtimeInputs` | listOf package | curl, util-linux, procps, bash, awww, ffmpeg, matugen, mpvpaper, … | PATH of the bar unit — everything services may fork. |
| `fonts.enable` | bool | `true` | Install the UI fonts (Doto + friends). |
| `lock.enable` | bool | `true` | `velocity-lock` wrapper + PAM check + watchdog unit/timer. Refuses to lock without the host PAM file. |
| `keybinds` | attrset | the D3 table below | Rendered to `~/.config/hypr/velocity-binds.lua` + `~/.config/velocity/keybinds.json`. Rows with `available: false` render in the cheat sheet but bind nothing. |
| `enabledPlugins` | listOf str | `[ "nikos.clock" "nikos.power" "nikos.keyboard" ]` | First-boot seed of `plugins-state.json`. |
| `systemd.enable` | bool | `true` | `quickshell-bar` + `velocity-cliphist` units (+ lock watchdog). |

## Keybinds

Generated from the D3 attrset (`tools/keybinds-default.json` → `nix/hm-module.nix` →
`velocity-binds.lua`). Press `SUPER+K` for the live cheat sheet.

**QUICK ACCESS**

| Key | Action |
|---|---|
| `SUPER+SPACE` | App launcher |
| `SUPER+SHIFT+V` | Clipboard history |
| `SUPER+N` | Settings dashboard |
| `SUPER+COMMA` | Settings › BAR |
| `SUPER+SHIFT+R` | Screen recorder |
| `SUPER+SHIFT+W` | Wallpaper cycle |
| `SUPER+SHIFT+N` | Do not disturb |
| `SUPER+SHIFT+S` | Screenshot region |
| `PRINT` | Screenshot output |

**OVERLAYS**

| Key | Action |
|---|---|
| `SUPER+SHIFT+T` | Network / Bluetooth center |
| `SUPER+K` | This cheat sheet |
| `SUPER+A` | Settings dashboard |
| `SUPER+T` | System logs |
| `SUPER+Z` | Z.ai usage |
| `SUPER+P` | Power menu |
| `SUPER+SHIFT+B` | Toggle the bar |
| `SUPER+SHIFT+SPACE` | Next keyboard layout |

**SESSION**

| Key | Action |
|---|---|
| `SUPER+L` | Lock screen |

## Burn-in doctrine

The target panel is a QD-OLED; static bright content burns. Non-negotiables, enforced
in review and gated by the qa suite:

- Pure `#000000` fills. No static bright strokes — hairlines at most ~3 % luminance, or dot rules.
- No full-white static text; accents only while something is happening.
- Always-on elements run `BurnOrbit` pixel shift (`bar/components/BurnOrbit.qml`, on in all four styles).
- Transient overlays fade to black within 1.5 s of idle.
- Sizes come from scale tokens, never literals. Light themes are out of scope.

## Repo map

| Path | What |
|---|---|
| `bar/` | The bar process: `shell.qml` host, engine (plugin host, popup coordinator), styles (`vector` default, `notch`, `ryoku`, `island`), builtins, components, services. See [bar/CLAUDE.md](bar/CLAUDE.md). |
| `settings/` | The settings app (loaded into the bar process on first open): themes, wallpapers, control, core, logs panes. |
| `plugins/` | Opt-in plugins (`nikos.*`): clock, keyboard, power, storage, timezones. See [plugins/README.md](plugins/README.md). |
| `shared/` | Files byte-identical across import roots, distributed by `tools/sync-shared`. See [shared/README.md](shared/README.md). |
| `lock/` | The lock screen (separate process, WlSessionLock + PAM). |
| `nix/` | HM module, plugin builder, unit definitions. |
| `tools/` | Gates (`check-all` = qmldir, IPC surface, bounded processes, engine architecture, shared sync, SSOT, glyphs, tools closure, plugins + runtime budgets), the qa harness (`tools/qa/run`), deploy + sync scripts. |

Verify a tree: `./tools/check-all` (static gates) · `nix flake check` (module eval +
tests in a sandbox) · `./tools/check-runtime` (live budgets: warnings 0, CPU, RSS,
spawns, cold start · embedded qa suite).
