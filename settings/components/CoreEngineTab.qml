// =============================================================================
// CoreEngineTab.qml — "Core Engine" tab (tab 4): shared ControlSectionNav + content swap
// =============================================================================
// Consolidated nav (user request): SYSTEM (CPU+GPU+MEM+LCD+drives — the AIO
// controller is embedded, not its own section) is the default pane; EVENTS
// remains separate.
// Telemetry gating preserved: coreVisible construct/destruct.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root

    property string active: "system"

    // Telemetry session (Shibumi consumer-refcount, single-consumer case):
    // this tab's Loader instantiation IS the CoreEngine/Gpu/Thermal gate.
    // (The core:* search entries are seeded once in SettingsWindowShell's
    // _seedSearchCatalog; the nav model itself lives in
    // Config.ControlConfig.coreSections so the seed and this ControlSectionNav share it.)
    Component.onCompleted: Services.HostBridge.metrics.coreVisible = true
    Component.onDestruction: Services.HostBridge.metrics.coreVisible = false

    // Section rail: compact fallback only — in labeled mode the dashboard
    // sidebar hosts the CORE submenu (TELEMETRY + LCD / EVENTS).
    ControlSectionNav {
        id: sideNav
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Config.UIScale.compact ? 56 : 0
        visible: Config.UIScale.compact
        items: Config.ControlConfig.coreSections
        activeSection: root.active
        onSectionSelected: function(key) { root.active = key }
    }

    // ── content: one pane per section ────────────────────────────────────
    Item {
        id: contentArea
        anchors.left: sideNav.right; anchors.top: parent.top; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 12

        // SYSTEM — consolidated CPU + GPU + memory + drives (no scrolling)
        Item {
            anchors.fill: parent; visible: root.active === "system"
            CoreSystemPane { anchors.fill: parent; anchors.margins: 8 }
        }

        // EVENTS — system event timeline (no scrolling)
        Item {
            anchors.fill: parent; visible: root.active === "events"
            CoreEventsPane { anchors.fill: parent; anchors.margins: 8 }
        }
    }
}
