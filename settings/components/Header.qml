// =============================================================================
// settings/components/Header.qml
// Shared Header Bar — compact single-row strip, matches the mockup exactly
// (date block | Local/Athens/UTC triple clock | identity), NOT the tall hero
// ClockWidget/IdentityWidget cards. Spans every tab (Dashboard, Themes, etc.)
// — sits above contentArea in ModernDashboard.qml.
//
// VERSION: V2.10 — the clock group is now anchored to the header's horizontal
// CENTRE (which is the screen centre, since the dashboard card is itself
// centred on screen), instead of being spacer-centred between the DATE and
// IDENTITY blocks (whose widths differ, which pulled LOCAL off-screen-centre).
// DATE pins left, IDENTITY pins right, clocks pin centre → LOCAL sits dead-
// centre on screen, each time centred between its dividers.
//
// Identity here duplicates IdentityWidget's minimal load (name/role/online)
// rather than importing that widget directly, since IdentityWidget's own
// layout (avatar + host/shell/wm stat rows + status footer) is card-sized,
// not strip-sized.
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
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
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

    // ── layout ────────────────────────────────────────────────────────────
    // DATE pinned left · clocks pinned to horizontalCentre · identity pinned
    // right. Anchoring the clock group to the centre (rather than spacer-
    // centring it between the unequal DATE/identity blocks) puts LOCAL at the
    // screen's horizontal centre.

    // -- Date block (left) --
    RowLayout {
        id: dateBlock
        anchors.left: parent.left; anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
            width: 36; height: 36
            color: "transparent"
            border.color: Config.ThemeConfig.colors.outlineVariant
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: "󰃭"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: Config.ThemeConfig.colors.secondary
            }
        }
        ColumnLayout {
            spacing: 1
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
    }

    Rectangle {   // divider after date
        anchors.left: dateBlock.right; anchors.leftMargin: 20
        anchors.top: parent.top; anchors.topMargin: 10
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        width: 1; color: Config.ThemeConfig.colors.border
    }

    // -- Identity block (right) --
    RowLayout {
        id: identityBlock
        anchors.right: parent.right; anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

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
            spacing: 1
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

    Rectangle {   // divider before identity
        anchors.right: identityBlock.left; anchors.rightMargin: 20
        anchors.top: parent.top; anchors.topMargin: 10
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        width: 1; color: Config.ThemeConfig.colors.border
    }

    // -- Triple clock (ATHENS | LOCAL | UNIVERSAL) — distributed evenly across
    // the central region between the DATE and IDENTITY blocks. Three equal-
    // width columns with dividers between them, so the times + separators are
    // spaced evenly horizontally (each time centred in its column).
    RowLayout {
        anchors.left: dateBlock.right
        anchors.leftMargin: 40      // clear the DATE divider
        anchors.right: identityBlock.left
        anchors.rightMargin: 40     // clear the IDENTITY divider
        anchors.verticalCenter: parent.verticalCenter
        spacing: 24

        ColumnLayout {   // ATHENS (left third)
            spacing: 2
            Layout.fillWidth: true
            Text {
                text: "ATHENS (EET)"
                Layout.alignment: Qt.AlignHCenter
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 8; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
            }
            Text {
                text: headerRoot.athensTime
                Layout.alignment: Qt.AlignHCenter
                color: Config.ThemeConfig.colors.secondary
                font.pixelSize: 20; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
        }

        Rectangle { Layout.fillHeight: true; Layout.topMargin: 10; Layout.bottomMargin: 10; width: 1; color: Config.ThemeConfig.colors.border }

        ColumnLayout {   // LOCAL (centre third)
            spacing: 2
            Layout.fillWidth: true
            Text {
                text: "LOCAL (LCT)"
                Layout.alignment: Qt.AlignHCenter
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 8; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
            }
            Text {
                text: headerRoot.localTime
                Layout.alignment: Qt.AlignHCenter
                color: Config.ThemeConfig.colors.text
                font.pixelSize: 24; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
        }

        Rectangle { Layout.fillHeight: true; Layout.topMargin: 10; Layout.bottomMargin: 10; width: 1; color: Config.ThemeConfig.colors.border }

        ColumnLayout {   // UNIVERSAL (right third)
            spacing: 2
            Layout.fillWidth: true
            Text {
                text: "UNIVERSAL (UTC)"
                Layout.alignment: Qt.AlignHCenter
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 8; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
            }
            Text {
                text: headerRoot.utcTime
                Layout.alignment: Qt.AlignHCenter
                color: Config.ThemeConfig.colors.text
                font.pixelSize: 20; font.bold: true
                font.family: Config.SettingsConfig.fontFamily
            }
        }
    }
}
