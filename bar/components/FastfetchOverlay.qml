// =============================================================================
// FastfetchOverlay.qml — system info, same QML overlay format as KeybindsOverlay
// =============================================================================
// Replaces ArchLogo's old `kitty --class fastfetch-float ... fastfetch` flow.
// Instead of launching a terminal window, it runs `fastfetch --logo none`,
// strips the ANSI color/cursor escapes, and renders fastfetch's own formatted
// output (sections, nerd-font icons, the ❯ separator, color swatches) inside a
// centered, themed PanelWindow card identical in shape to KeybindsOverlay.qml.
//
// Toggled by the ArchLogo bar icon (see shell.qml → onTriggered). Data refreshes
// on every open. Esc or outside-click closes.
// =============================================================================

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../config" as Config

PanelWindow {
    id: root

    property bool shown: false
    property string infoText: ""      // last fastfetch output (kept visible during refresh)
    visible: false
    function open()  { visible = true; shown = true; ffProc.running = true }
    function close() { shown = false; hideTimer.restart() }
    function toggle() { shown ? close() : open() }

    // strip ANSI CSI/OSC/escape sequences so fastfetch's box + icons render plain
    function stripAnsi(s) {
        return s.replace(/\x1b\[[0-9;?]*[a-zA-Z]/g, "")   // CSI: colors, cursor ([90m [14G …)
                .replace(/\x1b\][^\x1b]*(?:\x07|\x1b\\)/g, "")  // OSC sequences
                .replace(/\x1b[()=>N]/g, "")               // charset / keypad modes
                .replace(/\x1b./g, "")                      // any stray escape
                .replace(/\n{3,}/g, "\n\n")                 // collapse extra blanks
                .trim()
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    onShownChanged: if (!shown) hideTimer.restart()
    Timer { id: hideTimer; interval: 220; onTriggered: if (!root.shown) root.visible = false }

    // ---- dim backdrop (click-outside = close) ----
    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        opacity: root.shown ? 0.45 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ---- centered card ----
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 560
        height: 480
        color: Config.ThemeConfig.colors.background
        border.color: Config.ThemeConfig.colors.border
        border.width: 1
        clip: true
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: root.close()
        MouseArea { anchors.fill: parent }   // stop click-through to the backdrop

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "󰻠"
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: 16
                    color: Config.BarConfig.colorAccent
                }
                Text {
                    text: "SYSTEM INFO"
                    color: Config.ThemeConfig.colors.text
                    font.pixelSize: 16
                    font.bold: true
                    font.family: Config.BarConfig.fontFamily
                    font.letterSpacing: 2.5
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "ESC to close"
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: 10
                    font.family: Config.BarConfig.fontFamily
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.border }

            // ---- fastfetch output (monospace nerd font, scrollable) ----
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: ffText.implicitWidth
                contentHeight: ffText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.AutoFlickIfNeeded

                Text {
                    id: ffText
                    text: root.infoText
                    color: Config.ThemeConfig.colors.text
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: 13
                    // fastfetch lays out a fixed-width panel — preserve it, no wrap
                    wrapMode: Text.NoWrap
                    visible: root.infoText.length > 0
                }
            }
        }
    }

    // ---- run fastfetch on each open, capture stdout, strip ANSI ----
    Process {
        id: ffProc
        property string buffer: ""
        command: ["fastfetch", "--logo", "none"]
        // SplitParser hands each line WITHOUT its \n, so re-add it (BatteryService pattern)
        stdout: SplitParser { onRead: function(data) { ffProc.buffer += data + "\n" } }
        onRunningChanged: if (!running) {
            root.infoText = root.stripAnsi(ffProc.buffer)
            ffProc.buffer = ""
        }
    }
}
