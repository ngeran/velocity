// =============================================================================
// BarSection.qml — renders one bar layout section (left | center | right)
// =============================================================================
// Every style places three of these; what goes in them comes from
// PluginRegistry.sections (plugins-state.json `layout`). Each cell is a
// generation-guarded PluginSlot whose root is registered per window.
//
//   name        "left" | "center" | "right"
//   window      the PanelWindow hosting the section (ctx.window, per-output
//               instance routing)
//   gap         space before every non-empty cell except the first; an
//               auto-empty widget (idle privacy pill) collapses its gap
//   overrides   { pluginId: Component } — a style-owned renderer in place of
//               that plugin's BarWidget (ryoku's workspaces). Created in the
//               style's own scope; not mounted, so it gets no ctx.
//   fitMap      { pluginId: "full" | "compact" | "collapsed" } — the style's
//               overflow plan (PluginRegistry.planFit) for this window. A
//               collapsed cell is hidden (and its gap collapses); compact/
//               collapsed reach the widget as ctx.fit so it can drop to its
//               minimal form. A root may expose `compactWidth` (px) so the
//               plan knows its shrunk width; otherwise a square-ish estimate
//               is used.
// =============================================================================

import QtQuick
import QtQuick.Layouts
// NB: NOT `as Layout` — that name is the QtQuick.Layouts attached property
// every delegate cell uses (Layout.alignment / Layout.leftMargin); shadowing
// it breaks the whole BarSection type ("Expected type name").
import "lib/layout.mjs" as LayoutLib

RowLayout {
    id: section

    property string name: "right"
    property var window: null
    property int gap: 8
    property var overrides: ({})
    property var fitMap: ({})

    spacing: 0

    // Per-cell plan input: { id, w, wc, p }. Re-evaluated whenever a cell's
    // width or the mounted item changes; the scene feeds this to
    // PluginRegistry.planFit together with the window width.
    readonly property var cellInfos: {
        var out = []
        for (var i = 0; i < rep.count; i++) {
            var it = rep.itemAt(i)
            if (it) out.push({ id: it.plugin.id, w: it.implicitWidth, wc: it.compactW,
                               p: it.plugin.collapsePriority })
        }
        return out
    }

    function _applyFit(item, state) {
        if (item && item.ctx && item.ctx.fit !== state) item.ctx.fit = state
    }

    // P1: the cells live in a ListModel diffed against
    // PluginRegistry.sections (Layout.diffIdLists), NOT in the sections
    // array itself. `sections` is a readonly var — every toggle/place/move
    // re-resolves it into a NEW array, and a Repeater on that resets every
    // delegate: toggling one plugin remounted the whole bar. With the
    // diffed model, only the changed cells are inserted/removed; surviving
    // icons keep their state. Roles: `id` (string, the diff key) and `pw`
    // (the plugin record).
    ListModel { id: cells }

    Connections {
        target: PluginRegistry
        function onSectionsChanged() { section._syncCells() }
    }

    Component.onCompleted: section._syncCells()

    function _pw(list, id) {
        for (var i = 0; i < list.length; i++)
            if (list[i].id === id) return list[i]
        return null
    }

    function _syncCells() {
        var want = PluginRegistry.sections[section.name] || []
        var wantIds = []
        for (var i = 0; i < want.length; i++) wantIds.push(want[i].id)
        var haveIds = []
        for (var j = 0; j < cells.count; j++) haveIds.push(cells.get(j).id)
        var ops = LayoutLib.diffIdLists(haveIds, wantIds)
        if (ops.length === 0) {
            // Same ids, re-resolved records: refresh `pw` in place so
            // hot-reload revs (entryUrl ?rev=N) still reach the slots —
            // setProperty only re-fires bindings, no delegate is rebuilt.
            for (var u = 0; u < want.length; u++) cells.setProperty(u, "pw", want[u])
            return
        }
        for (var k = 0; k < ops.length; k++) {
            var o = ops[k]
            if (o.op === "remove") cells.remove(o.index)
            else cells.insert(o.index, { id: o.id, pw: _pw(want, o.id) })
        }
    }

    Repeater {
        id: rep
        model: cells

        Item {
            id: cell
            readonly property var plugin: model.pw
            readonly property Component override: section.overrides[cell.plugin.id] || null
            readonly property string fitState: section.fitMap[cell.plugin.id] || "full"
            // Cells the plan collapsed: out of the layout entirely (a hidden
            // RowLayout child occupies no space), gap included.
            visible: fitState !== "collapsed"
            // Widget-reported compact width, else a square-ish estimate —
            // good enough for the plan; the width self-corrects on the next
            // pass because the real render changes implicitWidth.
            readonly property real compactW: {
                var r = slot.item
                if (r && r.compactWidth > 0) return r.compactWidth
                return Math.min(implicitWidth, Math.ceil(section.height * 1.6))
            }

            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: index > 0 && implicitWidth > 0 && section._visibleBefore(index) ? section.gap : 0
            implicitWidth: cell.override ? (styleLoader.item ? styleLoader.item.implicitWidth : 0) : slot.implicitWidth
            implicitHeight: cell.override ? (styleLoader.item ? styleLoader.item.implicitHeight : 0) : slot.implicitHeight

            onFitStateChanged: section._applyFit(slot.item, cell.fitState)

            PluginSlot {
                id: slot
                anchors.verticalCenter: parent.verticalCenter
                pluginId: cell.plugin.id
                source: cell.override ? "" : PluginRegistry.entryUrl(cell.plugin, "barWidget")
                configure: function(item) {
                    PluginRegistry.mount(item, cell.plugin, "bar-widget", section.window)
                    section._applyFit(item, cell.fitState)
                }
            }

            Loader {
                id: styleLoader
                anchors.verticalCenter: parent.verticalCenter
                active: !!cell.override
                sourceComponent: cell.override
            }

            Component.onDestruction: PluginRegistry.unmount(cell.plugin.id, slot.item)
        }
    }

    function _visibleBefore(i) {
        for (var j = 0; j < i; j++) {
            var it = rep.itemAt(j)
            if (it && it.visible && it.implicitWidth > 0) return true
        }
        return false
    }
}
