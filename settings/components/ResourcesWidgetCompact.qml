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

Rectangle {
    id: root

    property real cpuUsage:  42
    property real memUsage:  68
    property real gpuUsage:  85

    color:  "#000000"
    radius: 0

    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: updateResources()
    }

    Component.onCompleted: updateResources()

    function updateResources() {
        cpuUsage  = Math.min(100, Math.max(0, cpuUsage  + (Math.random() - 0.5) * 10))
        memUsage  = Math.min(100, Math.max(0, memUsage  + (Math.random() - 0.5) * 5))
        gpuUsage  = Math.min(100, Math.max(0, gpuUsage  + (Math.random() - 0.5) * 15))
    }

    function barColor(pct) {
        if (pct >= 90) return "#e05555"
        if (pct >= 70) return "#d4a435"
        return "#00dce5"
    }

    ColumnLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 0

        // Section label
        Text {
            text:               "SYS"
            font.pixelSize:     6
            font.letterSpacing: 1.5
            color:              "#222222"
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
                color:              "#3a3a3a"
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

        Rectangle { Layout.fillWidth: true; height: 1; color: "#111111"; Layout.topMargin: 6; Layout.bottomMargin: 6 }

        // ── MEM ───────────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text:               "MEM"
                font.pixelSize:     7
                font.letterSpacing: 1.0
                color:              "#3a3a3a"
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

        Rectangle { Layout.fillWidth: true; height: 1; color: "#111111"; Layout.topMargin: 6; Layout.bottomMargin: 6 }

        // ── GPU ───────────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text:               "GPU"
                font.pixelSize:     7
                font.letterSpacing: 1.0
                color:              "#3a3a3a"
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

        Item { Layout.fillHeight: true }
    }
}
