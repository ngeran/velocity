// velocity.notifications — built-in bar widget, a thin wrapper over components/NotificationButton.qml.
import QtQuick
import "../../components" as Components

Components.NotificationButton {
    property var ctx: null
    isActive: !!ctx && !!ctx.host && ctx.host.ncShown
    onCenterRequested: if (ctx && ctx.host) ctx.host.toggleNotificationCenter()
}
