// =============================================================================
// NetworkCardBody.qml — NETWORK tray body: the glance layer (H1)
// =============================================================================
// Layering rule (report §1.1): the tray card shows STATE — the hero
// (SSID · signal % · DISCONNECT), IP and rx/tx rates, the wifi radio toggle
// and the bar-owned speed test — plus the deep link. Scanning, the AP list
// and joining (inline password, SAVED/lock chips) live ONLY in the settings
// app's WifiListView; a second scanner here was a full duplicate.
//
// The hero's live SSID/signal ride NetworkService's scanner lease
// (popupOpen): device.networks only exists while the wifi scanner runs, so
// the lease stays — it feeds the hero, not a list.
//
// Speed test: bar XHR ladder (NetworkService.runSpeedTest, no fork, up+down).
// The last completed run is persisted to
// $XDG_STATE_HOME/velocity/speedtest.json so settings can show "last test"
// and re-trigger it via the `network speedtest` IPC.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../config" as Config

ColumnLayout {
    id: body

    property var tray: null                       // the TrayCard (hair, tokens)
    signal settingsRequested(string verb)

    readonly property bool _ok: tray !== null
    readonly property real _hair: _ok ? tray.hair : 1
    readonly property var _net: Services.NetworkService

    spacing: 0

    // ── detail row — label left · value right (the body's original idiom) ──
    component NetRow: Item {
        property string label: ""
        property string value: "—"
        property bool valueBold: true
        property color valueColor: Config.BarConfig.colorText
        implicitWidth: lblTxt.implicitWidth + valTxt.implicitWidth + 16
        Layout.fillWidth: true
        Layout.preferredHeight: Config.PopupMetrics.px(28)
        Text {
            id: lblTxt
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(10)
            font.letterSpacing: 1
            color: Config.BarConfig.colorTextDim
        }
        Text {
            id: valTxt
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(13)
            font.bold: parent.valueBold
            color: parent.valueColor
            elide: Text.ElideMiddle
            width: Math.min(implicitWidth, parent.width * 0.7)
            horizontalAlignment: Text.AlignRight
        }
    }

    // ── HERO — the current link (glyph tile · SSID · state · live signal %) ──
    RowLayout {
        visible: Services.NetworkService.hasNetwork
        Layout.fillWidth: true
        spacing: Config.PopupMetrics.px(12)

        Rectangle {
            Layout.preferredWidth: Config.PopupMetrics.px(44)
            Layout.preferredHeight: Config.PopupMetrics.px(44)
            radius: Config.PopupMetrics.px(8)
            color: Config.ThemeConfig.fillRest
            border.color: Config.BarConfig.colorBorder; border.width: body._hair
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
        // live signal (wifi link only) — the hero's "%", replacing the old row
        ColumnLayout {
            visible: Services.NetworkService.isConnected
                     && Services.NetworkService.connectionType === "wifi"
            spacing: 0
            Text {
                text: Services.NetworkService.signalStrength + "%"
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(20); font.bold: true
                color: Config.BarConfig.colorText
                Layout.alignment: Qt.AlignRight
            }
            Text {
                text: "SIGNAL"
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(7); font.letterSpacing: 1.5
                color: Config.BarConfig.colorTextDim
                Layout.alignment: Qt.AlignRight
            }
        }
        Text {
            // upstream's destructive hero action — wifi only
            visible: Services.NetworkService.isConnected
                     && Services.NetworkService.connectionType === "wifi"
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

    // ── link diagnostics (popup-gated probes, unchanged) ─────────────────────
    NetRow {
        visible: Services.NetworkService.isConnected
        label: "IP"
        value: Services.NetworkService.ipAddress !== "" ? Services.NetworkService.ipAddress : "—"
    }
    NetRow {
        visible: Services.NetworkService.isConnected
        label: "↓ DOWNLOAD"
        value: Services.NetworkService.rxRate === ""
              ? "—" : Services.NetworkService.rxRate + "  ·  " + Services.NetworkService.rxTotal
        valueBold: false
    }
    NetRow {
        visible: Services.NetworkService.isConnected
        label: "↑ UPLOAD"
        value: Services.NetworkService.txRate === ""
              ? "—" : Services.NetworkService.txRate + "  ·  " + Services.NetworkService.txTotal
        valueBold: false
    }

    // ── SPEED TEST — panel-gated XHR probe (qsbar CloudflareSpeedTest, MIT) ──
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
        Text {
            readonly property bool running: Services.NetworkService.speedPhase === "download"
                                         || Services.NetworkService.speedPhase === "upload"
            text: running ? "testing…"
                : Services.NetworkService.speedPhase === "done"
                  ? "↓ " + Services.NetworkService.speedDownMbps.toFixed(1)
                    + "  ·  ↑ " + Services.NetworkService.speedUpMbps.toFixed(1) + " Mbps"
                : Services.NetworkService.speedPhase === "error" ? "failed" : ""
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
            color: Services.NetworkService.speedPhase === "error"
                   ? Config.ThemeConfig.colors.error
                   : Services.NetworkService.speedPhase === "done"
                     ? Config.ThemeConfig.colors.success : Config.BarConfig.colorTextDim
            Layout.alignment: Qt.AlignVCenter
        }
        Rectangle {
            readonly property bool running: Services.NetworkService.speedPhase === "download"
                                         || Services.NetworkService.speedPhase === "upload"
            width: runLbl.implicitWidth + Config.PopupMetrics.px(16)
            height: Config.PopupMetrics.px(22)
            radius: Config.PopupMetrics.px(5)
            color: runArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
            border.color: Config.BarConfig.colorBorder; border.width: body._hair
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
        height: body._hair
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
        border.width: body._hair
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

    // "OPEN IN SETTINGS ›" — joining/scanning/DNS/QR live there (H1 split)
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
}
