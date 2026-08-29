// =============================================================================
// PowerMenu.qml — full-screen power-control overlay
// =============================================================================
// Shutdown / Restart / Suspend / Lock. Modern System-Info-family design: dim
// click-to-close backdrop, a centred bordered card with a subtle grid + crisp
// corner brackets, a clean header (glyph, title, subtitle, explicit close
// button) over a 2×2 grid of icon-forward action cards. No uptime clutter.
// Colours are live ThemeConfig tokens; each action carries a semantic accent.
// Toggled via the 'powerMenu' IPC target (powerMenu.showing) — Esc /
// click-outside / ✕ all close.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../config" as Config
import "." as Components

PanelWindow {
    id: root

    // Public toggle (set by the 'powerMenu' IPC handler in shell.qml).
    property bool showing: false
    visible: false
    onShowingChanged: {
        if (showing) root.visible = true
        else hideTimer.restart()
    }

    // ---- inline two-step confirm (Shibumi pattern: no modal, 5s expiry) ----
    // Destructive tiles (shutdown/restart) arm a pending command instead of
    // executing; the strip below the header asks Confirm/Cancel and expires.
    property string pendingCmd: ""
    property string pendingLabel: ""
    readonly property bool confirming: pendingCmd !== ""
    Timer {
        id: confirmExpiry
        interval: 5000
        onTriggered: root._cancelConfirm()
    }
    function requestConfirm(cmd, label) {
        root.pendingCmd = cmd
        root.pendingLabel = label
        confirmExpiry.restart()
    }
    function _cancelConfirm() {
        root.pendingCmd = ""
        root.pendingLabel = ""
        confirmExpiry.stop()
    }
    function _doConfirm() {
        var cmd = root.pendingCmd
        root._cancelConfirm()
        systemCmd.execute(cmd)
    }

    Keys.onEscapePressed: {
        // Escape defuses the armed confirm first, then closes the menu.
        if (root.confirming) root._cancelConfirm()
        else root.showing = false
    }

    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // ---- palette (live theme tokens) ----
    readonly property color cBg:        Config.ThemeConfig.colors.background
    readonly property color cText:      Config.ThemeConfig.colors.text
    readonly property color cDim:       Config.ThemeConfig.colors.textDim
    readonly property color cBorder:    Config.ThemeConfig.colors.border
    readonly property color cSecondary: Config.ThemeConfig.colors.secondary
    readonly property color cPrimary:   Config.ThemeConfig.colors.primary
    readonly property color cErr:       Config.ThemeConfig.colors.error
    readonly property color cWarn:      Config.ThemeConfig.colors.warning
    readonly property string fontN:     "JetBrainsMono Nerd Font"

    readonly property int cardW: 500
    readonly property int cardH: 420

    // Delays hiding so the fade-out can play.
    Timer { id: hideTimer; interval: 220; onTriggered: if (!root.showing) root.visible = false }

    // ---- dim backdrop (click-outside = close) ----
    Rectangle {
        anchors.fill: parent
        color: root.cBg
        opacity: root.showing ? 0.55 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: root.showing = false }
    }

    // ---- centred card ----
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: root.cardW; height: root.cardH
        color: root.cBg
        border.color: root.cBorder; border.width: 1
        clip: true
        opacity: root.showing ? 1.0 : 0.0
        scale:  root.showing ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }   // swallow clicks so they don't close the menu

        // subtle grid background
        Item {
            anchors.fill: parent; opacity: 0.15; z: 0
            Repeater { model: Math.floor(card.width / 40);  Rectangle { width: 1; height: card.height; x: index * 40; color: root.cBorder } }
            Repeater { model: Math.floor(card.height / 40); Rectangle { height: 1; width: card.width;  y: index * 40; color: root.cBorder } }
        }

        // corner brackets (same construction as the System Info overlay)
        Repeater {
            model: 4
            Item {
                width: 14; height: 14; opacity: 0.7; z: 0
                x: (index === 0 || index === 2) ? 0 : (card.width - 14)
                y: (index === 0 || index === 1) ? 0 : (card.height - 14)
                property bool isRight:  (index === 1 || index === 3)
                property bool isBottom: (index === 2 || index === 3)
                Rectangle { width: 14; height: 2; color: root.cSecondary; y: parent.isBottom ? 12 : 0 }
                Rectangle { width: 2;  height: 14; color: root.cSecondary; x: parent.isRight  ? 12 : 0 }
            }
        }

        // ---- content ----
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 18
            z: 10

            // header
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Text { text: "⏻"; color: root.cErr; font.family: root.fontN; font.pixelSize: 22; Layout.alignment: Qt.AlignVCenter }
                ColumnLayout { spacing: 2; Layout.alignment: Qt.AlignVCenter
                    Text { text: "POWER OPTIONS"; color: root.cText
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 15; font.bold: true; font.letterSpacing: 3 }
                    Text { text: "Select an action to continue"; color: root.cDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }
                }
                Item { Layout.fillWidth: true }
                Text { text: "ESC"; color: root.cDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; Layout.alignment: Qt.AlignVCenter }
                Rectangle {   // explicit close button
                    width: 30; height: 30; Layout.alignment: Qt.AlignVCenter
                    color: "transparent"
                    border.color: closeMa.containsMouse ? root.cErr : root.cBorder
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Text { anchors.centerIn: parent; text: "✕"
                        color: closeMa.containsMouse ? root.cErr : root.cDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 12
                        Behavior on color { ColorAnimation { duration: 150 } } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.showing = false }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

            // confirm strip — appears only while a destructive action is armed
            Rectangle {
                visible: root.confirming
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                color: "transparent"
                border.color: root.cErr; border.width: 1
                Behavior on opacity { NumberAnimation { duration: 120 } }
                opacity: root.confirming ? 1 : 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Text {
                        text: "CONFIRM " + root.pendingLabel + "?"
                        color: root.cErr
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 12; font.bold: true; font.letterSpacing: 2
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: "· 5s"
                        color: root.cDim
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 9
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { Layout.fillWidth: true }

                    Rectangle {   // CANCEL
                        width: 92; height: 26
                        color: cancelMa.containsMouse ? root.cBorder : "transparent"
                        border.color: root.cBorder; border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "CANCEL"
                               color: root.cText; font.family: Config.ControlConfig.fontMono
                               font.pixelSize: 10; font.bold: true }
                        MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._cancelConfirm() }
                    }
                    Rectangle {   // CONFIRM
                        width: 100; height: 26
                        color: confirmMa.containsMouse ? root.cErr : "transparent"
                        border.color: root.cErr; border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "CONFIRM"
                               color: confirmMa.containsMouse ? root.cBg : root.cErr
                               font.family: Config.ControlConfig.fontMono
                               font.pixelSize: 10; font.bold: true
                               Behavior on color { ColorAnimation { duration: 120 } } }
                        MouseArea { id: confirmMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._doConfirm() }
                    }
                }
            }

            // 2×2 action grid
            GridLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                columns: 2; rowSpacing: 14; columnSpacing: 14

                Components.PowerTile {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    accent: root.cErr; iconText: "⏻"; labelText: "SHUTDOWN"
                    onActivated: root.requestConfirm("systemctl poweroff", "SHUTDOWN")
                }
                Components.PowerTile {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    accent: root.cWarn; iconText: "↺"; labelText: "RESTART"
                    onActivated: root.requestConfirm("systemctl reboot", "RESTART")
                }
                Components.PowerTile {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    accent: root.cSecondary; iconText: "☾"; labelText: "SUSPEND"
                    onActivated: systemCmd.execute("systemctl suspend")
                }
                Components.PowerTile {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    accent: root.cPrimary; iconText: ""; labelText: "LOCK"
                    onActivated: { systemCmd.execute("hyprlock"); root.showing = false }
                }
            }
        }
    }

    // ---- deferred executor: set .command then run ----
    Process {
        id: systemCmd
        function execute(cmd) {
            systemCmd.command = ["bash", "-c", cmd]
            systemCmd.running = true
            root.showing = false
        }
    }
}
