// =============================================================================
// ActiveThemeCard.qml — Dashboard identity card: "CURRENT ENVIRONMENT" switcher
// =============================================================================
// HudCard aesthetic. V8.03: laid out VERTICALLY so it fills a tall grid cell —
// eyebrow label at the top, the environment identity (icon + name + source)
// centred, and a full-width CHANGE button pinned to the bottom. Emits
// changeRequested() so the parent can deep-link to the Themes tab. Reads live
// theme metadata from ThemeConfig (reactive on every apply).
//
// PUBLIC API:
//   signal changeRequested()  — the CHANGE button was clicked
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

HudCard {
    id: root
    accent: Config.ThemeConfig.colors.warning

    signal changeRequested()

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        // Eyebrow (top) — "ACTIVE THEME" / letterSpacing 2.0 to match the
        // codename style used on DisplayInfoCard / ActivePaletteCard, so the
        // four dashboard cards read as one family instead of two dialects.
        Text {
            text: "ACTIVE THEME"
            color: Config.ThemeConfig.colors.warning
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.0
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        Item { Layout.fillHeight: true }   // centre the identity vertically

        // Identity — icon tile + name + source
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.warning, 0.10)
                border.color: Config.ThemeConfig.colors.outlineVariant
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "◑"   // environment glyph (verified in SidebarNav)
                    color: Config.ThemeConfig.colors.warning
                    font.family: Config.SettingsConfig.fontFamily
                    font.pixelSize: 22
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: Config.ThemeConfig.metadata.name || "—"
                    color: Config.ThemeConfig.colors.text
                    font.family: Config.SettingsConfig.fontFamily
                    font.pixelSize: 16; font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: "SOURCE: " + (Config.ThemeConfig.metadata.source || "—").toUpperCase()
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 8
                    elide: Text.ElideRight
                    font.letterSpacing: 1
                }
            }
        }

        Item { Layout.fillHeight: true }   // pin the button to the bottom

        // CHANGE button (bottom, full width). Stays transparent at all times —
        // no filled hover state, per the burn-in policy. Hover reads through
        // the border brightening to the accent, the label warming to match,
        // and a hairline accent underline growing in from the center: the
        // same "outline gets louder" language every other control in this
        // system already uses, just applied consistently here too.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: "transparent"
            border.color: changeMa.containsMouse
                          ? Config.ThemeConfig.colors.warning
                          : Config.ThemeConfig.colors.outlineVariant
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "CHANGE"
                color: changeMa.containsMouse
                       ? Config.ThemeConfig.colors.warning
                       : Config.ThemeConfig.colors.text
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                height: 2
                width: changeMa.containsMouse ? parent.width * 0.4 : 0
                color: Config.ThemeConfig.colors.warning
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            }

            MouseArea {
                id: changeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.changeRequested()
            }
        }
    }
}
