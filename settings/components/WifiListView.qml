// =============================================================================
// WifiListView.qml — NETWORK section: Network Monitor (Omarchy mockup port)
// =============================================================================
//   HEADER          glyph tile · SSID · ONLINE badge · band/security line ·
//                   QR button · wifi power toggle
//   TELEMETRY       4×2 label/value pairs — ping · loss · rx ↓ · tx ↑ ·
//                   downloaded · uploaded · ip · gateway
//   DNS PROVIDER    DHCP | Cloudflare | Google | Custom segmented control
//                   (nmcli con mod + con up; Custom = inline servers input)
//   SPEED TEST      label · Run › button · result
//   KNOWN NETWORKS  the connected profile card
//   OTHER NETWORKS  scan rows — click to connect (secured ⇒ inline password;
//                   list FROZEN while typing — Repeater array-identity trap)
//   QR OVERLAY      white matrix card (qrencode) toggled from the header
//
// Backed by Services.NetworkControlService. All colours are live ThemeConfig
// tokens. List freeze/capacity logic preserved (see memory notes — do not
// "simplify" it back to a live binding).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

// Root is an Item SHELL: the layout fills it, and the QR overlay is a
// SIBLING — a full-view overlay can neither use anchors inside a ColumnLayout
// nor occupy a layout slot of its own.
Item {
    id: viewRoot

    ColumnLayout {
        id: view
        anchors.fill: parent
        spacing: Config.ControlConfig.space2

    readonly property var cs: Services.NetworkControlService.connectionStatus
    readonly property var svc: Services.NetworkControlService
    readonly property bool linkUp: view.cs.connected === true

    function fmtRate(kbps) {
        return kbps < 1024 ? kbps.toFixed(0) + " KB/s" : (kbps / 1024).toFixed(1) + " MB/s"
    }
    function fmtTotal(mb) { return mb >= 1024 ? (mb / 1024).toFixed(2) + " GB" : mb.toFixed(1) + " MB" }

    // Nerd-font wifi-strength glyphs (4 bars → 1 bar → offline)
    function sigIcon(s) {
        return !view.linkUp && s === 0 ? "󰤭"
             : s >= 70 ? "󰤨" : s >= 40 ? "󰤥" : s >= 20 ? "󰤢" : "󰤟"
    }

    // Status line under the SSID — band • security • link speed.
    readonly property string statusLine: {
        if (!view.linkUp) return view.cs.wifiEnabled ? "not connected" : "wifi radio off"
        var parts = []
        if (view.cs.band !== "") parts.push(view.cs.band.replace(" ", "").toUpperCase())
        if (view.cs.security !== "") parts.push(view.cs.security.toUpperCase())
        if (view.cs.linkSpeed !== "") parts.push(view.cs.linkSpeed.toUpperCase())
        return parts.length ? parts.join("  •  ") : "connected"
    }

    // ── list state ──────────────────────────────────────────────────────────
    property bool anyRowEditing: false
    property string editingSsid: ""    // which OTHER row shows the password field

    readonly property var otherNets: {
        var all = Services.NetworkControlService.wifiNetworks
        var out = []
        for (var i = 0; i < all.length; i++)
            if (!all[i].inUse && all[i].ssid !== "") out.push(all[i])
        out.sort(function(a, b) { return b.signal - a.signal })
        return out
    }

    // HELD FROZEN while a row edits its password (array identity resets the
    // Repeater and kills the half-typed password — see file header).
    property var frozenNets: []
    onOtherNetsChanged: if (!anyRowEditing) frozenNets = otherNets
    onAnyRowEditingChanged: if (!anyRowEditing && frozenNets !== otherNets) frozenNets = otherNets
    Component.onCompleted: frozenNets = otherNets

    property bool showQr: false
    onShowQrChanged: if (showQr) Services.NetworkControlService.generateQr()

    // ── shared bits ──────────────────────────────────────────────────────────
    component SectionLabel: Text {
        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
        font.bold: true; font.letterSpacing: 1.6
        color: Config.ThemeConfig.colors.textDim
    }

    component TelemetryCell: ColumnLayout {
        id: tcell
        property string label: ""
        property string value: "—"
        property string unit: ""        // rendered after the value, dimmer
        property color valueColor: Config.ThemeConfig.colors.text
        spacing: 2
        // Equal quarters of the view width (3 × 12px column spacing).
        Layout.preferredWidth: (view.width - 3 * 12) / 4
        Text {
            text: tcell.label
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
            font.bold: true; font.letterSpacing: 1.4
            color: Config.ThemeConfig.colors.textDim
        }
        Row {
            spacing: 4
            Text {
                id: valTxt
                text: tcell.value
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 13
                font.bold: true; color: tcell.valueColor
            }
            Text {
                text: tcell.unit; visible: tcell.unit !== ""
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                color: tcell.valueColor
                anchors.baseline: valTxt.baseline
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 1. HEADER — glyph tile · SSID · badge · status line · QR · power toggle
    // ═════════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        // Glyph tile
        Rectangle {
            Layout.preferredWidth: 44; Layout.preferredHeight: 44
            radius: Config.ControlConfig.radiusSmall
            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.7)
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            Text {
                anchors.centerIn: parent
                text: view.cs.wifiEnabled ? view.sigIcon(view.cs.signal) : "󰤭"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 20
                color: view.linkUp ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.textDim
            }
        }

        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true

            RowLayout {
                spacing: 8
                Text {
                    text: view.cs.ssid !== "" ? view.cs.ssid : (view.cs.iface !== "" ? view.cs.iface : "No connection")
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 14
                    font.bold: true; color: Config.ThemeConfig.colors.text
                    elide: Text.ElideRight
                    Layout.maximumWidth: 260
                }
                // ONLINE / OFFLINE badge
                Rectangle {
                    width: badgeLbl.implicitWidth + 14; height: 17; radius: 3
                    visible: view.linkUp
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.14)
                    border.color: Config.ThemeConfig.colors.success; border.width: 1
                    Text {
                        id: badgeLbl; anchors.centerIn: parent
                        text: "ONLINE"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                        font.bold: true; font.letterSpacing: 1.2
                        color: Config.ThemeConfig.colors.success
                    }
                }
            }

            Text {
                text: view.statusLine
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                font.letterSpacing: 1.6
                color: Config.ThemeConfig.colors.textDim
            }
        }

        Item { Layout.fillWidth: true }

        // QR button — toggles the share-code overlay
        Rectangle {
            Layout.preferredWidth: 34; Layout.preferredHeight: 34
            radius: Config.ControlConfig.radiusSmall
            color: qrMa.containsMouse || view.showQr
                   ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16)
                   : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.7)
            border.color: qrMa.containsMouse || view.showQr
                          ? Config.ControlConfig.accent
                          : Config.ThemeConfig.colors.outlineVariant
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
                anchors.centerIn: parent
                text: "󰀄"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 15
                color: view.showQr ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
            }
            MouseArea {
                id: qrMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.showQr = !view.showQr
            }
        }

        // Wi-Fi power toggle
        ToggleSwitch {
            checked: view.cs.wifiEnabled
            Layout.alignment: Qt.AlignVCenter
            onToggled: Services.NetworkControlService.toggleWifi()
        }
    }

    Hairline {}
    component Hairline: Rectangle {
        Layout.fillWidth: true; height: 1
        color: Config.ThemeConfig.colors.outlineVariant
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 2. TELEMETRY — 4×2 label/value pairs (mockup: no boxes, plain pairs).
    // GridLayout + explicit preferredWidth: a plain Grid is a POSITIONER
    // (Layout.fillWidth is invisible to it), and nested-ColumnLayout cells
    // refuse fillWidth expansion — same trap as the weather outlook.
    // ═════════════════════════════════════════════════════════════════════════
    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 12
        rowSpacing: 10

        TelemetryCell { label: "PING"
            value: view.svc.latencyMs >= 0 ? Math.round(view.svc.latencyMs) + " ms" : "—" }
        TelemetryCell { label: "PACKET LOSS"
            value: view.svc.latencyMs >= 0 ? view.svc.lossPct.toFixed(0) + "%" : "—" }
        TelemetryCell { label: "RECEIVING"
            value: view.fmtRate(view.svc.rxRate)
            unit: "↓"; valueColor: Config.ThemeConfig.colors.primary }
        TelemetryCell { label: "SENDING"
            value: view.fmtRate(view.svc.txRate)
            unit: "↑"; valueColor: Config.ThemeConfig.colors.primary }
        TelemetryCell { label: "DOWNLOADED"
            value: view.fmtTotal(view.svc.rxTotalMB) }
        TelemetryCell { label: "UPLOADED"
            value: view.fmtTotal(view.svc.txTotalMB) }
        TelemetryCell { label: "IP ADDRESS"
            value: view.cs.ip !== "" ? view.cs.ip : "—" }
        TelemetryCell { label: "GATEWAY"
            value: view.cs.gateway !== "" ? view.cs.gateway : "—" }
    }

    Hairline {}

    // ═════════════════════════════════════════════════════════════════════════
    // 3. DNS PROVIDER — DHCP | Cloudflare | Google | Custom
    // ═════════════════════════════════════════════════════════════════════════
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SectionLabel { text: "DNS PROVIDER" }
            Text {
                visible: view.svc.dnsResult !== ""
                text: view.svc.dnsResult
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                color: Config.ThemeConfig.colors.textDim
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { key: "dhcp",      label: "DHCP" },
                    { key: "cloudflare", label: "Cloudflare" },
                    { key: "google",    label: "Google" },
                    { key: "custom",    label: "Custom" }
                ]

                delegate: Rectangle {
                    // Inline-literal model → implicit modelData (the required-
                    // property form breaks with JS-array models — memory note).
                    readonly property var seg: modelData
                    readonly property bool on: view.svc.dnsMode === seg.key
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: Config.ControlConfig.radiusSmall
                    color: on ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.9)
                              : segMa.containsMouse
                                ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                                : "transparent"
                    border.color: on ? Config.ControlConfig.accent
                                     : Config.ThemeConfig.colors.outlineVariant
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: parent.seg.label
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                        font.bold: parent.on
                        color: parent.on ? Config.ThemeConfig.colors.text
                                         : Config.ThemeConfig.colors.textDim
                    }

                    MouseArea {
                        id: segMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.seg.key === "custom") {
                                view.svc.dnsMode = "custom"
                            } else if (!parent.on) {
                                view.svc.applyDns(parent.seg.key, "")
                            }
                        }
                    }
                }
            }
        }

        // Custom servers input — visible in custom mode
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: view.svc.dnsMode === "custom"

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                radius: Config.ControlConfig.radiusSmall
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.7)
                border.color: customInput.activeFocus ? Config.ControlConfig.accent
                                                      : Config.ThemeConfig.colors.outlineVariant
                border.width: 1
                TextInput {
                    id: customInput
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Config.ThemeConfig.colors.text
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                    text: view.svc.customDns
                    selectByMouse: true
                    onEditingFinished: view.svc.customDns = text
                    Text {
                        anchors.fill: parent; visible: parent.text === ""
                        text: "e.g. 9.9.9.9 149.112.112.112"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                        verticalAlignment: Text.AlignVCenter
                        color: Config.ThemeConfig.colors.textDim
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 70; Layout.preferredHeight: 26
                radius: Config.ControlConfig.radiusSmall
                color: applyMa.containsMouse
                       ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.2)
                       : Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.1)
                border.color: Config.ControlConfig.accent; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "APPLY"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                    font.bold: true; color: Config.ControlConfig.accent
                }
                MouseArea {
                    id: applyMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.svc.applyDns("custom", view.svc.customDns)
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 4. SPEED TEST — label · result · Run ›
    // ═════════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        SectionLabel { text: "SPEED TEST" }
        Item { Layout.fillWidth: true }
        Text {
            visible: view.svc.speedTesting
            text: "testing…"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }
        Text {
            visible: !view.svc.speedTesting && view.svc.speedTestResult !== ""
            text: view.svc.speedTestResult
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            font.bold: true
            color: Config.ThemeConfig.colors.success
        }
        Rectangle {
            Layout.preferredWidth: 74; Layout.preferredHeight: 26
            radius: Config.ControlConfig.radiusSmall
            color: runMa.containsMouse
                   ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.8)
                   : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            Row {
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: view.svc.speedTesting ? "…" : "Run"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                    font.bold: true; color: Config.ThemeConfig.colors.text
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "›"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                    color: Config.ThemeConfig.colors.textDim
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                id: runMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.svc.runSpeedTest()
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 5. KNOWN NETWORKS — the connected profile
    // ═════════════════════════════════════════════════════════════════════════
    SectionLabel { text: "KNOWN NETWORKS"; visible: view.linkUp }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        radius: Config.ControlConfig.radiusSmall
        visible: view.linkUp
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 10

            Text {
                text: view.sigIcon(view.cs.signal)
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 15
                color: Config.ThemeConfig.colors.success
            }
            // Plain Column POSITIONER — the nested-ColumnLayout-in-RowLayout
            // indented its children ~60px for no reason the layout docs
            // explain; a positioner pins them to the column's left edge.
            Column {
                spacing: 1
                Text {
                    text: view.cs.ssid
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                    font.bold: true; color: Config.ThemeConfig.colors.text
                    elide: Text.ElideRight; width: Math.min(implicitWidth, 320)
                }
                Text {
                    text: "Connected"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                    color: Config.ThemeConfig.colors.textDim
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "󰌾"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 12
                color: Config.ThemeConfig.colors.textDim
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 6. OTHER NETWORKS — click to switch (secured ⇒ inline password)
    // ═════════════════════════════════════════════════════════════════════════
    SectionLabel { text: "OTHER NETWORKS" }

    ColumnLayout {
        id: listViewport
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 2

        Repeater {
            model: view.frozenNets

            delegate: ColumnLayout {
                id: netRow
                required property var modelData
                readonly property bool editing: view.editingSsid === modelData.ssid
                readonly property bool connecting: view.svc.connectingTo === modelData.ssid
                Layout.fillWidth: true
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: Config.ControlConfig.radiusSmall
                    color: rowMa.containsMouse || netRow.editing
                           ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
                           : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: view.sigIcon(netRow.modelData.signal)
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 12
                            color: netRow.modelData.signal >= 60
                                   ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: netRow.modelData.ssid
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                            color: Config.ThemeConfig.colors.text
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: (netRow.modelData.band || "").replace(" ", "")
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                            color: Config.ThemeConfig.colors.textDim
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            visible: netRow.modelData.security !== ""
                            text: "󰌾"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                            color: Config.ThemeConfig.colors.textDim
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            visible: netRow.connecting
                            text: "…"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                            color: Config.ControlConfig.accent
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (netRow.modelData.security === "") {
                                view.svc.connectWifi(netRow.modelData.ssid, "")
                            } else {
                                view.editingSsid = netRow.editing ? "" : netRow.modelData.ssid
                            }
                        }
                    }
                }

                // Inline password row (secured networks) — freezes the list.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: netRow.editing ? 32 : 0
                    visible: netRow.editing
                    radius: Config.ControlConfig.radiusSmall
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
                    border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 8
                        spacing: 8
                        visible: netRow.editing

                        Text {
                            text: "󰌾"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                            color: Config.ThemeConfig.colors.textDim
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            radius: 3
                            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.9)
                            border.color: pwInput.activeFocus ? Config.ControlConfig.accent
                                                              : Config.ThemeConfig.colors.outlineVariant
                            border.width: 1
                            TextInput {
                                id: pwInput
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: Config.ThemeConfig.colors.text
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                                selectByMouse: true
                                onAccepted: view.svc.connectWifi(netRow.modelData.ssid, text)
                            }
                        }
                        Text {
                            text: "CONNECT"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                            font.bold: true; color: Config.ControlConfig.accent
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.svc.connectWifi(netRow.modelData.ssid, pwInput.text)
                            }
                        }
                        Text {
                            text: "✕"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                            color: Config.ThemeConfig.colors.textDim
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.editingSsid = ""
                            }
                        }
                    }
                }

                // Per-row connect error surfaced once, under the list.
            }
        }

        Text {
            Layout.fillWidth: true
            visible: view.svc.lastConnectError !== ""
            text: view.svc.lastConnectError
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
            color: Config.ThemeConfig.colors.error
            elide: Text.ElideRight
            Layout.leftMargin: 10
        }

        Text {
            Layout.leftMargin: 10
            visible: view.frozenNets.length === 0 && !view.svc.scanning
            text: view.linkUp ? "// no other networks in range" : "// connect to see networks"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.textDim
        }
    }

    }   // ColumnLayout (view)

    // ═════════════════════════════════════════════════════════════════════════
    // QR OVERLAY — share code for the connected network. Sibling of the
    // layout (NOT a layout child): anchors.fill is legal here.
    // ═════════════════════════════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        visible: view.showQr
        z: 20
        // settings ThemeConfig has no withAlpha — plain rgba from tokens.
        color: Qt.rgba(Config.ThemeConfig.colors.background.r,
                       Config.ThemeConfig.colors.background.g,
                       Config.ThemeConfig.colors.background.b, 0.88)

        MouseArea { anchors.fill: parent; onClicked: view.showQr = false }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: view.svc.qrSsid !== "" ? view.svc.qrSsid : "—"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 14
                font.bold: true; color: Config.ThemeConfig.colors.text
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: qrDraw.matrix.length > 0 ? qrDraw.matrix[0].length * qrDraw.modulePx + qrDraw.quiet * 2 * qrDraw.modulePx : 120
                height: qrDraw.matrix.length > 0 ? qrDraw.matrix.length * qrDraw.modulePx + qrDraw.quiet * 2 * qrDraw.modulePx : 60
                color: "#ffffff"
                radius: 4

                Grid {
                    id: qrDraw
                    property var matrix: view.svc.qrMatrix
                    property int modulePx: 4
                    property int quiet: 3
                    anchors.centerIn: parent
                    columns: matrix.length > 0 ? matrix[0].length : 0
                    visible: matrix.length > 0

                    Repeater {
                        model: qrDraw.matrix.length > 0 ? qrDraw.matrix[0].length * qrDraw.matrix.length : 0

                        Rectangle {
                            readonly property int row: Math.floor(index / (qrDraw.matrix.length > 0 ? qrDraw.matrix[0].length : 1))
                            readonly property int col: index % (qrDraw.matrix.length > 0 ? qrDraw.matrix[0].length : 1)
                            readonly property bool dark: {
                                if (qrDraw.matrix.length === 0 || row >= qrDraw.matrix.length) return false
                                var line = qrDraw.matrix[row] || ""
                                return col < line.length && line.charAt(col) === "1"
                            }
                            width: qrDraw.modulePx; height: qrDraw.modulePx
                            color: dark ? "#1a1a1a" : "#ffffff"
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: view.svc.qrMatrix.length === 0
                    text: view.svc.qrError !== "" ? view.svc.qrError : "generating…"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                    color: "#1a1a1a"
                    width: parent.width - 16
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Rectangle {
                    width: qrSecLbl.implicitWidth + 14; height: 18; radius: 3
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.15)
                    border.color: Config.ThemeConfig.colors.primary; border.width: 1
                    Text {
                        id: qrSecLbl; anchors.centerIn: parent
                        text: view.svc.qrSecurity !== "" ? view.svc.qrSecurity : "OPEN"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                        font.bold: true; color: Config.ThemeConfig.colors.primary
                    }
                }
                Text {
                    text: view.svc.qrPassword !== "" ? "P:" + view.svc.qrPassword : ""
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                    color: Config.ThemeConfig.colors.textDim
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                text: "click anywhere to close"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                color: Config.ThemeConfig.colors.textDim
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
