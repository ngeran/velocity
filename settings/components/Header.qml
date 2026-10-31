// =============================================================================
// settings/components/Header.qml — dashboard header strip (HUD chrome)
// =============================================================================
// Left: power actions (PowerStrip — semantics + confirm discipline unchanged).
// Center (labeled mode): contextual per-tab title pair + amber LIVE badge
// (live tabs = SYS INFO / CORE). Right: identity badge (square avatar chip,
// name + role from ~/.config/ngeran/identity/identity.txt).
//
// The old LOGS launcher square is gone — LOGS is a sidebar item now; the
// logsActivated() signal stays (shell connects it) so external callers don't
// break. Height: 48 (set by SettingsWindowShell).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config
import "../services" as Services

Rectangle {
    id: headerRoot
    clip: true   // safety net — nothing here should ever overflow the bar

    // Transparent — the shell's HUD card (pure black) shows beneath, and the
    // window's rounded top corners stay visible.
    color: "transparent"
    radius: 0

    signal logsActivated()

    // Contextual center title — the shell binds this to the active tab key.
    property string contextKey: ""
    // LIVE pulse shown for telemetry tabs (SYS INFO / CORE).
    property bool live: false

    readonly property bool compact: Config.UIScale.compact

    function contextLeft(key) {
        var m = { "dashboard": "SYSTEM",
                  "core": "SYSTEM / TELEMETRY",
                  "themes": "APPEARANCE",
                  "wallpapers": "APPEARANCE",
                  "control": "CONTROL",
                  "logs": "JOURNAL",
                  "settings": "SETTINGS" }
        return m[key] || ""
    }
    function contextRight(key) {
        var m = { "dashboard": "TELEMETRY",
                  "core": "DIGITAL INSTRUMENT CLUSTER",
                  "themes": "THEME ENGINE",
                  "wallpapers": "WALLPAPERS",
                  "control": "CONSOLE",
                  "logs": "SYSTEM LOGS",
                  "settings": "PREFERENCES" }
        return m[key] || ""
    }

    // Bottom border separates header from content area.
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: headerRoot.compact ? Config.ThemeConfig.colors.border
                                  : Config.HudConfig.borderHi
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
    PowerStrip {
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.verticalCenter: parent.verticalCenter
    }

    // ── center: contextual title pair + LIVE badge (labeled mode) ──────────
    RowLayout {
        anchors.centerIn: parent
        spacing: 12
        visible: !headerRoot.compact && headerRoot.contextKey !== ""

        Text {
            text: headerRoot.contextLeft(headerRoot.contextKey)
            color: Config.HudConfig.textMid
            font.family: Config.HudConfig.fontData
            font.pixelSize: 11
            font.letterSpacing: 1.6
        }
        Text {
            text: "|"
            color: Config.HudConfig.borderLo
            font.family: Config.HudConfig.fontData
            font.pixelSize: 11
        }
        Text {
            text: headerRoot.contextRight(headerRoot.contextKey).toUpperCase()
            color: Config.HudConfig.textFaint
            font.family: Config.HudConfig.fontData
            font.pixelSize: 9
            font.letterSpacing: 2.0
        }
        Rectangle {
            visible: headerRoot.live
            width: liveRow.implicitWidth + 16
            height: 18
            radius: 9
            color: Config.ThemeConfig.tint(Config.HudConfig.amber, 0.10)
            border.color: Config.ThemeConfig.tint(Config.HudConfig.amber, 0.30)
            border.width: 1
            RowLayout {
                id: liveRow
                anchors.centerIn: parent
                spacing: 6
                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: Config.HudConfig.amber
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.35; duration: 1000 }
                        NumberAnimation { from: 0.35; to: 1.0; duration: 1000 }
                    }
                }
                Text {
                    text: "LIVE"
                    color: Config.HudConfig.amber
                    font.family: Config.HudConfig.fontData
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 1.4
                }
            }
        }
    }

    // ── right: identity badge ─────────────────────────────────────────────
    RowLayout {
        id: identityGroup
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
            width: 30; height: 30
            radius: 4
            color: Config.ThemeConfig.tint(Config.HudConfig.amber, 0.12)
            border.color: Config.ThemeConfig.tint(Config.HudConfig.amber, 0.40)
            border.width: 1
            clip: true
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
                color: Config.HudConfig.amber
                font.pixelSize: 11; font.bold: true
                font.family: Config.HudConfig.fontData
            }
        }

        ColumnLayout {
            spacing: 2
            Text {
                text: headerRoot.userName.toUpperCase()
                color: Config.HudConfig.textHi
                font.pixelSize: 11; font.bold: true
                font.family: Config.HudConfig.fontData
            }
            Text {
                text: headerRoot.roleText.toUpperCase()
                color: Config.HudConfig.textFaint
                font.pixelSize: 7
                font.family: Config.HudConfig.fontData
                font.letterSpacing: 1.4
            }
        }
    }
}
