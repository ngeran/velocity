// =============================================================================
// ActivePaletteCard.qml — Dashboard identity card: "SPECTRAL TOKENS"
// =============================================================================
// HudCard aesthetic. V8.03: the swatch grid FILLS the cell height (tall swatches)
// with the memory bar pinned to the bottom — no internal void. Swatch tokens are
// read straight from ThemeConfig (recolours live on every apply); memory comes
// from CoreEngineService.ramPct.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

HudCard {
    id: root
    accent: Config.ThemeConfig.colors.primary

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        // Header — title + token id
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "SPECTRAL TOKENS"
                color: Config.ThemeConfig.colors.primary
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.0
            }
            Item { Layout.fillWidth: true }
            Text {
                text: (Config.ThemeConfig.colors.secondary + "").toUpperCase()
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
            }
        }

        // Four hero swatches — fill the cell height. Faint token tint fill +
        // solid bottom accent bar (the token at full strength).
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: [
                    Config.ThemeConfig.colors.primary,
                    Config.ThemeConfig.colors.secondary,
                    Config.ThemeConfig.colors.warning,
                    Config.ThemeConfig.colors.text
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Config.ThemeConfig.tint(modelData, 0.18)
                    border.color: Config.ThemeConfig.tint(modelData, 0.45)
                    border.width: 1
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 4
                        color: modelData
                    }
                }
            }
        }

        // System Memory Load — live bar from CoreEngineService.ramPct (bottom).
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "SYSTEM MEMORY LOAD"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: Math.round(Services.CoreEngineService.ramPct) + "%"
                    color: Config.ThemeConfig.colors.warning
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 8; font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                color: Config.ThemeConfig.colors.outlineVariant

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * (Math.max(0, Math.min(100, Services.CoreEngineService.ramPct)) / 100)
                    color: Config.ThemeConfig.colors.warning
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
