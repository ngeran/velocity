// CoreLcdPane.qml — standalone MYSTIQUE AIO pane (Core tab ▸ lcd).
// Thin wrapper since the HUD rework: all controller UI + state lives in
// LcdControllerPanel / LcdConfigService (shared with the telemetry pane's
// embedded controller). This wrapper just adds the standalone breathing room.

import QtQuick
import "../config" as Config
import "../services" as Services

Item {
    LcdControllerPanel {
        anchors.fill: parent
        embedded: false
    }
}
