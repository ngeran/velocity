// =============================================================================
// HostBridge.qml — the ONE channel from the settings tree to bar-process state.
//
// Since P2.1 the dashboard runs INSIDE the bar process (a file://-loaded
// window), but the import-split law still holds: settings/* must not
// `import "../bar/..."` — a directory imported under two specifiers yields
// two singleton instances. Instead the bar hands its services over once at
// boot (SettingsBootstrap.barServices → attach), and views read them here:
//
//   readonly property var network: Services.HostBridge.bar.network
//
// Domains merged in P2.2+ appear as properties on the `bar` object; unset
// until the bar shell assigns barServices (null-safe access required).
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    id: bridge

    // Assigned once by SettingsBootstrap (which the bar shell loads at boot).
    // Reassigned, never mutated (instances-map doctrine).
    property var bar: null

    // Null-safe domain accessors — views read these. Null until the bar shell
    // attaches barServices (first seconds of boot); bindings re-evaluate on
    // attach because `bar` notifies.
    readonly property var audio: bar ? bar.audio : null
    readonly property var bluetooth: bar ? bar.bluetooth : null
    readonly property var network: bar ? bar.network : null
    readonly property var metrics: bar ? bar.metrics : null
    readonly property var log: bar ? bar.log : null
    readonly property var engine: bar ? bar.engine : null
    readonly property var configWriter: bar ? bar.configWriter : null
    readonly property var notifications: bar ? bar.notifications : null
    readonly property var hypr: bar ? bar.hypr : null

    function attach(services) {
        if (services && services !== bridge.bar)
            bridge.bar = services
    }
}
