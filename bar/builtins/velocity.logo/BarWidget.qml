// velocity.logo — built-in bar widget, a thin wrapper over components/ArchLogo.qml.
import QtQuick
import "../../components" as Components

Components.ArchLogo {
    property var ctx: null
    // Left click: the launcher spotlight (P4.8 — bar-settings moved into the
    // Control Center's BAR page). Right click: the fastfetch overlay.
    onTriggered: if (ctx && ctx.host) ctx.host.toggleOverlay("velocity.launcher")
    onAltTriggered: if (ctx && ctx.host) ctx.host.toggleOverlay("velocity.fastfetch")
}
