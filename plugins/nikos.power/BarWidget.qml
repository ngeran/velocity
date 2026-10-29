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

    // ── battery events (J7) ─────────────────────────────────────────────────
    // The singleton computes edges once; every mounted BarWidget forwards
    // them under the SAME ctx-namespaced keys ("nikos.power:*"), so a
    // multi-output bar converges on one island activity (update-in-place).
    // Threshold rides the bindable values read (J4) — a settings change
    // re-arms the state machine via the singleton's onChanged.
    Binding {
        target: PW.BatteryService
        property: "lowThreshold"
        value: root.ctx && root.ctx.settings.values.lowThreshold !== undefined
               ? root.ctx.settings.values.lowThreshold : 20
    }

    Connections {
        target: PW.BatteryService
        function onEventOccurred(kind, pct) {
            if (!root.ctx || !root.ctx.island) return
            var c = root.ctx.theme.colors
            if (kind === "plug") {
                root.ctx.island.activity({ key: "plug", icon: "󰂄",
                    label: "PLUGGED IN · " + pct + "%", accent: c.success,
                    priority: "timer", ttlMs: 5000 })
            } else if (kind === "full") {
                root.ctx.island.activity({ key: "full", icon: "󰁹",
                    label: "BATTERY FULL", accent: c.success,
                    priority: "timer", ttlMs: 5000 })
            } else if (kind === "low") {
                root.ctx.island.activity({ key: "low", icon: "󰁺",
                    label: "LOW BATTERY · " + pct + "%", accent: c.error,
                    priority: "progress", progress: pct, ttlMs: 8000 })
            }
        }
    }

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
            // Bindable .values reads (J4 doctrine) — get() in a binding is
            // opaque: it froze at the mount-time value and never re-evaluated
            // on a settings-file reload.
            if (PW.BatteryService.percentage <= root.ctx.settings.values.lowThreshold) return c.error
            if (PW.BatteryService.percentage <= root.ctx.settings.values.warnThreshold) return c.warning
            return root.ctx.bar.colorText
        }
        onClicked: function(button) { panel.toggle() }
    }
}
