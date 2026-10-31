// =============================================================================
// PowerStrip.qml — header power actions: lock · suspend · restart · shutdown
// =============================================================================
// Lives in the shared Header's empty left half, opposite the identity chip
// (user request: the power actions belong on the dashboard header, not buried
// in the System Info body). 28px icon buttons that fit the 48px HUD strip.
//
// Commands + confirm discipline are the PowerMenu's: destructive actions
// (restart/shutdown) arm a 5s pending state — the icons swap in place for a
// compact CONFIRM pill — and every action runs through BoundedProcess, so a
// wedged systemctl can never hang the header.
//
// Glyphs are \uXXXX escapes (transport law — tools/check-glyphs).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root

    implicitWidth: strip.implicitWidth
    implicitHeight: 28

    // ── palette ─────────────────────────────────────────────────────────────
    // HUD chrome palette (theme-independent — HudConfig is the SSOT here).
    readonly property color cText:      Config.HudConfig.textBody
    readonly property color cDim:       Config.HudConfig.textMid
    readonly property color cBorder:    Config.HudConfig.borderHi
    readonly property color cBg:        Config.HudConfig.panel
    readonly property color cSecondary: Config.HudConfig.cyan
    readonly property color cPrimary:   Config.HudConfig.amber
    readonly property color cWarn:      Config.HudConfig.amber
    readonly property color cErr:       Config.HudConfig.red
    readonly property string fontM:     Config.HudConfig.fontData
    readonly property string fontN:     Config.ControlConfig.fontNerd

    // ── two-step confirm (PowerMenu pattern: no modal, 5s expiry) ───────────
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
        sysCmd.execute(cmd)
    }

    Services.BoundedProcess {
        id: sysCmd
        function execute(cmd) {
            sysCmd.command = ["bash", "-c", cmd]
            sysCmd.run()
        }
    }

    // ── one small icon button (26×26; hover lights the action's accent) ─────
    component PowerIconButton: Rectangle {
        id: pib
        property string glyph: ""
        property color hot: root.cSecondary
        signal fired()
        width: 28; height: 28
        radius: Config.HudConfig.radiusSm
        color: pibArea.containsMouse ? Config.ThemeConfig.tint(pib.hot, 0.14) : "transparent"
        border.color: pibArea.containsMouse ? pib.hot : root.cBorder
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
            anchors.centerIn: parent
            text: pib.glyph
            color: pibArea.containsMouse ? pib.hot : root.cDim
            font.family: root.fontN
            font.pixelSize: 13
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            id: pibArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pib.fired()
        }
    }

    RowLayout {
        id: strip
        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.ControlConfig.space1

        // ---- the four actions (hidden while a confirm is armed) ----
        PowerIconButton {
            visible: !root.confirming
            glyph: ""                       // lock — immediate
            hot: root.cPrimary
            onFired: sysCmd.execute("hyprlock")
        }
        PowerIconButton {
            visible: !root.confirming
            glyph: "☾"                       // suspend — immediate
            hot: root.cSecondary
            onFired: sysCmd.execute("systemctl suspend")
        }
        PowerIconButton {
            visible: !root.confirming
            glyph: "↺"                       // restart — confirm
            hot: root.cWarn
            onFired: root.requestConfirm("systemctl reboot", "RESTART")
        }
        PowerIconButton {
            visible: !root.confirming
            glyph: "⏻"                       // shutdown — confirm
            hot: root.cErr
            onFired: root.requestConfirm("systemctl poweroff", "SHUTDOWN")
        }

        // ---- in-place confirm pill (replaces the icons while armed) ----
        Rectangle {
            visible: root.confirming
            Layout.preferredWidth: confLbl.implicitWidth + 20
            Layout.preferredHeight: 28
            color: confArea.containsMouse ? root.cErr : "transparent"
            border.color: root.cErr; border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                id: confLbl
                anchors.centerIn: parent
                text: "CONFIRM " + root.pendingLabel + " · 5s"
                color: confArea.containsMouse ? root.cBg : root.cErr
                font.family: root.fontM
                font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            MouseArea {
                id: confArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._doConfirm()
            }
        }
        Rectangle {
            visible: root.confirming
            width: 28; height: 28
            color: cancelArea.containsMouse ? Config.ThemeConfig.tint(root.cDim, 0.14) : "transparent"
            border.color: root.cBorder; border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "✕"
                color: root.cDim
                font.family: root.fontM; font.pixelSize: 12
            }
            MouseArea {
                id: cancelArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._cancelConfirm()
            }
        }
    }
}
