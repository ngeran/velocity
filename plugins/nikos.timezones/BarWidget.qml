// =============================================================================
// nikos.timezones — bar pill (plugin api 2)
// =============================================================================
// Clock glyph that expands on hover to "ATHENS 03:31 · LON 01:31 · TYO 09:31";
// left click toggles the working-hours panel, middle click refreshes.
// open()/close()/toggle() are the summon/hide contract.
// =============================================================================
import QtQuick
import qs.Ui
import "." as TZ

Item {
    id: root

    property var ctx: null

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.height

    // Configuration lives in ServiceRoot.qml (entryPoints.service): one headless
    // root per bar process pushes settings into TZ.TimezoneService. This
    // view only binds the singleton — safe on any number of outputs.

    function toggle() { panel.toggle() }
    function open()   { panel.open() }
    function close()  { panel.close() }

    PluginPopup {
        id: panel
        ctx: root.ctx
        anchorItem: root
        title: "TIME ZONES"
        icon: "󰅐"
        contentWidth: 800
        onOpen: TZ.TimezoneService.refresh()

        Loader {
            // The body binds hostBar/hostTheme at creation — wait for ctx.
            active: root.ctx !== null
            source: Qt.resolvedUrl("Panel.qml")
            onLoaded: {
                item.hostBar = root.ctx.bar
                item.hostTheme = root.ctx.theme
            }
        }
    }

    BarPill {
        id: pill
        ctx: root.ctx
        icon: "󰅐"
        label: TZ.TimezoneService.compactLabel
        active: panel.opened
        onClicked: function(button) {
            if (button === Qt.MiddleButton) TZ.TimezoneService.refresh()
            else panel.toggle()
        }
    }
}
