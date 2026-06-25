// =============================================================================
// ThemeQuickSwitch.qml — Theme quick-switch card for dashboard
// =============================================================================
//
// Shows current theme name + SWITCH button that cycles through curated themes.
// Part of the dashboard bento grid.
//
// =============================================================================


import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

DashboardCard {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Section label
        Text {
            text:               "THEME"
            font.pixelSize:     7
            font.family:        Config.SettingsConfig.fontFamily
            font.letterSpacing: 2.0
            color:              Config.ThemeConfig.colors.textDim
            Layout.bottomMargin: 4
        }

        // Current theme name
        Text {
            text:               Config.ThemeConfig.metadata.name || "Unknown"
            font.pixelSize:     14
            font.bold:          true
            font.family:        Config.SettingsConfig.fontFamily
            color:              Config.ThemeConfig.colors.primary
            Layout.fillWidth:   true
            elide:              Text.ElideRight
        }

        Item { Layout.fillHeight: true }

        // SWITCH button
        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: 32
            color:              switchHover.containsMouse
                                  ? Config.ThemeConfig.colors.secondary
                                  : Config.ThemeConfig.colors.surface
            radius:             6
            border.width:       1
            border.color:       Config.ThemeConfig.colors.border

            Behavior on color {
                ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
            }

            Text {
                anchors.centerIn: parent
                text:             "SWITCH"
                font.pixelSize:   10
                font.bold:        true
                font.family:      Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.5
                color:            Config.ThemeConfig.colors.primary
            }

            MouseArea {
                id: switchHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cycleNextTheme()
            }
        }
    }

    // Cycle to next theme in curated list
    function cycleNextTheme() {
        var themes = Services.ThemeService.curatedThemes
        if (!themes || themes.length === 0) return

        var current = Config.ThemeConfig.metadata.name
        var nextIndex = 0

        // Find current theme index
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].name === current) {
                nextIndex = (i + 1) % themes.length
                break
            }
        }

        Services.ThemeService.applyPreset(themes[nextIndex])
    }
}
