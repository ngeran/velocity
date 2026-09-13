// =============================================================================
// nikos.power — power panel body (placed inside the host PluginPanel)
// =============================================================================
// Mockup port: chips row (AC POWER · CHARGING · HEALTH) · CHARGE block with
// gradient-tint bar + capacity/rate · SOURCE row · POWER PROFILE segmented
// picker (hidden unless power-profiles-daemon is installed) · POWER MENU
// footer (deep-links to the settings shell's power menu). Battery blocks are
// gated on hasBattery — a desktop shows AC-only, honestly.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "." as PW

ColumnLayout {
    id: bodyRoot
    width: parent.width

    property var hostBar: null
    property var hostTheme: null

    Layout.fillWidth: true
    spacing: 0

    function _c(tok) { return hostTheme ? hostTheme.colors[tok] : "#888" }

    Process {
        id: pmProc
        command: ["qs", "-c", "settings", "ipc", "call", "powerMenu", "toggle"]
    }

    // ── chips row: source · battery state · HEALTH ──
    RowLayout {
        Layout.fillWidth: true; spacing: 8

        Rectangle {
            width: srcLbl.implicitWidth + 16; height: 20
            radius: 4
            color: "transparent"
            border.color: PW.BatteryService.onAc
                          ? (hostTheme ? hostTheme.colors.primary : "#7aa2f7") : (hostBar ? hostBar.colorBorder : "#333")
            border.width: 1
            Text { id: srcLbl; anchors.centerIn: parent
                text: PW.BatteryService.onAc ? "AC POWER" : "ON BATTERY"
                font.family: hostBar ? hostBar.fontFamily : "monospace"; font.pixelSize: 8; font.bold: true
                font.letterSpacing: 1.5
                color: PW.BatteryService.onAc ? (hostTheme ? hostTheme.colors.primary : "#7aa2f7") : (hostBar ? hostBar.colorTextDim : "#666") }
        }
        Rectangle {
            visible: PW.BatteryService.hasBattery
            width: chgLbl.implicitWidth + 22; height: 20
            radius: 4
            color: PW.BatteryService.charging ? (hostTheme ? hostTheme.accentTintSoft : "transparent") : (hostTheme ? hostTheme.fillRest : "transparent")
            border.color: hostBar ? hostBar.colorBorder : "#333"; border.width: 1
            Row {
                anchors.centerIn: parent; spacing: 5
                Rectangle {
                    width: 5; height: 5; radius: 2.5
                    color: PW.BatteryService.charging ? (hostTheme ? hostTheme.colors.success : "#9ece6a") : (hostBar ? hostBar.colorTextDim : "#666")
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text { id: chgLbl; anchors.verticalCenter: parent.verticalCenter
                    text: PW.BatteryService.stateLabel
                    font.family: hostBar ? hostBar.fontFamily : "monospace"; font.pixelSize: 8; font.bold: true
                    font.letterSpacing: 1.5
                    color: PW.BatteryService.charging ? (hostTheme ? hostTheme.colors.success : "#9ece6a") : (hostBar ? hostBar.colorTextDim : "#666") }
            }
        }
        Item { Layout.fillWidth: true }
        Text {
            visible: PW.BatteryService.hasBattery && PW.BatteryService.healthPct > 0
            text: "HEALTH:  " + PW.BatteryService.healthPct + "%"
            font.family: hostBar ? hostBar.fontFamily : "monospace"; font.pixelSize: 9
            color: hostBar ? hostBar.colorTextDim : "#666"
        }
    }
    Item { height: 12 }

    // ── CHARGE block (battery present) ──
    ColumnLayout {
        visible: PW.BatteryService.hasBattery
        Layout.fillWidth: true; spacing: 8

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text {
                text: "CHARGE"
                font.family: hostBar ? hostBar.fontFamily : "monospace"; font.pixelSize: 9; font.bold: true
                font.letterSpacing: 1.5
                color: hostBar ? hostBar.colorText : "#ddd"
            }
            Item { Layout.fillWidth: true }
            Text {
                text: PW.BatteryService.percentage + "%"
                font.family: hostBar ? hostBar.fontFamily : "monospace"; font.pixelSize: 15; font.bold: true
                color: hostBar ? hostBar.colorText : "#ddd"
            }
            Text {
                visible: PW.BatteryService.timeLabel !== ""
                text: PW.BatteryService.timeLabel
                font.family: hostBar ? hostBar.fontFamily : "monospace"; font.pixelSize: 10
                color: hostBar ? hostBar.colorTextDim : "#666"
            }
        }
        Rectangle {
            Layout.fillWidth: true; height: 8; radius: 2
            color: hostTheme ? hostTheme.hairlineSoft : "#222"
            Rectangle {
                width: parent.width * PW.BatteryService.percentage / 100
                height: parent.height; radius: 2
                color: hostTheme ? (PW.BatteryService.charging ? hostTheme.colors.primary : hostBar.colorAccent) : "#7aa2f7"
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: PW.BatteryService.hasEnergy
                      ? "Capacity: " + PW.BatteryService.energyNow.toFixed(1) + " / " +
                        PW.BatteryService.energyFull.toFixed(1) + " Wh"
                      : "Capacity: —"
                font.family: hostBar ? hostBar.fontFamily : "monospace"; font.pixelSize: 9
                color: hostBar ? hostBar.colorTextDim : "#666"
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: PW.BatteryService.energyRate > 0.5
                text: "Rate: " + (PW.BatteryService.charging ? "+" : "−") +
                      PW.BatteryService.energyRate.toFixed(1) + " W"
                font.family: hostBar ? hostBar.fontFamily : "monospace"; font.pixelSize: 9
                color: hostBar ? hostBar.colorTextDim : "#666"
            }
        }
    }
    Item { height: 10; visible: PW.BatteryService.hasBattery }
    Rectangle { visible: PW.BatteryService.hasBattery; Layout.fillWidth: true; height: 1; color: hostBar ? hostBar.colorBorder : "#333" }
    Item { height: 10; visible: PW.BatteryService.hasBattery }

    // ── SOURCE row ──
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Text {
            text: "SOURCE"
            font.family: hostBar ? hostBar.fontFamily : "monospace"; font.pixelSize: 9; font.bold: true
            font.letterSpacing: 1.5
            color: hostBar ? hostBar.colorTextDim : "#666"
        }
        Item { Layout.fillWidth: true }
        Text {
            text: PW.BatteryService.onAc ? "AC / Wall" : "Battery"
            font.family: hostBar ? hostBar.fontFamily : "monospace"; font.pixelSize: 12; font.bold: true
            color: hostBar ? hostBar.colorText : "#ddd"
        }
    }
    Item { height: 12; visible: PW.BatteryService.hasBattery }

    // ── POWER MENU footer ──
    Rectangle {
        Layout.fillWidth: true; height: 34
        radius: 8
        color: pmArea.containsMouse ? (hostTheme ? hostTheme.accentTint : "transparent") : (hostTheme ? hostTheme.fillRest : "transparent")
        border.color: hostTheme ? hostTheme.colors.primary : "#7aa2f7"; border.width: 1
        Behavior on color { ColorAnimation { duration: 150 } }
        RowLayout { anchors.centerIn: parent; spacing: 8
            Text { text: "⏻"; font.family: hostBar ? hostBar.fontNerd : "monospace"; font.pixelSize: 13; color: hostTheme ? hostTheme.colors.primary : "#7aa2f7" }
            Text { text: "POWER MENU"; font.family: hostBar ? hostBar.fontFamily : "monospace"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2.5; color: hostBar ? hostBar.colorText : "#ddd" }
        }
        MouseArea {
            id: pmArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pmProc.running = true
        }
    }
}
