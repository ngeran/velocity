// =============================================================================
// ClockWidget.qml — Simple clock display
// =============================================================================
//
// Displays current time in HH:MM format.
//
// IMPLEMENTATION
//   - Updates every 10 seconds
//   - Uses system local time
// =============================================================================

import QtQuick
import "../config" as Config

Column {
    spacing: 0

    // =========================================================================
    // TIME DISPLAY
    // =========================================================================

    Text {
        text: _formattedTime()
        color: Config.BarConfig.colorText
        font.pixelSize: Config.BarConfig.fontSizeClock
        font.family: Config.BarConfig.fontFamily
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // =========================================================================
    // UPDATE TIMER
    // =========================================================================

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: parent.children[0].text = _formattedTime()
    }

    // =========================================================================
    // TIME FORMATTING
    // =========================================================================

    function _formattedTime() {
        const d = new Date()
        const h = String(d.getHours()).padStart(2, "0")
        const m = String(d.getMinutes()).padStart(2, "0")
        return h + ":" + m
    }
}
