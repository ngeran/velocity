// =============================================================================
// settings/components/Header.qml
// Shared Header Bar — compact single-row strip (date | Athens/Local/UTC clocks
// | identity). Spans every tab (Dashboard, Themes, etc.) — sits above
// contentArea in ModernDashboard.qml.
//
// VERSION: V3.1 — fixes uneven divider/clock spacing from V3.0.
//   1) Stat columns now share a fixed Layout.preferredWidth, so ATHENS /
//      LOCAL / UTC no longer render at different intrinsic widths (LOCAL's
//      big:true value and UNIVERSAL's longer label used to skew things).
//   2) The clock trio is anchored directly to headerRoot's horizontal
//      center instead of being sandwiched between two Layout.fillWidth
//      spacers — true centering no longer depends on the Date block and
//      Identity block happening to be the same width (they never are).
//   Dividers now travel with their adjacent block (Date+divider on the
//   left, divider+Identity on the right) rather than floating in a
//   variable-width gap.
//
// SIZING: intrinsically ~72px tall. ModernDashboard.qml sets height: 72.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config
import "../services" as Services

Rectangle {
    id: headerRoot
    clip: true   // safety net — nothing here should ever overflow the bar,
                 // but if content grows, clip instead of bleeding onto tabs.

    color: Config.ThemeConfig.colors.background
    radius: 0

    // Bottom border separates header from content area.
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Config.ThemeConfig.colors.border
    }

    // ── live clock state ─────────────────────────────────────────────────────
    property var _now: new Date()

    Timer {
        interval: 1000; running: Config.SharedState.dashboardVisible; repeat: true; triggeredOnStart: true
        onTriggered: headerRoot._now = new Date()
    }

    readonly property string localTime: Qt.formatTime(headerRoot._now, "hh:mm:ss")

    // Athens = local + 7h (manual offset, matches ClockWidget's approach —
    // avoids relying on QML's JS engine timeZone support for toLocaleTimeString).
    readonly property string athensTime: {
        var a = new Date(headerRoot._now.getTime())
        a.setHours(a.getHours() + 7)
        return Qt.formatTime(a, "hh:mm:ss")
    }

    readonly property string utcTime: {
        var n = headerRoot._now
        function pad2(v) { return String(v).padStart(2, '0') }
        return pad2(n.getUTCHours()) + ":" + pad2(n.getUTCMinutes()) + ":" + pad2(n.getUTCSeconds())
    }

    readonly property string dateText: {
        var days = ["SUN","MON","TUE","WED","THU","FRI","SAT"]
        var months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
        var n = headerRoot._now
        return days[n.getDay()] + " " + n.getDate() + " " + months[n.getMonth()] + " " + n.getFullYear()
    }

    // ── identity state (minimal load — name/role/online only) ───────────────
    property string userName: "NIKOS"
    property string roleText: "NETWORK ENGINEER"
    property bool   online:   true
    property bool   hasAvatar: false
    readonly property string avatarSource: "file://" + Services.ThemeService.homeDir + "/.config/ngeran/identity/avatar.png"

    Component.onCompleted: identityLoader.running = true

    // System Logs overlay lives in the BAR process — toggle it via Quickshell
    // IPC (cross-process, WeatherWidget.qml precedent).
    Process {
        id: logsToggleProc
        command: ["quickshell", "ipc", "-c", "bar", "call", "logs", "toggle"]
    }

    Process {
        id: identityLoader
        command: ["sh", "-c", "cat ~/.config/ngeran/identity/identity.txt 2>/dev/null; test -f ~/.config/ngeran/identity/avatar.png && echo HAS_AVATAR"]
        stdout: SplitParser {
            onRead: function(line) {
                if (line === "HAS_AVATAR") { headerRoot.hasAvatar = true; return }
                var eq = line.indexOf("=")
                if (eq > 0) {
                    var k = line.substring(0, eq).trim()
                    var v = line.substring(eq + 1).trim()
                    if      (k === "name") headerRoot.userName = v
                    else if (k === "role") headerRoot.roleText = v
                }
            }
        }
    }

    // ── shared building blocks ───────────────────────────────────────────────

    // Hairline vertical divider — every separator in the header uses this,
    // so spacing/height/colour can never drift between blocks.
    component Divider: Rectangle {
        Layout.fillHeight: true
        Layout.topMargin: 18
        Layout.bottomMargin: 18
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignVCenter
        // NOTE: colors.border reads as near-invisible against a pure-black OLED
        // background — using textDim at low opacity instead so the separator
        // is actually visible, while staying subtle (not a filled bar).
        color: Config.ThemeConfig.colors.textDim
        opacity: 0.35
    }

    // Small caption-over-value pair used by the three clocks. `big` bumps the
    // value's size/weight for the LOCAL (primary) reading.
    //
    // FIX: all three Stat instances now get an identical fixed
    // Layout.preferredWidth (statColumnWidth, sized to fit the longest
    // label "UNIVERSAL (UTC)" plus the big LOCAL value comfortably), and
    // both Texts fill that width with horizontalAlignment: Text.AlignHCenter
    // instead of Layout.alignment on a variable-width ColumnLayout. That's
    // what actually keeps the dividers equidistant from the text — before,
    // each Stat sized itself to its own longest child, so ATHENS / LOCAL /
    // UTC were all different widths despite the RowLayout's spacing being
    // a constant 28px.
    component Stat: ColumnLayout {
        property string label: ""
        property string value: ""
        property bool accent: false
        property bool big: false
        spacing: 2
        Layout.preferredWidth: headerRoot.statColumnWidth
        Layout.fillWidth: false

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: parent.label
            color: Config.ThemeConfig.colors.textDim
            font.pixelSize: 8; font.bold: true
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 1.5
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: parent.value
            color: parent.accent ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.text
            font.pixelSize: parent.big ? 24 : 18
            font.bold: true
            font.family: Config.SettingsConfig.fontFamily
        }
    }

    // Shared width for every Stat column — sized to comfortably fit the
    // longest label ("UNIVERSAL (UTC)") and the big LOCAL value. Bump this
    // if fonts/labels change and text starts clipping.
    readonly property int statColumnWidth: 108

    // ── layout ────────────────────────────────────────────────────────────
    // Three independent groups instead of one long RowLayout:
    //   - dateGroup   anchored to headerRoot's left edge
    //   - clockTrio   anchored to headerRoot's true horizontal center
    //   - identityGroup anchored to headerRoot's right edge
    // This is what actually fixes centering: previously the clock trio's
    // position depended on two Layout.fillWidth spacers splitting the
    // *leftover* space evenly, which only centers the trio if the Date
    // block and Identity block happen to be equal width. They never are
    // (date text vs. name+role text differ), so the whole trio silently
    // drifted off-center. Anchoring straight to parent.horizontalCenter
    // removes that dependency entirely.

    // -- Date block (+ its own trailing divider) --
    RowLayout {
        id: dateGroup
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
            width: 34; height: 34
            color: "transparent"
            border.color: Config.ThemeConfig.colors.outlineVariant
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: "󰃭"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: Config.ThemeConfig.colors.secondary
            }
        }
        ColumnLayout {
            spacing: 2
            Text {
                text: "DATE"
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 8; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
            }
            Text {
                text: headerRoot.dateText
                color: Config.ThemeConfig.colors.text
                font.pixelSize: 13; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
        }

        Item { Layout.preferredWidth: 10 }  // breathing room before the divider
        Divider {}

        // System Logs launcher — toggles the BAR process's overlay cross-process
        // (same shape as bar/components/WeatherWidget.qml calling settings IPC).
        // clockTrio is anchored to the header's true horizontal center, so this
        // extra left-side width cannot shift the clocks.
        Rectangle {
            width: 34; height: 34
            color: "transparent"
            border.color: logsMouse.containsMouse ? Config.ThemeConfig.colors.secondary
                                                  : Config.ThemeConfig.colors.outlineVariant
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: "󰗋"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: Config.ThemeConfig.colors.secondary
            }
            MouseArea {
                id: logsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: logsToggleProc.running = true
            }
        }
    }

    // -- Clock trio (Athens | Local | Universal), evenly spaced --
    RowLayout {
        id: clockTrio
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 28
        Stat { label: "ATHENS (EET)";    value: headerRoot.athensTime }
        Divider {}
        Stat { label: "LOCAL (LCT)";     value: headerRoot.localTime; accent: true; big: true }
        Divider {}
        Stat { label: "UNIVERSAL (UTC)"; value: headerRoot.utcTime }
    }

    // -- Identity block (+ its own leading divider) --
    RowLayout {
        id: identityGroup
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Divider {}
        Item { Layout.preferredWidth: 10 }  // breathing room after the divider

        Item {
            width: 34; height: 34
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Config.ThemeConfig.colors.outlineVariant
                border.width: 1
                radius: 17   // the one deliberate circle — avatar convention
            }
            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: headerRoot.hasAvatar ? headerRoot.avatarSource : ""
                fillMode: Image.PreserveAspectCrop
                visible: headerRoot.hasAvatar
            }
            Text {
                anchors.centerIn: parent
                visible: !headerRoot.hasAvatar
                text: headerRoot.userName.substring(0, 2).toUpperCase()
                color: Config.ThemeConfig.colors.secondary
                font.pixelSize: 12; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
            Rectangle {
                width: 8; height: 8; radius: 4
                color: headerRoot.online ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.textDim
                border.color: Config.ThemeConfig.colors.background
                border.width: 2
                anchors.right: parent.right
                anchors.bottom: parent.bottom
            }
        }

        ColumnLayout {
            spacing: 2
            Text {
                text: headerRoot.userName.toUpperCase()
                color: Config.ThemeConfig.colors.text
                font.pixelSize: 12; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
            Text {
                text: headerRoot.roleText
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 8
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.2
            }
        }
    }
}
