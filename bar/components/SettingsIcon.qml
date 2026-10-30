// =============================================================================
// SettingsIcon.qml — bar trigger for the settings dashboard (gear glyph)
// =============================================================================
// Mounted by the velocity.settings built-in (bar/builtins).
// With controlCenter set (the built-in sets it): left click asks the host for
// the Control Center card, right click opens the dashboard directly.
//
// P2.1: the dashboard is hosted IN this process — activate() just emits
// settingsRequested(); the built-in routes it through ctx.host (the bar
// ShellRoot) to the hosted window. Toggle stays honest UX: click the gear
// when open → closes.
//
// The hover-pill shell is the shared HoverGlyph base (DU10) with
// rightClickEnabled — click policy stays here.
// =============================================================================

import QtQuick

HoverGlyph {
    id: root

    glyph: "\u{F0493}"   // nf-md-cog — the SOLID gear (F0492 is cog_outline, reads as a ring at bar size)
    label: "SETTINGS"
    rightClickEnabled: true

    // Rail parity (LogsIcon/NotificationButton carry it)
    property bool controlCenter: false
    signal controlRequested()
    signal settingsRequested()

    function activate() {
        root.settingsRequested()
    }

    onTriggered: {
        if (root.controlCenter) root.controlRequested()
        else root.activate()
    }
    onRightTriggered: root.activate()
}
