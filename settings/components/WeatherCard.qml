// =============================================================================
// WeatherCard.qml — Dashboard widget: weather from the clock plugin's cache
// =============================================================================
// One weather source for the whole setup: the nikos.clock plugin's Open-Meteo
// pipeline (location = plugin lat/lon settings > cached coords > ipwho.is;
// refresh gated to its panel-open + 15 min, idle-zero at rest). This card is
// a READ-ONLY window onto that pipeline's cache
// ($XDG_STATE_HOME/velocity/plugins/nikos.clock-weather.json) — no fetcher,
// no second provider, no geolocator of its own (the old wttr.in dup is gone).
// Parsing is shared/weather.mjs (node-tested; the exact module the panel
// uses), so glyph/condition/metrics render identically on both surfaces.
//
// Reads: on show, every 10 min while visible, and twice after REFRESH ›
// (the plugin's curl lands within seconds; the second read catches a slow
// one at its 10s watchdog edge). REFRESH › nudges the plugin over the engine
// IPC (`plugins call nikos.clock refresh`) — no timers on the plugin side.
//
// Age honesty: the header shows AS OF HH:MM and dims past the plugin's
// 15-min gate. No cache yet → "open the clock panel to refresh". The old
// PRES row died with wttr.in (the plugin's Open-Meteo fetch carries no
// pressure); HI/LO took its slot.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../config" as Config
import "../services" as Services
import "../lib/weather.mjs" as Wx

HudCard {
    id: root
    accent: Config.ThemeConfig.colors.info

    // ── state (from the plugin cache; "—" until the first read lands) ──
    property string _place: ""
    property var _wx: null              // Wx.parseForecast output
    property double _fetchedAt: 0       // ms epoch; 0 = coords-only cache
    readonly property bool _has: _wx !== null && _wx.available === true
    readonly property int _ageMin: _fetchedAt > 0
                                  ? Math.floor((Date.now() - _fetchedAt) / 60000) : -1
    // Past the plugin's own 15-min refresh gate the data is officially old.
    readonly property bool _stale: _ageMin >= 15

    // °C/°F from the session locale — the plugin's rule, shared module.
    readonly property string _unit: Wx.unitFor(
        Quickshell.env("LC_ALL") || Quickshell.env("LANG") || "")

    readonly property string _readPath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "~") + "/.local/state")
        + "/velocity/plugins/nikos.clock-weather.json"

    function _read() {
        _buf = ""
        reader.running = false
        reader.running = true
    }

    Component.onCompleted: _read()
    onVisibleChanged: if (visible) _read()

    // ── one-shot cache read (cat; startup-reader idiom) ──────────────────
    property string _buf: ""
    Process {
        id: reader   // unbounded-ok: one-shot local command — timeout migration queued
        command: ["sh", "-c", 'cat "$1" 2>/dev/null', "sh", root._readPath]
        stdout: SplitParser { onRead: function(line) { root._buf += line + "\n" } }
        onRunningChanged: {
            if (running) return
            var c = Wx.parseJson(root._buf)
            root._buf = ""
            if (!c || typeof c.fetchedAt !== "number") return   // no cache yet
            var wxp = Wx.parseForecast(c.raw, root._unit)
            if (!wxp.available) return
            root._place = (typeof c.place === "string") ? c.place : ""
            root._wx = wxp
            root._fetchedAt = c.fetchedAt
        }
    }

    // 10-min re-read while the dashboard is visible — the plugin refreshes at
    // most every 15 min, so the next tick always catches a fresh cache.
    Timer {
        interval: 600000; running: root.visible; repeat: true
        onTriggered: root._read()
    }

    // REFRESH › — nudge the plugin over the engine IPC, then re-read twice.
    Services.BoundedProcess {
        id: refreshCall
        onDone: function(out, err, code) {
            if (code !== 0 || String(out).trim().indexOf("ok") !== 0)
                console.log("[WeatherCard] refresh nudge failed:",
                            String(out).trim() || "(no output)", String(err).trim())
        }
    }
    Timer {
        id: reRead
        interval: 4000; repeat: true
        property int left: 0
        onTriggered: { root._read(); if (--left <= 0) stop() }
    }
    function _refresh() {
        refreshCall.command = ["qs", "-c", "bar", "ipc", "call",
                               "plugins", "call", "nikos.clock", "refresh", ""]
        refreshCall.run()
        reRead.left = 2
        reRead.restart()
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        // Header — eyebrow + place + age
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "WEATHER"
                color: Config.ThemeConfig.colors.info
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.0
            }
            Item { Layout.fillWidth: true }
            Text {
                Layout.maximumWidth: 150
                visible: root._place.length > 0
                text: root._place
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 8; font.letterSpacing: 1
                elide: Text.ElideRight
            }
            Text {
                visible: root._has
                text: root._stale ? "· STALE"
                                  : "· AS OF " + Qt.formatDateTime(new Date(root._fetchedAt), "HH:mm")
                color: Config.ThemeConfig.colors.textDim
                opacity: root._stale ? 0.55 : 1.0
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 8; font.letterSpacing: 1
            }
        }

        // Thin separator under the header, spans full width
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.ThemeConfig.colors.info
            opacity: 0.15
        }

        // Body — left = icon/temp, right = condition + stat rows
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
                        text: root._has ? Wx.nerdFor(root._wx.code, root._wx.isDay) : "—"
                        font.family: Config.ControlConfig.fontNerd
                        font.pixelSize: 30
                        color: Config.ThemeConfig.colors.info
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: root._has ? root._wx.temp : "—"
                        color: Config.ThemeConfig.colors.text
                        font.family: Config.SettingsConfig.fontFamily
                        font.pixelSize: 38; font.weight: Font.Light
                    }
                    Text {
                        visible: !root._has
                        text: "open the clock panel to refresh"
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

            // ---- Right block: condition + stat rows --------------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: 10

                Text {
                    text: root._has ? root._wx.condition : ""
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

                    // Stat rows — same model, same formats as the clock panel's
                    // 2×2 metrics (WIND bare · HUMIDITY/RAIN % · FEELS °), plus
                    // HI/LO where PRES used to live.
                    Repeater {
                        model: root._has ? [
                            { l: "RH",    v: root._wx.humidity + "%" },
                            { l: "WIND",  v: String(root._wx.wind) },
                            { l: "RAIN",  v: (root._wx.hourly.length > 1
                                              ? root._wx.hourly[1].precip
                                              : (root._wx.hourly.length
                                                 ? root._wx.hourly[0].precip : "")) + "%" },
                            { l: "FEELS", v: root._wx.feels + "°" },
                            { l: "HI/LO", v: (root._wx.daily.length > 0)
                                             ? root._wx.daily[0].hi + "° / "
                                               + root._wx.daily[0].lo + "°" : "" }
                        ] : []
                        delegate: RowLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Text {
                                text: modelData.l
                                color: Config.ThemeConfig.colors.textDim
                                font.family: Config.ControlConfig.fontMono
                                font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                                Layout.preferredWidth: 30
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                elide: Text.ElideRight
                                text: modelData.v
                                color: Config.ThemeConfig.colors.text
                                font.family: Config.ControlConfig.fontMono
                                font.pixelSize: 10
                            }
                        }
                    }

                    Text {
                        text: "REFRESH ›"
                        color: root._stale ? Config.ThemeConfig.colors.info
                                           : Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._refresh()
                        }
                    }
                }
            }
        }
    }
}
