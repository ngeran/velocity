// =============================================================================
// NetworkCardBody.qml — NETWORK tray body (C3 upstream-Ryoku adaptation)
// =============================================================================
// Mechanisms adapted from upstream's shared NetworkPopout + qsbar's
// NetworkPanel/CloudflareSpeedTest (MIT, credit Ryoku) onto our contracts
// (native Quickshell.Networking — no daemon, no nmcli in the popup):
//
//   ┌─ HERO  [glyph tile] SSID            82 % ┐   signal hero (the joined
//   │              CONNECTED · 82%   DISCONNECT│   link; % is live, native)
//   │  IP x.x.x.x · ↓ rate · ↑ rate            │   popup-gated probes
//   │  SPEED TEST            ↓ 234.1 · …  RUN ›│   panel-gated XHR test
//   │  NETWORKS · 5                            │
//   │  󰤨 eduroam        󰌾            74 % …    │   AP rows: glyph + SSID +
//   │     [password ••••••••     CONNECT  ✕]   │   inline password expansion
//   │  [        DISABLE WI-FI              ]   │   radio pill
//   └──────────────────────────────────────────┘
//
// Join flow is FULLY native on the WifiNetwork QObject: known/open rows
// connect() with the saved profile; secured+unknown rows expand an inline
// password and connectWithPsk(psk). stateChanging is the native connecting
// spinner; connectionFailed(reason) maps to the row's error line. The list
// is best-per-SSID (Model.groupAps), FROZEN while a password is half-typed
// and diff-gated by Model.apsSignature — the wifi-list array-identity law
// (this list regressed twice before the freeze existed; do not "simplify").
//
// Keyboard: the host window flips WlrKeyboardFocus to OnDemand while
// keyboardWanted (a password field is focused) — upstream's "on-demand
// keyboard while open". hoverPause tells the Popover to hold its 450ms
// hover-out close so typing with the cursor elsewhere cannot kill the card.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import "../services" as Services
import "../config" as Config
import "../services/NetworkModel.js" as Model

ColumnLayout {
    id: body

    property var tray: null                       // the TrayCard (hair, tokens)
    signal settingsRequested(string verb)

    readonly property bool _ok: tray !== null
    readonly property real _hair: _ok ? tray.hair : 1
    readonly property var _net: Services.NetworkService

    // Live-scan grouping, frozen while editing + content-diff gated.
    readonly property var groupedAps: Model.groupAps(_net.aps, _net.ssid)
    readonly property string apSig: Model.apsSignature(groupedAps)
    property var frozenAps: []
    property string _lastSig: ""
    property string editingSsid: ""               // which row shows the password
    readonly property bool keyboardWanted: editingSsid !== ""
    readonly property int maxRows: 8

    onApSigChanged: if (editingSsid === "" && apSig !== _lastSig) {
        _lastSig = apSig
        frozenAps = groupedAps
    }
    onEditingSsidChanged: if (editingSsid === "" && apSig !== _lastSig) {
        _lastSig = apSig
        frozenAps = groupedAps
    }
    Component.onCompleted: { _lastSig = apSig; frozenAps = groupedAps }

    // A join that lands (or a disconnect) always closes the password row.
    Connections {
        target: Services.NetworkService
        function onActiveNetChanged() { body.editingSsid = "" }
        function onPopupOpenChanged() {
            if (!Services.NetworkService.popupOpen) body.editingSsid = ""
        }
    }

    // SCANNING — the scanner lease warms on open; claim it until the first
    // rows land or 15s passes (upstream's scanClear), then say "no networks".
    Timer {
        id: scanGrace
        interval: 15000
        running: Services.NetworkService.popupOpen && Services.NetworkService.hasNetwork
                 && Services.NetworkService.wifiRadio && body.frozenAps.length === 0
    }
    readonly property bool scanning: scanGrace.running

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

    // ── NETWORKS header ──────────────────────────────────────────────────────
    RowLayout {
        visible: Services.NetworkService.hasNetwork && Services.NetworkService.wifiRadio
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(10)
        Text {
            text: body.scanning ? "NETWORKS · SCANNING" : "NETWORKS"
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: Config.PopupMetrics.px(8); font.bold: true; font.letterSpacing: 1.5
            color: Config.BarConfig.colorTextDim
        }
        Item { Layout.fillWidth: true }
        Text {
            visible: body.frozenAps.length > 0
            text: body.frozenAps.length + " IN RANGE"
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 1
            color: Config.BarConfig.colorTextDim
        }
    }

    // ── AP rows (best-per-SSID · frozen while editing) ───────────────────────
    Repeater {
        model: body.frozenAps.slice(0, body.maxRows)

        delegate: ColumnLayout {
            id: apRow
            required property var modelData
            readonly property bool editing: body.editingSsid === modelData.name
            readonly property int pct: modelData.pct
            readonly property bool liveChanging: modelData.net.stateChanging
            property string errorText: ""
            spacing: 0
            Layout.fillWidth: true

            // wrong-password / failure line lives under the row it belongs to
            Connections {
                target: apRow.modelData.net
                function onConnectionFailed(reason) {
                    if (!apRow.editing) return
                    apRow.errorText = Model.failLabel(ConnectionFailReason.toString(reason))
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Config.PopupMetrics.px(30)
                radius: Config.PopupMetrics.px(6)
                color: apTap.containsMouse || apRow.editing
                       ? Config.ThemeConfig.fillHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Config.PopupMetrics.px(10)
                    anchors.rightMargin: Config.PopupMetrics.px(10)
                    spacing: Config.PopupMetrics.px(8)

                    Text {
                        text: Model.sigGlyph(apRow.pct)
                        font.family: Config.BarConfig.fontNerd
                        font.pixelSize: Config.PopupMetrics.px(12)
                        color: apRow.pct >= 60 ? Config.BarConfig.colorText
                                               : Config.BarConfig.colorTextDim
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: apRow.modelData.name
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: Config.PopupMetrics.px(10)
                        color: Config.BarConfig.colorText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: apRow.modelData.known
                        text: "SAVED"
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: Config.PopupMetrics.px(7); font.letterSpacing: 1
                        color: Config.BarConfig.colorTextDim
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        visible: apRow.modelData.secured
                        text: "\u{f033e}"
                        font.family: Config.BarConfig.fontNerd
                        font.pixelSize: Config.PopupMetrics.px(10)
                        color: Config.BarConfig.colorTextDim
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        visible: apRow.liveChanging
                        text: "…"
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: Config.PopupMetrics.px(11); font.bold: true
                        color: Config.BarConfig.colorAccent
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        visible: !apRow.liveChanging
                        text: apRow.pct + "%"
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: Config.PopupMetrics.px(9)
                        color: Config.BarConfig.colorTextDim
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
                MouseArea {
                    id: apTap
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var d = apRow.modelData
                        if (d.known || !d.secured) {
                            body.editingSsid = ""
                            d.net.connect()          // saved profile / open join
                        } else {
                            body.editingSsid = apRow.editing ? "" : d.name
                            if (body.editingSsid !== "")
                                Qt.callLater(function() { if (pwField) pwField.forceActiveFocus() })
                        }
                    }
                }
            }

            // ── inline password expansion (secured, unsaved) ─────────────────
            Rectangle {
                visible: apRow.editing
                Layout.fillWidth: true
                Layout.preferredHeight: Config.PopupMetrics.px(34)
                Layout.bottomMargin: apRow.errorText !== "" ? Config.PopupMetrics.px(16) : 0
                radius: Config.PopupMetrics.px(6)
                color: Config.ThemeConfig.fillRest
                border.color: Config.BarConfig.colorBorder; border.width: body._hair

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Config.PopupMetrics.px(10)
                    anchors.rightMargin: Config.PopupMetrics.px(8)
                    spacing: Config.PopupMetrics.px(8)

                    Text {
                        text: "\u{f033e}"
                        font.family: Config.BarConfig.fontNerd
                        font.pixelSize: Config.PopupMetrics.px(10)
                        color: Config.BarConfig.colorTextDim
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Config.PopupMetrics.px(22)
                        radius: Config.PopupMetrics.px(3)
                        color: Config.ThemeConfig.accentTintSoft
                        border.color: pwField.activeFocus
                                      ? Config.BarConfig.colorAccent : Config.BarConfig.colorBorder
                        border.width: body._hair
                        TextInput {
                            id: pwField
                            property var row: apRow
                            anchors.fill: parent
                            anchors.leftMargin: Config.PopupMetrics.px(8)
                            anchors.rightMargin: Config.PopupMetrics.px(8)
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Config.BarConfig.colorText
                            font.family: Config.BarConfig.fontFamily
                            font.pixelSize: Config.PopupMetrics.px(10)
                            clip: true
                            Keys.onEscapePressed: { body.editingSsid = ""; text = "" }
                            onAccepted: apRow.join()
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: pwField.text === "" && !pwField.activeFocus
                                text: "password"
                                font: pwField.font
                                color: Config.BarConfig.colorTextDim
                            }
                        }
                    }
                    Text {
                        text: "CONNECT"
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: Config.PopupMetrics.px(8); font.bold: true
                        color: Config.BarConfig.colorAccent
                        Layout.alignment: Qt.AlignVCenter
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: apRow.join()
                        }
                    }
                    Text {
                        text: "✕"
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: Config.PopupMetrics.px(10)
                        color: Config.BarConfig.colorTextDim
                        Layout.alignment: Qt.AlignVCenter
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { body.editingSsid = ""; pwField.text = "" }
                        }
                    }
                }
            }
            Text {
                visible: apRow.editing && apRow.errorText !== ""
                Layout.fillWidth: true
                text: apRow.errorText
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(8)
                color: Config.ThemeConfig.colors.error
                elide: Text.ElideRight
                Layout.leftMargin: Config.PopupMetrics.px(10)
                Layout.topMargin: Config.PopupMetrics.px(2)
            }

            function join() {
                var d = apRow.modelData
                if (d.known || !d.secured) { d.net.connect(); return }
                var pw = pwField.text
                apRow.errorText = ""
                d.net.connectWithPsk(pw)
                // Editing stays open until an outcome: stateChanging shows the
                // spinner, connectionFailed paints the error, success flips the
                // service's activeNet (which closes every expansion).
            }
        }
    }

    // empty / overflow states
    Text {
        visible: Services.NetworkService.hasNetwork && Services.NetworkService.wifiRadio
                 && body.frozenAps.length === 0
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(6)
        horizontalAlignment: Text.AlignHCenter
        text: body.scanning ? "Scanning…" : "No networks found"
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: Config.PopupMetrics.px(9); font.italic: true
        color: Config.BarConfig.colorTextDim
    }
    Text {
        visible: body.frozenAps.length > body.maxRows
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(2)
        horizontalAlignment: Text.AlignHCenter
        text: "+" + (body.frozenAps.length - body.maxRows) + " MORE — Settings ▸ Network"
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: Config.PopupMetrics.px(8)
        color: Config.BarConfig.colorTextDim
    }

    // Named state (Omarchy): radio-off otherwise reads as a broken empty list
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

    // "OPEN IN SETTINGS ›" — the full manager (networks/DNS/QR) lives there
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
        return "CHOOSE A NETWORK"
    }
}
