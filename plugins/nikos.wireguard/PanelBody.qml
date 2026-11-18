// =============================================================================
// nikos.wireguard — popup body ("WIREGUARD" / "TAILSCALE" tabs)
// =============================================================================
// Port of ngeran.wireguard's Panel.qml (Omarchy) into this bar's plugin kit.
// Two panes, one each for WireGuard (nmcli) and Tailscale:
//
//   WireGuard: hero (active tunnel + master switch) · last error · tunnel
//   rows (click / cursor keys to toggle) · live telemetry (sparkline, rates,
//   session counters, profile geometry) · .conf import via FileDialog.
//   Tailscale: hero (state + switch) · pending-login row · peer/path/exit
//   node telemetry · device list with exit-node pick · last error.
//
// THEME-AWARE (user requirement): every colour flows through ctx.theme —
// token lookups via _c(), translucency via ctx.theme.withAlpha. ThemeConfig
// reassigns the whole colors object on a theme swap, so these bindings
// re-derive automatically; the only literals are the pre-ctx fallbacks.
//
// Keyboard (panel takes focus while open): 1/2 tabs · j/k or arrows move the
// cursor · enter toggles the cursor row · space/t hero toggle · r refresh ·
// i import · esc closes. Dropped from the source: bar panel cycling (Tab),
// the polkit handshake button (Decision C — no root wg in v1) and its
// statusMessage; the delete flow never had UI upstream and stays off.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.Ui
import "lib/glyphs.mjs" as G
import "lib/model.mjs" as Model
import "." as WG

ColumnLayout {
    id: body

    // Injected by BarWidget's Loader.
    property var ctx: null      // PluginContext (theme, bar, settings)
    property var panel: null    // the PluginPopup hosting this body
    property var host: null     // BarWidget root (owns activeTab)

    // ── keyboard cursor over tunnel rows ────────────────────────────────────
    property int tunnelIndex: 0
    property bool cursorActive: false

    // ── service facades ─────────────────────────────────────────────────────
    readonly property var wg: WG.WireGuardService
    readonly property var ts: WG.TailscaleService
    readonly property var tunnels: wg.tunnels
    readonly property bool connected: wg.connected
    readonly property string activeTab: host ? host.activeTab : "wireguard"

    // ── scale + fonts (all sizes flow through sp() so contentScale holds) ───
    readonly property real scaleFactor: ctx && ctx.bar ? ctx.bar.contentScale : 1
    readonly property string fontBody: ctx && ctx.bar ? ctx.bar.fontFamily : "Space Mono"
    readonly property string fontNerd: ctx && ctx.bar ? ctx.bar.fontNerd : "JetBrainsMono Nerd Font"
    readonly property int sizeLabel: ctx && ctx.bar ? ctx.bar.fontSizeLabel : 11
    readonly property int sizeBody: Math.max(10, Math.round(sizeLabel * scaleFactor))
    readonly property int sizeSmall: Math.max(9, Math.round(sizeLabel * scaleFactor) - 1)
    readonly property int sizeCaption: Math.max(8, Math.round(sizeLabel * scaleFactor) - 2)
    readonly property int sizeTitle: Math.round(sizeLabel * scaleFactor) + 5

    function sp(n) { return Math.round(n * scaleFactor) }

    // Token lookup (LayoutSearch contract): base tokens live in
    // theme.colors, derived fills (fillRest/fillHover/hairline…) on theme.
    function _c(tok, fallback) {
        if (!ctx || !ctx.theme) return fallback
        if (ctx.theme.colors && ctx.theme.colors[tok] !== undefined) return ctx.theme.colors[tok]
        if (ctx.theme[tok] !== undefined) return ctx.theme[tok]
        return fallback
    }

    // withAlpha with a pre-ctx fallback so preview never hard-fails.
    function _wa(base, alpha, fallback) {
        if (ctx && ctx.theme && ctx.theme.withAlpha) return ctx.theme.withAlpha(base, alpha)
        return fallback
    }

    // ── formatters (I18n.formatNumber dropped — plain English digits) ───────
    function formatBytes(value) {
        var p = Model.splitBytes(value)
        return p.digits.toFixed(p.decimals) + " " + p.unit
    }
    function formatRate(value) {
        var p = Model.splitBytes(value)
        return p.digits.toFixed(p.decimals) + " " + p.unit + "/s"
    }
    function formatUptime(activatedAt) {
        return Model.uptimeLabel(activatedAt, Math.floor(Date.now() / 1000))
    }
    function stateLabel(tunnel) {
        if (!tunnel) return ""
        if (tunnel.state === "activated") return "Up"
        if (tunnel.state === "activating" || tunnel.state === "ip-config"
            || tunnel.state === "secondaries") return "Starting"
        if (tunnel.state === "deactivating") return "Stopping"
        return "Down"
    }

    // ── actions ─────────────────────────────────────────────────────────────
    function setTab(name) {
        if (host) host.activeTab = name === "tailscale" ? "tailscale" : "wireguard"
    }
    function moveCursor(delta) {
        if (activeTab !== "wireguard" || tunnels.length === 0) return
        tunnelIndex = Math.max(0, Math.min(tunnels.length - 1, tunnelIndex + delta))
    }
    function activateCursor() {
        if (activeTab !== "wireguard" || tunnels.length === 0) return
        wg.toggleTunnel(tunnels[tunnelIndex].uuid)
    }
    function togglePrimaryTunnel() { wg.togglePrimary() }

    onActiveTabChanged: cursorActive = false
    onTunnelsChanged: {
        if (tunnelIndex >= tunnels.length) tunnelIndex = Math.max(0, tunnels.length - 1)
        if (telemetryBlock) telemetryBlock.clearHistory()
    }

    // The panel body takes keyboard focus while the popup is open
    // (LayoutSearch precedent — PluginPopup content can own keys).
    Component.onCompleted: if (panel && panel.opened) forceActiveFocus()

    Connections {
        target: body.panel
        function onOpenedChanged() {
            if (body.panel.opened) body.forceActiveFocus()
            body.cursorActive = false
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) { if (panel) panel.close(); event.accepted = true; return }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activateCursor(); event.accepted = true; return
        }
        if (event.key === Qt.Key_Space) { togglePrimaryTunnel(); event.accepted = true; return }
        if (event.key === Qt.Key_Down || event.text === "j") {
            if (!cursorActive) cursorActive = true
            else moveCursor(1)
            event.accepted = true; return
        }
        if (event.key === Qt.Key_Up || event.text === "k") {
            if (!cursorActive) cursorActive = true
            else moveCursor(-1)
            event.accepted = true; return
        }
        if (event.text === "1") { setTab("wireguard"); event.accepted = true; return }
        if (event.text === "2") { setTab("tailscale"); event.accepted = true; return }
        if (event.text === "t" || event.text === "T") {
            if (activeTab === "tailscale") ts.toggle()
            else togglePrimaryTunnel()
            event.accepted = true; return
        }
        if (event.text === "r" || event.text === "R") {
            wg.refresh(); ts.refresh(); event.accepted = true; return
        }
        if (event.text === "i" || event.text === "I") {
            setTab("wireguard"); importDialog.open(); event.accepted = true; return
        }
    }

    FileDialog {
        id: importDialog
        title: "Import WireGuard configuration"
        nameFilters: ["WireGuard config (*.conf)"]
        onAccepted: wg.importConf(importDialog.selectedFile)
    }

    // ── shared chrome ───────────────────────────────────────────────────────

    component SectionHeader: Text {
        id: header
        property string label: ""
        Layout.fillWidth: true
        topPadding: sp(2)
        text: label
        color: body._c("textDim", "#808080")
        font.family: body.fontBody
        font.pixelSize: body.sizeCaption
        font.bold: true
        font.letterSpacing: 1
        textFormat: Text.PlainText
    }

    // Hero: icon + title/meta + state pill + one trailing control (the
    // master Switch). Source PanelHero, restyled on theme tokens.
    component Hero: Rectangle {
        id: hero
        property string title: ""
        property string meta: ""
        property string detail: ""
        property string glyph: ""
        property color glyphColor: body._c("text", "#e0e0e0")
        property bool detailOn: false
        default property alias trailing: trailer.data

        Layout.fillWidth: true
        implicitHeight: sp(56)
        radius: sp(10)
        color: body._c("fillRest", "#0d0d0d")
        border.width: 1
        border.color: body._c("hairline", "#1a1a1a")

        RowLayout {
            anchors.fill: parent
            anchors.margins: sp(10)
            spacing: sp(10)

            Text {
                textFormat: Text.PlainText
                text: hero.glyph
                color: hero.glyphColor
                font.family: body.fontNerd
                font.pixelSize: sp(22)
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: hero.title
                    color: body._c("text", "#e0e0e0")
                    font.family: body.fontBody
                    font.pixelSize: body.sizeBody
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: hero.meta
                    color: body._c("textDim", "#808080")
                    font.family: body.fontBody
                    font.pixelSize: body.sizeSmall
                    elide: Text.ElideRight
                    visible: hero.meta !== ""
                }
            }

            // State pill: filled when on (accent tint), hairline when off.
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: detailText.implicitWidth + sp(12)
                implicitHeight: detailText.implicitHeight + sp(6)
                radius: height / 2
                color: hero.detailOn
                    ? body._wa(body._c("accent", "#00dce5"), 0.16, "#16282a")
                    : "transparent"
                border.width: 1
                border.color: hero.detailOn
                    ? body._wa(body._c("accent", "#00dce5"), 0.45, "#2a5a60")
                    : body._c("hairline", "#1a1a1a")

                Text {
                    id: detailText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: hero.detail
                    color: hero.detailOn
                        ? body._c("accent", "#00dce5")
                        : body._c("textDim", "#808080")
                    font.family: body.fontBody
                    font.pixelSize: body.sizeCaption
                    font.bold: true
                    visible: hero.detail !== ""
                }
            }

            Item {
                id: trailer
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
        }
    }

    // Hairline button with optional glyph + label (source Button).
    component PillButton: Rectangle {
        id: pillBtn
        property string label: ""
        property string glyph: ""
        property bool isDim: false
        signal clicked()

        implicitWidth: btnRow.implicitWidth + sp(16)
        implicitHeight: sp(26)
        radius: sp(6)
        color: btnMouse.containsMouse
            ? body._c("fillHover", "#1c1c1c")
            : body._c("fillRest", "#0d0d0d")
        border.width: 1
        border.color: body._c("hairline", "#1a1a1a")

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: sp(6)

            Text {
                textFormat: Text.PlainText
                text: pillBtn.glyph
                visible: pillBtn.glyph !== ""
                color: pillBtn.isDim ? body._c("textDim", "#808080") : body._c("text", "#e0e0e0")
                font.family: body.fontNerd
                font.pixelSize: body.sizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                textFormat: Text.PlainText
                text: pillBtn.label
                color: pillBtn.isDim ? body._c("textDim", "#808080") : body._c("text", "#e0e0e0")
                font.family: body.fontBody
                font.pixelSize: body.sizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pillBtn.clicked()
        }
    }

    // Label-left / value-right telemetry row (source stat rows).
    component StatRow: Item {
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        implicitHeight: statLabel.implicitHeight

        Text {
            id: statLabel
            textFormat: Text.PlainText
            text: parent.label
            color: body._c("textDim", "#808080")
            font.family: body.fontBody
            font.pixelSize: body.sizeSmall
        }
        Text {
            textFormat: Text.PlainText
            text: parent.value
            color: body._c("text", "#e0e0e0")
            font.family: body.fontBody
            font.pixelSize: body.sizeSmall
            anchors.right: parent.right
            width: Math.max(0, parent.width - statLabel.implicitWidth - sp(12))
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
        }
    }

    // ── tab row (source ButtonGroup, restyled) ─────────────────────────────
    Rectangle {
        id: tabBar
        Layout.fillWidth: true
        implicitHeight: sp(30)
        radius: sp(6)
        color: body._c("fillRest", "#0d0d0d")
        border.width: 1
        border.color: body._c("hairline", "#1a1a1a")

        Row {
            anchors.fill: parent
            spacing: 2

            Repeater {
                model: [
                    { value: "wireguard", label: "WIREGUARD" },
                    { value: "tailscale", label: "TAILSCALE" }
                ]

                delegate: Rectangle {
                    // Plain `property var` — `required property` breaks
                    // modelData on JS-array models (codebase trap).
                    property var entry: modelData
                    width: (tabBar.width - 4) / 2
                    height: tabBar.height - 4
                    anchors.verticalCenter: parent.verticalCenter
                    radius: sp(4)
                    color: body.activeTab === entry.value
                        ? body._c("fillHover", "#1c1c1c")
                        : "transparent"

                    Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: entry.label
                        color: body.activeTab === entry.value
                            ? body._c("text", "#e0e0e0")
                            : body._c("textDim", "#808080")
                        font.family: body.fontBody
                        font.pixelSize: body.sizeSmall
                        font.bold: true
                        font.letterSpacing: 1
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: body.setTab(entry.value)
                    }
                }
            }
        }
    }

    // ── panes (both stay warm; the services keep polling) ─────────────────
    // No inner Flickable/height cap (user call): the endpoint, allowed-IPs
    // and DNS rows must be visible without scrolling. The Popover card
    // sizes to its content up to the screen budget, and the card's own
    // bodyScroll (UA 2.2) only engages past that budget.
    ColumnLayout {
        id: panes
        Layout.fillWidth: true
        spacing: sp(12)

        // ── WireGuard pane ─────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: sp(12)
            visible: body.activeTab === "wireguard"

            Hero {
                title: body.connected && body.wg.activeTunnel
                    ? body.wg.activeTunnel.name : "WireGuard"
                meta: body.connected && body.wg.activeTunnel
                    ? body.wg.activeTunnel.device + " · " + body.formatUptime(body.wg.activeTunnel.activatedAt)
                    : "No tunnel is up"
                detail: body.connected ? "UP" : "DOWN"
                detailOn: body.connected
                glyph: body.connected ? G.glyph("shield") : G.glyph("lockOutline")
                glyphColor: body.connected
                    ? body._c("success", "#7ee787")
                    : body._c("textDim", "#808080")

                // ctx in: the kit Switch derives track/knob colours from
                // ctx.theme; without it the checked track stays on the
                // neutral #00dce5 literal and ignores theme swaps.
                Switch {
                    ctx: body.ctx
                    checked: body.connected
                    interactive: body.tunnels.length > 0 && !body.wg.busy
                    onToggled: body.togglePrimaryTunnel()
                }
            }

            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                visible: body.wg.lastError !== ""
                text: body.wg.lastError
                color: body._c("error", "#ff6b6b")
                opacity: 0.85
                font.family: body.fontBody
                font.pixelSize: body.sizeSmall
                elide: Text.ElideRight
            }

            SectionHeader { label: "TUNNELS" }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: sp(4)

                Repeater {
                    model: body.tunnels

                    delegate: Item {
                        id: row
                        property var tunnel: modelData
                        Layout.fillWidth: true
                        implicitHeight: sp(46)

                        // Cursor band (source CursorSurface).
                        Rectangle {
                            anchors.fill: parent
                            radius: sp(6)
                            color: body.cursorActive && body.tunnelIndex === index
                                ? body._c("fillHover", "#1c1c1c")
                                : "transparent"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                body.cursorActive = true
                                body.tunnelIndex = index
                            }
                            onClicked: body.wg.toggleTunnel(row.tunnel.uuid)
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.leftMargin: sp(10)
                            anchors.right: statePill.left
                            anchors.rightMargin: sp(10)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                text: row.tunnel.name
                                color: body._c("text", "#e0e0e0")
                                font.family: body.fontBody
                                font.pixelSize: body.sizeBody
                                font.bold: row.tunnel.active
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                text: body.stateLabel(row.tunnel)
                                    + (row.tunnel.device !== "" ? " · " + row.tunnel.device : "")
                                color: body._c("textDim", "#808080")
                                font.family: body.fontBody
                                font.pixelSize: body.sizeSmall
                                elide: Text.ElideRight
                            }
                        }

                        // State pill: inverted (text-on-fill) when active.
                        Rectangle {
                            id: statePill
                            anchors.right: parent.right
                            anchors.rightMargin: sp(10)
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: statePillText.implicitWidth + sp(12)
                            implicitHeight: statePillText.implicitHeight + sp(5)
                            radius: sp(4)
                            color: row.tunnel.active
                                ? body._c("text", "#e0e0e0")
                                : "transparent"
                            border.width: 1
                            border.color: row.tunnel.active
                                ? "transparent"
                                : body._c("hairline", "#1a1a1a")

                            Text {
                                id: statePillText
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: body.stateLabel(row.tunnel).toUpperCase()
                                color: row.tunnel.active
                                    ? body._c("background", "#000000")
                                    : body._c("textDim", "#808080")
                                font.family: body.fontBody
                                font.pixelSize: body.sizeCaption
                                font.bold: true
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    visible: body.tunnels.length === 0
                    text: "No WireGuard tunnels configured."
                    color: body._c("textDim", "#808080")
                    font.family: body.fontBody
                    font.pixelSize: body.sizeBody
                    wrapMode: Text.WordWrap
                }
            }

            SectionHeader { label: "TELEMETRY"; visible: body.connected }

            TelemetryBlock {
                id: telemetryBlock
                Layout.fillWidth: true
                visible: body.connected
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: sp(8)

                PillButton {
                    label: "IMPORT .CONF"
                    glyph: G.glyph("importConf")
                    onClicked: importDialog.open()
                }

                Item { Layout.fillWidth: true }

                Text {
                    textFormat: Text.PlainText
                    Layout.alignment: Qt.AlignVCenter
                    visible: body.tunnels.length === 0
                    text: "Import a wg-quick .conf to add a tunnel"
                    color: body._c("textDim", "#808080")
                    opacity: 0.8
                    font.family: body.fontBody
                    font.pixelSize: body.sizeCaption
                    elide: Text.ElideRight
                }
            }
        }

        // ── Tailscale pane ──────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: sp(12)
            visible: body.activeTab === "tailscale"

            Hero {
                title: "Tailscale"
                meta: {
                    var t = body.ts
                    if (!t || !t.installed || !t.running) return ""
                    var parts = []
                    if (t.self.hostName !== "") parts.push(t.self.hostName)
                    if (t.self.ips.length > 0) parts.push(t.self.ips[0])
                    if (t.tailnetName !== "") parts.push(t.tailnetName)
                    return parts.join(" · ")
                }
                detail: {
                    var t = body.ts
                    if (!t || !t.installed) return ""
                    if (t.running) return "UP"
                    if (t.needsLogin) return "LOGIN"
                    if (t.stopped) return "DOWN"
                    return "…"
                }
                detailOn: body.ts.running
                glyph: G.glyph("lanConnect")
                glyphColor: body.ts.running
                    ? body._c("success", "#7ee787")
                    : body._c("textDim", "#808080")

                Switch {
                    ctx: body.ctx
                    checked: body.ts.running
                    interactive: body.ts.installed && !body.ts.busy
                    onToggled: body.ts.toggle()
                }
            }

            TailscaleBlock {
                Layout.fillWidth: true
            }
        }
    }

    // ── WireGuard telemetry (source TelemetryBlock) ────────────────────────
    component TelemetryBlock: ColumnLayout {
        id: telemetryBlockRoot

        property string device: body.wg.activeTunnel ? body.wg.activeTunnel.device : ""
        readonly property var counters: body.wg.counters[device] || null
        readonly property var rates: body.wg.rates[device] || null
        readonly property var tunnel: body.wg.activeTunnel
        readonly property var profile: tunnel && body.wg.profiles[tunnel.uuid]
            ? body.wg.profiles[tunnel.uuid] : null
        // Profile-derived peer geometry (Decision C: no root wg dump in v1).
        readonly property var profilePeers: profile ? Model.parsePeerProfile(profile.peers) : []

        spacing: sp(8)

        function clearHistory() { sparkline.clearHistory() }
        onDeviceChanged: clearHistory()

        Item {
            Layout.fillWidth: true
            implicitHeight: sp(60)

            Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                visible: sparkline.rxHistory.length < 2
                text: "No traffic yet"
                color: body._c("textDim", "#808080")
                opacity: 0.7
                font.family: body.fontBody
                font.pixelSize: body.sizeSmall
            }

            Canvas {
                id: sparkline
                anchors.fill: parent

                property var rxHistory: []
                property var txHistory: []
                property real maxRate: 4096

                function clearHistory() {
                    rxHistory = []
                    txHistory = []
                    maxRate = 4096
                    requestPaint()
                }

                function pushSample() {
                    var ratesNow = telemetryBlockRoot.rates
                    if (!ratesNow) return
                    var nextRx = rxHistory.concat([ratesNow.rx])
                    var nextTx = txHistory.concat([ratesNow.tx])
                    if (nextRx.length > 120) {
                        nextRx = nextRx.slice(nextRx.length - 120)
                        nextTx = nextTx.slice(nextTx.length - 120)
                    }
                    rxHistory = nextRx
                    txHistory = nextTx
                    var peak = 4096
                    for (var i = 0; i < nextRx.length; i++)
                        peak = Math.max(peak, nextRx[i], nextTx[i])
                    maxRate = peak
                    requestPaint()
                }

                Timer {
                    interval: 1000
                    repeat: true
                    running: body.panel && body.panel.opened && body.connected
                    onTriggered: sparkline.pushSample()
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()

                    // Baseline hairline through the middle.
                    var lineBase = body._c("text", "#e0e0e0")
                    ctx.strokeStyle = body._wa(lineBase, 0.12, "rgba(255,255,255,0.12)")
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(0, Math.floor(height / 2) + 0.5)
                    ctx.lineTo(width, Math.floor(height / 2) + 0.5)
                    ctx.stroke()

                    drawSeries(ctx, rxHistory, body._c("accent", "#00dce5"), 1)
                    drawSeries(ctx, txHistory, lineBase, 0.45)
                }

                function drawSeries(ctx, series, color, alpha) {
                    if (series.length < 2) return
                    ctx.globalAlpha = alpha
                    ctx.strokeStyle = color
                    ctx.lineWidth = 1.5
                    ctx.beginPath()
                    for (var i = 0; i < series.length; i++) {
                        var x = width * (i / Math.max(2, series.length - 1))
                        var y = height - (height - 2) * Math.min(1, series[i] / sparkline.maxRate) - 1
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                    ctx.globalAlpha = 1
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: sp(14)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    textFormat: Text.PlainText
                    text: "DOWNLOAD"
                    color: body._c("textDim", "#808080")
                    font.family: body.fontBody
                    font.pixelSize: body.sizeCaption
                    font.bold: true
                    font.letterSpacing: 1
                }
                Text {
                    textFormat: Text.PlainText
                    text: telemetryBlockRoot.rates ? body.formatRate(telemetryBlockRoot.rates.rx) : "0 B/s"
                    color: body._c("text", "#e0e0e0")
                    font.family: body.fontBody
                    font.pixelSize: body.sizeTitle
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    textFormat: Text.PlainText
                    text: "UPLOAD"
                    color: body._c("textDim", "#808080")
                    font.family: body.fontBody
                    font.pixelSize: body.sizeCaption
                    font.bold: true
                    font.letterSpacing: 1
                }
                Text {
                    textFormat: Text.PlainText
                    text: telemetryBlockRoot.rates ? body.formatRate(telemetryBlockRoot.rates.tx) : "0 B/s"
                    color: body._c("text", "#e0e0e0")
                    font.family: body.fontBody
                    font.pixelSize: body.sizeTitle
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: sp(3)

            Repeater {
                model: {
                    if (!telemetryBlockRoot.tunnel) return []
                    var rows = [
                        { label: "Session received", value: body.formatBytes(telemetryBlockRoot.counters ? telemetryBlockRoot.counters.rx : 0) },
                        { label: "Session sent", value: body.formatBytes(telemetryBlockRoot.counters ? telemetryBlockRoot.counters.tx : 0) },
                        { label: "Uptime", value: body.formatUptime(telemetryBlockRoot.tunnel.activatedAt) },
                        // Handshake/listen-port need the root wg dump — parked
                        // with Tier 7 (Decision C); peers come from the profile.
                        { label: "Last handshake", value: "—" },
                        { label: "Listen port", value: "—" },
                        { label: "Peers", value: telemetryBlockRoot.profilePeers.length > 0
                            ? String(telemetryBlockRoot.profilePeers.length) : "—" }
                    ]
                    if (telemetryBlockRoot.profilePeers.length === 1) {
                        var peer = telemetryBlockRoot.profilePeers[0]
                        if (peer.endpoint !== "")
                            rows.push({ label: "Endpoint", value: peer.endpoint })
                        if (peer.allowedIps.length > 0)
                            rows.push({ label: "Allowed IPs", value: peer.allowedIps.join(", ") })
                    }
                    if (telemetryBlockRoot.profile && telemetryBlockRoot.profile.dns !== "")
                        rows.push({ label: "DNS", value: telemetryBlockRoot.profile.dns })
                    return rows
                }

                delegate: StatRow {
                    // plain property var per delegate (JS-array model trap)
                    property var entry: modelData
                    label: entry.label
                    value: entry.value
                }
            }
        }
    }

    // ── Tailscale body (source TailscaleBlock) ─────────────────────────────
    component TailscaleBlock: ColumnLayout {
        id: tsBlock

        readonly property var t: body.ts
        spacing: sp(8)

        // Pending login: the daemon hands out a URL, the browser finishes it.
        RowLayout {
            Layout.fillWidth: true
            spacing: sp(8)
            visible: tsBlock.t.needsLogin && tsBlock.t.authUrl !== ""

            PillButton {
                label: "OPEN LOGIN PAGE"
                glyph: G.glyph("openInNew")
                onClicked: Qt.openUrlExternally(tsBlock.t.authUrl)
            }

            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: tsBlock.t.authUrl
                color: body._c("textDim", "#808080")
                font.family: body.fontBody
                font.pixelSize: body.sizeSmall
                elide: Text.ElideMiddle
            }
        }

        // Connectivity / path / exit-node telemetry.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: sp(3)
            visible: tsBlock.t.installed

            Repeater {
                model: {
                    var t = tsBlock.t
                    var rows = [
                        { label: "Peers", value: t.peersOnline + " / " + t.peers.length },
                        { label: "Path", value: t.directPeers + " direct · " + t.relayPeers + " relay" },
                        { label: "Exit node", value: t.exitNode
                            ? (t.exitNode.hostName || t.exitNode.dnsName || t.exitNode.ips.join(", "))
                            : "None" },
                        { label: "Session received", value: body.formatBytes(t.counters.rx) },
                        { label: "Session sent", value: body.formatBytes(t.counters.tx) }
                    ]
                    if (t.health.length > 0) rows.push({ label: "Health", value: t.health[0] })
                    return rows
                }

                delegate: StatRow {
                    property var entry: modelData
                    label: entry.label
                    value: entry.value
                }
            }
        }

        // Device list with exit-node selection.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: sp(2)
            visible: tsBlock.t.peers.length > 0

            Repeater {
                model: tsBlock.t.peers.slice(0, 6)

                delegate: RowLayout {
                    // plain property var per delegate (JS-array model trap)
                    property var peer: modelData
                    Layout.fillWidth: true
                    spacing: sp(8)

                    Rectangle {
                        width: sp(5)
                        height: sp(5)
                        radius: width / 2
                        color: peer.online
                            ? body._c("accent", "#00dce5")
                            : body._c("textDim", "#808080")
                        opacity: peer.online ? 1 : 0.45
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: peer.hostName !== "" ? peer.hostName : peer.dnsName
                            color: body._c("text", "#e0e0e0")
                            font.family: body.fontBody
                            font.pixelSize: body.sizeSmall
                            font.bold: peer.exitNode
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: {
                                var meta = []
                                if (peer.os !== "") meta.push(peer.os)
                                meta.push(Model.peerPath(peer))
                                meta.push(body.formatBytes(peer.rx) + " ↓ " + body.formatBytes(peer.tx) + " ↑")
                                return meta.join(" · ")
                            }
                            color: body._c("textDim", "#808080")
                            font.family: body.fontBody
                            font.pixelSize: body.sizeCaption
                            elide: Text.ElideRight
                        }
                    }

                    PillButton {
                        visible: peer.exitNodeOption
                        isDim: !peer.exitNode
                        label: peer.exitNode ? "USING" : "USE"
                        onClicked: tsBlock.t.setExitNode(peer.exitNode ? "" : peer.id)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                visible: tsBlock.t.peers.length > 6
                text: "+" + (tsBlock.t.peers.length - 6) + " more"
                color: body._c("textDim", "#808080")
                font.family: body.fontBody
                font.pixelSize: body.sizeCaption
            }
        }

        // Not-installed notice (pre-switch state on this host).
        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            visible: !tsBlock.t.installed
            text: "Tailscale is not installed — enable services.velocityVpn in .omni-nix and rebuild."
            color: body._c("textDim", "#808080")
            font.family: body.fontBody
            font.pixelSize: body.sizeSmall
            wrapMode: Text.WordWrap
        }

        // Last failure (operator missing, daemon down, refused command).
        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            visible: tsBlock.t.lastError !== ""
            text: tsBlock.t.lastError
            color: body._c("error", "#ff6b6b")
            opacity: 0.85
            font.family: body.fontBody
            font.pixelSize: body.sizeSmall
            elide: Text.ElideRight
        }
    }
}
