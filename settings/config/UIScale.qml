// =============================================================================
// UIScale.qml — responsive scale/breakpoint helper (Shibumi refresh)
// =============================================================================
// Single source of truth for §6 of the ui-refresh skill: breakpoint class,
// density factor, and grid-column math. `sourceWidth` is the panel window's
// LOGICAL width, injected once by settings/shell.qml — singletons can't use
// the Screen attached property (they are not part of a scene), so the window
// feeds us instead of us guessing.
//
// Breakpoints (§6):  compact <1440 · standard 1440–2559 · large ≥2560.
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    // Injected by shell.qml: logical px width of the screen the card is on.
    property real sourceWidth: 1920

    readonly property string breakpoint: sourceWidth < 1440 ? "compact"
                                       : (sourceWidth >= 2560 ? "large" : "standard")
    readonly property bool compact: breakpoint === "compact"
    readonly property bool large:   breakpoint === "large"

    // Density: slightly tighter type/spacing on laptop panels, 1:1 from 1440 up.
    readonly property real factor: sourceWidth < 1440 ? 0.85
                                 : (sourceWidth >= 2560 ? 1.0 : 0.92)

    function px(base) { return Math.round(base * factor) }

    // Card-grid column count — never a fixed column count (§6).
    function columnsFor(availableWidth, minCardWidth) {
        return Math.max(1, Math.floor(availableWidth / minCardWidth))
    }
}
