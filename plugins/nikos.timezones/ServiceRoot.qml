// =============================================================================
// ServiceRoot.qml — headless root (entryPoints.service, the service/view split)
// =============================================================================
// The ONE configuration writer for the TimezoneService singleton: pushes the
// plugin settings (manifest `zone` + `zones`) into it, once per bar process
// no matter how many outputs render the pill. The pill, the panel and the
// settings header's clock all bind the singleton; views never configure it.
// =============================================================================
import QtQuick
import "." as TZ

Item {
    id: root

    width: 0
    height: 0

    property var ctx: null

    readonly property var _settings: ctx ? ctx.settings.values : null
    on_SettingsChanged: TZ.TimezoneService.configure(_settings)
    // ctx lands after mount (post-Component.onCompleted); the _settings
    // binding re-evaluates then and fires on_SettingsChanged — this call
    // only covers the defaults case before the store's file loads.
    Component.onCompleted: {
        TZ.TimezoneService.configure(_settings)
        console.log("[nikos.timezones] service root mounted (configures the singleton)")
    }
}
