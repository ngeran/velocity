// =============================================================================
// SystemPulseCard.qml — SYSTEM PULSE (H4: the dashboard calendar's successor)
// =============================================================================
// READ-ONLY window over the bar's H7 metrics feed. Sits in the Overview tab's
// left-column square (DashboardCard wrapper in OverviewTab provides
// the brackets); WeatherCard stays below it.
//
// Data sources — every one of them is another component's primary, this card
// only reads:
//   • $XDG_RUNTIME_DIR/velocity/metrics.json (bar SystemInfoService, lease-
//     gated) → CPU/MEM/GPU/DISK gauge rows. Same file+idiom as GpuService:
//     watchChanges stays FALSE (tmp+mv renames don't fire it — KernelEventReader
//     lesson), a 2s visible-gated Timer drives reload() (ASYNC; parse lands
//     in onTextChanged). gpu:null → the GPU row reads dim "—".
//   • NetworkControlService.rxRate/txRate (KB/s, its own dashboard-visible-
//     gated sysfs sampler) → the ↓↑ line. No second sampler here.
//   • NetworkControlService.lastTest + lib/age.mjs → last speed-test line.
//   • the nikos.clock weather cache (same file as WeatherCard, lib/weather.mjs)
//     → one glyph/temp/condition line, dimmed past the 15-min staleness rule.
//
// LEASE: while visible a 10s Timer renews the bar's metrics lease via the
// `metrics lease 30` IPC (SystemMetricsService idiom) — close the dashboard and
// the bar's poll timer self-clears at expiry; idle cost returns to zero.
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

    // ── metrics file state ────────────────────────────────────────────────
    property double _ts: 0               // file's publish timestamp (ms epoch)
    property bool _live: false           // file advanced within the last 6s
    property real _cpuPct: 0
    property real _memPct: 0
    property real _diskPct: 0
    property var _gpu: null              // metrics gpu object | null

    readonly property bool _gpuPresent: _gpu !== null

    // ── weather cache state (same file as WeatherCard) ────────────────────
    property var _wx: null               // Wx.parseForecast output
    property double _fetchedAt: 0
    readonly property bool _wxHas: _wx !== null && _wx.available === true
    readonly property bool _wxStale: _fetchedAt > 0
        && (Date.now() - _fetchedAt) >= 15 * 60000

    readonly property string _wxUnit: Wx.unitFor(
        Quickshell.env("LC_ALL") || Quickshell.env("LANG") || "")

    readonly property string _metricsPath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/" + (Quickshell.env("UID") || "1000"))
        + "/velocity/metrics.json"

    readonly property string _wxPath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "~") + "/.local/state")
        + "/velocity/plugins/nikos.clock-weather.json"

    function _clamp(v) {
        return (typeof v === "number" && isFinite(v)) ? Math.max(0, Math.min(100, v)) : 0
    }

    function _ingestMetrics(raw) {
        var v = null
        try { v = JSON.parse(raw) } catch (e) { v = null }
        if (!v || typeof v !== "object") return
        _ts = typeof v.ts === "number" ? v.ts : 0
        _live = _ts > 0 && (Date.now() - _ts) < 6000
        _cpuPct = v.cpu ? _clamp(v.cpu.pct) : 0
        _memPct = (v.mem && v.mem.totalB > 0) ? _clamp(v.mem.usedB / v.mem.totalB * 100) : 0
        _diskPct = (v.disk && v.disk.totalB > 0) ? _clamp(v.disk.usedB / v.disk.totalB * 100) : 0
        _gpu = (v.gpu && typeof v.gpu === "object") ? v.gpu : null
    }

    function _ingestWx(raw) {
        var c = null
        try { c = Wx.parseJson(raw) } catch (e) { c = null }
        if (!c || typeof c.fetchedAt !== "number") return   // no cache yet
        var wxp = null
        try { wxp = Wx.parseForecast(c.raw, _wxUnit) } catch (e) { wxp = null }
        if (!wxp || !wxp.available) return
        _wx = wxp
        _fetchedAt = c.fetchedAt
    }

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
                // Honest indicator: only while the metrics file is actually
                // advancing (lease held). Resets on the next parse after the
                // file stops moving.
                text: root._live ? "LIVE" : "IDLE"
                color: root._live ? Config.ThemeConfig.colors.success
                                  : Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 7; font.bold: true; font.letterSpacing: 1.0
                opacity: root._live ? 1.0 : 0.55
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

            GaugeRow { label: "CPU"; pct: root._cpuPct }
            GaugeRow { label: "MEM"; pct: root._memPct }
            GaugeRow { label: "GPU"; pct: root._gpuPresent ? root._clamp(root._gpu.pct) : 0
                       present: root._gpuPresent }
            GaugeRow { label: "DSK"; pct: root._diskPct }

            // ── network line ──────────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: {
                    var net = Services.NetworkControlService
                    if (!net.connectionStatus.connected) return "NET — DISCONNECTED"
                    var rx = Units.formatRate(net.rxRate * 1024)
                    var tx = Units.formatRate(net.txRate * 1024)
                    return "↓ " + rx + "   ↑ " + tx
                }
                color: Services.NetworkControlService.connectionStatus.connected
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
                var t = Services.NetworkControlService.lastTest
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
            visible: root._wxHas
            spacing: 6

            Text {   // glyph needs the nerd face — mono has no PUA coverage
                visible: root._wxHas
                text: root._wxHas ? Wx.nerdFor(root._wx.code, root._wx.isDay) : ""
                color: root._wxStale
                    ? Config.ThemeConfig.colors.textDim : Config.ThemeConfig.colors.info
                font.family: Config.ControlConfig.fontNerd
                font.pixelSize: 10
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root._wxHas ? root._wx.temp + "  " + root._wx.condition : ""
                color: root._wxStale
                    ? Config.ThemeConfig.colors.textDim : Config.ThemeConfig.colors.text
                opacity: root._wxStale ? 0.55 : 0.85
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 7; font.letterSpacing: 0.5
            }
        }
    }

    // ── readers — file-fed, no forks ──────────────────────────────────────
    FileView {
        id: metricsFile
        path: root._metricsPath
        watchChanges: false          // tmp+mv renames don't fire it — Timer reloads
        printErrors: false
        onTextChanged: root._ingestMetrics(text())
    }
    FileView {
        id: wxFile
        path: root._wxPath
        watchChanges: false          // plugin cache writes are also atomic
        printErrors: false
        onTextChanged: root._ingestWx(text())
    }

    // ── lease renewal — dashboard open = the bar keeps polling ────────────
    Services.BoundedProcess {
        id: leaseProc
        timeoutMs: 5000
        command: ["qs", "-c", "bar", "ipc", "call", "metrics", "lease", "30"]
    }

    // The sanctioned visibility gate (NetworkControlService idiom): the card's
    // `visible` alone would keep the lease alive behind a hidden window.
    readonly property bool _cardLive: visible && Config.SharedState.dashboardVisible

    Timer {
        interval: 10000
        repeat: true
        running: root._cardLive
        triggeredOnStart: true
        onTriggered: leaseProc.run()
    }

    // ── 2s metrics read + 60s weather read, both visible-gated ────────────
    Timer {
        interval: 2000
        repeat: true
        running: root._cardLive
        triggeredOnStart: true
        onTriggered: {
            metricsFile.reload()
            // The speed-test result is written by the BAR (tmp+mv) whenever a
            // test completes — without this reload the footer would only
            // refresh when the Wi-Fi section is opened (Hr review).
            Services.NetworkControlService.refreshLastTest()
            // Re-judge freshness here — the last parse of a lapsed lease
            // would otherwise leave LIVE lit forever.
            root._live = root._ts > 0 && (Date.now() - root._ts) < 6000
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: root._cardLive
        triggeredOnStart: true
        onTriggered: wxFile.reload()
    }
}
