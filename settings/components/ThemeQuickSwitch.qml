// =============================================================================
// ThemeQuickSwitch.qml — Theme cycler for the dashboard bento grid
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services
import "." as Components

Item {
    id: root

    // curatedThemes is a list of preset NAME strings (see ThemeService).
    function cycleTheme(dir) {
        var themes = Services.ThemeService.curatedThemes
        if (!themes || themes.length === 0) return
        var current = Config.ThemeConfig.metadata.name
        var idx = 0
        for (var i = 0; i < themes.length; i++) {
            if (themes[i] === current) { idx = i; break }
        }
        var next = (idx + dir + themes.length) % themes.length
        Services.ThemeService.applyPreset(themes[next])
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Components.WidgetHeader {
            icon: "󰉗"
            label: "THEME"
            Layout.bottomMargin: 12
        }

        // Active theme name (primary value)
        Text {
            text: Config.ThemeConfig.metadata.name || "DEFAULT"
            color: Config.ThemeConfig.colors.primary
            font.pixelSize: 14
            font.bold: true
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 0.5
            Layout.fillWidth: true
            elide: Text.ElideRight
            Layout.bottomMargin: 2
        }

        // Source subtitle
        Text {
            text: (Config.ThemeConfig.metadata.source || "preset").toUpperCase()
            color: Config.ThemeConfig.colors.secondary
            font.pixelSize: 8
            font.bold: true
            font.family: Config.SettingsConfig.fontFamily
            font.letterSpacing: 2.0
            Layout.bottomMargin: 12
        }

        // Accent swatch strip
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Layout.bottomMargin: 12

            Repeater {
                model: [
                    Config.ThemeConfig.colors.secondary,
                    Config.ThemeConfig.colors.primary,
                    Config.ThemeConfig.colors.accent,
                    Config.ThemeConfig.colors.success,
                    Config.ThemeConfig.colors.warning,
                    Config.ThemeConfig.colors.error
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    color: modelData
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Prev / Next
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true; height: 28
                color: prevArea.containsMouse ? Config.ThemeConfig.colors.surfaceVariant : Config.ThemeConfig.colors.surface
                border.width: 1
                border.color: prevArea.containsMouse ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "←"
                    color: prevArea.containsMouse ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
                    font.pixelSize: 14; font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea { id: prevArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cycleTheme(-1) }
            }

            Rectangle {
                Layout.fillWidth: true; height: 28
                color: nextArea.containsMouse ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surface
                border.width: 1
                border.color: nextArea.containsMouse ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "→"
                    color: nextArea.containsMouse ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.textDim
                    font.pixelSize: 14; font.bold: true
                    font.family: Config.SettingsConfig.fontFamily
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cycleTheme(1) }
            }
        }
    }
}
