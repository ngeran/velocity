// =============================================================================
// TimezoneWidget.qml — World clock for the bar (omarchy-inspired)
// =============================================================================
// Shows current time in multiple timezones with hover expansion and click
// to open detailed panel. Zero-config uses system timezone data.
//
// Features:
//   - Globe icon (󱉊) that expands on hover to show compact times
//   - Click to open detailed hour-grid panel
//   - Middle-click to refresh timezone offsets
//   - Right-click to open worldtimebuddy.com
//   - Uses system tzdata (no network/API)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../config" as Config
import "../services" as Services

Item {
    id: root
    width: iconRow.width + Config.BarConfig.iconSpacing
    height: Config.BarConfig.iconSize

    property bool expanded: mouseArea.containsMouse && compactLabel !== ""
    property string compactLabel: ""

    // Timezone configuration (editable by user)
    property var zones: [
        { label: "Local", shortLabel: "LOCAL", zone: "", home: true },
        { label: "New York", shortLabel: "NY", zone: "America/New_York" },
        { label: "California", shortLabel: "CA", zone: "America/Los_Angeles" },
        { label: "UTC", shortLabel: "UTC", zone: "UTC" }
    ]

    // Update times every minute
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: updateTimes()
    }

    Component.onCompleted: updateTimes()

    function updateTimes() {
        var now = new Date()
        var parts = []

        for (var i = 0; i < zones.length; i++) {
            var z = zones[i]
            if (z.home || !z.zone) continue

            var time = getTimezoneTime(z.zone, now)
            if (time) {
                parts.push(z.shortLabel + " " + time)
            }
        }

        compactLabel = parts.join(" · ")
    }

    function getTimezoneTime(zone, date) {
        // Simple timezone conversion using Date
        var d = new Date(date)
        var originalOffset = d.getTimezoneOffset() * 60000

        // Create a date string in the target timezone
        var options = { timeZone: zone, hour: '2-digit', minute: '2-digit', hour12: false }
        try {
            var formatter = new Intl.DateTimeFormat('en-US', options)
            var parts = formatter.formatToParts(d)
            var hour = parts.find(p => p.type === 'hour').value
            var minute = parts.find(p => p.type === 'minute').value
            return hour + ":" + minute
        } catch (e) {
            return null
        }
    }

    RowLayout {
        id: iconRow
        anchors.centerIn: parent
        spacing: root.expanded ? 8 : 0

        // Globe icon
        Text {
            text: "󱉊"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Config.BarConfig.iconSize
            color: Config.BarConfig.colorText
            opacity: mouseArea.containsMouse ? 1.0 : 0.7
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        // Expanded time labels (shown on hover)
        Text {
            visible: root.expanded
            text: root.compactLabel
            font.family: "JetBrains Mono"
            font.pixelSize: 11
            color: Config.BarConfig.colorText
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                // TODO: Open detailed timezone panel
                print("Open timezone panel")
            } else if (mouse.button === Qt.MiddleButton) {
                updateTimes()
            } else if (mouse.button === Qt.RightButton) {
                Qt.openUrlExternally("https://www.worldtimebuddy.com/")
            }
        }
    }

    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
}
