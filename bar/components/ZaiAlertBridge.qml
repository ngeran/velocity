// ZaiAlertBridge.qml — Z.ai quota threshold alerts → NotificationService
// (no notify-send on this box). Mounted once in shell.qml (host); referencing
// the service starts its polling.
import QtQuick
import "../services" as Services

Item {
    visible: false

    // The bridge is the service's only listener, so its copy of the singleton
    // owns threshold evaluation and the on-disk "already announced" state
    // (ZaiUsageService.alertRole). This lands during the shell's load; the
    // first poll result only arrives once that load has finished.
    Component.onCompleted: Services.ZaiUsageService.claimAlertRole()

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
