// =============================================================================
// ActivePaletteCard.qml — Dashboard identity card: "SPECTRAL TOKENS"
// =============================================================================
// HudCard aesthetic. Header + divider, then four key/value TokenRows
// (PRIMARY / ACCENT / WARNING / TEXT) — the same row pattern as
// DisplayInfoCard's SpecRow, so the two spec-sheet cards read as a pair.
// Each row shows a small colour chip + hex, read live from ThemeConfig
// (updates automatically on every theme apply).
//
// NOTE: an earlier version of this comment described a tall swatch-grid
// layout with a memory usage bar pinned to the bottom (from
// CoreEngineService.ramPct). That never made it into this file — worth
// deciding whether it's still wanted before it goes stale again.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

HudCard {
    id: root
    accent: Config.ThemeConfig.colors.primary

    // Reusable token row — label (left) + small colour chip + hex (right),
    // laid out like DisplayInfoCard's SpecRow so the two cards read as a pair.
    component TokenRow: RowLayout {
        property string label: ""
        property string hex: "#000000"
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: parent.label
            color: Config.ThemeConfig.colors.textDim
            font.family: Config.SettingsConfig.fontFamily
            font.pixelSize: 10
            Layout.alignment: Qt.AlignVCenter
        }
        Item { Layout.fillWidth: true }
        Rectangle {
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            Layout.alignment: Qt.AlignVCenter
            color: parent.hex
            border.color: Config.ThemeConfig.colors.outlineVariant
            border.width: 1
        }
        Text {
            text: ("" + parent.hex).toUpperCase()
            color: Config.ThemeConfig.colors.text
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10; font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

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

        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        TokenRow { label: "PRIMARY"; hex: Config.ThemeConfig.colors.primary }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }
        TokenRow { label: "ACCENT";  hex: Config.ThemeConfig.colors.secondary }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }
        TokenRow { label: "WARNING"; hex: Config.ThemeConfig.colors.warning }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }
        TokenRow { label: "TEXT";    hex: Config.ThemeConfig.colors.text }

        Item { Layout.fillHeight: true }   // pin the token rows to the top of the card
    }
}
