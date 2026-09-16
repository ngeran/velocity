// qs.Ui/PanelKeyCatcher.qml — Escape/Tab handling for compat panels.
// Focusable surface: when the panel grants it focus, Escape emits
// closeRequested and Tab emits tabRequested(direction).
import QtQuick

Item {
    id: catcher

    signal closeRequested()
    signal tabRequested(var direction)

    focus: true
    Keys.onEscapePressed: closeRequested()
    Keys.onTabPressed: tabRequested(1)
}
