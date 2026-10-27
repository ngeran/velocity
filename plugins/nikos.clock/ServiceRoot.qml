// =============================================================================
// ServiceRoot.qml — headless root (entryPoints.service, the service/view split)
// =============================================================================
// The ONE configuration writer for the WeatherService singleton: pushes the
// plugin settings (manifest `showWeather`/`place`/`lat`/`lon`) into it, once
// per bar process no matter how many outputs render the clock. The calendar
// panel binds the singleton; views never configure it.
// Reference: plugins/nikos.timezones/ServiceRoot.qml.
// =============================================================================
import QtQuick
import "." as Clock

Item {
    id: root

    width: 0
    height: 0

    property var ctx: null

    readonly property var _settings: ctx ? ctx.settings.values : null
    on_SettingsChanged: Clock.WeatherService.configure(_settings)
    // ctx lands after mount (post-Component.onCompleted); the _settings
    // binding re-evaluates then and fires on_SettingsChanged — this call
    // only covers the defaults case before the store's file loads.
    Component.onCompleted: {
        Clock.WeatherService.configure(_settings)
        console.log("[nikos.clock] service root mounted (configures WeatherService)")
    }
}
