// =============================================================================
// ActiveWallpaperCard.qml — Dashboard identity card: the active wallpaper
// =============================================================================
// HudCard aesthetic. Shows the live applied wallpaper: a preview thumbnail, the
// wallpaper file name, and its path (location). Reads SharedState
// (wallpaperPath / wallpaperName / wallpaperCyclingEnabled) pushed by
// WallpaperService.applyWallpaper(), so it updates the moment a wallpaper is set
// from the Wallpaper tab or externally. The preview fills the available cell;
// sourceSize is capped so large wallpapers decode at preview res.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

HudCard {
    id: root
    accent: Config.ThemeConfig.colors.success

    // Mirrors ActiveThemeCard's changeRequested() — clicking the preview
    // deep-links to the Wallpaper tab. Before this, ActiveThemeCard was the
    // only "identity" card with any interaction; this card was a dead end.
    signal changeRequested()

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        // Header — title + cycling badge
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "ACTIVE WALLPAPER"
                color: Config.ThemeConfig.colors.success
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.0
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                visible: Config.SharedState.wallpaperCyclingEnabled
                border.color: Config.ThemeConfig.colors.success; border.width: 1
                height: 14; width: cycW.implicitWidth + 10
                Text {
                    id: cycW; anchors.centerIn: parent; text: "CYCLE"
                    color: Config.ThemeConfig.colors.success
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        // Preview — fills the remaining cell. Clickable, mirroring
        // ActiveThemeCard's CHANGE affordance: border brightens to the
        // accent on hover (no fill, same outline-gets-louder language) and
        // a small OPEN chip fades in bottom-right as the click target.
        // sourceSize now tracks the preview's actual rendered size instead
        // of a fixed 360x240, so it decodes crisp at whatever the grid
        // gives it on the QD-OLED rather than upscaling a soft decode.
        Rectangle {
            id: previewRect
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Config.ThemeConfig.colors.surface
            border.color: previewMa.containsMouse
                          ? Config.ThemeConfig.colors.success
                          : Config.ThemeConfig.colors.border
            border.width: 1
            clip: true
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Image {
                anchors.fill: parent
                source: Config.SharedState.wallpaperPath
                        ? "file://" + Config.SharedState.wallpaperPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Math.round(previewRect.width)
                sourceSize.height: Math.round(previewRect.height)
            }
            Text {
                anchors.centerIn: parent
                visible: !Config.SharedState.wallpaperPath
                text: "◌"
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.SettingsConfig.fontFamily
                font.pixelSize: 24
                opacity: 0.4
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 6
                height: 16; width: openLbl.implicitWidth + 12
                color: Config.ThemeConfig.colors.background
                border.color: Config.ThemeConfig.colors.success; border.width: 1
                opacity: previewMa.containsMouse ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Text {
                    id: openLbl; anchors.centerIn: parent; text: "OPEN"
                    color: Config.ThemeConfig.colors.success
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 7; font.bold: true
                }
            }

            MouseArea {
                id: previewMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.changeRequested()
            }
        }

        // Wallpaper file name
        Text {
            Layout.fillWidth: true
            text: Config.SharedState.wallpaperName || "NONE"
            color: Config.ThemeConfig.colors.text
            font.family: Config.SettingsConfig.fontFamily
            font.pixelSize: 12; font.bold: true
            elide: Text.ElideRight
        }

        // Path (location)
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "PATH"
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 7; font.bold: true; font.letterSpacing: 1
            }
            Text {
                text: Config.SharedState.wallpaperPath || "—"
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 7
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
        }
    }
}
