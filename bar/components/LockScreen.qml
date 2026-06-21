// =============================================================================
// FILE: LockScreen.qml
// PROJECT: Quickshell Desktop Environment
// PURPOSE: Session lock screen overlay
// DESIGN: Full-screen overlay with theme background, large clock, unlock button
// TRIGGER: Via IPC (lockScreenToggle, lock, unlock)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config" as Config

PanelWindow {
    id: root

    // =========================================================================
    // LOCK STATE
    // =========================================================================
    property bool locked: false

    // =========================================================================
    // WINDOW CONFIGURATION
    // =========================================================================
    // Show on all screens by using Variants pattern in shell
    color: Config.ThemeConfig.colors.background
    visible: locked

    // Focus handling - wrap in Item since PanelWindow doesn't support Keys directly
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: { if (root.locked) root.locked = false }
    }

    // =========================================================================
    // BACKGROUND
    // =========================================================================
    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background

        // Subtle grid overlay
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
    }

    // =========================================================================
    // CONTENT
    // =========================================================================
    Item {
        anchors.fill: parent

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
                right: parent.right
            }
            height: 60
            radius: 12
            color: Config.ThemeConfig.colors.surface

            HoverHandler { id: unlockHover }

            TapHandler {
                onTapped: root.locked = false
            }

            Text {
                anchors.centerIn: parent
                text: "UNLOCK (ESC)"
                font.family: "JetBrains Mono"
                font.pixelSize: 14
                font.weight: Font.SemiBold
                font.letterSpacing: 2
                color: unlockHover.hovered
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

    // =========================================================================
    // BACKGROUND CLICK TO UNLOCK
    // =========================================================================
    MouseArea {
        anchors.fill: parent
        onClicked: root.locked = false
    }
}
