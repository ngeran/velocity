// =============================================================================
// FILE: LockScreen.qml
// PROJECT: Obsidian Core — Quickshell Desktop Environment
// PURPOSE: Session lock screen (loginctl lock-session integration)
// DESIGN: Full-screen overlay with theme background, large clock, unlock button
// LAYER: WlrLayerShell.Overlay — exclusive keyboard focus
// TRIGGER: Bind to loginctl lock-session in Hyprland config
// AUTHOR: ngeran
// VERSION: 0.1.0
// UPDATED: 2025-06
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../config" as Config

PanelWindow {
    id: root

    // =========================================================================
    // LOCK STATE
    // =========================================================================
    property bool locked: false

    // Layer-shell configuration
    WlrLayerShell.layer: WlrLayerShell.Layer.Overlay
    WlrLayerShell.keyboardFocus: WlrLayerShell.KeyboardFocus.Exclusive
    WlrLayerShell.namespace: "obsidian-lock-screen"

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: locked

    // Close on Escape or click background
    Keys.onEscapePressed: root.locked = false

    MouseArea {
        anchors.fill: parent
        onClicked: root.locked = false
    }

    // =========================================================================
    // BACKGROUND
    // =========================================================================
    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background

        // Subtle grid overlay (optional - can match login screen)
        Canvas {
            anchors.fill: parent
            opacity: 0.015
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = Config.ThemeConfig.colors.text
                ctx.lineWidth = 1
                var step = 60
                for (var x = 0; x <= width;  x += step) {
                    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
                }
                for (var y = 0; y <= height; y += step) {
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                }
            }
        }

        // Blur overlay using multiple layers for performance
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            layer.enabled: true
            layer.effect: null  // Attach MultiEffect if available for blur
        }
    }

    // =========================================================================
    // CONTENT
    // =========================================================================
    Item {
        anchors.fill: parent

        // Logo placeholder
        Item {
            anchors.centerIn: parent
            width: 120
            height: 120

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Config.ThemeConfig.colors.primary
                border.width: 2
                radius: 24

                Text {
                    anchors.centerIn: parent
                    text: "◉"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 48
                    color: Config.ThemeConfig.colors.primary
                }
            }
        }

        // Large clock
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            Text {
                id: clockTime
                text: "00:00"
                font.family: "JetBrains Mono"
                font.pixelSize: 80
                font.weight: Font.Bold
                color: Config.ThemeConfig.colors.text
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                id: clockDate
                text: "WEDNESDAY, OCT 25"
                font.family: "JetBrains Mono"
                font.pixelSize: 16
                color: Config.ThemeConfig.colors.textDim
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Unlock button
        Rectangle {
            anchors {
                bottom: parent.bottom
                bottomMargin: 80
                left: parent.left
                right: parent.left
            }
            width: parent.width
            height: 60
            radius: 12
            color: Config.ThemeConfig.colors.surface

            HoverHandler { id: unlockHover }
            TapHandler {
                onTapped: root.locked = false
            }

            Text {
                anchors.centerIn: parent
                text: "UNLOCK"
                font.family: "JetBrains Mono"
                font.pixelSize: 14
                font.weight: Font.SemiBold
                font.letterSpacing: 2
                color: unlockHover.pressed
                    ? Config.ThemeConfig.colors.primary
                    : Config.ThemeConfig.colors.text
            }
        }
    }

    // =========================================================================
    // CLOCK TIMER
    // =========================================================================
    Timer {
        interval: 1000
        running: root.locked
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            clockTime.text = String(now.getHours()).padStart(2, '0') + ":" +
                             String(now.getMinutes()).padStart(2, '0')
            var days   = ["SUNDAY","MONDAY","TUESDAY","WEDNESDAY","THURSDAY","FRIDAY","SATURDAY"]
            var months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
            clockDate.text = days[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate()
        }
    }
}
