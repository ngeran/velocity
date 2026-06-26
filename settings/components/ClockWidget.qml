// =============================================================================
// components/ClockWidget.qml — Full-bleed clock for bento grid
// VERSION: V2.0
//
// Layout: fills card top-to-bottom
//   TOP    — seconds ticker + live status bar (fills remaining space)
//   MIDDLE — HH:MM large, anchored to vertical center
//   BOTTOM — date row + day-of-week
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Item {
    id: clockRoot

    property var  _now:   new Date()
    property bool _blink: true

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { clockRoot._now = new Date(); clockRoot._blink = !clockRoot._blink }
    }

    // Faint accent glow band behind the time for depth (theme-aware).
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 96
        color: Config.ThemeConfig.colors.secondary
        opacity: 0.05
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── TOP ACCENT BAR — week progress ───────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            height: 28

            // "WEEK 26 · WED" label left, seconds ticker right
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "WK " + Qt.formatDateTime(clockRoot._now, "ww")
                      + "  ·  " + Qt.formatDateTime(clockRoot._now, "ddd").toUpperCase()
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 9
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 2.0
            }

            // Live seconds — teal, monospace, right-aligned
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

        // Thin teal top rule
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Config.ThemeConfig.colors.secondary
            opacity: 0.3
            Layout.bottomMargin: 0
        }

        // ── SPACER ────────────────────────────────────────────────────────────
        Item { Layout.fillHeight: true }

        // ── MAIN TIME — HH:MM ─────────────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: 0

            Text {
                text: Qt.formatDateTime(clockRoot._now, "HH")
                color: Config.ThemeConfig.colors.primary
                font.pixelSize: 64
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }

            // Blinking colon
            Text {
                text: ":"
                color: Config.ThemeConfig.colors.secondary
                font.pixelSize: 64
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                opacity: clockRoot._blink ? 1.0 : 0.15
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }

            Text {
                text: Qt.formatDateTime(clockRoot._now, "mm")
                color: Config.ThemeConfig.colors.primary
                font.pixelSize: 64
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
        }

        // ── SPACER ────────────────────────────────────────────────────────────
        Item { Layout.fillHeight: true }

        // ── BOTTOM DIVIDER ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Config.ThemeConfig.colors.outlineVariant
            Layout.bottomMargin: 10
        }

        // ── DATE ROW ─────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: Qt.formatDateTime(clockRoot._now, "dddd").toUpperCase()
                color: Config.ThemeConfig.colors.secondary
                font.pixelSize: 10
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 2.5
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Qt.formatDateTime(clockRoot._now, "dd MMM yyyy").toUpperCase()
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 10
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
            }
        }
    }
}
