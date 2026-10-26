// NetworkIcon.qml — network glyph; hover reveals the live IP / state; click opens the tray.
// The hover-pill shell is the shared HoverGlyph base (DU10).
import QtQuick
import "../services" as Services

HoverGlyph {
    id: root

    glyph: !Services.NetworkService.isConnected ? "󰖪"
           : (Services.NetworkService.connectionType === "wifi" ? "󰖩" : "󰈀")
    // Hover reveals the LIVE IP when connected (mockup), else state
    label: Services.NetworkService.isConnected
           ? (Services.NetworkService.ipAddress !== "" ? Services.NetworkService.ipAddress : "NET")
           : "OFFLINE"

    signal trayRequested()
    onTriggered: root.trayRequested()
}
