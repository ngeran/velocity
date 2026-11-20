# nikos.vnc — TigerVNC client pill with saved connections

Velocity bar plugin (api 2). Monitor glyph tracks the VNC session; the
popup shows saved connections with one-click connect, a login form that
stores credentials encrypted, reachability probes (ICMP + VNC port), an
RTT sparkline, session duration, and connect/disconnect.

## Host requirements

- `services.velocityVnc.enable = true;` (`.omni-nix` `modules/vnc.nix`) —
  puts `vncviewer` + `vncpasswd` on the system PATH.
- Bar runtimeInputs carry `tigervnc` (viewer), `iputils` (ping) and the
  usual `netcat`/`procps` so the service unit is self-sufficient.

## Saved connections

- The form (popup › ADD) captures NAME, HOST, PORT, USER, PASSWORD.
  Host is a raw IP on this network (no DNS — e.g. `10.0.0.70`) or an
  mDNS name if you run one. Up to 12 connections, MRU-first; connecting
  stamps `lastUsed`.
- The password is piped over stdin to `vncpasswd -f` (never argv — argv
  is world-readable in `/proc`) and stored encrypted at
  `~/.config/secrets/vnc/<id>.vnc`, mode 600. The connections index
  lives under `$XDG_STATE_HOME/velocity/plugins/`. Plaintext exists
  only in memory and the pipe. DES limits the usable password to 8
  characters.
- USER is metadata for the row display only: TigerVNC has no argv for
  user+pass, so servers requiring Plain/TLSPlain auth prompt in the
  viewer itself. macOS Screen Sharing uses VncAuth — fully covered by
  the stored password file.
- SAVE + CONNECT persists the record and secret first; the viewer only
  launches after both are durable. Editing with a blank password keeps
  the existing secret; DELETE removes the row and its secret file.
- The ad-hoc settings (host/port/fullScreen) still work when no saved
  connection is active; a saved row overrides them while it is the
  target.

## Remote side (one-time, on the target)

1. System Settings › Sharing › Screen Sharing → **ON** (macOS).
2. Enable "VNC viewers may control screen with password" and set a
   password (the one you will paste into the plugin form).

## Behavior

- **State** — `connected` (a `vncviewer` process exists), `disconnected`,
  `host-unreachable` (ICMP fails), `port-closed` (port probe fails). A
  launch that never produces a viewer process surfaces as a "viewer did
  not start" hint (usually `vncviewer` missing from the bar's PATH),
  not a state.
- **Connect** — `vncviewer <host>::<port>` launched detached (`ctx.run`),
  with `-PasswordFile` when the active target has a stored secret and
  `-FullScreen` when the connection (or the global setting) asks for
  it. Single session by design: disconnect first.
- **Disconnect** — `pkill -x vncviewer`. This kills *any* TigerVNC
  viewer session owned by the user.
- **Probes** — `pgrep -x vncviewer` (session), `ping -c1 -W1`
  (reachability + RTT), `nc -z -w1` (VNC port), all against the active
  target. Slow cadence while the popup is closed, 1 Hz while open.
- **Popup keys** — `c` connect/toggle, `r` refresh, `Esc` close (form
  first). Rows: click to connect, pencil to edit, trash twice to delete.
- **IPC verbs** — `toggle open close refresh status telemetry connect
  disconnect` (`qs -c bar ipc call plugins call nikos.vnc <verb>`).

## Troubleshooting

- If macOS negotiates oddly, TigerVNC's `SecurityTypes` parameter can
  be tuned per-launch (`vncviewer -SecurityTypes VncAuth
  10.0.0.70::5900`) — deliberately not a settings knob.
- Fullscreen on multi-monitor: the viewer defaults to
  `-FullScreenMode Current`; change only if needed.
- Corrupt/missing secret file: the viewer falls back to prompting
  interactively.

## Scope limits (v2)

One viewer session at a time, one secret per connection (no username
auth via argv — viewer prompts), no traffic counters (RFB gives none
unprivileged), no file transfer / clipboard controls, no TLS/X509 or
SSH tunnel management.
