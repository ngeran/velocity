// =============================================================================
// components/ClockWidget.qml
// Live Clock — HH:MM with Date Row and Day-of-Week
//
// USAGE:
//   UI.ClockWidget {
//       anchors.fill: parent
//       anchors.margins: 32
//   }
//
// SELF-CONTAINED: Owns its own Timer. No external bindings required.
//                 Tick interval is 1000ms — updates every second.
//
// COLOR SPLIT: Hours render in primary white; minutes in accentCyan.
//              Divider and date metadata in outlineVariant / textMuted.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

ColumnLayout {
    id: clockRoot

    spacing: 0

    // -------------------------------------------------------------------------
    // INTERNAL STATE — updated by Timer below
    // -------------------------------------------------------------------------
    property var  _now:    new Date()
    property bool _blink:  true   // Colon blink state (optional, currently unused)

    // -------------------------------------------------------------------------
    // TIMER — fires every second, refreshes _now
    // -------------------------------------------------------------------------
    Timer {
        interval:         1000
        running:          true
        repeat:           true
        triggeredOnStart: true   // Populate immediately on load, no 1s blank wait

        onTriggered: {
            clockRoot._now   = new Date()
            clockRoot._blink = !clockRoot._blink
        }
    }

    // -------------------------------------------------------------------------
    // TIME ROW — HH : MM
    // Hours = primary white   Minutes = accentCyan
    // The colon is a static separator; swap to _blink logic if you want pulse.
    // -------------------------------------------------------------------------
    RowLayout {
        Layout.alignment: Qt.AlignLeft
        spacing: 4

        // Hours
        Text {
            text:           Qt.formatDateTime(clockRoot._now, "HH")
            color:          Config.ThemeConfig.colors.primary
            font.pixelSize: 48
            font.bold:      true
            font.family:    "monospace"
        }

        // Separator
        Text {
            text:           ":"
            color:          Config.ThemeConfig.colors.outlineVariant
            font.pixelSize: 48
            font.bold:      true
            font.family:    "monospace"
            // Optional blink — uncomment to activate:
            // opacity: clockRoot._blink ? 1.0 : 0.2
        }

        // Minutes
        Text {
            text:           Qt.formatDateTime(clockRoot._now, "mm")
            color:          Config.ThemeConfig.colors.secondary
            font.pixelSize: 48
            font.bold:      true
            font.family:    "monospace"
        }
    }

    // -------------------------------------------------------------------------
    // HORIZONTAL DIVIDER
    // -------------------------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        height:           1
        color:            Config.ThemeConfig.colors.outlineVariant
        Layout.topMargin: 12
        Layout.bottomMargin: 10
    }

    // -------------------------------------------------------------------------
    // DATE ROW — DATE LEFT   DAY-OF-WEEK RIGHT
    // -------------------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true

        Text {
            text:           Qt.formatDateTime(clockRoot._now, "MMM dd yyyy").toUpperCase()
            color:          Config.ThemeConfig.colors.textDim
            font.pixelSize: 10
            font.family:    "monospace"
            font.letterSpacing: 1.2
        }

        Item { Layout.fillWidth: true }   // Push day-of-week to the right

        Text {
            text:           Qt.formatDateTime(clockRoot._now, "dddd").toUpperCase()
            color:          Config.ThemeConfig.colors.secondary
            font.pixelSize: 9
            font.bold:      true
            font.family:    "monospace"
            font.letterSpacing: 2.0
        }
    }
}
