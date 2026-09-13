// =============================================================================
// nikos.clock — CENTER-slot plugin (plugin api 1)
// =============================================================================
// Center anchor pill: date-time · live weather glyph · temperature.
//   • time click    → this plugin's CALENDAR popup (TEMPORAL MAP styling)
//   • weather click → force a refresh of the embedded WeatherSource fetcher
// Colours ride api tokens; active modules get an underline + primary border.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import "file:///home/nikos/.config/quickshell/bar/components" as Host

Item {
    id: root

    property string pluginId: ""
    property var api: null

    // Host IPC (plugins summon/hide) routes through these — same contract as
    // the weather plugin's root.
    function toggle() { calPanel.toggle() }
    function open()   { calPanel.open() }
    function close()  { calPanel.close() }

    width: anchorRow.implicitWidth + 24
    height: api ? api.bar.barHeight : 30

    // Minute-boundary exact (a 60s Timer drifts when created mid-minute).
    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }

    // Embedded weather fetcher — self-contained (no cross-plugin import).
    WeatherSource {
        id: wxSource
    }

    readonly property var _days:   ["SUN","MON","TUE","WED","THU","FRI","SAT"]
    readonly property var _fullDays: ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    readonly property var _months: ["JAN","FEB","MAR","APR","MAY","JUN",
                                    "JUL","AUG","SEP","OCT","NOV","DEC"]

    function _shifted(d) {
        var off = api ? api.bar.clockOffset : 0
        if (off !== 0) {
            var utc = d.getTime() + (d.getTimezoneOffset() * 60000)
            d = new Date(utc + (off * 3600000))
        }
        return d
    }

    function _formattedTime(d) {
        var s = root._shifted(d)
        return String(s.getHours()).padStart(2, "0") + ":" + String(s.getMinutes()).padStart(2, "0")
    }

    function _formattedDate(d) {
        var s = root._shifted(d)
        var out = root._fullDays[s.getDay()] + " " + root._formattedTime(d)
        var city = api ? (api.bar.clockCity || "").trim() : ""
        if (city.length > 0 && city.toLowerCase() !== "local")
            out += " · " + city.toUpperCase()
        return out
    }

    // Anchor pill — bordered cluster: "Saturday 15:41" · live weather glyph ·°C
    Rectangle {
        anchors.centerIn: parent
        implicitWidth: anchorRow.implicitWidth + 24
        height: api ? api.bar.barHeight - 6 : 20
        radius: 6
        color: anchorMa.containsMouse ? api.theme.withAlpha(api.theme.colors.text, 0.06)
                                      : "transparent"
        border.color: (calOpen || wxOpen) ? api.theme.colors.primary
                                          : api.theme.colors.outlineVariant
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Row {
            id: anchorRow
            anchors.centerIn: parent
            spacing: 10

            // Time text — click toggles the calendar popup
            Text {
                text: root._formattedDate(clk.date)
                font.family: api ? api.bar.fontFamily : "monospace"
                font.pixelSize: 12
                color: calOpen || timeMa.containsMouse ? api.theme.colors.accent
                                                       : (api ? api.theme.colors.text : "#ddd")
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 120 } }

                // Active-module underline while the calendar is open
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -2
                    width: parent.width; height: 2; radius: 1
                    color: api.theme.colors.accent
                    visible: calOpen
                }

                MouseArea {
                    id: timeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calPanel.toggle()
                }
            }

            // Live weather — condition glyph + temperature from the EMBEDDED
            // WeatherSource (self-contained; the nikos.weather plugin was
            // removed). Click forces a refresh. Temp hidden until the first
            // valid sample lands.
            Item {
                width: wxRow.implicitWidth
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: wxRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: wxSource.glyph
                        font.family: api ? api.bar.fontNerd : "monospace"
                        font.pixelSize: 13
                        color: wxMa.containsMouse ? "#7DCFFF"
                                                  : (api ? api.theme.colors.warning : "#888")
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        visible: wxSource.hasData
                        text: wxSource.temp
                        font.family: api ? api.bar.fontFamily : "monospace"
                        font.pixelSize: 11
                        color: wxMa.containsMouse ? api.theme.colors.accent
                                                  : (api ? api.theme.colors.text : "#ddd")
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    id: wxMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wxSource.refresh()
                }
            }
        }
    }

    onApiChanged: if (calPanel.item) calPanel.item.api = api

    // Panel-open state for the calendar underline
    readonly property bool calOpen: api ? api.host.openPanel === "nikos.clock" : false

    MouseArea {
        id: anchorMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // ── CALENDAR POPUP — centered under the anchor, TEMPORAL MAP styling ────
    Host.PluginPanel {
        id: calPanel
        pluginId: "nikos.clock"
        title: "CALENDAR"
        icon: "󰃭"
        contentWidth: 336
        anchorX: "center"
        showHeader: false

        Loader {
            // Defer until api lands — the body binds api tokens at creation.
            // NOTE: the LOADER is the layout child — a Layout.fillWidth set
            // inside the loaded file does nothing; stretch it here or the
            // body computes its grid from a stale intrinsic width.
            Layout.fillWidth: true
            active: root.api !== null
            source: Qt.resolvedUrl("CalendarPanel.qml")
            onLoaded: item.api = root.api
        }
    }
}
