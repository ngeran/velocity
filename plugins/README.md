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
  `overlay` → `overlay`. A plugin may have several kinds.
- **bar.defaultSection**: where the widget goes the first time it is enabled.
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

| member | what |
|--------|------|
| `ctx.pluginId`, `ctx.dir`, `ctx.manifest` | identity |
| `ctx.window`, `ctx.screen` | the bar window / screen this instance lives on (one widget per monitor) |
| `ctx.theme` | live theme tokens: `colors.accent`, `colors.text`, `colors.background`, `hairline`, … |
| `ctx.bar` | bar tokens: `barHeight`, `fontFamily`, `fontNerd`, `fontSizeIcon`, `colorText`, … |
| `ctx.settings` | `values.<key>` (bindable), `get(key, fallback)`, `set(key, value)`, `onSettingChanged(key)` |
| `ctx.run(argv)` | fire-and-forget command; `argv[0]` must be in `manifest.commands` |
| `ctx.popup` | `open`, `request(sub)`, `release(sub)`: one popup at a time across the whole bar |
| `ctx.events` | `onHyprEvent(line)`: the bar's Hyprland socket2 stream (don't open your own) |
| `ctx.osd` | `showVolume(v, muted)`, `showMute(m)` |
| `ctx.summon(id, payloadJson)`, `ctx.hide(id)` | open/close another plugin |
| `ctx.log(msg)` | `[<id>] msg` in the bar's journal |

Settings are stored in `$XDG_STATE_HOME/velocity/plugins/<id>.json`.

## UI kit: `import qs.Ui`

These are stateless pieces, and anything stateful comes through `ctx`. Never
import bar folders by path (`tools/check-engine` enforces this).

- `BarPill`: the standard widget. A glyph at rest, the label on hover;
  `onClicked(button)`, `onScrolled(delta)`.
- `PluginPopup`: the card a widget opens, anchored under it, on its screen.
  Excludes other popups via `ctx.popup`; give a second panel a `subKey`.
- `BarIconButton`, `WidgetButton`, `BorderSurface`, `PanelKeyCatcher`, `Util`.
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
