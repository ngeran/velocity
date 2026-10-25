// =============================================================================
// PluginContext.qml — `ctx`, the ONE object a plugin root receives (api 2)
// =============================================================================
// Declare `property var ctx: null` on a plugin root and the engine injects a
// context per mounted instance (destroyed with it). Everything a plugin may
// touch in the bar goes through here — no raw singletons.
//
//   ctx.pluginId / ctx.dir / ctx.manifest / ctx.window / ctx.screen
//   ctx.theme       theme tokens (colors.*, hairline, tint()…) — read-only
//   ctx.bar         bar tokens (barHeight, fontFamily, fontNerd, fontSizeIcon,
//                   colorText, colorAccent…) — read-only
//   ctx.osd         OSD (showVolume / showMute / showLayout …)
//   ctx.events      onHyprEvent(line) — the bar's socket2 stream
//   ctx.settings    SettingsStore: values / get / set / onSettingChanged
//   ctx.service     the plugin's entryPoints.service root — ONE headless
//                   instance per plugin across hosts/outputs (null until mounted)
//   ctx.popup       open (bool) · request() · release() · publish(geom) ·
//                   island — one-at-a-time panels, notch carve geometry, and
//                   the island host on this screen (null unless island style)
//
// qs.Ui components reach engine state ONLY through ctx: a plugin loads qs.Ui
// through the qs module path, and a singleton touched from there could be a
// second instance if that path resolves differently from the bar's own
// path imports.
//   ctx.run(argv)   fire-and-forget; argv[0] must be in manifest.commands
//   ctx.summon(id, payloadJson) / ctx.hide(id)
//   ctx.log(msg)
//   ctx.host        built-ins only (source "builtin"): the bar shell —
//                   toggleOverlay(id)/overlayShown(id), ncShown. null for everyone else.
// =============================================================================

import QtQuick
import Quickshell

QtObject {
    id: ctx

    readonly property int version: 2

    // `id` is reserved in QML, hence pluginId.
    property string pluginId: ""
    property string dir: ""
    property var manifest: null
    property var window: null
    readonly property var screen: window ? window.screen : null

    property var theme: null
    property var bar: null
    property var osd: null
    property QtObject events: null
    property var settings: null
    property var host: null

    // The plugin's ONE headless service root (entryPoints.service), mounted
    // once in the host and shared by every view on every output — the
    // service/view split. null until it mounts; bindings on this
    // re-evaluate when it appears (the instance map changes). Views bind it,
    // never copy it at Component.onCompleted.
    readonly property var service: PluginRegistry.serviceFor(ctx.pluginId)

    // Overflow state for THIS instance's window: "full" | "compact" |
    // "collapsed". "compact" asks a widget to drop to its glyph/minimum form
    // (the bar is tight); "collapsed" means the section already hid the cell.
    // Bindings on this re-evaluate when the window resizes or the layout
    // changes (BarSection drives it from the fit plan).
    property string fit: "full"

    // One open popup at a time, bar-wide (PopupCoordinator). A plugin with
    // several panels (clock: calendar) gives each a sub-key, so they
    // exclude each other too: slot keys are "<pluginId>" or "<pluginId>.<sub>".
    readonly property QtObject popup: QtObject {
        // The slot key currently open anywhere in the bar ("" = none).
        readonly property string current: PopupCoordinator.current
        // True while any of THIS plugin's panels is the open one.
        readonly property bool open: current !== "" && (current === ctx.pluginId || current.indexOf(ctx.pluginId + ".") === 0)
        function keyFor(sub) { return sub ? ctx.pluginId + "." + sub : ctx.pluginId }
        // Claim the slot (closes any other panel, the tray card, the
        // notification center and overlays).
        function request(sub) { PopupCoordinator.request(keyFor(sub)) }
        function release(sub) { PopupCoordinator.release(keyFor(sub)) }
        // Notch-lobe carve geometry while open ({ screen, caretX }), or null
        // to retract.
        function publish(geom, sub) { PopupCoordinator.publish(keyFor(sub), geom) }
        // The island host on this instance's screen (island style), or null.
        // PluginPopup hands it to its Popover, which then presents inside the
        // island; plugins never call into it directly.
        readonly property var island: ctx.screen
            ? (PopupCoordinator.islands[ctx.screen.name] || null) : null
    }

    function run(argv) {
        if (!Array.isArray(argv) || argv.length === 0) { ctx.log("run: argv must be a non-empty array"); return false }
        var cmd = String(argv[0])
        var declared = ctx.manifest && Array.isArray(ctx.manifest.commands) ? ctx.manifest.commands : []
        if (declared.indexOf(cmd) === -1) {
            ctx.log("run refused: '" + cmd + "' is not in manifest.commands")
            return false
        }
        Quickshell.execDetached(argv.map(String))
        return true
    }

    function summon(id, payloadJson) { return PluginRegistry.summon(String(id || ctx.pluginId), payloadJson || "{}") }
    function hide(id) { return PluginRegistry.hide(String(id || ctx.pluginId)) }
    function log(msg) { console.log("[" + ctx.pluginId + "] " + msg) }
}
