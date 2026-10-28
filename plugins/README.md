# Velocity plugins

A plugin is one self-contained folder: a `manifest.json` plus the QML files it
names. The bar's plugin engine (`bar/engine/`) finds it, validates it, mounts
it, and hands it one object, `ctx`. Everything on the bar is a plugin,
including the logo, workspaces, and tray icons (`bar/builtins/velocity.*`), so
your widget can sit anywhere among them.

All management goes through one CLI, `bin/velocity-plugin`. It is on your PATH
when installed with the flake; otherwise run it from the checkout. Settings ▸
Control ▸ Plugins drives the same CLI.

## Tutorial: from nothing to a placed widget

```sh
# 1. scaffold — lands in ~/.config/velocity/plugins/acme.hello and asks the
#    running bar to enable it (kinds: bar-widget | overlay | service)
velocity-plugin new acme.hello

# 2. edit ~/.config/velocity/plugins/acme.hello/BarWidget.qml. The bar
#    watches the file and remounts the widget on save. If it misses a save:
velocity-plugin reload acme.hello

# 3. check it (manifest, entry files, no symlinks): the same validator the
#    bar loads with
velocity-plugin validate acme.hello

# 4. turn it on/off (new plugins are opt-in; `new` already enabled this one)
velocity-plugin enable acme.hello
velocity-plugin disable acme.hello

# 5. place it: section left | center | right, optional index (default: end)
velocity-plugin place acme.hello left 0
velocity-plugin move acme.hello 1          # one step right within its section
velocity-plugin layout                     # the whole bar, as JSON

# 6. remove it: moves to ~/.local/share/velocity/plugins-trash, undoable
velocity-plugin remove acme.hello
velocity-plugin trash
velocity-plugin restore acme.hello
```

Other commands:

```sh
velocity-plugin list                        # every plugin: status, source, section
velocity-plugin paths                       # where everything lives
velocity-plugin clone nikos.clock           # copy into the user dir: same id = override
velocity-plugin clone nikos.clock acme.clock   # … or fork it under a new id
velocity-plugin install https://github.com/acme/velocity-weather.git
velocity-plugin install <url> --quattro     # Omarchy/Quattro plugin (auto-detected too)
velocity-plugin settings acme.hello         # schema + current values
velocity-plugin set acme.hello label '"HI"' # value is JSON
velocity-plugin summon acme.hello           # open its popup / overlay
velocity-plugin hide acme.hello
velocity-plugin call acme.hello ping hi     # a verb from manifest.ipc
velocity-plugin rescan
velocity-plugin help
```

`enable`, `disable`, `place`, `move`, `layout`, `settings`, `set`, `summon`,
`hide`, `call`, `reload` and `rescan` talk to the running bar
(`qs -c bar ipc call plugins …`). The bar is the only writer of
`plugins-state.json` and of each plugin's settings file, so those commands
need the bar to be running.

## Naming rules

- **Plugin id = `<owner>.<feature>`** — `velocity.*` is reserved for first-party
  built-ins; your own namespace (`nikos.*`, `acme.*`, …) for everything else.
  The id is persisted (plugins-state.json, settings files, IPC) — never rename
  a published one without a migration.
- Inside a plugin, a headless root is `ServiceRoot.qml` (wired via
  `entryPoints.service`); IO-owning singletons are `*Service.qml` (e.g. WeatherService.qml — a qmldir singleton name, not a headless root); pure logic
  goes in `lib/kebab-case.mjs` with a sibling `.test.mjs`.

## Where plugins come from

Highest precedence first. When two folders share an id, the higher one wins
and the lower one shows as `shadowed`:

| source  | path | notes |
|---------|------|-------|
| user    | `$XDG_CONFIG_HOME/velocity/plugins/<id>` | `new`, `clone`, `install` write here |
| system  | `$VELOCITY_PLUGIN_PATH` dirs, then `$XDG_DATA_DIRS/*/velocity/plugins` | read-only, symlinks allowed (Nix store, distro packages) |
| bundled | `<repo>/plugins` | ships with velocity |
| builtin | `<repo>/bar/builtins` | can be disabled, not removed |

Folders under user and bundled may not contain symlinks.

## manifest.json

```json
{
  "schemaVersion": 2,
  "api": 2,
  "id": "acme.hello",
  "name": "Hello",
  "version": "0.1.0",
  "description": "Says hello.",
  "author": "acme",
  "license": "MIT",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "BarWidget.qml" },
  "bar": { "defaultSection": "right" },
  "settings": {
    "label": { "type": "string", "default": "HELLO", "label": "Label" }
  },
  "commands": ["curl"],
  "ipc": ["ping"]
}
```

- **id**: `author.name` (more segments are fine: `io.github.me.thing`).
  `omarchy.*` is reserved.
- **api**: must be `2`; the bar refuses other versions.
- **kinds / entryPoints**: `bar-widget` → `barWidget`, `service` → `service`,
  `overlay` → `overlay`. A plugin may have several kinds. A bar-widget or
  overlay may ALSO declare an extra `entryPoints.service` root — a headless
  component mounted ONCE per bar process (not per output) and exposed to the
  plugin's views as `ctx.service`: the service/view split. Put shared state,
  probes and timers there; views bind it (never copy it in
  Component.onCompleted — it may mount after them).
- **bar.defaultSection**: where the widget goes the first time it is enabled.
- **bar.collapsePriority**: optional int (default 50) — when the bar runs out
  of width, widgets hide lowest-priority first (settings 20 hides before
  workspaces 95). Only matters on narrow windows.
- **settings**: types `string`, `number` (`min`/`max`), `bool`, `enum`
  (`options`), `list` (of strings). Every key needs a valid `default`.
  Settings ▸ Plugins generates a form from this (⚙ on the row).
- **commands**: every program the plugin runs. `ctx.run` refuses anything
  not listed, and `tools/check-plugins` fails the build on it.
- **ipc**: verbs callable as `velocity-plugin call <id> <verb> <arg>`. Each one
  must be a `function <verb>(arg)` on one of the plugin's roots, and it may
  return a string.

## ctx (api 2)

Declare `property var ctx: null` on each root; the engine injects it.

A root may also expose `readonly property real compactWidth` — the width it
shrinks to in `ctx.fit` `"compact"` — so the bar's overflow plan gets a real
number instead of estimating (the built-in clock does this).

| member | what |
|--------|------|
| `ctx.pluginId`, `ctx.dir`, `ctx.manifest` | identity |
| `ctx.window`, `ctx.screen` | the bar window / screen this instance lives on (one widget per monitor) |
| `ctx.theme` | live theme tokens: `colors.accent`, `colors.text`, `colors.background`, `hairline`, … |
| `ctx.bar` | bar tokens: `barHeight` (any int 18–64), `fontFamily`, `fontNerd`, `fontSizeIcon`, `fontSizeLabel` (pill/hover labels), `fontSizeBadge` (count badges), `contentScale` (barHeight/26 — scale your own one-off sizes off it), `colorText`, … |
| `ctx.settings` | `values.<key>` (bindable), `get(key, fallback)`, `set(key, value)`, `onSettingChanged(key)` |
| `ctx.fit` | `"full"` / `"compact"` / `"collapsed"`. On a narrow window the bar asks widgets to drop to their minimal form (`compact` — hide labels, keep the glyph); `collapsed` means the plan hid the cell entirely. React to it with bindings; do nothing and only wide widgets lose their labels. |
| `ctx.run(argv)` | fire-and-forget command; `argv[0]` must be in `manifest.commands` |
| `ctx.popup` | `open`, `request(sub)`, `release(sub)`: one popup at a time across the whole bar; `island`: the island host on this screen (island style only, else null — PluginPopup uses it, plugins don't need to) |
| `ctx.island` | `activity(spec)` → bool, `end(key)`: transient live activities (J0) — one visible bar-wide, shown as an island activity (floating Osd card on other styles). `spec = {key, icon, label, progress, accent, ttlMs, priority, focusedOnly}`; `ttlMs` required unless `progress` is present (10-min hard cap); `priority` ∈ `osd > recording > peek > progress > timer` (unknown → `timer`); same key = update in place (progress refresh); `end(key)` retracts. Keys are namespaced per plugin — see the "Live activities" section |
| `ctx.events` | `onHyprEvent(line)`: the bar's Hyprland socket2 stream (don't open your own) |
| `ctx.osd` | `showVolume(v, muted)`, `showMute(m)` |
| `ctx.summon(id, payloadJson)`, `ctx.hide(id)` | open/close another plugin |
| `ctx.log(msg)` | `[<id>] msg` in the bar's journal |

Settings are stored in `$XDG_STATE_HOME/velocity/plugins/<id>.json`.

## Live activities (`ctx.island`, J0)

Transient status — downloads, timers, recording state — that blooms the island
(floating Osd card on non-island styles) without opening a panel:

```qml
const h = ctx.island.activity({ key: "dl", icon: "\u{F01A7}", label: dlPct + "%",
                                progress: dlPct, ttlMs: 4000 })   // true
// ...updates are in-place (same key, no flicker); drop ttlMs while a
// progress value is present and keep updating, or it expires at the 10-min cap
ctx.island.end("dl")
```

Arbitration (node-tested in `bar/engine/lib/activity-queue.mjs`): exactly one
activity renders — highest `priority` wins, ties go to the most recent update;
an open panel beats any activity; entries expire at `ttlMs` (hard cap 10 min,
refreshed by updates). Scripts use the same queue headlessly:
`qs -c bar ipc call island activity '{"key":"dl","label":"42%","progress":42}'`
(keys there are prefixed `ipc:`).

## UI kit: `import qs.Ui`

These are stateless pieces, and anything stateful comes through `ctx`. Never
import bar folders by path (`tools/check-engine` enforces this).

- `BarPill`: the standard widget. A glyph at rest, the label on hover;
  `onClicked(button)`, `onScrolled(delta)`.
- `PluginPopup`: the card a widget opens, anchored under it, on its screen.
  Excludes other popups via `ctx.popup`; give a second panel a `subKey`.
  Under the island bar style the same panel opens *inside* the island, which
  morphs to the body's size: keep the body's `implicitHeight` honest and
  `contentWidth` realistic, and don't rely on the drag header there (the island
  hides it).
- `QsBarWidget`, `QsPanel`: compat bases for converted Quattro plugins.

The three kinds, smallest form (`velocity-plugin new` writes fuller versions,
from `tools/templates/`):

```qml
// bar-widget
import QtQuick
import qs.Ui
Item {
    id: root
    property var ctx: null
    implicitWidth: pill.implicitWidth; implicitHeight: pill.height
    BarPill { id: pill; ctx: root.ctx; icon: "󰜗"; label: "HELLO" }
    function open() { /* optional: velocity-plugin summon */ }
}
```

```qml
// overlay: mounted hidden; `shown` claims the one-popup slot
PanelWindow {
    property var ctx: null
    property bool shown: false
    visible: false
    function open(payloadJson) { visible = true; shown = true }
    function close() { shown = false; visible = false }
    function toggle(payloadJson) { shown ? close() : open(payloadJson) }
}
```

```qml
// service: headless; lives while enabled, survives bar style swaps
Item { property var ctx: null; Timer { interval: 60000; running: true; repeat: true } }
```

### Service/view split (extra `entryPoints.service` on a widget or overlay)

Two ways to share state across a plugin's per-output views:

- **Plugin-internal qmldir singleton** (`singleton Foo 1.0 Foo.qml` in your
  `qmldir`): one instance per bar process, but invisible to the engine — no
  ctx, no settings injection, not reachable by `plugins call`. Best for pure
  data bridges. (`nikos.timezones`' `TimezoneService`.)
- **`entryPoints.service` root**: mounted by the host like a kind-service
  plugin — full `ctx` (settings, events, run), survives bar style swaps and
  view reloads, and its functions are reachable by
  `qs -c bar ipc call plugins call <id> <verb>` (routing tries bar-widget →
  service → overlay). Views reach it via `ctx.service`. Best when the shared
  logic needs the engine (settings-driven config, socket2 subscriptions,
  switch commands that must run exactly once regardless of output count —
  e.g. a `hyprctl` apply).

Reference: `plugins/nikos.timezones` (ServiceRoot.qml configures the singleton
from settings; BarWidget/Panel only bind it).

### Self-installing runtime (service kind)

A service that needs files outside its own dir (a Lua engine under
`~/.config/hypr`, a helper binary, a unit) bootstraps them on enable — the
`--kind service` template ships the full pattern:

- **`install.sh`** runs once per enable, from the QML side, `timeout`-bounded.
  It is **serialized** (`flock`), **skip-if-unchanged** (a checksum over
  `runtime/` in a state marker), and `--force`-able via the `setup` IPC verb.
  Log: `$XDG_STATE_HOME/velocity/plugins/<id>/install.log`.
- **Anything it edits outside the plugin dir gets backup-once**
  (`<target>.<id>.bak`, never overwritten on re-run) and a **validator before
  the marker is written** (`luac -p` for Lua, `hyprctl configerrors` for the
  deployed Hyprland config) — a failed validation leaves the marker unwritten,
  so the next run retries instead of skipping.
- State surfaces through manifest `ipc: ["status", "setup"]`:
  `velocity-plugin call <id> status ""` → `{ready, installing, error, log}`.

Runtime files live in the plugin's `runtime/` dir (checksummed payload); the
QML side reaches `install.sh` via `Qt.resolvedUrl` — plugin dirs load from
`file://`, so crossing roots is allowed here (unlike `qrc://` plugins).

## Gates

Run before you publish a plugin:

```sh
velocity-plugin validate <id>
tools/check-plugins ~/.config/velocity/plugins   # commands / ctx.run / ipc verbs
tools/check-engine                                # bundled plugins: no bar path imports
```

## Packaging

**Nix (home-manager):**

```nix
imports = [ velocity.homeManagerModules.default ];
programs.velocity = {
  enable = true;
  checkout = "/home/me/src/velocity";   # linked, writable, to ~/.config/quickshell
  plugins = [ (velocity.lib.mkPlugin pkgs { src = ./acme.hello; }) ];
};
```

Packaged plugins are read-only `system` plugins, and like every plugin they
start disabled (`velocity-plugin enable acme.hello`).

**Arch / other distros:** install the plugin folder to
`/usr/share/velocity/plugins/<id>/`. It is on the default search path. For
the bar itself, see `deploy/quickshell-bar.service` (link the checkout with
`tools/deploy-link` first).
