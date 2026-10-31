// ZaiAlertBridge.qml — Z.ai quota threshold alerts → NotificationService
// (no notify-send on this box). Mounted by the velocity.zai-usage built-in;
// referencing the service starts its polling.
import QtQuick
import "../services" as Services

Item {
    visible: false

    Connections {
        target: Services.ZaiUsageService
        ignoreUnknownSignals: true
        function onThresholdAlert(info) {
            Services.NotificationService.add(
                "Z.ai Usage",
                info.windowName + " at " + Math.round(info.pct) + "%",
                "Quota window used. Resets in " + info.resetLabel + ".",
                info.urgency,
                0)
        }
    }
}
