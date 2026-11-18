# nikos.wireguard

WireGuard + Tailscale panel for the velocity bar. Ported from
[`ngeran.wireguard`](https://github.com/ngeran/omarchy-plugins) (Omarchy bar
plugin by ngeran, MIT — see LICENSE); the shell integration is rewritten for
the velocity plugin API 2, the data model is his.

## What it does

- **Bar pill** — shield when a tunnel is up, lock when down. Left click opens
  the panel, right click toggles the primary tunnel, middle click refreshes.
- **WireGuard tab** — one row per NetworkManager WireGuard profile (toggle,
  two-step delete), `.conf` import via a file dialog (the path goes to
  `nmcli connection import`; file contents never enter QML), and live
  telemetry for the active tunnel: rates (sysfs counters via FileView — zero
  forks), uptime, endpoint, allowed IPs, DNS.
- **Tailscale tab** — backend state (running / needs login / stopped /
  not installed), login URL hand-off, device list with direct/relay paths,
  exit-node picker, up/down.
- **IPC** — every action is reachable headless:
  `qs -c bar ipc call plugins call nikos.wireguard <verb> [arg]`
  (verbs: toggle/open/close/status/telemetry/up/down/toggleTunnel/tailscale/
  tailscaleUp/tailscaleDown/tailscaleExitNode/tab/refresh).

## Deliberately not ported (v1)

- **Handshake telemetry** (`wg show`, needs root) — ngeran ships a pkexec
  sudoers installer for it. Dropped here; handshake-dependent rows render
  "—". A declarative `security.sudo.extraRules` variant is a possible future
  tier.

## Privileges

- WireGuard profiles are plain NetworkManager connections: `nmcli` as the
  user, nothing elevated.
- Tailscale control is unprivileged through the operator grant — the host
  module (`.omni-nix/modules/vpn.nix`) starts tailscaled with
  `--operator=<user>`.

## Declared commands

`nmcli`, `sh` (one-shot binary presence probe only), `tailscale`.

## Settings

- `refreshIntervalSec` (2–60, default 5) — closed-panel poll cadence for both
  services; the panel forces 1 Hz (WireGuard) / 2 s (Tailscale) while open.
