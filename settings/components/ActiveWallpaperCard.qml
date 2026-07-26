// =============================================================================
// ActiveWallpaperCard.qml — Dashboard identity card: "SYSTEM REFERENCE CAPTURE"
// =============================================================================
// HudCard aesthetic. V8.03: the capture image FILLS the cell height (no fixed
// small height → no internal void). A low-key reference capture of the live
// wallpaper (low opacity, brightens on hover). Reads the applied wallpaper from
// SharedState (wallpaperPath / wallpaperName), pushed by WallpaperService.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

HudCard {
    id: root
    accent: Config.ThemeConfig.colors.textDim
    showBrackets: true

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        // Header — title + wallpaper name
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "SYSTEM REFERENCE CAPTURE"
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.0
            }
            Item { Layout.fillWidth: true }
            Text {
                Layout.maximumWidth: 200
                text: (Config.SharedState.wallpaperName || "NONE").toUpperCase()
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 8; font.letterSpacing: 1
                elide: Text.ElideRight
            }
        }

        // Reference capture — fills the cell. Low opacity, brightens on hover.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Config.ThemeConfig.colors.surface
            border.color: Config.ThemeConfig.colors.outlineVariant
            border.width: 1
            clip: true

            Image {
                anchors.fill: parent
                source: Config.SharedState.wallpaperPath
                        ? "file://" + Config.SharedState.wallpaperPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 480
                sourceSize.height: 270
                opacity: capMa.containsMouse ? 0.55 : 0.25
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            // Fallback glyph when no wallpaper is set.
            Text {
                anchors.centerIn: parent
                visible: !Config.SharedState.wallpaperPath
                text: "◌"
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.SettingsConfig.fontFamily
                font.pixelSize: 28
                opacity: 0.4
            }

            MouseArea {
                id: capMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
