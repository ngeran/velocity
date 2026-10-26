// BluetoothIcon.qml — bluetooth glyph; hover reveals "BT"; click opens the tray.
// The hover-pill shell is the shared HoverGlyph base (DU10).
import QtQuick
import "../services" as Services

HoverGlyph {
    id: root

    glyph: Services.BluetoothService.powered ? "󰂯" : "󰂲"
    label: "BT"

    signal trayRequested()
    onTriggered: root.trayRequested()
}
