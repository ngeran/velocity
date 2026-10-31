// =============================================================================
// settings/components/Header.qml
// Shared Header Bar — compact single-row strip (logs launcher | identity).
// Spans every tab (Dashboard, Themes, etc.) — sits above contentArea in
// SettingsWindowShell.qml.
//
// DEDUPED: the DATE block and the Athens/Local/UTC clock trio were removed —
// the bar's nikos.clock / nikos.timezones plugins own date and time (since H4
// the dashboard carries no calendar either — the left square is the System
// Pulse card); the header repeating them was pure duplication (user call,
// 2026-10-21). What remains is functional: the LOGS launcher (deep-links the
// in-app LOGS tab) and the identity chip.
//
// SIZING: intrinsically ~44px tall. SettingsWindowShell.qml sets height: 44 —
// LOGS + identity sit as one compact cluster on the right; the strip stays
// quiet and every tab's content keeps the reclaimed vertical room.
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

    // Transparent — the shell's background card (same color) shows beneath,
    // and the window's rounded top corners stay visible (this strip spans the
    // full width; painting it opaque would square the top-right corner off).
    color: "transparent"
    radius: 0

    // The LOGS launcher deep-links INTO this app (LogsTab, tab index 5) —
    // SettingsWindowShell handles it. It no longer toggles the bar process's
    // overlay cross-process (that overlay remains for SUPER+T / the bar icon).
    signal logsActivated()

    // Bottom border separates header from content area.
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Config.ThemeConfig.colors.border
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

    // Hairline vertical divider between the cluster halves.
    component Divider: Rectangle {
        Layout.fillHeight: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignVCenter
        // NOTE: colors.border reads as near-invisible against a pure-black OLED
        // background — using textDim at low opacity instead so the separator
        // is actually visible, while staying subtle (not a filled bar).
        color: Config.ThemeConfig.colors.textDim
        opacity: 0.35
    }

    // ── layout ────────────────────────────────────────────────────────────
    // Power actions on the LEFT (the half the strip used to keep empty) and
    // the compact cluster on the right: LOGS launcher | identity chip. The
    // informational dedupe rule still holds — the tab content owns the data;
    // the left half now carries the power actions instead of nothing.

    PowerStrip {
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.verticalCenter: parent.verticalCenter
    }

    RowLayout {
        id: identityGroup
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // System Logs launcher — deep-links to the in-app LOGS tab
        // (SettingsWindowShell.onLogsActivated → openLogsTab).
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
                onClicked: headerRoot.logsActivated()
            }
        }

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
