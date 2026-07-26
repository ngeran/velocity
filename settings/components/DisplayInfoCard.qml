// =============================================================================
// DisplayInfoCard.qml — Dashboard identity card: "DISPLAY MATRIX" spec sheet
// =============================================================================
// HudCard aesthetic. V8.00 mockup restyle: an icon + header followed by four
// divided key/value rows (Resolution / Refresh Rate / Diagonal / Scaling) — the
// same data the prior hero+sub-tile layout exposed, in the mockup's row format.
//
// SOURCE: `hyprctl monitors` (text) — the authoritative source on Hyprland
// (native res, real refresh, physical mm, scale). Parsed line-by-line (jq is
// NOT assumed). The focused monitor's fields are all parsed before its
// `focused: yes` line, so we commit there.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config

HudCard {
    id: root
    accent: Config.ThemeConfig.colors.secondary

    // Focused monitor, parsed from `hyprctl monitors`.
    property var mon: ({ name: "", w: 0, h: 0, hz: 0, mmW: 0, mmH: 0, make: "", model: "", scale: 1.0, focused: false })
    property var _cur: null

    readonly property real diagIn: {
        if (mon.mmW <= 0 || mon.mmH <= 0) return 0
        return Math.sqrt(mon.mmW * mon.mmW + mon.mmH * mon.mmH) / 25.4
    }

    function _blank() {
        return { name: "", w: 0, h: 0, hz: 0, mmW: 0, mmH: 0, make: "", model: "", scale: 1.0, focused: false }
    }

    Process {
        id: monProc
        command: ["hyprctl", "monitors"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var s = ("" + line).trim()                       // strip leading tab
                if (s.indexOf("Monitor ") === 0) {
                    if (root._cur && root._cur.focused) { root.mon = root._cur; root._cur = null; }
                    else { root._cur = root._blank(); }
                    var n0 = s.indexOf("Monitor ") + 8
                    var n1 = s.indexOf(" (", n0)
                    if (n1 > n0) root._cur.name = s.substring(n0, n1)
                } else if (root._cur) {
                    if (s.length > 0 && s[0] >= "0" && s[0] <= "9" && s.indexOf("@") > -1) {
                        var at = s.indexOf("@")
                        var left = s.substring(0, at)
                        var right = s.substring(at + 1)
                        var xi = left.indexOf("x")
                        if (xi > -1) {
                            root._cur.w = parseInt(left.substring(0, xi), 10)
                            root._cur.h = parseInt(left.substring(xi + 1), 10)
                        }
                        var sp = right.indexOf(" ")
                        root._cur.hz = parseFloat(sp > -1 ? right.substring(0, sp) : right)
                    } else if (s.indexOf("physical size") === 0) {
                        var p = s.substring(s.indexOf(":") + 1).trim()
                        var px = p.indexOf("x")
                        if (px > -1) {
                            root._cur.mmW = parseInt(p.substring(0, px), 10)
                            root._cur.mmH = parseInt(p.substring(px + 1), 10)
                        }
                    } else if (s.indexOf("make:") === 0) {
                        root._cur.make = s.substring(5).trim()
                    } else if (s.indexOf("model:") === 0) {
                        root._cur.model = s.substring(6).trim()
                    } else if (s.indexOf("scale:") === 0) {
                        root._cur.scale = parseFloat(s.substring(6).trim())
                    } else if (s.indexOf("focused: yes") === 0) {
                        root._cur.focused = true
                        root.mon = root._cur          // commit (all fields already parsed)
                        root._cur = null
                    }
                }
            }
        }
    }

    // Reusable key/value row with a hairline divider underneath.
    component SpecRow: RowLayout {
        property string keyText: ""
        property string valueText: "—"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

        Text {
            text: parent.keyText
            color: Config.ThemeConfig.colors.textDim
            font.family: Config.SettingsConfig.fontFamily
            font.pixelSize: 11
            Layout.alignment: Qt.AlignVCenter
        }
        Item { Layout.fillWidth: true }
        Text {
            text: parent.valueText
            color: Config.ThemeConfig.colors.text
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 11; font.bold: true
            font.letterSpacing: 0.5
            Layout.alignment: Qt.AlignVCenter
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
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
            valueText: root.mon.hz > 0 ? (root.mon.hz.toFixed(2) + " HZ") : "—"
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

        // Footer — make / model
        Text {
            Layout.fillWidth: true
            text: {
                var m = (root.mon.make + " " + root.mon.model).trim()
                return m.length ? m.toUpperCase() : (root.mon.name ? root.mon.name.toUpperCase() : "PRIMARY")
            }
            color: Config.ThemeConfig.colors.textDim
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
            elide: Text.ElideRight
            font.letterSpacing: 1
        }
    }
}
