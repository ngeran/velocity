import QtQuick
import "ui"
import "ui/controls"
import "ui/Format.js" as Format

// Bar-widget entry (manifest entryPoints.barWidget). The old vendored
// qs/Ui/BarWidget base (21 lines, C5) is folded in below: the engine
// injects `ctx` (api 2); identity comes from the manifest id — moduleName
// defaults to ctx.pluginId so the host's PluginSlot injection makes drift
// impossible. `bar` is the surface Omarchy-converted widgets call into;
// shell verbs route through ctx (summon/hide cover widget AND overlay
// kinds — the launcher summons this plugin's overlay).
Item {
    id: root
    objectName: "xrayBarWidget"

    property var ctx: null
    property string moduleName: root.ctx ? root.ctx.pluginId : ""
    readonly property var bar: root.ctx ? ({
        theme: root.ctx.theme,
        shell: {
            toggle: function(name, payload) { return root.ctx.summon(name || root.moduleName, payload || "{}") },
            summon: function(name, payload) { return root.ctx.summon(name || root.moduleName, payload || "{}") },
            hide: function(name) { return root.ctx.hide(name || root.moduleName) }
        }
    }) : null

    XRayTheme { id: theme; ctx: root.ctx }

    implicitWidth: launcher.implicitWidth
    implicitHeight: launcher.implicitHeight

    BarIconButton {
        id: launcher
        objectName: "xrayBarLauncher"

        anchors.fill: parent
        bar: root.bar
        text: Format.icon("xray")
        label: "X-RAY"                     // hover-reveal, like NET / VOL / EN
        fontFamily: theme.dataFont
        fontPixelSize: 14                  // = BarConfig.fontSizeIcon (house tray glyphs)
        tooltipText: "Trace system activity"
        onPressed: function(button) {
            if (!root.bar || !root.bar.shell)
                return;
            root.bar.shell.toggle(root.moduleName, "{}")
        }
    }
}
