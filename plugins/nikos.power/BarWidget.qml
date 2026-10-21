// =============================================================================
// nikos.power — battery glyph + power popup (plugin api 2)
// =============================================================================
// Tier colours ride ctx.theme tokens. Hover reveals the charge %; click
// toggles the plugin's own power panel. open()/close()/toggle() are the
// summon/hide contract (`plugins summon nikos.power '{}'`).
// =============================================================================
import QtQuick
import qs.Ui
import "." as PW

Item {
    id: root

    property var ctx: null

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.height

    function toggle() { panel.toggle() }
    function open()   { panel.open() }
    function close()  { panel.close() }

    PluginPopup {
        id: panel
        ctx: root.ctx
        anchorItem: root
        title: "POWER"
        icon: PW.BatteryService.glyph
        contentWidth: 340

        Loader {
            // The body binds theme tokens at creation — wait for ctx.
            active: root.ctx !== null
            source: Qt.resolvedUrl("Panel.qml")
            onLoaded: {
                item.hostBar = root.ctx.bar
                item.hostTheme = root.ctx.theme
            }
            onStatusChanged: if (status === Loader.Error) console.log("[nikos.power] panel failed to load")
        }
    }

    BarPill {
        id: pill
        ctx: root.ctx
        icon: PW.BatteryService.glyph
        label: PW.BatteryService.hasBattery ? "PWR " + PW.BatteryService.percentage + "%" : "PWR"
        active: panel.opened
        restColor: {
            if (!root.ctx) return "#888"
            var c = root.ctx.theme.colors
            if (!PW.BatteryService.hasBattery) return root.ctx.bar.colorText
            if (PW.BatteryService.charging) return c.success
            if (PW.BatteryService.percentage <= root.ctx.settings.get("lowThreshold", 20)) return c.error
            if (PW.BatteryService.percentage <= root.ctx.settings.get("warnThreshold", 50)) return c.warning
            return root.ctx.bar.colorText
        }
        onClicked: function(button) { panel.toggle() }
    }
}
