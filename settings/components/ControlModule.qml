// =============================================================================
// ControlModule.qml — Control tab wrapper for Settings dashboard
// =============================================================================
//
// This is the Control tab content shown when currentTab === 4.
// It embeds the ControlDashboard (which contains the full control UI)
// and exposes the activeSection property so external callers can deep-link
// to specific control sub-sections (network, bluetooth, audio, power, system).
// =============================================================================

import QtQuick
import "." as Components

Item {
    id: root

    // Exposed so shell.qml's openControl(section) can set this
    property string activeSection: "network"

    // The actual control dashboard UI
    ControlDashboard {
        id: controlDashboard
        anchors.fill: parent

        // Bind the dashboard's activeSection to this module's property
        activeSection: root.activeSection
    }
}
