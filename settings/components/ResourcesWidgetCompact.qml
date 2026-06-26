// =============================================================================
// ResourcesWidgetCompact.qml — Compact Resources Widget
// =============================================================================
//
// Smaller vertical layout for resources display.
// - CPU / MEM / GPU stacked with 2px sharp bars
// - Colour-coded: teal < 70%, amber 70-89%, red >= 90%
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: root
    property real cpuUsage: Services.SysInfoService.cpuPercent
    property real memUsage: Services.SysInfoService.memPercent
    property real gpuUsage: Services.SysInfoService.gpuPercent

    color:  Config.ThemeConfig.colors.background
    radius: 0


    function barColor(pct) {
        if (pct >= 90) return Config.ThemeConfig.colors.error
        if (pct >= 70) return Config.ThemeConfig.colors.warning
        return Config.ThemeConfig.colors.secondary
    }

    ColumnLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 0

        // Section label
        Text {
            text:               "SYS"
            font.pixelSize:     6
            font.letterSpacing: 1.5
            color:              Config.ThemeConfig.colors.textDim
            Layout.bottomMargin: 8
        }

        // ── CPU ───────────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text:               "CPU"
                font.pixelSize:     7
                font.letterSpacing: 1.0
                color:              Config.ThemeConfig.colors.textDim
                Layout.fillWidth:   true
            }

            Text {
                text:           Math.round(cpuUsage) + "%"
                font.pixelSize: 9
                color:          barColor(cpuUsage)
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        Item { Layout.preferredHeight: 3 }

        Rectangle {
            Layout.fillWidth: true
            height: 2; color: Config.ThemeConfig.colors.border; radius: 0
            border.color: Config.ThemeConfig.colors.outline; border.width: 1

            Rectangle {
                width:  parent.width * (root.cpuUsage / 100)
                height: parent.height
                color:  barColor(root.cpuUsage)
                radius: 0
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: 300 } }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.surfaceVariant; Layout.topMargin: 6; Layout.bottomMargin: 6 }

        // ── MEM ───────────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text:               "MEM"
                font.pixelSize:     7
                font.letterSpacing: 1.0
                color:              Config.ThemeConfig.colors.textDim
                Layout.fillWidth:   true
            }

            Text {
                text:           Math.round(memUsage) + "%"
                font.pixelSize: 9
                color:          barColor(memUsage)
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        Item { Layout.preferredHeight: 3 }

        Rectangle {
            Layout.fillWidth: true
            height: 2; color: Config.ThemeConfig.colors.border; radius: 0
            border.color: Config.ThemeConfig.colors.outline; border.width: 1

            Rectangle {
                width:  parent.width * (root.memUsage / 100)
                height: parent.height
                color:  barColor(root.memUsage)
                radius: 0
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: 300 } }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.surfaceVariant; Layout.topMargin: 6; Layout.bottomMargin: 6 }

        // ── GPU ───────────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text:               "GPU"
                font.pixelSize:     7
                font.letterSpacing: 1.0
                color:              Config.ThemeConfig.colors.textDim
                Layout.fillWidth:   true
            }

            Text {
                text:           Math.round(gpuUsage) + "%"
                font.pixelSize: 9
                color:          barColor(gpuUsage)
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        Item { Layout.preferredHeight: 3 }

        Rectangle {
            Layout.fillWidth: true
            height: 2; color: Config.ThemeConfig.colors.border; radius: 0
            border.color: Config.ThemeConfig.colors.outline; border.width: 1

            Rectangle {
                width:  parent.width * (root.gpuUsage / 100)
                height: parent.height
                color:  barColor(root.gpuUsage)
                radius: 0
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: 300 } }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
