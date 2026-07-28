// =============================================================================
// WeatherCard.qml — Dashboard widget: live weather (wttr.in, no API key)
// =============================================================================
// HudCard aesthetic. Fetches IP-geolocated weather from wttr.in via curl in a
// Quickshell Process (the project's sanctioned no-python/no-notify pattern —
// no secret/API key needed). One-line format "%l|%t|%f|%C|%h|%w|%p|%P&m" →
// location | temp | feels-like | condition | humidity | wind | precip |
// pressure, parsed by splitting on "|". Refreshes every 10 min.
//
// Graceful degradation: if curl fails / no network, the fields stay "—" (the
// guard only accepts a line whose temp field contains "°", so wttr.in error
// text is ignored). All colours are live ThemeConfig tokens.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config

HudCard {
    id: root
    accent: Config.ThemeConfig.colors.info

    property string _loc: "—"
    property string _temp: "—"
    property string _feels: ""
    property string _cond: "—"
    property string _humidity: ""
    property string _wind: ""
    property string _precip: ""
    property string _pressure: ""

    // Condition text → weather glyph. Kept to standard Unicode symbols
    // (not a Nerd Font PUA range) so it renders regardless of icon-font setup.
    function getWeatherIcon(cond) {
        var c = (cond || "").toLowerCase()
        if (c.indexOf("thunder") >= 0 || c.indexOf("storm") >= 0) return "⛈"
        if (c.indexOf("snow") >= 0 || c.indexOf("sleet") >= 0 || c.indexOf("ice") >= 0) return "❄"
        if (c.indexOf("rain") >= 0 || c.indexOf("drizzle") >= 0 || c.indexOf("shower") >= 0) return "🌧"
        if (c.indexOf("fog") >= 0 || c.indexOf("mist") >= 0 || c.indexOf("haze") >= 0) return "🌫"
        if (c.indexOf("overcast") >= 0 || c.indexOf("cloudy") >= 0) return "☁"
        if (c.indexOf("partly") >= 0) return "⛅"
        if (c.indexOf("clear") >= 0 || c.indexOf("sunny") >= 0) return "☀"
        if (c.indexOf("wind") >= 0) return "🌬"
        return "—"
    }

    Process {
        id: wxProc
        command: ["sh", "-c", "curl -s --max-time 8 'wttr.in/?format=%l|%t|%f|%C|%h|%w|%p|%P&m'"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var s = ("" + line).trim()
                var p = s.split("|")
                // Only accept a well-formed line (temp field has a degree sign).
                if (p.length >= 8 && p[1].indexOf("°") >= 0) {
                    root._loc      = p[0].trim()
                    root._temp     = p[1].trim().replace(/^\+/, "")   // drop leading "+"
                    root._feels    = p[2].trim().replace(/^\+/, "")
                    root._cond     = p[3].trim()
                    root._humidity = p[4].trim()
                    root._wind     = p[5].trim()
                    root._precip   = p[6].trim()
                    root._pressure = p[7].trim()
                }
            }
        }
    }

    // Refresh every 10 minutes.
    Timer {
        interval: 600000; running: true; repeat: true
        onTriggered: { wxProc.running = false; wxProc.running = true }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        // Header — eyebrow + location (elided)
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "WEATHER"
                color: Config.ThemeConfig.colors.info
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.0
            }
            Item { Layout.fillWidth: true }
            Text {
                Layout.maximumWidth: 200
                text: root._loc
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 8; font.letterSpacing: 1
                elide: Text.ElideRight
            }
        }

        // Thin separator under the header, spans full width
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.ThemeConfig.colors.info
            opacity: 0.15
        }

        // Body — fills all remaining space: left = icon/temp, right = condition + stat grid
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            spacing: 18

            // ---- Left block: glyph + temperature -----------------------------
            RowLayout {
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 14

                Item {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Config.ThemeConfig.colors.info
                        opacity: 0.35
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.getWeatherIcon(root._cond)
                        font.pixelSize: 30
                        color: Config.ThemeConfig.colors.info
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: root._temp
                        color: Config.ThemeConfig.colors.text
                        font.family: Config.SettingsConfig.fontFamily
                        font.pixelSize: 38; font.weight: Font.Light
                    }
                    Text {
                        text: root._feels.length > 0 ? "feels " + root._feels : ""
                        visible: root._feels.length > 0
                        color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 9
                    }
                }
            }

            // ---- Vertical divider --------------------------------------------
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: Config.ThemeConfig.colors.info
                opacity: 0.15
            }

            // ---- Right block: condition + stat grid --------------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: 10

                Text {
                    text: root._cond
                    color: Config.ThemeConfig.colors.info
                    font.family: Config.SettingsConfig.fontFamily
                    font.pixelSize: 15; font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 6

                    // Humidity
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        visible: root._humidity.length > 0
                        Text {
                            text: "RH"
                            color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                            Layout.preferredWidth: 30
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            text: root._humidity
                            color: Config.ThemeConfig.colors.text
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 10
                        }
                    }

                    // Wind
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        visible: root._wind.length > 0
                        Text {
                            text: "WIND"
                            color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                            Layout.preferredWidth: 30
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            text: root._wind
                            color: Config.ThemeConfig.colors.text
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 10
                        }
                    }

                    // Precipitation (wttr.in's %p already includes the "mm" suffix)
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        visible: root._precip.length > 0
                        Text {
                            text: "RAIN"
                            color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                            Layout.preferredWidth: 30
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            text: root._precip
                            color: Config.ThemeConfig.colors.text
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 10
                        }
                    }

                    // Pressure (wttr.in's %P already includes the "hPa" suffix)
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        visible: root._pressure.length > 0
                        Text {
                            text: "PRES"
                            color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                            Layout.preferredWidth: 30
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            text: root._pressure
                            color: Config.ThemeConfig.colors.text
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
}
