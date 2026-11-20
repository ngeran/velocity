// =============================================================================
// nikos.vnc — PanelBody (popup content)
// =============================================================================
// Single-pane popup, v2:
//   • hero (active target state + master switch) · last error
//   • SAVED CONNECTIONS — one row per stored connection (state dot, meta,
//     CONNECT, edit, delete-with-confirm) and a collapsible form to create
//     or edit them (name/host/port/user/password; the password encrypts via
//     vncpasswd over stdin — see VncService for the store contract)
//   • probe rows (ICMP reachability + RTT, VNC port) bound to the target
//   • RTT sparkline telemetry (Canvas, service-driven history)
//   • session duration · transient form feedback · auth hint.
//
// THEME-AWARE: every colour flows through ctx.theme — token lookups via
// _c(), translucency via ctx.theme.withAlpha (wireguard PanelBody idiom).
// The only literals are the pre-ctx fallbacks.
//
// Keyboard (panel takes focus while open): c connect/disconnect · r refresh
// · esc closes the form first, then the panel. Text fields (LogsOverlay
// Controls.TextField idiom) own their keys while focused — printable keys
// type, Esc bubbles through our field handler to close the form.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import qs.Ui
import "lib/glyphs.mjs" as G
import "lib/model.mjs" as Model
import "." as VNC

ColumnLayout {
    id: body

    // Injected by BarWidget's Loader.
    property var ctx: null      // PluginContext (theme, bar, settings)
    property var panel: null    // the PluginPopup hosting this body
    property var host: null     // BarWidget root (owns IPC verbs)

    // ── service facade ──────────────────────────────────────────────────────
    readonly property var svc: VNC.VncService

    // 1 Hz ticker while the popup is open — re-renders the session duration
    // (the service's own poll only guarantees this cadence when pollFast).
    property real nowTick: 0
    Timer {
        interval: 1000
        repeat: true
        running: body.panel && body.panel.opened
        onTriggered: body.nowTick = Date.now()
    }

    // ── scale + fonts (all sizes flow through sp() so contentScale holds) ───
    readonly property real scaleFactor: ctx && ctx.bar ? ctx.bar.contentScale : 1
    readonly property string fontBody: ctx && ctx.bar ? ctx.bar.fontFamily : "Space Mono"
    readonly property string fontNerd: ctx && ctx.bar ? ctx.bar.fontNerd : "JetBrainsMono Nerd Font"
    readonly property int sizeLabel: ctx && ctx.bar ? ctx.bar.fontSizeLabel : 11
    readonly property int sizeBody: Math.max(10, Math.round(sizeLabel * scaleFactor))
    readonly property int sizeSmall: Math.max(9, Math.round(sizeLabel * scaleFactor) - 1)
    readonly property int sizeCaption: Math.max(8, Math.round(sizeLabel * scaleFactor) - 2)

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

    // ── actions ─────────────────────────────────────────────────────────────
    // Hero switch / `c` key: reconnect the ACTIVE target when one is set,
    // else the ad-hoc settings host.
    function toggleSession() {
        if (body.svc.connected) body.svc.disconnectViewer()
        else if (body.svc.activeConnectionId !== "") body.svc.connectTo(body.svc.activeConnectionId)
        else body.svc.connectViewer()
    }

    // ── form state ──────────────────────────────────────────────────────────
    // editingId === "" means a NEW draft; otherwise the id of the connection
    // being edited (fields seed from it; password seeds EMPTY — a blank
    // password on save keeps the stored secret).
    property bool formOpen: false
    property string editingId: ""
    property string formError: ""

    function openForm(conn) {
        body.editingId = conn ? conn.id : ""
        fHost.seed(conn ? conn.host : "")
        fPort.seed(conn ? String(conn.port) : "5900")
        fName.seed(conn ? conn.name : "")
        fUser.seed(conn ? conn.user : "")
        fPass.seed("")
        fPass.reveal = false
        body.formError = ""
        body.formOpen = true
        // Auto-focus: the primary field of the task at hand.
        if (conn) fName.focusField()
        else fHost.focusField()
    }

    function closeForm() {
        body.formOpen = false
        body.formError = ""
        body.forceActiveFocus()
    }

    function submitForm(andConnect) {
        var draft = {
            id: body.editingId,
            name: fName.value,
            host: fHost.value,
            port: fPort.value,   // raw text — clampPort parses it ("" → 5900)
            user: fUser.value,
            password: fPass.value
        }
        var err = body.svc.saveConnection(draft, andConnect)
        if (err !== "") { body.formError = err; return }
        body.closeForm()
    }

    // The panel body takes keyboard focus while the popup is open.
    Component.onCompleted: if (panel && panel.opened) forceActiveFocus()

    Connections {
        target: body.panel
        function onOpenedChanged() {
            if (body.panel.opened) {
                // Reopening: resume where the user left the form.
                if (body.formOpen) fHost.focusField()
                else body.forceActiveFocus()
                // History may predate the last paint — sample-driven updates
                // alone would show a stale sparkline until the next RTT lands.
                sparkline.requestPaint()
            }
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (body.formOpen) body.closeForm()
            else if (panel) panel.close()
            event.accepted = true
            return
        }
        // While the form is open the keys belong to the fields — c/r would
        // be surprising shortcuts mid-typing.
        if (body.formOpen) return
        if (event.text === "c" || event.text === "C") { toggleSession(); event.accepted = true; return }
        if (event.text === "r" || event.text === "R") { body.svc.refresh(); event.accepted = true }
    }

    // ── hero ────────────────────────────────────────────────────────────────
    Hero {
        title: body.svc.targetLabel
        meta: {
            var m = Model.endpoint(body.svc.targetHost, body.svc.targetPort)
            if (body.svc.connected && body.svc.sessionStartedAt > 0)
                m += " · " + Model.fmtDuration((body.nowTick - body.svc.sessionStartedAt) / 1000)
            return m
        }
        detail: {
            if (body.svc.state === "connected") return "UP"
            if (body.svc.state === "host-unreachable") return "UNREACHABLE"
            if (body.svc.state === "port-closed") return "PORT CLOSED"
            return "DOWN"
        }
        detailOn: body.svc.connected
        glyph: body.svc.state === "connected" ? G.glyph("monitorCheck")
            : body.svc.state === "host-unreachable" ? G.glyph("monitorOff")
            : G.glyph("monitor")
        glyphColor: body.svc.connected
            ? body._c("success", "#7ee787")
            : body._c("textDim", "#808080")

        Switch {
            ctx: body.ctx
            checked: body.svc.connected
            onToggled: body.toggleSession()
        }
    }

    // ── last error + manual refresh ─────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: sp(8)
        visible: body.svc.lastError !== ""

        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: body.svc.lastError
            color: body._c("warning", "#e3b341")
            font.family: body.fontBody
            font.pixelSize: body.sizeCaption
            elide: Text.ElideMiddle
        }

        PillButton {
            glyph: G.glyph("refresh")
            label: "RETRY"
            onClicked: body.svc.refresh()
        }
    }

    // ── saved connections ───────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: sp(4)

        RowLayout {
            Layout.fillWidth: true
            spacing: sp(8)

            Text {
                textFormat: Text.PlainText
                text: "SAVED CONNECTIONS"
                color: body._c("textDim", "#808080")
                font.family: body.fontBody
                font.pixelSize: body.sizeCaption
                font.letterSpacing: 1
            }
            Item { Layout.fillWidth: true }
            PillButton {
                glyph: body.formOpen ? G.glyph("close") : G.glyph("plus")
                label: body.formOpen ? "CLOSE" : "ADD"
                onClicked: body.formOpen ? body.closeForm() : body.openForm(null)
            }
        }

        // One row per stored connection (MRU-first — the store re-sorts on
        // connect, so the top row is what you used last).
        Repeater {
            model: body.svc.connections

            ConnectionRow {
                conn: modelData
            }
        }

        Text {
            Layout.fillWidth: true
            visible: body.svc.connections.length === 0 && !body.formOpen
            textFormat: Text.PlainText
            text: "no saved connections yet — ADD one below"
            color: body._c("textDim", "#808080")
            opacity: 0.7
            font.family: body.fontBody
            font.pixelSize: body.sizeSmall
        }
    }

    // ── connection form (collapsible) ───────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: sp(6)
        visible: body.formOpen
        enabled: body.formOpen

        Text {
            textFormat: Text.PlainText
            text: body.editingId === "" ? "NEW CONNECTION" : "EDIT CONNECTION"
            color: body._c("text", "#e0e0e0")
            font.family: body.fontBody
            font.pixelSize: body.sizeCaption
            font.letterSpacing: 1
        }

        FormField {
            id: fHost
            caption: "HOST"
            placeholder: "10.0.0.70"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: sp(6)

            FormField {
                id: fName
                Layout.fillWidth: true
                caption: "NAME"
                placeholder: "mac mini"
            }

            FormField {
                id: fPort
                Layout.preferredWidth: sp(96)
                caption: "PORT"
                placeholder: "5900"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: sp(6)

            FormField {
                id: fUser
                Layout.fillWidth: true
                caption: "USER"
                placeholder: "optional"
            }

            FormField {
                id: fPass
                Layout.fillWidth: true
                caption: "PASSWORD"
                placeholder: body.editingId === "" ? "optional" : "unchanged"
                isPassword: true
            }
        }

        Text {
            Layout.fillWidth: true
            visible: body.formError !== ""
            textFormat: Text.PlainText
            text: body.formError
            color: body._c("warning", "#e3b341")
            font.family: body.fontBody
            font.pixelSize: body.sizeCaption
            elide: Text.ElideMiddle
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: sp(6)

            PillButton {
                primary: true
                glyph: G.glyph("contentSave")
                label: "SAVE + CONNECT"
                onClicked: body.submitForm(true)
            }
            PillButton {
                glyph: G.glyph("check")
                label: "SAVE"
                onClicked: body.submitForm(false)
            }
            PillButton {
                visible: body.editingId !== ""
                glyph: G.glyph("close")
                label: "CANCEL"
                onClicked: body.closeForm()
            }
            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: G.glyph("key") + "  password encrypts to ~/.config/secrets/vnc (vncpasswd, 8-char DES limit) — plain-auth user+pass is prompted by the viewer"
            color: body._c("textDim", "#808080")
            opacity: 0.8
            font.family: body.fontNerd
            font.pixelSize: body.sizeCaption
            wrapMode: Text.WordWrap
        }
    }

    // ── probe rows ──────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: sp(4)

        ProbeRow {
            glyph: G.glyph("earth")
            label: "ICMP " + body.svc.targetHost
            value: body.svc.hostReachable ? Model.fmtRtt(body.svc.lastRttMs) : "no reply"
            on: body.svc.hostReachable
        }

        ProbeRow {
            glyph: G.glyph(body.svc.portOpen ? "lanConnect" : "lanDisconnect")
            label: "VNC PORT " + body.svc.targetPort
            value: body.svc.portOpen ? "open" : "closed"
            on: body.svc.portOpen
        }
    }

    // ── RTT telemetry (sparkline driven by the service's history ring) ─────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: sp(6)

        Text {
            textFormat: Text.PlainText
            text: G.glyph("chartLine") + "  RTT"
            color: body._c("textDim", "#808080")
            font.family: body.fontNerd
            font.pixelSize: body.sizeCaption
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: sp(56)

            Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                visible: sparkline.rttHistory.length < 2
                text: "No samples yet"
                color: body._c("textDim", "#808080")
                opacity: 0.7
                font.family: body.fontBody
                font.pixelSize: body.sizeSmall
            }

            Canvas {
                id: sparkline
                anchors.fill: parent

                // Mirrors the service's capped ring — repaint on replacement,
                // never poll from the view.
                property var rttHistory: []

                Connections {
                    target: body.svc
                    function onRttHistoryChanged() {
                        sparkline.rttHistory = body.svc.rttHistory
                        sparkline.requestPaint()
                    }
                }

                onPaint: {
                    var c = getContext("2d")
                    c.reset()

                    // Baseline hairline through the middle.
                    var lineBase = body._c("text", "#e0e0e0")
                    c.strokeStyle = body._wa(lineBase, 0.12, "rgba(255,255,255,0.12)")
                    c.lineWidth = 1
                    c.beginPath()
                    c.moveTo(0, Math.floor(height / 2) + 0.5)
                    c.lineTo(width, Math.floor(height / 2) + 0.5)
                    c.stroke()

                    var series = sparkline.rttHistory
                    if (series.length < 2) return
                    var peak = 1
                    for (var i = 0; i < series.length; i++) peak = Math.max(peak, series[i])
                    c.globalAlpha = 1
                    c.strokeStyle = body._c("accent", "#00dce5")
                    c.lineWidth = 1.5
                    c.beginPath()
                    for (i = 0; i < series.length; i++) {
                        var x = width * (i / (series.length - 1))
                        var y = height - (height - 2) * Math.min(1, series[i] / peak) - 1
                        if (i === 0) c.moveTo(x, y)
                        else c.lineTo(x, y)
                    }
                    c.stroke()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: sp(8)

            Text {
                textFormat: Text.PlainText
                text: "now " + Model.fmtRtt(body.svc.lastRttMs)
                color: body._c("text", "#e0e0e0")
                font.family: body.fontBody
                font.pixelSize: body.sizeSmall
            }
            Item { Layout.fillWidth: true }
            Text {
                textFormat: Text.PlainText
                text: "avg " + Model.fmtRtt(body.svc.avgRttMs)
                color: body._c("textDim", "#808080")
                font.family: body.fontBody
                font.pixelSize: body.sizeSmall
            }
            Item { Layout.fillWidth: true }
            Text {
                // nowTick dependency re-evaluates the duration each second
                // while the popup is open (see Timer above).
                textFormat: Text.PlainText
                text: G.glyph("timerOutline") + " " + (body.svc.connected && body.svc.sessionStartedAt > 0
                    ? Model.fmtDuration((body.nowTick - body.svc.sessionStartedAt) / 1000) : "—")
                color: body._c("textDim", "#808080")
                font.family: body.fontNerd
                font.pixelSize: body.sizeSmall
            }
        }
    }

    // ── transient store feedback (saved / storing / failures) ───────────────
    Text {
        Layout.fillWidth: true
        visible: body.svc.formHint !== ""
        textFormat: Text.PlainText
        text: body.svc.formHint
        color: body._c("accent", "#00dce5")
        font.family: body.fontBody
        font.pixelSize: body.sizeCaption
        elide: Text.ElideMiddle
    }

    // ── settings hint (ad-hoc values live in Settings ▸ Plugins ▸ VNC) ─────
    Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: "ad-hoc host/port + fullscreen in Settings ▸ Plugins ▸ VNC — saved rows above override them"
        color: body._c("textDim", "#808080")
        opacity: 0.8
        font.family: body.fontBody
        font.pixelSize: body.sizeCaption
        elide: Text.ElideRight
    }

    // ── inline components (wireguard PanelBody idioms) ─────────────────────
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

    // Hairline button with optional glyph + label (wireguard PillButton).
    // primary = accent-tinted (form's SAVE + CONNECT); danger = warning-tinted
    // (the delete-confirm state).
    component PillButton: Rectangle {
        id: pillBtn
        property string label: ""
        property string glyph: ""
        property bool primary: false
        property bool danger: false
        signal clicked()

        implicitWidth: btnRow.implicitWidth + sp(16)
        implicitHeight: sp(26)
        radius: sp(6)
        color: primary
            ? (btnMouse.containsMouse
               ? body._wa(body._c("accent", "#00dce5"), 0.26, "#1c3a40")
               : body._wa(body._c("accent", "#00dce5"), 0.16, "#16282a"))
            : btnMouse.containsMouse
              ? body._c("fillHover", "#1c1c1c")
              : body._c("fillRest", "#0d0d0d")
        border.width: 1
        border.color: primary
            ? body._wa(body._c("accent", "#00dce5"), 0.5, "#2a5a60")
            : danger
              ? body._wa(body._c("warning", "#e3b341"), 0.5, "#6a5320")
              : body._c("hairline", "#1a1a1a")

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: sp(6)

            Text {
                textFormat: Text.PlainText
                text: pillBtn.glyph
                visible: pillBtn.glyph !== ""
                color: pillBtn.primary
                    ? body._c("accent", "#00dce5")
                    : pillBtn.danger
                      ? body._c("warning", "#e3b341")
                      : body._c("text", "#e0e0e0")
                font.family: body.fontNerd
                font.pixelSize: body.sizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                textFormat: Text.PlainText
                text: pillBtn.label
                color: pillBtn.primary
                    ? body._c("accent", "#00dce5")
                    : pillBtn.danger
                      ? body._c("warning", "#e3b341")
                      : body._c("text", "#e0e0e0")
                font.family: body.fontBody
                font.pixelSize: body.sizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: pillBtn.clicked()
        }
    }

    // Label + value row with an on/off tint dot (probe results).
    component ProbeRow: Rectangle {
        id: probeRow
        property string glyph: ""
        property string label: ""
        property string value: ""
        property bool on: false

        Layout.fillWidth: true
        implicitHeight: probeRowText.implicitHeight + sp(8)
        radius: sp(6)
        color: body._c("fillRest", "#0d0d0d")
        border.width: 1
        border.color: body._c("hairline", "#1a1a1a")

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: sp(8)
            anchors.rightMargin: sp(8)
            spacing: sp(8)

            Text {
                textFormat: Text.PlainText
                text: probeRow.glyph
                color: probeRow.on ? body._c("success", "#7ee787") : body._c("textDim", "#808080")
                font.family: body.fontNerd
                font.pixelSize: body.sizeSmall
            }

            Text {
                id: probeRowText
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: probeRow.label
                color: body._c("text", "#e0e0e0")
                font.family: body.fontBody
                font.pixelSize: body.sizeSmall
                elide: Text.ElideMiddle
            }

            Text {
                textFormat: Text.PlainText
                text: probeRow.value
                color: probeRow.on ? body._c("success", "#7ee787") : body._c("textDim", "#808080")
                font.family: body.fontBody
                font.pixelSize: body.sizeSmall
            }
        }
    }

    // One saved connection: state dot (pulses while it is the active target
    // without a session yet) · name + user@host:port meta · CONNECT / EDIT /
    // DELETE (two-step confirm — a stray click must not destroy a secret).
    component ConnectionRow: Rectangle {
        id: crow
        property var conn: null
        readonly property bool isActive: conn && body.svc.activeConnectionId === conn.id
        property bool confirmDelete: false

        // Confirm state self-reverts — no lingering "SURE?" landmine.
        Timer {
            id: confirmReset
            interval: 3000
            onTriggered: crow.confirmDelete = false
        }

        Layout.fillWidth: true
        implicitHeight: sp(40)
        radius: sp(6)
        color: rowMouse.containsMouse
            ? body._c("fillHover", "#1c1c1c")
            : body._c("fillRest", "#0d0d0d")
        border.width: 1
        border.color: crow.isActive
            ? body._wa(body._c("accent", "#00dce5"), 0.35, "#1e4449")
            : body._c("hairline", "#1a1a1a")

        // Row-wide click = quick connect (buttons above it eat their own
        // clicks — stacking order puts them first).
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (crow.conn) body.svc.connectTo(crow.conn.id)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: sp(8)
            anchors.rightMargin: sp(8)
            spacing: sp(8)

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: sp(8)
                implicitHeight: sp(8)
                radius: sp(4)
                color: crow.isActive && body.svc.connected
                    ? body._c("success", "#7ee787")
                    : crow.isActive
                      ? body._c("accent", "#00dce5")
                      : body._c("textDim", "#808080")

                // Active-but-not-yet-connected: the launch is in flight.
                SequentialAnimation on opacity {
                    running: crow.isActive && !body.svc.connected
                    alwaysRunToEnd: true
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.35; duration: 600 }
                    NumberAnimation { from: 0.35; to: 1; duration: 600 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Layout.alignment: Qt.AlignVCenter

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: crow.conn && crow.conn.name !== "" ? crow.conn.name : (crow.conn ? crow.conn.host : "")
                    color: body._c("text", "#e0e0e0")
                    font.family: body.fontBody
                    font.pixelSize: body.sizeSmall
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: crow.conn
                        ? (crow.conn.user !== "" ? crow.conn.user + "@" : "")
                          + Model.endpoint(crow.conn.host, crow.conn.port)
                        : ""
                    color: body._c("textDim", "#808080")
                    font.family: body.fontBody
                    font.pixelSize: body.sizeCaption
                    elide: Text.ElideMiddle
                }
            }

            PillButton {
                glyph: crow.isActive && body.svc.connected
                    ? G.glyph("lanDisconnect")
                    : G.glyph("lanConnect")
                label: crow.isActive && body.svc.connected ? "DISCONNECT" : "CONNECT"
                onClicked: {
                    if (!crow.conn) return
                    if (crow.isActive && body.svc.connected) body.svc.disconnectViewer()
                    else body.svc.connectTo(crow.conn.id)
                }
            }

            PillButton {
                glyph: G.glyph("pencil")
                onClicked: body.openForm(crow.conn)
            }

            PillButton {
                danger: crow.confirmDelete
                glyph: G.glyph("trashCan")
                label: crow.confirmDelete ? "SURE?" : ""
                onClicked: {
                    if (!crow.confirmDelete) {
                        crow.confirmDelete = true
                        confirmReset.restart()
                        return
                    }
                    if (crow.conn) body.svc.deleteConnection(crow.conn.id)
                    if (body.editingId !== "" && crow.conn && body.editingId === crow.conn.id)
                        body.closeForm()
                }
            }
        }
    }

    // Caption + styled text field (LogsOverlay search-field idiom: Rectangle
    // wrapper for bg/border, Controls.TextField with background:null inside).
    // seed() fills the field (openForm); value reads what the user typed.
    // Password fields get a reveal toggle — the glyph click flips echoMode.
    component FormField: ColumnLayout {
        id: fld
        property string caption: ""
        property string placeholder: ""
        property bool isPassword: false
        property bool reveal: false
        readonly property alias value: tf.text
        function seed(v) { tf.text = v || "" }
        function focusField() { tf.forceActiveFocus() }

        spacing: 2

        Text {
            textFormat: Text.PlainText
            text: fld.caption
            color: body._c("textDim", "#808080")
            font.family: body.fontBody
            font.pixelSize: body.sizeCaption
            font.letterSpacing: 1
        }

        Rectangle {
            Layout.fillWidth: true
            // Height follows the field's own metrics so scaled fonts never
            // clip (fixed sp(28) was too tight at high contentScale).
            implicitHeight: Math.max(sp(28), tf.implicitHeight + 2 * sp(4))
            radius: sp(6)
            color: body._wa(body._c("fillRest", "#0d0d0d"), 0.6, "#0a0a0a")
            border.width: 1
            border.color: tf.activeFocus
                ? body._wa(body._c("accent", "#00dce5"), 0.6, "#2a5a60")
                : body._c("hairline", "#1a1a1a")

            Controls.TextField {
                id: tf
                anchors.fill: parent
                anchors.margins: sp(4)
                anchors.rightMargin: fld.isPassword ? sp(26) : sp(4)
                background: null
                // Zero vertical padding + centered text: the wrapper (not the
                // style) owns the insets, so sizing stays deterministic.
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                color: body._c("text", "#e0e0e0")
                placeholderText: fld.placeholder
                placeholderTextColor: body._c("textDim", "#808080")
                selectionColor: body._c("accent", "#00dce5")
                selectedTextColor: "#000000"
                font.family: body.fontBody
                font.pixelSize: body.sizeSmall
                selectByMouse: true
                echoMode: fld.isPassword && !fld.reveal ? TextInput.Password : TextInput.Normal
                // Esc in a field closes the FORM first, not the panel.
                Keys.onEscapePressed: body.closeForm()
            }

            Text {
                visible: fld.isPassword
                anchors.right: parent.right
                anchors.rightMargin: sp(6)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: fld.reveal ? G.glyph("eyeOff") : G.glyph("eye")
                color: body._c("textDim", "#808080")
                font.family: body.fontNerd
                font.pixelSize: body.sizeSmall

                MouseArea {
                    anchors.fill: parent
                    onClicked: fld.reveal = !fld.reveal
                }
            }
        }
    }
}
