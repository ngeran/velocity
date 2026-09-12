// =============================================================================
// nikos.power — power panel body (placed inside the host PluginPanel)
// =============================================================================
// State chip · CHARGE / SOURCE rows · charge bar · POWER MENU deep-link
// (suspend/reboot/shutdown live in the settings shell's power menu — the
// audit's "popup titled POWER but shows a datasheet" fix). Tokens injected.
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

    Component.onCompleted: console.log("[nikos.power] panel body loaded, w=" + width + " h=" + height)

    RowLayout {
        Layout.fillWidth: true; spacing: 6
        Rectangle {
            width: stateLbl.implicitWidth + 16; height: 18
            radius: 0
            color: {
                if (!PW.BatteryService.hasBattery) return hostTheme ? hostTheme.accentTint : "transparent"
                if (PW.BatteryService.charging) return hostTheme ? hostTheme.successTint : "transparent"
                if (PW.BatteryService.percentage <= 20) return hostTheme ? hostTheme.errorTint : "transparent"
                return hostTheme ? hostTheme.fillRest : "transparent"
            }
            border.color: {
                if (!PW.BatteryService.hasBattery) return hostBar ? hostBar.colorAccent : "#7aa2f7"
                if (PW.BatteryService.charging) return hostTheme ? hostTheme.colors.success : "#9ece6a"
                if (PW.BatteryService.percentage <= 20) return hostTheme ? hostTheme.colors.error : "#f7768e"
                return hostBar ? hostBar.colorBorder : "#333"
            }
            border.width: 1
            Behavior on color { ColorAnimation { duration: 200 } }
            Text {
                id: stateLbl; anchors.centerIn: parent
                text: PW.BatteryService.stateLabel
                font.family: hostBar ? hostBar.fontFamily : "monospace"
                font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                color: {
                    if (!PW.BatteryService.hasBattery) return hostBar ? hostBar.colorAccent : "#7aa2f7"
                    if (PW.BatteryService.charging) return hostTheme ? hostTheme.colors.success : "#9ece6a"
                    if (PW.BatteryService.percentage <= 20) return hostTheme ? hostTheme.colors.error : "#f7768e"
                    return hostBar ? hostBar.colorTextDim : "#888"
                }
            }
        }
        Item { Layout.fillWidth: true }
    }

    Item { height: 12 }

    RowLayout {
        Layout.fillWidth: true; spacing: 0
        Text { text: "CHARGE"
            font.family: hostBar ? hostBar.fontFamily : "monospace"
            font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
            color: hostBar ? hostBar.colorTextDim : "#666"; Layout.preferredWidth: 52 }
        Text {
            text: PW.BatteryService.hasBattery ? PW.BatteryService.percentage + "%" : "—"
            font.family: hostBar ? hostBar.fontFamily : "monospace"
            font.pixelSize: 13; font.bold: true
            color: {
                if (!PW.BatteryService.hasBattery) return hostBar ? hostBar.colorTextDim : "#666"
                if (PW.BatteryService.charging) return hostTheme ? hostTheme.colors.success : "#9ece6a"
                if (PW.BatteryService.percentage <= 20) return hostTheme ? hostTheme.colors.error : "#f7768e"
                if (PW.BatteryService.percentage <= 50) return hostTheme ? hostTheme.colors.warning : "#e0af68"
                return hostBar ? hostBar.colorText : "#ddd"
            }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    // Charge bar
    Item {
        Layout.fillWidth: true; height: 8
        Layout.topMargin: 4
        Rectangle {
            anchors.fill: parent
            radius: 0
            color: hostTheme ? hostTheme.hairlineSoft : "#222"
            Rectangle {
                height: parent.height
                width: parent.width * (PW.BatteryService.hasBattery ? PW.BatteryService.percentage : 0) / 100
                color: PW.BatteryService.charging ? (hostTheme ? hostTheme.colors.success : "#9ece6a")
                     : PW.BatteryService.percentage <= 20 ? (hostTheme ? hostTheme.colors.error : "#f7768e")
                     : hostBar ? hostBar.colorAccent : "#7aa2f7"
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }
    }

    Item { height: 8 }
    RowLayout { Layout.fillWidth: true; spacing: 0
        Text { text: "SOURCE"
            font.family: hostBar ? hostBar.fontFamily : "monospace"
            font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
            color: hostBar ? hostBar.colorTextDim : "#666"; Layout.preferredWidth: 52 }
        Text { text: PW.BatteryService.onAc ? "AC / Wall" : "Battery"
            font.family: hostBar ? hostBar.fontFamily : "monospace"
            font.pixelSize: 12; color: hostBar ? hostBar.colorText : "#ddd" }
    }

    Item { height: 10 }
    Rectangle { Layout.fillWidth: true; height: 1
        color: hostTheme ? hostTheme.hairline : "#222" }
    Item { height: 8 }

    // POWER MENU deep-link — suspend/reboot/shutdown live in the settings
    // shell's power menu (SUPER+P / powerMenu IPC); this is the bridge.
    Rectangle {
        Layout.fillWidth: true; height: 26
        radius: 0
        color: pmArea.containsMouse ? (hostTheme ? hostTheme.accentTint : "#222")
                                    : (hostTheme ? hostTheme.fillRest : "transparent")
        border.color: hostBar ? hostBar.colorAccent : "#7aa2f7"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 150 } }
        RowLayout {
            anchors.centerIn: parent; spacing: 6
            Text { text: "󰐥"; font.family: hostBar ? hostBar.fontNerd : "monospace"
                font.pixelSize: 12; color: hostBar ? hostBar.colorAccent : "#7aa2f7" }
            Text { text: "POWER MENU"
                font.family: hostBar ? hostBar.fontFamily : "monospace"
                font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                color: hostBar ? hostBar.colorAccent : "#7aa2f7" }
        }
        MouseArea {
            id: pmArea
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menuProc.running = true
        }
    }

    Process {
        id: menuProc
        command: ["quickshell", "-c", "settings", "ipc", "call", "powerMenu", "toggle"]
    }
}
