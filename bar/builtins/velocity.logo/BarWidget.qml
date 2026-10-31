// velocity.logo — built-in bar widget, a thin wrapper over components/ArchLogo.qml.
import QtQuick
import "../../components" as Components

Components.ArchLogo {
    property var ctx: null
    // Left click: the launcher spotlight. (The fastfetch right click was
    // removed with the overlay — the dashboard's SYS INFO tab is the system
    // info surface now, same MetricsService data.)
    onTriggered: if (ctx && ctx.host) ctx.host.toggleOverlay("velocity.launcher")
}
