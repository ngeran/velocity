// qs.Ui/PanelKeyCatcher.qml — keyboard handling for compat panels.
// Focusable surface: when the panel grants it focus, Escape emits
// closeRequested, Return emits returnRequested, and Tab emits
// tabRequested(direction) — the upstream Quattro PanelKeyCatcher API.
import QtQuick

Item {
    id: catcher

    signal closeRequested()
    signal returnRequested()
    signal tabRequested(var direction)

    focus: true
    Keys.onEscapePressed: closeRequested()
    Keys.onReturnPressed: returnRequested()
    Keys.onTabPressed: tabRequested(1)
}
