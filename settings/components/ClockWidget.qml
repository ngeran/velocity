// =============================================================================
// ClockWidget.qml — Hero clock for the dashboard bento grid
// =============================================================================
// Header (icon + live seconds) · greeting · big centered HH:MM · date.
// The clock is the dashboard's focal point.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "." as Components

Item {
    id: clockRoot

    property var  _now: new Date()
    property bool _blink: true

    function _greeting() {
        var h = clockRoot._now.getHours()
        if (h < 5)  return "GOOD NIGHT"
        if (h < 12) return "GOOD MORNING"
        if (h < 18) return "GOOD AFTERNOON"
        if (h < 22) return "GOOD EVENING"
        return "GOOD NIGHT"
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { clockRoot._now = new Date(); clockRoot._blink = !clockRoot._blink }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header + live seconds
        Item {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            height: 18

            Components.WidgetHeader {
                icon: "󰥔"
                label: "CLOCK"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clockRoot._now, "ss") + "s"
                color: Config.ThemeConfig.colors.secondary
                font.pixelSize: 9
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
                opacity: clockRoot._blink ? 1.0 : 0.4
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }
        }

        Item { Layout.fillHeight: true }

        // Greeting
        Text {
            text: clockRoot._greeting()
            color: Config.ThemeConfig.colors.textDim
            font.pixelSize: 9
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 3.0
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 4
        }

        // Main time — HH:MM
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0

            Text {
                text: Qt.formatDateTime(clockRoot._now, "HH")
                color: Config.ThemeConfig.colors.primary
                font.pixelSize: 56
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
            Text {
                text: ":"
                color: Config.ThemeConfig.colors.secondary
                font.pixelSize: 56
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                opacity: clockRoot._blink ? 1.0 : 0.15
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
            Text {
                text: Qt.formatDateTime(clockRoot._now, "mm")
                color: Config.ThemeConfig.colors.primary
                font.pixelSize: 56
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
        }

        Item { Layout.fillHeight: true }

        // Date
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clockRoot._now, "dddd").toUpperCase()
                  + "  ·  " + Qt.formatDateTime(clockRoot._now, "dd MMM yyyy").toUpperCase()
            color: Config.ThemeConfig.colors.textDim
            font.pixelSize: 10
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 1.5
        }
    }
}
