// =============================================================================
// StripWindow.qml — per-output strip window chrome shared by the bar styles
// =============================================================================
// DU1: every strip style (vector, ryoku, notch) declared the same PanelWindow
// boilerplate per output — this component is that block, once. A style nests
// it inside its `Variants { model: Quickshell.screens }` and supplies what is
// genuinely style-specific: height, colour/transparency, mask, content.
//
// Owned here (verbatim from the styles, traps included):
//   - `modelData` as a PLAIN property — a `required property` breaks
//     initial-property assignment on JS-array models and the window never
//     re-attaches after lock/DPMS ("PanelWindow does not have a property
//     called modelData").
//   - validScreen gate — placeholder/zero-sized screens (connector hotplug
//     churn) must not spawn ghost bars (Shibumi BarPanel pattern).
//   - userHidden — kept OFF the visible binding (assignment would break it);
//     the barToggle IPC writes it.
//   - B5 edge remap — layer-shell anchors only re-read on (re)map, so an
//     edge change cycles the window (150ms flicker) to land on the new edge
//     live. The flag is written imperatively; `visible` stays a binding.
//   - empty-strip click closes the tray card this window opened (host).
//
// NOT owned here (per-style): implicitHeight, color, mask, content.
// Note: lives in components/ (not engine/) on purpose — D1 keeps engine/
// free of config imports and the edge/height/colour chrome IS BarConfig.
// =============================================================================

import QtQuick
import Quickshell
import bar.config as Config

PanelWindow {
    id: strip

    property var host: null

    // Variants REQUIRE the delegate to declare the model item slot:
    // without `modelData` (plain property — a `required property` breaks on
    // JS-array models), delegate recreation fails initial-property
    // assignment and the window NEVER re-attaches to an output.
    property var modelData: null
    screen: modelData

    readonly property bool validScreen: screen !== null && screen.name !== "" && screen.width > 0
    property bool userHidden: false
    // B5: the cycle flag is written imperatively; `visible` stays a binding.
    property bool edgeApplied: true
    readonly property string edgeKey: Config.BarConfig.barPosition
    onEdgeKeyChanged: { edgeApplied = false; edgeRemap.restart() }
    Timer {
        id: edgeRemap
        interval: 150
        onTriggered: strip.edgeApplied = true
    }
    visible: validScreen && !userHidden && edgeApplied

    anchors {
        top: !Config.BarConfig.barAtBottom
        bottom: Config.BarConfig.barAtBottom
        left: true
        right: true
    }

    // Click on empty strip area closes the tray card this bar opened.
    // Declared FIRST so style content (added after) stacks above it.
    MouseArea {
        anchors.fill: parent
        enabled: !!strip.host && strip.host.trayOwner === strip && strip.host.activeTray !== ""
        onClicked: strip.host.closeTray()
    }
}
