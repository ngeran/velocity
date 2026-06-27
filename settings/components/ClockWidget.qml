// =============================================================================
// ClockWidget.qml — Hero clock with Athens Dual Zone (+7H Offset)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "." as Components

Item {
    id: clockRoot

    // -------------------------------------------------------------------------
    // Properties & Logic
    // -------------------------------------------------------------------------
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

    // Manual calculation to ensure exactly +7 hours difference
    function _getAthensTime() {
        // Create a new date object based on current time
        var athens = new Date(clockRoot._now.getTime());
        // Add 7 hours (7 * 60 * 60 * 1000 milliseconds)
        athens.setHours(athens.getHours() + 7);
        
        var hh = String(athens.getHours()).padStart(2, '0');
        var mm = String(athens.getMinutes()).padStart(2, '0');
        return hh + ":" + mm;
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { 
            clockRoot._now = new Date(); 
            clockRoot._blink = !clockRoot._blink 
        }
    }

    // -------------------------------------------------------------------------
    // Main Layout
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 0

        // --- SECTION: Header ---
        Item {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            height: 18

            Components.WidgetHeader {
                icon: "󰥔"
                label: "SYSTEM CLOCK"
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

        // --- SECTION: Greeting ---
        Text {
            text: clockRoot._greeting()
            color: Config.ThemeConfig.colors.textDim
            font.pixelSize: 9
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 3.0
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 4
        }

        // --- SECTION: Main Time (Local) ---
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0

            Text {
                text: Qt.formatDateTime(clockRoot._now, "HH")
                color: Config.ThemeConfig.colors.primary
                font.pixelSize: 58
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
            Text {
                text: ":"
                color: Config.ThemeConfig.colors.secondary
                font.pixelSize: 58
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                opacity: clockRoot._blink ? 1.0 : 0.15
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
            Text {
                text: Qt.formatDateTime(clockRoot._now, "mm")
                color: Config.ThemeConfig.colors.primary
                font.pixelSize: 58
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
        }

        // --- SECTION: Athens Dual Zone (+7H) ---
        // A clean, horizontal bar style
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.bottomMargin: 10
            spacing: 10

            Rectangle { width: 12; height: 1; color: Config.ThemeConfig.colors.secondary; opacity: 0.3 }

            Row {
                spacing: 6
                Text {
                    text: "ATHENS"
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    font.family: Config.SettingsConfig.fontFamily
                }
                Text {
                    text: clockRoot._getAthensTime()
                    color: Config.ThemeConfig.colors.secondary
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.family: Config.SettingsConfig.fontFamily
                }
                Text {
                    text: "+7H"
                    color: Config.ThemeConfig.colors.secondary
                    font.pixelSize: 8
                    opacity: 0.5
                    font.family: Config.SettingsConfig.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle { width: 12; height: 1; color: Config.ThemeConfig.colors.secondary; opacity: 0.3 }
        }

        Item { Layout.fillHeight: true }

        // --- SECTION: Footer Date ---
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
