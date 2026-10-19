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
// =============================================================================

import QtQuick
import QtQuick.Layouts

RowLayout {
    id: section

    property string name: "right"
    property var window: null
    property int gap: 8
    property var overrides: ({})

    spacing: 0

    Repeater {
        model: PluginRegistry.sections[section.name] || []

        Item {
            id: cell
            readonly property var plugin: modelData
            readonly property Component override: section.overrides[cell.plugin.id] || null

            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: index > 0 && implicitWidth > 0 ? section.gap : 0
            implicitWidth: cell.override ? (styleLoader.item ? styleLoader.item.implicitWidth : 0) : slot.implicitWidth
            implicitHeight: cell.override ? (styleLoader.item ? styleLoader.item.implicitHeight : 0) : slot.implicitHeight

            PluginSlot {
                id: slot
                anchors.verticalCenter: parent.verticalCenter
                pluginId: cell.plugin.id
                source: cell.override ? "" : PluginRegistry.entryUrl(cell.plugin, "barWidget")
                configure: function(item) { PluginRegistry.mount(item, cell.plugin, "bar-widget", section.window) }
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
}
