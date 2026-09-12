// =============================================================================
// nikos.weather — panel body (Omarchy "ATMOSPHERE" mockup port)
// =============================================================================
// Header:  pin + LOCATION / region … LIVE ● (dot blinks while fetching)
// Hero:    glyph tile · big temp + °C · "condition • breeze" — right column
//          DAY RANGE H/L + UV.
// Strip:   boxed FEELS / WIND / HUMID metrics with vertical hairlines.
// Chips:   Barometer + Dew Point rounded info chips.
// Outlook: EXTENDED OUTLOOK — full day names, glyph, H/L, rain% (primary
//          colour when wet). Tokens injected (hostBar / hostTheme).
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "." as WX

ColumnLayout {
    id: bodyRoot

    property var hostBar: null
    property var hostTheme: null

    Layout.fillWidth: true
    spacing: 12

    // Shared token shorthands (hostTheme may be null until api lands).
    function _c(tok)      { return hostTheme ? hostTheme.colors[tok] : "#888" }
    function _a(tok, a)   { return hostTheme ? hostTheme.withAlpha(hostTheme.colors[tok], a) : "#222" }
    function _mono()      { return hostBar ? hostBar.fontFamily : "monospace" }
    function _nerd()      { return hostBar ? hostBar.fontNerd : "monospace" }

    // Section divider — hairline rhythm between the mockup's blocks.
    component Hairline: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: _a("text", 0.08)
    }

    readonly property var today: WX.WeatherService.days.length > 0 ? WX.WeatherService.days[0] : null

    // ── HEADER — pin · LOCATION / region … LIVE ● ────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: "󰌥"
            font.family: _nerd(); font.pixelSize: 11
            color: _c("primary")
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            text: (WX.WeatherService.location || "—").toUpperCase()
            font.family: _mono(); font.pixelSize: 11; font.bold: true
            font.letterSpacing: 1
            color: _c("text")
        }
        Text {
            visible: WX.WeatherService.region !== ""
            text: "/ " + WX.WeatherService.region
            font.family: _mono(); font.pixelSize: 11
            color: _c("textDim")
            elide: Text.ElideRight
            Layout.maximumWidth: 120
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "LIVE"
            font.family: _mono(); font.pixelSize: 9; font.bold: true
            font.letterSpacing: 2
            color: _c("textDim")
            Layout.alignment: Qt.AlignVCenter
        }
        Rectangle {
            width: 6; height: 6; radius: 3
            color: _c("primary")
            Layout.alignment: Qt.AlignVCenter
            opacity: WX.WeatherService.fetching ? 0.25 : 1
            SequentialAnimation on opacity {
                running: WX.WeatherService.fetching
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 500 }
                NumberAnimation { to: 0.25; duration: 500 }
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    // ── HERO — glyph tile · big temp · condition · DAY RANGE / UV ────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        // Glyph tile — rounded square chip
        Rectangle {
            width: 58; height: 58; radius: 10
            color: _a("text", 0.05)
            border.width: 1
            border.color: _a("text", 0.08)
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: WX.WeatherService.glyph
                font.family: _nerd(); font.pixelSize: 26
                color: hostTheme ? hostTheme.colors.warning : "#e0af68"
            }
        }

        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true

            Row {
                spacing: 4
                Text {
                    id: tempTxt
                    text: WX.WeatherService.temp.split("°")[0] || "—"
                    font.family: _mono(); font.pixelSize: 38; font.bold: true
                    color: _c("text")
                }
                Text {
                    text: "°C"
                    font.family: _mono(); font.pixelSize: 14
                    color: _c("textDim")
                    anchors.baseline: tempTxt.baseline
                }
            }

            Text {
                text: {
                    var c = WX.WeatherService.condition || "—"
                    var d = WX.WeatherService.windDesc
                    return d !== "" ? c + " • " + d : c
                }
                font.family: _mono(); font.pixelSize: 10
                color: _c("textDim")
            }
        }

        // Right column — DAY RANGE / H·L / UV
        ColumnLayout {
            spacing: 3
            Layout.alignment: Qt.AlignTop

            Text {
                text: "DAY RANGE"
                font.family: _mono(); font.pixelSize: 8; font.bold: true
                font.letterSpacing: 1.5
                color: _c("textDim")
                Layout.alignment: Qt.AlignRight
            }
            Text {
                text: bodyRoot.today
                      ? "H: " + bodyRoot.today.max + "° / L: " + bodyRoot.today.min + "°"
                      : "H: — / L: —"
                font.family: _mono(); font.pixelSize: 12; font.bold: true
                color: _c("text")
                Layout.alignment: Qt.AlignRight
            }
            Text {
                text: WX.WeatherService.uv !== "" ? "UV: " + WX.WeatherService.uv : "UV: —"
                font.family: _mono(); font.pixelSize: 9
                color: _c("textDim")
                Layout.alignment: Qt.AlignRight
            }
        }
    }

    // ── METRICS STRIP — boxed FEELS / WIND / HUMID with vertical dividers ────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 54
        radius: 8
        color: _a("text", 0.03)
        border.width: 1
        border.color: _a("text", 0.05)

        Row {
            anchors.fill: parent

            Repeater {
                model: [
                    { label: "FEELS", value: WX.WeatherService.feels },
                    { label: "WIND",  value: WX.WeatherService.wind },
                    { label: "HUMID", value: WX.WeatherService.humidity }
                ]

                Item {
                    width: parent.width / 3
                    height: parent.height

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: modelData.label
                            font.family: _mono(); font.pixelSize: 8; font.bold: true
                            font.letterSpacing: 2
                            color: _c("textDim")
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: modelData.value || "—"
                            font.family: _mono(); font.pixelSize: 12; font.bold: true
                            color: _c("text")
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // Vertical divider on the left edge of columns 2 and 3.
                    Rectangle {
                        visible: index > 0
                        width: 1; height: parent.height * 0.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: _a("text", 0.08)
                    }
                }
            }
        }
    }

    // ── INFO CHIPS — Barometer · Dew Point ────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: [
                { label: "BAROMETER", value: WX.WeatherService.pressure },
                { label: "DEW POINT", value: WX.WeatherService.dewPoint }
            ]

            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 6
                color: _a("text", 0.03)
                border.width: 1
                border.color: _a("text", 0.06)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    font.family: _mono(); font.pixelSize: 9
                    font.letterSpacing: 1
                    color: _c("textDim")
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.value !== "" ? modelData.value : "—"
                    font.family: _mono(); font.pixelSize: 10; font.bold: true
                    color: _c("text")
                }
            }
        }
    }

    // ── EXTENDED OUTLOOK ──────────────────────────────────────────────────────
    Text {
        text: "EXTENDED OUTLOOK"
        font.family: _mono(); font.pixelSize: 8; font.bold: true
        font.letterSpacing: 2
        color: _c("textDim")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: WX.WeatherService.days

            ColumnLayout {
                required property var modelData
                // Equal thirds across the body width. (Layout.fillWidth on a
                // nested ColumnLayout delegate left the columns packed at
                // their implicit width — preferredWidth spreads for sure.)
                Layout.preferredWidth: (bodyRoot.width - 2 * 8) / 3
                spacing: 4

                readonly property bool wet: modelData.rain >= 40

                Text {
                    text: modelData.label.toUpperCase()
                    font.family: _mono(); font.pixelSize: 9; font.bold: true
                    font.letterSpacing: 1.5
                    color: _c("text")
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: modelData.glyph || "󰖐"
                    font.family: _nerd(); font.pixelSize: 16
                    color: parent.wet ? _c("primary") : _c("textDim")
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: modelData.max + "° " + modelData.min + "°"
                    font.family: _mono(); font.pixelSize: 11; font.bold: true
                    color: _c("text")
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: modelData.rain + "% rain"
                    font.family: _mono(); font.pixelSize: 8
                    color: parent.wet ? _c("primary") : _c("textDim")
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    Hairline { }
}
