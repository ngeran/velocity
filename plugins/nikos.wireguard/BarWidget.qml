// =============================================================================
// nikos.wireguard — RIGHT-slot plugin (plugin api 2)
// =============================================================================
// WireGuard/Tailscale shield pill. Shield glyph + tunnel name while a tunnel
// is up, lock glyph while down (hover slides the label out); the rest tint
// follows the theme's success/textDim tokens. Left click toggles the panel,
// right click flips the primary tunnel, middle click forces a refresh.
// Ported from ngeran.wireguard (Omarchy) — panel body in PanelBody.qml.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.Ui
import "lib/glyphs.mjs" as G
import "." as WG

Item {
    id: root

    property var ctx: null

    // The panel's active tab — the Tier 5 PanelBody binds this; the `tab`
    // IPC verb and keyboard shortcuts write it.
    property string activeTab: "wireguard"

    // ── IPC surface (host `plugins call` + summon/hide) ──────────────────────
    function toggle() { panel.toggle() }
    function open() { panel.open() }
    function close() { panel.close() }
    function refresh() {
        WG.WireGuardService.refresh()
        WG.TailscaleService.refresh()
    }
    function up(key) { return WG.WireGuardService.setByName(key, true) }
    function down(key) { return WG.WireGuardService.setByName(key, false) }
    function toggleTunnel() { WG.WireGuardService.togglePrimary(); return "ok" }
    function status() {
        return WG.WireGuardService.statusText() + " · " + WG.TailscaleService.statusText()
    }
    function telemetry() { return WG.WireGuardService.telemetryJson() }
    function tailscale() { return WG.TailscaleService.telemetryJson() }
    function tailscaleUp() {
        if (!WG.TailscaleService.installed) return "tailscale is not installed"
        WG.TailscaleService.connect()
        return "connecting"
    }
    function tailscaleDown() {
        if (!WG.TailscaleService.installed) return "tailscale is not installed"
        WG.TailscaleService.disconnect()
        return "disconnecting"
    }
    function tailscaleExitNode(key) { return WG.TailscaleService.setExitNode(key) }
    function tab(name) {
        var wanted = name === "tailscale" ? "tailscale" : "wireguard"
        root.activeTab = wanted
        return wanted
    }

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.height

    // ── panel open state drives both services' poll cadence ─────────────────
    Connections {
        target: panel
        function onOpenedChanged() {
            WG.WireGuardService.pollFast = panel.opened
            WG.TailscaleService.pollFast = panel.opened
        }
    }

    BarPill {
        id: pill
        ctx: root.ctx
        icon: WG.WireGuardService.connected ? G.glyph("shield") : G.glyph("lock")
        label: {
            var tunnel = WG.WireGuardService.activeTunnel
            if (WG.WireGuardService.connected && tunnel) return tunnel.name
            if (WG.TailscaleService.running) return "TAILSCALE"
            return ""
        }
        active: panel.opened
        restColor: root.ctx && root.ctx.theme
            ? (WG.WireGuardService.connected
               ? root.ctx.theme.colors.success
               : root.ctx.theme.colors.textDim)
            : "#888888"
        onClicked: function(button) {
            if (button === Qt.RightButton) WG.WireGuardService.togglePrimary()
            else if (button === Qt.MiddleButton) root.refresh()
            else panel.toggle()
        }
    }

    // ── WIREGUARD POPUP — PanelBody owns both panes ────────────────────────
    PluginPopup {
        id: panel
        ctx: root.ctx
        anchorItem: root
        title: "WIREGUARD"
        icon: G.glyph("shield")
        contentWidth: 560
        // ngeran parity: the panel is keyboard-driven (1/2/j/k/enter/t/r/i/esc).
        // The kit default is keyboardFocus None — keys never arrive. Opt THIS
        // instance into OnDemand so a click (or activation) hands it the
        // keyboard; other plugins' popups keep the kit default.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Loader {
            id: panelBodyLoader
            Layout.fillWidth: true
            active: root.ctx !== null
            source: Qt.resolvedUrl("PanelBody.qml")
            onLoaded: {
                item.ctx = root.ctx
                item.panel = panel
                item.host = root
            }
            onStatusChanged: if (status === Loader.Error)
                console.log("[nikos.wireguard] panel body failed to load")
        }
    }
}
