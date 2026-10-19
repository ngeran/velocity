// velocity.logo — built-in bar widget, a thin wrapper over components/ArchLogo.qml.
import QtQuick
import "../../components" as Components

Components.ArchLogo {
    property var ctx: null
    onTriggered: if (ctx && ctx.host) ctx.host.toggleFastfetch()
}
