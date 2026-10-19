// velocity.logs — built-in bar widget, a thin wrapper over components/LogsIcon.qml.
import QtQuick
import "../../components" as Components

Components.LogsIcon {
    property var ctx: null
    isActive: !!ctx && !!ctx.host && ctx.host.logsShown
    onTriggered: if (ctx && ctx.host) ctx.host.toggleLogs()
}
