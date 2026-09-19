import QtQuick
import "../services" as Services

// PluginSlot — generation-guarded mount for bar-widget plugins.
//
// Port of ryoku-arch's plugins/kit/PluginObjectSlot.qml. The inline Loader it
// replaces tore down the working instance the moment `source` reassigns, so a
// plugin whose new path fails to load left a hole (and its error re-report
// retriggered the documented rail-Repeater binding loop). Here the new
// component is created OFFSIDE; only a successful createObject replaces the
// current item — a broken source keeps the previous instance rendered and just
// reports into PluginHostService.
//
// The generation counter folds races: any source change bumps it, and a stale
// async publish (slow file read, late statusChanged) discards itself instead
// of mounting an object the slot has already moved past.
Item {
    id: slot

    property string source: ""
    property string pluginId: ""
    // Called with the new item BEFORE it becomes current — injection point for
    // pluginId/api/registry wiring (see the barWidgetPlugins Repeater).
    property var configure: null
    property var item: null
    property int _generation: 0

    // Loader sized itself to its item; keep that contract for the rail layout.
    width: item ? item.width : 0
    height: item ? item.height : 0

    onSourceChanged: rebuild()
    Component.onCompleted: rebuild()

    function rebuild() {
        const generation = ++slot._generation
        if (!source || source.length === 0) {
            const prev = slot.item
            slot.item = null
            if (prev) prev.destroy()
            return
        }
        const requestedSource = source
        const previous = slot.item
        const component = Qt.createComponent(requestedSource)
        function publish() {
            if (generation !== slot._generation || requestedSource !== slot.source)
                return
            if (component.status === Component.Ready) {
                const next = component.createObject(slot)
                if (!next) {
                    console.warn("PluginSlot: createObject failed for", requestedSource)
                    Services.PluginHostService.reportError(slot.pluginId, "BarWidget failed to instantiate")
                    return
                }
                if (slot.configure) slot.configure(next)
                slot.item = next
                if (previous && previous !== next) previous.destroy()
            } else if (component.status === Component.Error) {
                console.warn("PluginSlot:", component.errorString())
                Services.PluginHostService.reportError(slot.pluginId, "BarWidget failed to load: " + component.errorString())
            }
        }
        if (component.status === Component.Loading)
            component.statusChanged.connect(publish)
        else
            publish()
    }
}
