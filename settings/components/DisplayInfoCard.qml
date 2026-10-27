// =============================================================================
// DisplayInfoCard.qml — Dashboard identity card: "DISPLAY MATRIX" spec sheet
// =============================================================================
// HudCard aesthetic. V8.00 mockup restyle: an icon + header followed by four
// divided key/value rows (Resolution / Refresh Rate / Diagonal / Scaling) — the
// same data the prior hero+sub-tile layout exposed, in the mockup's row format.
//
// SOURCE (H5): Services.MonitorService.primary — the focused monitor (fallback
// first). This card's private `hyprctl monitors` fork is gone; the service is
// the ONE monitors probe in this process.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Card { variant: "hud";
    id: root
    accent: Config.ThemeConfig.colors.secondary

    function _blank() {
        return { name: "", w: 0, h: 0, refreshHz: 0, physW: 0, physH: 0, make: "", model: "", scale: 1.0, focused: false }
    }

    // Focused monitor (fallback first), blank until the service's async probe lands.
    readonly property var mon: Services.MonitorService.primary || _blank()

    readonly property real diagIn: {
        if (mon.physW <= 0 || mon.physH <= 0) return 0
        return Math.sqrt(mon.physW * mon.physW + mon.physH * mon.physH) / 25.4
    }

    // Reusable key/value row with a hairline divider underneath. The value
    // fills the row and right-aligns + elides from the left, so a narrow grid
    // cell never overflows the card (keeps the resolution height visible).
    component SpecRow: RowLayout {
        property string keyText: ""
        property string valueText: "—"
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: parent.keyText
            color: Config.ThemeConfig.colors.textDim
            font.family: Config.SettingsConfig.fontFamily
            font.pixelSize: 10
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: parent.valueText
            color: Config.ThemeConfig.colors.text
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10; font.bold: true
            font.letterSpacing: 0.5
            elide: Text.ElideLeft
            Layout.alignment: Qt.AlignVCenter
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        // Header — icon + DISPLAY MATRIX
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "󰃜"   // display glyph (verified in ControlConfig.sections)
                color: Config.ThemeConfig.colors.secondary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
            }
            Text {
                text: "DISPLAY MATRIX"
                color: Config.ThemeConfig.colors.secondary
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.0
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.mon.name ? root.mon.name.toUpperCase() : "—"
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 8; font.letterSpacing: 1
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        SpecRow {
            keyText: "RESOLUTION"
            valueText: (root.mon.w && root.mon.h)
                       ? (root.mon.w + " × " + root.mon.h) : "—"
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        SpecRow {
            keyText: "REFRESH RATE"
            valueText: root.mon.refreshHz > 0 ? (root.mon.refreshHz.toFixed(2) + " HZ") : "—"
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        SpecRow {
            keyText: "DIAGONAL"
            valueText: root.diagIn > 0 ? (root.diagIn.toFixed(1) + "″") : "—"
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        SpecRow {
            keyText: "SCALING"
            valueText: root.mon.scale ? (root.mon.scale.toFixed(2) + "×") : "—"
        }

        Item { Layout.fillHeight: true }   // rows packed at the top; footer pinned to the bottom

        // Footer — monitor make/model: a bordered chip, centred, a touch larger.
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 26
            Layout.maximumWidth: parent.width
            Layout.preferredWidth: monitorLabel.implicitWidth + 24
            color: "transparent"
            border.color: Config.ThemeConfig.colors.outlineVariant
            border.width: 1

            Text {
                id: monitorLabel
                anchors.centerIn: parent
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: {
                    var m = (root.mon.make + " " + root.mon.model).trim()
                    return m.length ? m.toUpperCase() : (root.mon.name ? root.mon.name.toUpperCase() : "PRIMARY")
                }
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10; font.bold: true
                font.letterSpacing: 1
            }
        }
    }
}
