// =============================================================================
// nikos.example — minimal bar-widget plugin (plugin api 2)
// =============================================================================
// The engine injects ONE object after loading:
//   ctx — this plugin's context: pluginId, manifest, theme/bar tokens,
//         settings, popup slot, events, run()/summon()/hide()/log().
//         See bar/engine/PluginContext.qml.
// UI parts come from `qs.Ui` (stateless). Never import bar dirs by path.
//
// BarPill is the standard pill: glyph at rest, label on hover. Click
// deep-links to the plugin manager (Control ▸ Plugins) in the settings
// dashboard — cross-process, via the settings shell's IPC. `quickshell` is
// declared in manifest.commands, which ctx.run() enforces.
// =============================================================================
import QtQuick
import qs.Ui

Item {
    id: root

    property var ctx: null

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.height

    BarPill {
        id: pill
        ctx: root.ctx
        icon: "󰜗"
        label: "PLUGIN"
        restColor: root.ctx ? root.ctx.theme.colors.success : "#888"
        onClicked: function(button) {
            if (root.ctx) root.ctx.run(["quickshell", "-c", "settings", "ipc", "call", "SettingsWindow", "openControlPlugins"])
        }
    }
}
