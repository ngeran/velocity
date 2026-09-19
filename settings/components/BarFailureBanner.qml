// =============================================================================
// BarFailureBanner.qml — "the bar is down and here's why" surface
// =============================================================================
// The reload-cover idea (ryoku), adapted: our supervisor is systemd and the
// settings process outlives bar crashes, so the failure surface lives HERE
// instead of a separate config. A thin top strip in the bar's place while
// BarWatchService.barAlive is false: status, the last journal lines (error
// tail probed at failure onset), and the recovery command. Auto-hides the
// moment the bar's instance lock reappears.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services" as Services
import "../config" as Config

PanelWindow {
    id: banner

    visible: !Services.BarWatchService.barAlive

    anchors { top: true; left: true; right: true }
    implicitHeight: 34
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    WlrLayershell.namespace: "bar-failure-banner"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        border.width: 1
        border.color: Config.ThemeConfig.colors.error

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: "󰅚 BAR OFFLINE"
                font.family: Config.ControlConfig.fontNerd
                font.pixelSize: 12
                font.bold: true
                color: Config.ThemeConfig.colors.error
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: Services.BarWatchService.errorTail !== ""
                      ? Services.BarWatchService.errorTail
                      : "systemd is auto-restarting the bar — see the journal"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9
                color: Config.ThemeConfig.colors.textDim
                elide: Text.ElideMiddle
            }

            Text {
                text: "journalctl --user -u quickshell-bar"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9
                color: Config.ThemeConfig.colors.text
                opacity: 0.8
            }
        }
    }
}
