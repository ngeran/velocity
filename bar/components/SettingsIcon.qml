// =============================================================================
// SettingsIcon.qml — bar trigger for the settings dashboard (gear glyph)
// =============================================================================
// Mounted by the velocity.settings built-in (bar/builtins).
// With controlCenter set (the built-in sets it): left click asks the host for
// the Control Center card, right click opens the dashboard directly.
// Dashboard open: if the settings instance is running, IPC-toggle its window; if not,
// spawn it detached. One sh line covers both — ipc exits non-zero with
// "Target not found" when nothing owns the target, and the || branch spawns.
//
// Self-contained on purpose: unlike LogsIcon/NotificationButton (which route
// through the host to in-process overlays), the dashboard is a SEPARATE
// process — there is no host handler to call. The `show` verb is
// intentionally avoided: `show` is a quickshell ipc CLI subcommand and never
// parses as a function name (see SettingsWindowShell). Toggle is also honest UX:
// click the gear when open → closes.
//
// The hover-pill shell is the shared HoverGlyph base (DU10) with
// rightClickEnabled — click policy stays here.
// =============================================================================

import QtQuick
import Quickshell.Io

HoverGlyph {
    id: root

    glyph: "\u{F0493}"   // nf-md-cog — the SOLID gear (F0492 is cog_outline, reads as a ring at bar size)
    label: "SETTINGS"
    rightClickEnabled: true

    // Rail parity (LogsIcon/NotificationButton carry it); no feedback channel
    // from the settings process exists yet — the bar cannot know its state.
    property bool controlCenter: false
    signal controlRequested()

    Process {   // unbounded-ok: one-shot ipc toggle / detached spawn — exits at once
        id: launcher
        command: []
    }

    function activate() {
        launcher.command = ["sh", "-c",
            "quickshell ipc -c settings call SettingsWindow toggle 2>/dev/null || " +
            "setsid quickshell -c settings >/dev/null 2>&1 &"]
        launcher.running = true
    }

    onTriggered: {
        if (root.controlCenter) root.controlRequested()
        else root.activate()
    }
    onRightTriggered: root.activate()
}
