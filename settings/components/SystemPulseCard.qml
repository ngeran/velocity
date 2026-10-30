// =============================================================================
// SystemPulseCard.qml — SYSTEM PULSE (H4: the dashboard calendar's successor)
// =============================================================================
// READ-ONLY window over the metrics engine. Sits in the Overview tab's
// left-column square (DashboardCard wrapper in OverviewTab provides
// the brackets); WeatherCard stays below it.
//
// Data sources — every one of them is another component's primary, this card
// only reads:
//   • HostBridge.metrics (P2.3: one process — the ex-SystemInfoService engine,
//     now MetricsService) → CPU/MEM/GPU/DISK gauge rows. `leased` is the LIVE
//     indicator; extendLease(30) while the card is live keeps the poll running.
//   • HostBridge.network.trafficRxKB/trafficTxKB (KB/s, its own dashboard-
//     visible-gated sysfs sampler) → the ↓↑ line. No second sampler here.
//   • HostBridge.network.lastTest + lib/age.mjs → last speed-test line.
//   • the nikos.clock weather cache (same file as WeatherCard, lib/weather.mjs)
//     → one glyph/temp/condition line, dimmed past the 15-min staleness rule.
//
// LEASE: while visible a 10s Timer calls extendLease(30) directly (the
// `metrics lease` IPC round-trip is gone — same process). Close the dashboard
// and the engine's poll timer self-clears at expiry; idle cost returns to zero.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "." as Components
import "../config" as Config
import "../services" as Services
import "../lib/units.mjs" as Units
import "../lib/age.mjs" as Age
import "../lib/weather.mjs" as Wx

Item {
    id: root

    // ── weather cache state (same file as WeatherCard) ────────────────────
    property var _weather: null               // Wx.parseForecast output
    property double _fetchedAt: 0
    readonly property bool _weatherHas: _weather !== null && _weather.available === true
    readonly property bool _weatherStale: _fetchedAt > 0
        && (Date.now() - _fetchedAt) >= 15 * 60000

    readonly property string _weatherUnit: Wx.unitFor(
        Quickshell.env("LC_ALL") || Quickshell.env("LANG") || "")

    readonly property string _weatherPath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "~") + "/.local/state")
        + "/velocity/plugins/nikos.clock-weather.json"

    function _clamp(v) {
        return (typeof v === "number" && isFinite(v)) ? Math.max(0, Math.min(100, v)) : 0
    }

    function _ingestWx(raw) {
        var c = null
        try { c = Wx.parseJson(raw) } catch (e) { c = null }
        if (!c || typeof c.fetchedAt !== "number") return   // no cache yet
        var wxp = null
        try { wxp = Wx.parseForecast(c.raw, _weatherUnit) } catch (e) { wxp = null }
        if (!wxp || !wxp.available) return
        _weather = wxp
        _fetchedAt = c.fetchedAt
    }

    // ── the metrics engine (null until the bar shell attaches barServices) ──
    readonly property var _m: Services.HostBridge.metrics

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ── header ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "SYSTEM PULSE"
                color: Config.ThemeConfig.colors.primary
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.0
            }
            Item { Layout.fillWidth: true }
            Text {
                // Honest indicator: the engine's own lease state — LIVE while
                // anything (this card, the Core tab, the LCD feed, the overlay)
                // keeps the poll running.
                text: root._m && root._m.leased ? "LIVE" : "IDLE"
                color: root._m && root._m.leased ? Config.ThemeConfig.colors.success
                                                 : Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 7; font.bold: true; font.letterSpacing: 1.0
                opacity: root._m && root._m.leased ? 1.0 : 0.55
            }
        }

        // ── gauge rows — share the spare height so 4K breathes, 768 still fits
        ColumnLayout {
            id: gauges
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // One instrument row: LABEL [track+fill] PCT. Fill tier-tints
            // (CoreDashBand idiom); the 3px track is the dim instrument line.
            component GaugeRow: RowLayout {
                id: gauge
                property string label: ""
                property real pct: 0
                property bool present: true
                spacing: 8

                Text {
                    text: gauge.label
                    color: Config.ThemeConfig.colors.textDim
                    opacity: gauge.present ? 1.0 : 0.5
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0
                    Layout.preferredWidth: 30
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 3
                    Layout.alignment: Qt.AlignVCenter
                    Rectangle {   // dim track — always visible (live instrument)
                        anchors.fill: parent
                        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.08)
                    }
                    Rectangle {   // live fill — tier-tinted, moves with data
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * gauge.pct / 100
                        color: Config.ThemeConfig.tierColor(gauge.pct, 50, 85)
                        Behavior on width {
                            NumberAnimation {
                                duration: Config.MotionConfig.move
                                easing.type: Config.MotionConfig.ease
                            }
                        }
                    }
                }
                Text {
                    text: gauge.present ? Math.round(gauge.pct) + "%" : "—"
                    color: gauge.present
                        ? Config.ThemeConfig.tierColor(gauge.pct, 50, 85)
                        : Config.ThemeConfig.colors.textDim
                    opacity: gauge.present ? 1.0 : 0.5
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 8; font.bold: true
                    Layout.preferredWidth: 26
                    Layout.alignment: Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                }
            }

            GaugeRow { label: "CPU"; pct: root._m ? root._clamp(root._m.cpuUsage) : 0 }
            GaugeRow { label: "MEM"; pct: root._m ? root._clamp(root._m.ramPct) : 0 }
            GaugeRow { label: "GPU"; pct: root._m ? root._clamp(root._m.gpuUsagePct) : 0
                       present: root._m ? root._m.present : false }
            GaugeRow { label: "DSK"; pct: root._m ? root._clamp(root._m.diskPct) : 0 }

            // ── network line ──────────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: {
                    var net = Services.HostBridge.network
                    if (!net.connectionStatus.connected) return "NET — DISCONNECTED"
                    var rx = Units.formatRate(net.trafficRxKB * 1024)
                    var tx = Units.formatRate(net.trafficTxKB * 1024)
                    return "↓ " + rx + "   ↑ " + tx
                }
                color: Services.HostBridge.network.connectionStatus.connected
                    ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 8
                opacity: 0.85
            }
        }

        // ── footer: last speed test + weather ─────────────────────────────
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: {
                var t = Services.HostBridge.network.lastTest
                if (!t) return "SPEED TEST — NO RUNS YET"
                return "SPEED TEST  ↓" + t.downMbps.toFixed(1) + " ↑" + t.upMbps.toFixed(1)
                    + " MBPS · " + Age.ageLabel(t.ts)
            }
            color: Config.ThemeConfig.colors.textDim
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 7; font.letterSpacing: 0.5
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root._weatherHas
            spacing: 6

            Text {   // glyph needs the nerd face — mono has no PUA coverage
                visible: root._weatherHas
                text: root._weatherHas ? Wx.nerdFor(root._weather.code, root._weather.isDay) : ""
                color: root._weatherStale
                    ? Config.ThemeConfig.colors.textDim : Config.ThemeConfig.colors.info
                font.family: Config.ControlConfig.fontNerd
                font.pixelSize: 10
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root._weatherHas ? root._weather.temp + "  " + root._weather.condition : ""
                color: root._weatherStale
                    ? Config.ThemeConfig.colors.textDim : Config.ThemeConfig.colors.text
                opacity: root._weatherStale ? 0.55 : 0.85
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 7; font.letterSpacing: 0.5
            }
        }
    }

    // ── weather reader — file-fed, no forks (plugin cache writes are atomic) ─
    FileView {
        id: wxFile
        path: root._weatherPath
        watchChanges: false          // atomic renames don't fire it — Timer reloads
        printErrors: false
        onTextChanged: root._ingestWx(text())
    }

    // The sanctioned visibility gate (NetworkControlService idiom): the card's
    // `visible` alone would keep the lease alive behind a hidden window.
    readonly property bool _cardLive: visible && Config.SharedState.dashboardVisible

    Timer {
        interval: 10000
        repeat: true
        running: root._cardLive
        triggeredOnStart: true
        onTriggered: if (root._m) root._m.extendLease(30)   // dashboard open = poll on
    }
    Timer {
        interval: 60000
        repeat: true
        running: root._cardLive
        triggeredOnStart: true
        onTriggered: wxFile.reload()
    }
}
