// =============================================================================
// ResourcesWidget.qml — Right Column Resources (Redesigned for 3-col layout)
// =============================================================================
//
// Vertical layout for a narrow fixed-width right column (170px).
// - CPU / MEM / GPU stacked with 2px sharp bars
// - Colour-coded: teal < 70%, amber 70-89%, red >= 90%
// - Disk usage pinned to bottom as secondary dim stat
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: root

    // Bind to live SysInfoService metrics instead of fake Math.random()
    property real cpuUsage: Services.SysInfoService.cpuPercent
    property real memUsage: Services.SysInfoService.memPercent
    property real gpuUsage: Services.SysInfoService.gpuPercent
    property real diskUsage: Services.SysInfoService.diskPercent

    color:  "#000000"
    radius: 0


    function barColor(pct) {
        if (pct >= 90) return "#e05555"
        if (pct >= 70) return "#d4a435"
        return "#00dce5"
    }

    ColumnLayout {
        anchors { fill: parent; margins: 18 }
        spacing: 0

        // Section label
        Text {
            text:               "RESOURCES"
            font.pixelSize:     7
            font.family:        Config.SettingsConfig.fontFamily
            font.letterSpacing: 2.0
            color:              "#222222"
            Layout.bottomMargin: 14
        }

        // ── CPU ───────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text:               "CPU"
                font.pixelSize:     8
                font.family:        Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.2
                color:              "#3a3a3a"
                Layout.fillWidth:   true
            }

            Text {
                text:           Math.round(cpuUsage) + "%"
                font.pixelSize: 10
                font.family:    Config.SettingsConfig.fontFamily
                color:          barColor(cpuUsage)
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        Item { Layout.preferredHeight: 5 }

        Rectangle {
            Layout.fillWidth: true
            height: 2; color: "#0d0d0d"; radius: 0
            border.color: "#111"; border.width: 1

            Rectangle {
                width:  parent.width * (root.cpuUsage / 100)
                height: parent.height
                color:  barColor(root.cpuUsage)
                radius: 0
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: 300 } }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#111111"; Layout.topMargin: 8; Layout.bottomMargin: 8 }

        // ── MEM ───────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text:               "MEM"
                font.pixelSize:     8
                font.family:        Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.2
                color:              "#3a3a3a"
                Layout.fillWidth:   true
            }

            Text {
                text:           Math.round(memUsage) + "%"
                font.pixelSize: 10
                font.family:    Config.SettingsConfig.fontFamily
                color:          barColor(memUsage)
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        Item { Layout.preferredHeight: 5 }

        Rectangle {
            Layout.fillWidth: true
            height: 2; color: "#0d0d0d"; radius: 0
            border.color: "#111"; border.width: 1

            Rectangle {
                width:  parent.width * (root.memUsage / 100)
                height: parent.height
                color:  barColor(root.memUsage)
                radius: 0
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: 300 } }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#111111"; Layout.topMargin: 8; Layout.bottomMargin: 8 }

        // ── GPU ───────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text:               "GPU"
                font.pixelSize:     8
                font.family:        Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.2
                color:              "#3a3a3a"
                Layout.fillWidth:   true
            }

            Text {
                text:           Math.round(gpuUsage) + "%"
                font.pixelSize: 10
                font.family:    Config.SettingsConfig.fontFamily
                color:          barColor(gpuUsage)
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        Item { Layout.preferredHeight: 5 }

        Rectangle {
            Layout.fillWidth: true
            height: 2; color: "#0d0d0d"; radius: 0
            border.color: "#111"; border.width: 1

            Rectangle {
                width:  parent.width * (root.gpuUsage / 100)
                height: parent.height
                color:  barColor(root.gpuUsage)
                radius: 0
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: 300 } }
            }
        }

        // ── Push DISK to bottom ───────────────────────────────────────────────
        Item { Layout.fillHeight: true }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#111111"; Layout.bottomMargin: 10 }

        Text {
            text:               "DISK"
            font.pixelSize:     7
            font.family:        Config.SettingsConfig.fontFamily
            font.letterSpacing: 2.0
            color:              "#222222"
            Layout.bottomMargin: 6
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text:           "/ root"
                font.pixelSize: 8
                font.family:    Config.SettingsConfig.fontFamily
                color:          "#2e2e2e"
                Layout.fillWidth: true
            }

            Text {
                text:           Math.round(diskUsage) + "%"
                font.pixelSize: 10
                font.family:    Config.SettingsConfig.fontFamily
                color:          "#2a2a2a"
            }
        }

        Item { Layout.preferredHeight: 5 }

        Rectangle {
            Layout.fillWidth: true
            height: 2; color: "#0d0d0d"; radius: 0
            border.color: "#111"; border.width: 1

            Rectangle {
                width:  parent.width * (root.diskUsage / 100)
                height: parent.height
                color:  "#2a2a2a"
                radius: 0
            }
        }
    }
}
