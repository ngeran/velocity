// =============================================================================
// NetworkCardBody.qml — NETWORK tray body (P4.1 full card)
// =============================================================================
// The card is a VIEW of NetworkService (the domain's one owner). Spec P4.1:
// hero (SSID · signal · DISCONNECT), LINK readouts (IP/IPv6/gateway/DNS/
// band·channel/link speed/interface/security — wired shows carrier rows), a
// leased 60s Rx/Tx sparkline with session totals, VPN row, the bar-owned
// speed test (RUN + persisted last result), the radio pill, NEARBY top-5
// with connect, QR share, deep link.
//
// Layering: JOINING an UNKNOWN-SECURED network still lives in settings (the
// card is keyboard-inert — no text input in a tray body). Known-network
// connect rides connectWifi(ssid, "") — nmcli --ask fills the stored PSK.
//
// Leases: the popup lease (popupOpen) already drives the 2s traffic stats,
// the wifi scanner (hero + NEARBY rows), the link probe (speed/gateway/DNS)
// and the VPN probe; on close everything stops (spawn/min back to idle).
//
// Derived readout: dBm is the standard wpa_supplicant inverse of the SAME
// quality the % shows (dBm ≈ %/2 − 100) — one source, two units, no second
// probe. Channel comes from the AP-enrich cache via the in-use row.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import bar.services as Services
import bar.config as Config

ColumnLayout {
    id: body

    property var tray: null                       // the TrayCard (hair, tokens)
    signal settingsRequested(string verb)

    readonly property bool _ok: tray !== null
    readonly property bool _wifiLink: Services.NetworkService.isConnected
                                      && Services.NetworkService.connectionType === "wifi"
    readonly property bool _wiredLink: Services.NetworkService.isConnected
                                       && Services.NetworkService.connectionType !== "wifi"
    readonly property var _cs: Services.NetworkService.connectionStatus
    readonly property var _net: Services.NetworkService
    // Active AP's enrichment row (channel) — "" while the cache is cold.
    readonly property string _chan: {
        var rows = Services.NetworkService.wifiNetworks
        for (var i = 0; i < rows.length; i++) if (rows[i].inUse) return String(rows[i].chan || "")
        return ""
    }
    readonly property int _dbm: Math.round(Services.NetworkService.signalStrength / 2) - 100

    spacing: 0

    // ── HERO — the current link (glyph tile · SSID · state · live signal) ──
    RowLayout {
        visible: Services.NetworkService.hasNetwork
        Layout.fillWidth: true
        spacing: Config.PopupMetrics.px(12)

        Rectangle {
            Layout.preferredWidth: Config.PopupMetrics.px(44)
            Layout.preferredHeight: Config.PopupMetrics.px(44)
            radius: Config.PopupMetrics.px(8)
            color: Config.ThemeConfig.fillRest
            border.color: Config.BarConfig.colorBorder; border.width: body._ok ? body.tray.hair : 1
            Text {
                anchors.centerIn: parent
                text: !Services.NetworkService.isConnected ? "\u{f05aa}"
                    : Services.NetworkService.connectionType === "wifi" ? "\u{f05a9}"
                    : "\u{f0200}"
                font.family: Config.BarConfig.fontNerd
                font.pixelSize: Config.PopupMetrics.px(20)
                color: Services.NetworkService.isConnected
                       ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorTextDim
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.PopupMetrics.px(2)
            Text {
                text: body.heroSsid
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(12); font.bold: true
                color: Config.BarConfig.colorText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: body.heroStatus
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(9); font.letterSpacing: 1.2
                color: Config.BarConfig.colorTextDim
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        // live signal (wifi link only) — % big, self-drawn 4-bar glyph under
        ColumnLayout {
            visible: body._wifiLink
            spacing: Config.PopupMetrics.px(3)
            Text {
                text: Services.NetworkService.signalStrength + "%"
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(20); font.bold: true
                color: Config.BarConfig.colorText
                Layout.alignment: Qt.AlignRight
            }
            Item {
                width: Config.PopupMetrics.px(22)
                height: Config.PopupMetrics.px(12)
                Layout.alignment: Qt.AlignRight
                Repeater {
                    model: 4
                    Rectangle {
                        readonly property int filled:
                            Services.NetworkService.signalStrength > 80 ? 4
                          : Services.NetworkService.signalStrength > 60 ? 3
                          : Services.NetworkService.signalStrength > 35 ? 2 : 1
                        x: index * Config.PopupMetrics.px(6)
                        y: parent.height - height
                        width: Config.PopupMetrics.px(4)
                        height: Config.PopupMetrics.px(4 + index * 3)
                        radius: 1
                        color: index < filled ? Config.ThemeConfig.colors.primary
                                              : Qt.rgba(Config.BarConfig.colorText.r,
                                                        Config.BarConfig.colorText.g,
                                                        Config.BarConfig.colorText.b, 0.12)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }
            Text {
                text: body._dbm + " dBm"
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(7); font.letterSpacing: 1
                color: Config.BarConfig.colorTextDim
                Layout.alignment: Qt.AlignRight
            }
        }
        Text {
            // upstream's destructive hero action — wifi only
            visible: body._wifiLink
            text: "DISCONNECT"
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: Config.PopupMetrics.px(8); font.bold: true; font.letterSpacing: 1.2
            color: discArea.containsMouse ? Config.ThemeConfig.colors.error
                                          : Config.BarConfig.colorTextDim
            MouseArea {
                id: discArea
                anchors.fill: parent; anchors.margins: -6
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: if (Services.NetworkService.activeNet)
                               Services.NetworkService.activeNet.disconnect()
            }
        }
    }

    // nmcli absent — dim dash instead of a misleading "DISCONNECTED" pill
    Text {
        visible: !Services.NetworkService.hasNetwork
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "—"
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: Config.PopupMetrics.px(28)
        color: Config.BarConfig.colorTextDim
    }

    // ── LINK — address/route readouts (leased link probe) ────────────────────
    CardFrame {
        visible: Services.NetworkService.isConnected
        title: "LINK"
        uiScale: Config.PopupMetrics.scale
        titleColor: Config.BarConfig.colorTextDim
        hairlineColor: Config.ThemeConfig.hairline
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(8)

        CardRow {
            label: "IP"
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText; labelColor: Config.BarConfig.colorTextDim
            // ipAddress = the popup's own fast probe; _cs.ip = the link probe's
            value: {
                var ip = Services.NetworkService.ipAddress !== ""
                         ? Services.NetworkService.ipAddress : body._cs.ip
                return ip !== "" ? ip + (body._cs.subnet || "") : "—"
            }
            muted: Services.NetworkService.ipAddress === "" && body._cs.ip === ""
        }
        CardRow {
            visible: body._wifiLink
            label: "IPV6"
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText; labelColor: Config.BarConfig.colorTextDim
            value: body._cs.ip6 !== "" ? body._cs.ip6 : "—"
            muted: body._cs.ip6 === ""
        }
        CardRow {
            label: "GATEWAY"
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText; labelColor: Config.BarConfig.colorTextDim
            value: body._cs.gateway !== "" ? body._cs.gateway : "—"
            muted: body._cs.gateway === ""
        }
        CardRow {
            label: "DNS"
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText; labelColor: Config.BarConfig.colorTextDim
            value: body._cs.dns !== "" ? body._cs.dns : "—"
            muted: body._cs.dns === ""
        }
        CardRow {
            visible: body._wifiLink
            label: "BAND"
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText; labelColor: Config.BarConfig.colorTextDim
            value: (body._cs.band !== "" ? body._cs.band : "—")
                   + (body._chan !== "" ? "  ·  CH " + body._chan : "")
            muted: body._cs.band === "" && body._chan === ""
        }
        CardRow {
            visible: body._wifiLink
            label: "SECURITY"
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText; labelColor: Config.BarConfig.colorTextDim
            value: body._cs.security !== "" ? body._cs.security : "OPEN"
        }
        CardRow {
            label: "LINK"
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText; labelColor: Config.BarConfig.colorTextDim
            value: body._cs.linkSpeed !== "" ? body._cs.linkSpeed : "—"
            muted: body._cs.linkSpeed === ""
        }
        CardRow {
            label: "INTERFACE"
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText; labelColor: Config.BarConfig.colorTextDim
            value: body._cs.iface !== "" ? body._cs.iface : "—"
            muted: body._cs.iface === ""
        }
        CardRow {
            visible: Services.NetworkService.vpnStatus.active
            label: "VPN"
            uiScale: Config.PopupMetrics.scale
            valueColor: Config.ThemeConfig.colors.primary
            textColor: Config.BarConfig.colorText; labelColor: Config.BarConfig.colorTextDim
            value: Services.NetworkService.vpnStatus.name
                   + (Services.NetworkService.vpnStatus.type !== ""
                      ? "  (" + Services.NetworkService.vpnStatus.type + ")" : "")
        }
    }

    // ── TRAFFIC — leased 60s sparklines + rates + session totals ────────────
    CardFrame {
        visible: Services.NetworkService.isConnected
        title: "TRAFFIC  ·  60S"
        uiScale: Config.PopupMetrics.scale
        titleColor: Config.BarConfig.colorTextDim
        hairlineColor: Config.ThemeConfig.hairline
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(10)

        Sparkline {
            Layout.fillWidth: true
            Layout.preferredHeight: Config.PopupMetrics.px(30)
            samples: body._rxSamples
            capacity: 60
            valueMax: 0
            stroke: Config.ThemeConfig.colors.primary
            fill: Qt.rgba(Config.ThemeConfig.colors.primary.r,
                          Config.ThemeConfig.colors.primary.g,
                          Config.ThemeConfig.colors.primary.b, 0.10)
        }
        CardRow {
            label: "↓ DOWNLOAD"
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText; labelColor: Config.BarConfig.colorTextDim
            valueBold: false
            value: Services.NetworkService.rxRate === "" ? "—"
                 : Services.NetworkService.rxRate + "  ·  " + body._sessionRx
            muted: Services.NetworkService.rxRate === ""
        }
        Sparkline {
            Layout.fillWidth: true
            Layout.preferredHeight: Config.PopupMetrics.px(30)
            samples: body._txSamples
            capacity: 60
            stroke: Config.ThemeConfig.colors.secondary
            fill: Qt.rgba(Config.ThemeConfig.colors.secondary.r,
                          Config.ThemeConfig.colors.secondary.g,
                          Config.ThemeConfig.colors.secondary.b, 0.10)
        }
        CardRow {
            label: "↑ UPLOAD"
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText; labelColor: Config.BarConfig.colorTextDim
            valueBold: false
            value: Services.NetworkService.txRate === "" ? "—"
                 : Services.NetworkService.txRate + "  ·  " + body._sessionTx
            muted: Services.NetworkService.txRate === ""
        }
    }

    // ── SPEED TEST — bar XHR probe + persisted last result ───────────────────
    RowLayout {
        visible: Services.NetworkService.hasNetwork && Services.NetworkService.isConnected
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(4)
        Layout.preferredHeight: Config.PopupMetrics.px(26)
        spacing: Config.PopupMetrics.px(8)

        Text {
            text: "SPEED TEST"
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: Config.PopupMetrics.px(10); font.letterSpacing: 1
            color: Config.BarConfig.colorTextDim
            Layout.alignment: Qt.AlignVCenter
        }
        Item { Layout.fillWidth: true }
        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter
            Text {
                readonly property bool running: Services.NetworkService.speedPhase === "download"
                                             || Services.NetworkService.speedPhase === "upload"
                text: running ? "testing…"
                    : Services.NetworkService.speedPhase === "done"
                      ? "↓ " + Services.NetworkService.speedDownMbps.toFixed(1)
                        + "  ·  ↑ " + Services.NetworkService.speedUpMbps.toFixed(1) + " Mbps"
                    : Services.NetworkService.speedPhase === "error" ? "failed" : body._lastTestLine
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                color: Services.NetworkService.speedPhase === "error"
                       ? Config.ThemeConfig.colors.error
                       : Services.NetworkService.speedPhase === "done"
                         ? Config.ThemeConfig.colors.success
                         : (running ? Config.BarConfig.colorText : Config.BarConfig.colorTextDim)
                Layout.alignment: Qt.AlignRight
            }
            Text {
                visible: Services.NetworkService.speedPhase === "idle"
                         && body._lastTestLine !== ""
                text: "LAST RUN"
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(7); font.letterSpacing: 1.5
                color: Config.BarConfig.colorTextDim
                Layout.alignment: Qt.AlignRight
            }
        }
        Rectangle {
            readonly property bool running: Services.NetworkService.speedPhase === "download"
                                         || Services.NetworkService.speedPhase === "upload"
            width: runLbl.implicitWidth + Config.PopupMetrics.px(16)
            height: Config.PopupMetrics.px(22)
            radius: Config.PopupMetrics.px(5)
            color: runArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
            border.color: Config.BarConfig.colorBorder
            border.width: body._ok ? body.tray.hair : 1
            Text {
                id: runLbl
                anchors.centerIn: parent
                text: parent.running ? "STOP" : "RUN ›"
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(8); font.bold: true; font.letterSpacing: 1.2
                color: Config.BarConfig.colorText
            }
            MouseArea {
                id: runArea
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: parent.running ? Services.NetworkService.cancelSpeedTest()
                                          : Services.NetworkService.runSpeedTest()
            }
        }
    }

    Rectangle {
        visible: Services.NetworkService.hasNetwork
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(8)
        height: body._ok ? body.tray.hair : 1
        color: Config.ThemeConfig.hairline
    }

    // Named state (Omarchy): radio-off otherwise reads as a broken link
    Text {
        visible: Services.NetworkService.hasNetwork && !Services.NetworkService.wifiRadio
                 && !Services.NetworkService.isConnected
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(6)
        text: "Wi-Fi radio is off — enable it below"
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: Config.PopupMetrics.px(10); font.italic: true
        color: Config.BarConfig.colorTextDim
    }

    // ── Wi-Fi radio on/off toggle (full-width pill) ──────────────────────────
    Item { height: Config.PopupMetrics.px(10); visible: Services.NetworkService.hasNetwork }
    Rectangle {
        visible: Services.NetworkService.hasNetwork
        Layout.fillWidth: true
        Layout.preferredHeight: Config.PopupMetrics.px(34)
        radius: Config.PopupMetrics.px(6)
        color: {
            if (wifiBtnArea.containsMouse)
                return Services.NetworkService.wifiRadio ? Config.ThemeConfig.fillHover : Config.ThemeConfig.accentTint
            return Services.NetworkService.wifiRadio ? Config.ThemeConfig.fillRest : Config.ThemeConfig.accentTintSoft
        }
        border.color: Services.NetworkService.wifiRadio ? Config.BarConfig.colorBorder : Config.BarConfig.colorAccent
        border.width: body._ok ? body.tray.hair : 1
        Behavior on color { ColorAnimation { duration: 150 } }
        RowLayout {
            anchors.centerIn: parent
            spacing: Config.PopupMetrics.px(6)
            Text {
                text: Services.NetworkService.wifiRadio ? "\u{f05b2}" : "\u{f05a9}"
                font.family: Config.BarConfig.fontNerd
                font.pixelSize: Config.PopupMetrics.px(12)
                color: Services.NetworkService.wifiRadio ? Config.BarConfig.colorTextDim
                                                         : Config.BarConfig.colorAccent
            }
            Text {
                text: Services.NetworkService.wifiRadio ? "DISABLE WI-FI" : "ENABLE WI-FI"
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(8); font.bold: true; font.letterSpacing: 1.5
                color: Services.NetworkService.wifiRadio ? Config.BarConfig.colorTextDim
                                                         : Config.BarConfig.colorAccent
            }
        }
        MouseArea {
            id: wifiBtnArea
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: Services.NetworkService.toggleRadio()
        }
    }

    // ── NEARBY — top-5, connect KNOWN networks only (P4.1) ───────────────────
    // Frozen slice: the card list reassigns ONLY when membership changes (an
    // AP appears/vanishes). Live signal jitter would otherwise reset the
    // Repeater every sweep and eat clicks (array-identity law).
    CardFrame {
        visible: Services.NetworkService.hasNetwork && Services.NetworkService.wifiRadio
                 && body._nearList.length > 0
        title: "NEARBY"
        uiScale: Config.PopupMetrics.scale
        titleColor: Config.BarConfig.colorTextDim
        hairlineColor: Config.ThemeConfig.hairline
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(10)

        Repeater {
            model: body._nearList

            ListRow {
                // Inline member access ONLY (the Repeater idiom):
                // a delegate-side `property var net: modelData` capture does
                // not resolve here; `modelData.X` inline does.
                uiScale: Config.PopupMetrics.scale
                textColor: Config.BarConfig.colorText
                detailColor: Config.BarConfig.colorTextDim
                accentColor: Config.BarConfig.colorAccent
                glyph: modelData.security === "" ? "\u{f05a9}" : "\u{f05aa}"
                glyphColor: Config.BarConfig.colorTextDim
                title: modelData.ssid
                detail: (modelData.known ? "SAVED  ·  " : "")
                        + (modelData.security === "" ? "OPEN" : modelData.security)
                        + "  ·  " + modelData.signal + "%"
                dimmed: Services.NetworkService.connectingTo === modelData.ssid
                onClicked: {
                    if (!modelData.known) { body.settingsRequested("openControlNetwork"); return }
                    Services.NetworkService.connectWifi(modelData.ssid, "")
                }
            }
        }

        Text {
            visible: body._hasUnknown
            Layout.fillWidth: true
            text: "Password-protected networks: JOIN IN SETTINGS ›"
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: Config.PopupMetrics.px(8); font.italic: true
            color: Config.BarConfig.colorTextDim
        }
    }

    // ── QR SHARE — the current network's credentials (P4.1) ──────────────────
    Text {
        visible: body._wifiLink
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(10)
        text: body._qrOpen ? "HIDE QR ▴" : "QR SHARE ▾"
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: Config.PopupMetrics.px(8); font.bold: true; font.letterSpacing: 1.5
        horizontalAlignment: Text.AlignHCenter
        color: qrArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
        MouseArea {
            id: qrArea
            anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                body._qrOpen = !body._qrOpen
                if (body._qrOpen) Services.NetworkService.generateQr()
            }
        }
    }
    Rectangle {
        visible: body._qrOpen && body._wifiLink && Services.NetworkService.qrMatrix.length > 0
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Config.PopupMetrics.px(8)
        width: Services.NetworkService.qrMatrix.length > 0
               ? Services.NetworkService.qrMatrix[0].length * Config.PopupMetrics.px(3)
                 + Config.PopupMetrics.px(3) * 2 * 2 : 100
        height: Services.NetworkService.qrMatrix.length > 0
                ? Services.NetworkService.qrMatrix.length * Config.PopupMetrics.px(3)
                  + Config.PopupMetrics.px(3) * 2 * 2 : 50
        color: "#ffffff"
        Grid {
            anchors.centerIn: parent
            columns: Services.NetworkService.qrMatrix.length > 0
                     ? Services.NetworkService.qrMatrix[0].length : 0
            visible: Services.NetworkService.qrMatrix.length > 0
            Repeater {
                model: Services.NetworkService.qrMatrix.length > 0
                       ? Services.NetworkService.qrMatrix[0].length * Services.NetworkService.qrMatrix.length : 0
                Rectangle {
                    readonly property int cols: Services.NetworkService.qrMatrix.length > 0
                                                ? Services.NetworkService.qrMatrix[0].length : 1
                    readonly property int row: Math.floor(index / cols)
                    readonly property int col: index % cols
                    readonly property bool dark: {
                        var line = Services.NetworkService.qrMatrix[row] || ""
                        return col < line.length && line.charAt(col) === "1"
                    }
                    width: Config.PopupMetrics.px(3); height: Config.PopupMetrics.px(3)
                    color: dark ? "#1a1a1a" : "#ffffff"
                }
            }
        }
    }

    // "OPEN IN SETTINGS ›" — hidden networks, joining unknown, DNS/QR editor
    SettingsLinkRow {
        visible: Services.NetworkService.hasNetwork
        onActivated: function(verb) { body.settingsRequested(verb) }
    }

    // (moved verbatim from TrayCard — its inline component isn't shareable)
    component SettingsLinkRow: Item {
        id: link
        property string verb: "openControlNetwork"
        signal activated(string verb)
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(10)
        implicitHeight: Config.PopupMetrics.px(20)
        implicitWidth: linkTxt.implicitWidth
        Text {
            id: linkTxt
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: "OPEN IN SETTINGS ›"
            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
            font.bold: true; font.letterSpacing: 1.5
            color: linkArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
        }
        MouseArea {
            id: linkArea; anchors.fill: linkTxt; anchors.margins: -4; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.activated(link.verb)
        }
    }

    // ── derived readouts ──────────────────────────────────────────────────────
    readonly property string heroSsid: {
        var s = Services.NetworkService
        if (!s.isConnected) return "Not connected"
        return s.ssid !== "" ? s.ssid : (s.iface !== "" ? s.iface : "Connected")
    }
    readonly property string heroStatus: {
        var s = Services.NetworkService
        if (s.isConnected && s.connectionType === "wifi")
            return "CONNECTED · " + s.signalStrength + "%"
        if (s.isConnected) return "WIRED · CONNECTED"
        if (!s.wifiRadio) return "WI-FI RADIO OFF"
        return "JOIN IN SETTINGS ›"
    }

    // Last-60s slice of the service history rings → Sparkline samples.
    readonly property var _rxSamples: body._tail60(Services.NetworkService.rxHistory)
    readonly property var _txSamples: body._tail60(Services.NetworkService.txHistory)
    function _tail60(h) {
        var cutoff = Date.now() - 60000
        var out = []
        for (var i = 0; i < h.length; i++) if (h[i].time > cutoff) out.push(h[i].value)
        return out
    }

    // Session totals (since shell start, service-owned MB accumulators).
    readonly property string _sessionRx: Services.NetworkService.rxTotalMB >= 1024
        ? (Services.NetworkService.rxTotalMB / 1024).toFixed(2) + " GB"
        : Services.NetworkService.rxTotalMB.toFixed(1) + " MB"
    readonly property string _sessionTx: Services.NetworkService.txTotalMB >= 1024
        ? (Services.NetworkService.txTotalMB / 1024).toFixed(2) + " GB"
        : Services.NetworkService.txTotalMB.toFixed(1) + " MB"

    // Persisted last speed test — "↓x · ↑y Mbps · Nm ago" or "".
    readonly property string _lastTestLine: {
        var t = Services.NetworkService.lastTest
        if (!t || !t.downMbps) return ""
        var age = Math.max(0, Math.round((Date.now() - t.ts) / 60000))
        var ageStr = age >= 60 ? Math.round(age / 60) + "h" : age + "m"
        return "↓ " + Number(t.downMbps).toFixed(1) + " · ↑ " + Number(t.upMbps).toFixed(1)
               + " Mbps  ·  " + ageStr + " ago"
    }

    // Membership-diffed NEARBY slice (top 5, current link excluded).
    property var _nearList: []
    property string _nearKey: ""
    property bool _qrOpen: false
    readonly property bool _hasUnknown: {
        for (var i = 0; i < _nearList.length; i++)
            if (!_nearList[i].known && _nearList[i].security !== "") return true
        return false
    }
    // The slice reassigns ONLY when membership changes (an AP appears/vanishes,
    // a network gains/loses SAVED, radio flips, card reopens). Live signal
    // jitter never touches it — the Repeater keeps its delegates mid-click.
    on_WifiLinkChanged: body._nearKey = ""
    Connections {
        target: Services.NetworkService
        function onWifiNetworksChanged() {
            var rows = Services.NetworkService.wifiNetworks
            var picked = []
            for (var i = 0; i < rows.length && picked.length < 5; i++)
                if (!rows[i].inUse) picked.push(rows[i])
            var key = ""
            for (var j = 0; j < picked.length; j++)
                key += picked[j].ssid + "|" + picked[j].known + "|" + picked[j].security + ";"
            if (key === body._nearKey) return
            body._nearKey = key
            body._nearList = picked          // reassign on membership change only
        }
        function onWifiRadioChanged() { body._nearKey = "" }
        // Reopening the card refreshes the frozen slice against the fresh scan.
        function onPopupOpenChanged() {
            if (Services.NetworkService.popupOpen) { body._nearKey = ""; body._qrOpen = false }
        }
    }
}
