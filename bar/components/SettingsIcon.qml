// =============================================================================
// SettingsIcon.qml — bar trigger for the settings dashboard (gear glyph)
// =============================================================================
// Mounted by the velocity.settings built-in (bar/builtins). BOTH buttons open
// the dashboard now (UX U1 removal: the Control Center panel is gone — one
// settings surface). Kept as separate signals so a future secondary action
// doesn't have to re-thread HoverGlyph.
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

    signal settingsRequested()

    function activate() {
        root.settingsRequested()
    }

    onTriggered: root.activate()
    onRightTriggered: root.activate()
}
