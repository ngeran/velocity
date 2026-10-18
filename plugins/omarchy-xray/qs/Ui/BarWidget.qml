import QtQuick
Item {
    id: root
    // pluginId is INJECTED by the host (PluginSlot configure — Scene.qml) from
    // the manifest, so identity can never drift from the manifest again.
    property string pluginId: ""
    property string moduleName: root.pluginId
    property var api: null
    property var bar: root.api ? ({
        shell: {
            // Lifecycle verbs MUST go through the compatSummon bus — the host
            // connects it to _summonAny, which covers widget plugins AND
            // overlay plugins (xray: the overlay registry). The panel bus
            // (requestTogglePanel) only reaches bar-widget toggle() fns.
            toggle: function(name, payload) {
                if (root.api.host) root.api.host.requestSummon(name || root.pluginId, payload || "{}")
                return "ok"
            },
            summon: function(name, payload) {
                if (root.api.host) root.api.host.requestSummon(name || root.pluginId, payload || "{}")
                return "ok"
            },
            hide: function(name) {
                if (root.api.host) root.api.host.requestHide(name || root.pluginId)
                return "ok"
            }
        }
    }) : null
    implicitWidth: 10
    implicitHeight: 10
}
