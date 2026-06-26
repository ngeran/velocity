// =============================================================================
// ThemeQuickSwitch.qml — Theme cycler for bento dashboard
// VERSION: V2.0 — Item root, full-bleed layout, prev/next controls
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root

    function cycleTheme(dir) {
        var themes = Services.ThemeService.curatedThemes
        if (!themes || themes.length === 0) return
        var current = Config.ThemeConfig.metadata.name
        var idx = 0
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].name === current) { idx = i; break }
        }
        var next = (idx + dir + themes.length) % themes.length
        Services.ThemeService.applyPreset(themes[next])
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── HEADER ────────────────────────────────────────────────────────────
        Text {
            text: "THEME"
            color: Config.ThemeConfig.colors.textDim
            font.pixelSize: 9
            font.bold: true
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 2.5
            Layout.bottomMargin: 10
        }

        // Thin rule
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Config.ThemeConfig.colors.outlineVariant
            Layout.bottomMargin: 14
        }

        // ── COLOR SWATCH ROW — accent preview ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Layout.bottomMargin: 14

            Repeater {
                model: [
                    Config.ThemeConfig.colors.primary,
                    Config.ThemeConfig.colors.secondary,
                    Config.ThemeConfig.colors.surface,
                    Config.ThemeConfig.colors.surfaceVariant,
                    Config.ThemeConfig.colors.outlineVariant
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    color: modelData
                    radius: 0
                }
            }
        }

        // ── ACTIVE THEME NAME ─────────────────────────────────────────────────
        Text {
            text: Config.ThemeConfig.metadata.name || "DEFAULT"
            color: Config.ThemeConfig.colors.primary
            font.pixelSize: 13
            font.bold: true
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 1.0
            Layout.fillWidth: true
            elide: Text.ElideRight
            Layout.bottomMargin: 4
        }

        Text {
            text: (Config.ThemeConfig.metadata.variant || "dark").toUpperCase()
            color: Config.ThemeConfig.colors.secondary
            font.pixelSize: 8
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 2.0
            opacity: 0.7
        }

        Item { Layout.fillHeight: true }

        // ── PREV / NEXT ROW ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // PREV
            Rectangle {
                Layout.fillWidth: true
                height: 30
                color: prevArea.containsMouse
                       ? Config.ThemeConfig.colors.surfaceVariant
                       : Config.ThemeConfig.colors.surface
                radius: 0
                border.width: 1
                border.color: prevArea.containsMouse ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border
                Behavior on color       { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "← PREV"
                    font.pixelSize: 9
                    font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                    font.letterSpacing: 1.5
                    color: prevArea.containsMouse ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cycleTheme(-1)
                }
            }

            // NEXT
            Rectangle {
                Layout.fillWidth: true
                height: 30
                color: nextArea.containsMouse ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surface
                radius: 0
                border.width: 1
                border.color: nextArea.containsMouse ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border
                Behavior on color       { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "NEXT →"
                    font.pixelSize: 9
                    font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                    font.letterSpacing: 1.5
                    color: nextArea.containsMouse ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.textDim
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cycleTheme(1)
                }
            }
        }
    }
}
