import QtQuick
// Vendored Quattro-shaped base for the X-Ray launcher, on velocity plugin
// api 2: the engine injects `ctx`; identity comes from the manifest id.
Item {
    id: root
    property var ctx: null
    property string moduleName: root.ctx ? root.ctx.pluginId : ""
    // The `bar` surface Quattro widgets expect: lifecycle verbs + theme.
    // summon/hide cover widget plugins AND overlays (the registry tries the
    // bar widget first, then the overlay — xray's launcher → its overlay).
    property var bar: root.ctx ? ({
        theme: root.ctx.theme,
        shell: {
            toggle: function(name, payload) { return root.ctx.summon(name || root.moduleName, payload || "{}") },
            summon: function(name, payload) { return root.ctx.summon(name || root.moduleName, payload || "{}") },
            hide: function(name) { return root.ctx.hide(name || root.moduleName) }
        }
    }) : null
    implicitWidth: 10
    implicitHeight: 10
}
