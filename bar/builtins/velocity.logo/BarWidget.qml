// velocity.logo — built-in bar widget, a thin wrapper over components/ArchLogo.qml.
import QtQuick
import "../../components" as Components

Components.ArchLogo {
    property var ctx: null
    // Left click: the bar-settings reveal (C4). Right click: the fastfetch
    // overlay — the logo's original action, kept one click away.
    onTriggered: if (ctx && ctx.host) ctx.host.toggleOverlay("velocity.bar-settings")
    onAltTriggered: if (ctx && ctx.host) ctx.host.toggleOverlay("velocity.fastfetch")
}
