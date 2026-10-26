// LogsIcon.qml — System Logs overlay glyph; hover reveals "LOGS".
// The hover-pill shell is the shared HoverGlyph base (DU10; its 150/120ms
// hardcoded durations were drift — the base uses the MotionConfig tokens).
import QtQuick

HoverGlyph {
    id: root

    glyph: "󰗋"
    label: "LOGS"

    signal triggered()
}
