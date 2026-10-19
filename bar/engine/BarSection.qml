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

    Repeater {
        id: rep
        model: PluginRegistry.sections[section.name] || []

        Item {
            id: cell
            readonly property var plugin: modelData
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
