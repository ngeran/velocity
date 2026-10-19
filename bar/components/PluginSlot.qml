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
// of mounting an object the slot has already moved past. That
// {requestedSource, generation} tuple IS the provenance check — Shibumi's
// WidgetSlot submission discipline: every completion revalidates against the
// exact submitted handle before adoption.
//
// Failure recovery (Shibumi's bounded-budget diagnostics): a failed load
// retries with backoff (interval min(400, 40·attempt), hard cap 10) riding a
// Timer instead of a signal storm; exhaustion reports ONCE via reportError
// (idempotent per plugin). A hot-plugged plugin file that lands a few ms
// after its manifest now recovers itself.
Item {
    id: slot

    property string source: ""
    property string pluginId: ""
    // Called with the new item BEFORE it becomes current — injection point for
    // pluginId/api/registry wiring (see the barWidgetPlugins Repeater).
    property var configure: null
    property var item: null
    property int _generation: 0
    property int _attempts: 0

    // A fresh source is a fresh failure budget — without this, one flaky
    // plugin file would exhaust the cap permanently for the slot.
    onSourceChanged: {
        _attempts = 0
        retryTimer.stop()
        rebuild()
    }
    Component.onCompleted: rebuild()

    Timer {
        id: retryTimer
        interval: Math.min(400, 40 * Math.max(1, slot._attempts))
        onTriggered: slot.rebuild()
    }

    function _scheduleRetry(why) {
        if (slot._attempts >= 10) {
            console.warn("PluginSlot: exhausted retries for", slot.source)
            Services.PluginHostService.reportError(slot.pluginId,
                "BarWidget failed after " + slot._attempts + " attempts: " + why)
            return
        }
        slot._attempts++
        retryTimer.restart()
    }

    // Loader-identical sizing contract. Layouts size children by
    // implicitWidth/implicitHeight, and plugin widgets use the hover-reveal
    // idiom (animate implicitWidth, never a fixed width — see
    // plugins/nikos.power/BarWidget.qml header), so the slot must PASS THROUGH
    // the item's implicit size. item.width alone is wrong: that idiom never
    // sets it (T6 regression: hover-revealed text painted over neighbor icons
    // because the slot never grew). The width fallback covers roots that size
    // explicitly without implicit (defensive both ways).
    implicitWidth: item ? (item.implicitWidth || item.width || 0) : 0
    implicitHeight: item ? (item.implicitHeight || item.height || 0) : 0
    width: implicitWidth
    height: implicitHeight

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
                    slot._scheduleRetry("instantiate")
                    return
                }
                if (slot.configure) slot.configure(next)
                slot.item = next
                if (previous && previous !== next) previous.destroy()
                slot._attempts = 0
                retryTimer.stop()
            } else if (component.status === Component.Error) {
                console.warn("PluginSlot:", component.errorString())
                slot._scheduleRetry(component.errorString())
            }
        }
        if (component.status === Component.Loading)
            component.statusChanged.connect(publish)
        else
            publish()
    }
}
