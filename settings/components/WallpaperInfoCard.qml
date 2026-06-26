// =============================================================================
// WallpaperInfoCard.qml — Active Wallpaper Info Card
// =============================================================================
//
// OLED-minimal card showing active wallpaper information.
// - Wallpaper filename
// - Thumbnail preview
// - Auto-cycle status
// - Next countdown
//
// =============================================================================

import QtQuick
import Quickshell.Io
import "../config" as Config
import "../config" as SharedConfig

Rectangle {
    id: root

    // Read from shared state
    readonly property string wallpaperPath: SharedConfig.SharedState.wallpaperPath
    readonly property string wallpaperName: SharedConfig.SharedState.wallpaperName
    readonly property bool cyclingEnabled: SharedConfig.SharedState.wallpaperCyclingEnabled
    readonly property int cycleInterval: SharedConfig.SharedState.wallpaperCycleInterval
    readonly property int countdown: SharedConfig.SharedState.wallpaperCountdown
    readonly property string transitionType: SharedConfig.SharedState.wallpaperTransitionType
    readonly property int wallpaperCount: SharedConfig.SharedState.wallpaperCount

    color: Config.ThemeConfig.colors.background
    border.color: Config.ThemeConfig.colors.border
    border.width: 1
    radius: 0

    // Countdown timer (shared state manages this)
    Timer {
        interval: 1000
        running: cyclingEnabled
        repeat: true
        onTriggered: {
            // Shared state handles countdown
        }
    }

    function formatTime(seconds) {
        var m = Math.floor(seconds / 60)
        var s = seconds % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Column {
        anchors {
            fill: parent
            margins: 12
        }
        spacing: 8

        // Section label
        Text {
            text: "WALLPAPER"
            font.pixelSize: 7
            font.letterSpacing: 2.0
            color: Config.ThemeConfig.colors.textDim
        }

        // Thumbnail preview
        Rectangle {
            width: parent.width - 24
            height: 60
            color: Config.ThemeConfig.colors.surface
            border.color: Config.ThemeConfig.colors.border
            border.width: 1

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: wallpaperPath.length > 0 ? "file://" + wallpaperPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true

                Rectangle {
                    anchors.fill: parent
                    visible: parent.status === Image.Loading || parent.status === Image.Error || wallpaperPath.length === 0
                    color: Config.ThemeConfig.colors.surface

                    Text {
                        anchors.centerIn: parent
                        text: wallpaperPath.length === 0 ? "—" : "…"
                        font.pixelSize: 10
                        color: Config.ThemeConfig.colors.textDim
                    }
                }
            }
        }

        // Filename (truncated)
        Text {
            width: parent.width - 24
            text: basename(wallpaperPath)
            font.pixelSize: 8
            font.letterSpacing: 0.5
            color: Config.ThemeConfig.colors.text
            elide: Text.ElideMiddle
        }

        Item { height: 4 }

        // Status row
        Row {
            spacing: 8

            Text {
                text: cyclingEnabled ? "AUTO" : "MANUAL"
                font.pixelSize: 7
                font.letterSpacing: 1.5
                color: cyclingEnabled ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
            }

            Text {
                visible: cyclingEnabled
                text: "NEXT " + formatTime(countdown)
                font.pixelSize: 7
                font.letterSpacing: 1.5
                color: Config.ThemeConfig.colors.secondary
            }

            Text {
                text: "󰉩 " + wallpaperCount
                font.pixelSize: 7
                font.letterSpacing: 1.5
                color: Config.ThemeConfig.colors.textDim
            }
        }
    }
}
