// =============================================================================
// TimezoneWidget.qml — World clock for the bar (omarchy-inspired)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root
    width: timezoneRow.implicitWidth + 12
    height: Config.BarConfig.barHeight

    property bool expanded: mouseArea.containsMouse && compactLabel !== ""
    property string compactLabel: ""

    // Timezone configuration
    property var zones: [
        { label: "Local", shortLabel: "LOCAL", zone: "", home: true },
        { label: "New York", shortLabel: "NY", zone: "America/New_York" },
        { label: "California", shortLabel: "CA", zone: "America/Los_Angeles" },
        { label: "UTC", shortLabel: "UTC", zone: "UTC" }
    ]

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
            if (time) parts.push(z.shortLabel + " " + time)
        }
        root.compactLabel = parts.join(" · ")
    }

    function getTimezoneTime(zone, date) {
        var options = { timeZone: zone, hour: '2-digit', minute: '2-digit', hour12: false }
        try {
            var formatter = new Intl.DateTimeFormat('en-US', options)
            var parts = formatter.formatToParts(date)
            var hour = parts.find(p => p.type === 'hour').value
            var minute = parts.find(p => p.type === 'minute').value
            return hour + ":" + minute
        } catch (e) {
            return null
        }
    }

    Row {
        id: timezoneRow
        anchors.centerIn: parent
        spacing: root.expanded ? 8 : 0

        Text {
            text: "🌐"
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.BarConfig.fontSizeIcon
            color: Config.ThemeConfig.colors.textDim
            opacity: mouseArea.containsMouse ? 1.0 : 0.7
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        Text {
            visible: root.expanded
            text: root.compactLabel
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: 11
            color: Config.ThemeConfig.colors.text
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
                print("Opening timezone panel")
            } else if (mouse.button === Qt.MiddleButton) {
                updateTimes()
            } else if (mouse.button === Qt.RightButton) {
                Qt.openUrlExternally("https://www.worldtimebuddy.com/")
            }
        }
    }

    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
}
