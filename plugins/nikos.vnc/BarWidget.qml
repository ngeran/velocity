// =============================================================================
// nikos.vnc — RIGHT-slot plugin (plugin api 2)
// =============================================================================
// TigerVNC client pill for the Mac mini. Monitor glyph tracks the session:
// monitor-check while the viewer runs, monitor when idle, monitor-off when
// the host is unreachable; the label shows the active connection's name
// (or target host) while connected. Left click toggles the popup, middle
// click connects/disconnects, and the viewer itself is launched detached
// via ctx.run (never a captive Process). Panel body in PanelBody.qml.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.Ui
import "lib/glyphs.mjs" as G
import "." as VNC

Item {
    id: root

    property var ctx: null

    // ── IPC surface (host `plugins call` + summon/hide) ─────────────────────
    function toggle() { panel.toggle() }
    function open() { panel.open() }
    function close() { panel.close() }
    function refresh() { VNC.VncService.refresh() }
    function status() { return VNC.VncService.statusText() }
    function telemetry() { return VNC.VncService.telemetryJson() }
    function connect() { VNC.VncService.connectViewer(); return "connecting" }
    function disconnect() { VNC.VncService.disconnectViewer(); return "disconnecting" }

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.height

    // ── panel open state drives the service's poll cadence ──────────────────
    Connections {
        target: panel
        function onOpenedChanged() {
            VNC.VncService.pollFast = panel.opened
        }
    }

    BarPill {
        id: pill
        ctx: root.ctx
        icon: VNC.VncService.state === "connected" ? G.glyph("monitorCheck")
            : VNC.VncService.state === "host-unreachable" ? G.glyph("monitorOff")
            : G.glyph("monitor")
        label: VNC.VncService.connected ? VNC.VncService.targetShort : ""
        active: panel.opened
        restColor: root.ctx && root.ctx.theme
            ? (VNC.VncService.connected
               ? root.ctx.theme.colors.success
               : root.ctx.theme.colors.textDim)
            : "#888888"
        onClicked: function(button) {
            if (button === Qt.MiddleButton) {
                if (VNC.VncService.connected) root.disconnect()
                else root.connect()
            } else {
                panel.toggle()
            }
        }
    }

    // ── VNC POPUP — PanelBody owns status/actions/telemetry ────────────────
    PluginPopup {
        id: panel
        ctx: root.ctx
        anchorItem: root
        title: "VNC"
        icon: G.glyph("apple")
        contentWidth: 420
        // Keyboard-driven panel (c/r/esc in PanelBody): the kit default is
        // keyboardFocus None — keys never arrive. Opt THIS instance into
        // OnDemand so a click hands it the keyboard (wireguard precedent).
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
                console.log("[nikos.vnc] panel body failed to load")
        }
    }
}
