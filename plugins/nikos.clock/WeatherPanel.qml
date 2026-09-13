// =============================================================================
// WeatherPanel.qml — ATMOSPHERE popup body (Omarchy mockup port).
// =============================================================================
// Port of the removed nikos.weather plugin's popup; lives inside the clock
// plugin now and reads the EMBEDDED WeatherSource (injected as `wx`).
// Header: pin + LOCATION / region … LIVE ● · Hero: glyph tile · big temp ·
// condition • breeze · DAY RANGE H/L + UV · boxed FEELS/WIND/HUMID strip ·
// Barometer + Dew Point chips · EXTENDED OUTLOOK with rain%.
// =============================================================================
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: bodyRoot

    property var hostBar: null
    property var hostTheme: null
    property var wx: null             // the WeatherSource instance

    Layout.fillWidth: true
    spacing: 12

    // Shared token shorthands (hostTheme may be null until api lands).
    function _c(tok)      { return hostTheme ? hostTheme.colors[tok] : "#888" }
    function _a(tok, a)   { return hostTheme ? hostTheme.withAlpha(hostTheme.colors[tok], a) : "#222" }
    function _mono()      { return hostBar ? hostBar.fontFamily : "monospace" }
    function _nerd()      { return hostBar ? hostBar.fontNerd : "monospace" }

    component Hairline: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: _a("text", 0.08)
    }

    readonly property var today: wx && wx.days.length > 0 ? wx.days[0] : null

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
            text: (wx && wx.location ? wx.location : "—").toUpperCase()
            font.family: _mono(); font.pixelSize: 11; font.bold: true
            font.letterSpacing: 1
            color: _c("text")
        }
        Text {
            visible: wx && wx.region !== ""
            text: "/ " + (wx ? wx.region : "")
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
            opacity: wx && wx.fetching ? 0.25 : 1
            SequentialAnimation on opacity {
                running: wx ? wx.fetching : false
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

        Rectangle {
            width: 58; height: 58; radius: 10
            color: _a("text", 0.05)
            border.width: 1
            border.color: _a("text", 0.08)
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: wx ? wx.glyph : "󰖐"
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
                    text: wx ? (wx.temp.split("°")[0] || "—") : "—"
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
                    if (!wx) return "—"
                    var c = wx.condition || "—"
                    var d = wx.windDesc
                    return d !== "" ? c + " • " + d : c
                }
                font.family: _mono(); font.pixelSize: 10
                color: _c("textDim")
            }
        }

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
                text: wx && wx.uv !== "" ? "UV: " + wx.uv : "UV: —"
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
                    { label: "FEELS", value: wx ? wx.feels : "" },
                    { label: "WIND",  value: wx ? wx.wind : "" },
                    { label: "HUMID", value: wx ? wx.humidity : "" }
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
                { label: "BAROMETER", value: wx ? wx.pressure : "" },
                { label: "DEW POINT", value: wx ? wx.dewPoint : "" }
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
            model: wx ? wx.days : []

            ColumnLayout {
                required property var modelData
                // Equal thirds across the body width (nested-ColumnLayout
                // delegates refuse fillWidth — preferredWidth spreads).
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
