// =============================================================================
// NetworkEngineerView.qml — NETWORK section, engineer page (second tab)
// =============================================================================
// Link/PHY (iw), full addressing + DNS + DHCP, routes, interface counters,
// neighbors, listeners — one Flickable column of grouped sections, fed by
// NetworkControlService's aggregated engineer probe (15s while the network
// section is visible; REFRESH re-runs it on demand). All read-only:
// control surfaces (connect, DNS picker) live on the WIFI page.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: viewRoot

    readonly property var svc: Services.NetworkControlService
    readonly property bool hasIface: svc.connectionStatus.iface !== ""

    ColumnLayout {
        anchors.fill: parent
        spacing: Config.ControlConfig.space2
        visible: viewRoot.hasIface

        // ---- header row: title + refreshed-at + REFRESH ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.ControlConfig.space2

            Text {
                text: "󰛳"
                font.family: Config.ControlConfig.fontNerd
                font.pixelSize: 14
                color: Config.ThemeConfig.colors.secondary
            }
            Text {
                text: "NETWORK ENGINEER"
                font.family: Config.ControlConfig.fontSans
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 1.4
                color: Config.ThemeConfig.colors.text
            }
            Text {
                Layout.fillWidth: true
                text: svc.engRefreshedAt > 0
                      ? "·  sampled " + Math.max(0, Math.round((Date.now() - svc.engRefreshedAt) / 1000)) + "s ago"
                      : "·  sampling…"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9
                color: Config.ThemeConfig.colors.textDim
                opacity: 0.8
            }
            Rectangle {
                width: refLbl.implicitWidth + 18; height: 22
                radius: height / 2
                color: refArea.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.14) : "transparent"
                border.color: Config.ThemeConfig.colors.secondary; border.width: 1
                Text { id: refLbl; anchors.centerIn: parent
                    text: "REFRESH"
                    color: Config.ThemeConfig.colors.secondary
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                    font.bold: true; font.letterSpacing: 0.8 }
                MouseArea { id: refArea; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: { svc.refreshStatus(); svc.sampleEngineer() } }
            }
        }

        // ---- scrolling sections ----
        Flickable {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                width: scroll.width - 14   // right gutter keeps rows clear of the indicator
                spacing: Config.ControlConfig.space3

                // ── LINK & PHY ─────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.ControlConfig.space1
                    SectionHeader { Layout.fillWidth: true; title: "LINK & PHY" }
                    InfoStatRow { Layout.fillWidth: true; label: "CHANNEL"; value: svc.engLink.channel !== undefined ? svc.engLink.channel + " (" + (svc.engLink.freqMhz || 0) + " MHz)" : "—" }
                    InfoStatRow { Layout.fillWidth: true; label: "SIGNAL"; accentValue: true
                        value: svc.engLink.signalDbm !== undefined
                               ? svc.engLink.signalDbm + " dBm" + (svc.engLink.chains ? "  [" + svc.engLink.chains + "]" : "") : "—" }
                    InfoStatRow { Layout.fillWidth: true; label: "SIGNAL AVG"
                        value: svc.engLink.signalAvgDbm !== undefined ? svc.engLink.signalAvgDbm + " dBm" : "—" }
                    InfoStatRow { Layout.fillWidth: true; label: "BEACON AVG"
                        value: svc.engLink.beaconAvgDbm !== undefined ? svc.engLink.beaconAvgDbm + " dBm" : "—" }
                    InfoStatRow { Layout.fillWidth: true; label: "TX RATE"; accentValue: true
                        value: svc.engLink.txBitrate ? svc.engLink.txBitrate + (svc.engLink.txMcs ? "  ·  " + svc.engLink.txMcs : "") : "—" }
                    InfoStatRow { Layout.fillWidth: true; label: "RX RATE"
                        value: svc.engLink.rxBitrate || "—" }
                    InfoStatRow { Layout.fillWidth: true; label: "REG DOMAIN"; value: svc.engLink.regDomain || "—" }
                    InfoStatRow { Layout.fillWidth: true; label: "MTU"; value: svc.ifaceStats.mtu !== undefined ? String(svc.ifaceStats.mtu) : "—" }
                }

                // ── ADDRESSES & DNS ────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.ControlConfig.space1
                    SectionHeader { Layout.fillWidth: true; title: "ADDRESSES & DNS" }
                    Repeater {
                        model: svc.engAddr.v4 || []
                        delegate: InfoStatRow { required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            label: index === 0 ? "IPV4" : ""
                            value: modelData; accentValue: index === 0 }
                    }
                    Repeater {
                        model: svc.engAddr.v6 || []
                        delegate: InfoStatRow { required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            label: index === 0 ? "IPV6" : ""
                            value: modelData }
                    }
                    Repeater {
                        model: svc.engAddr.dnsServers || []
                        delegate: InfoStatRow { required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            label: index === 0 ? "DNS" : ""
                            value: modelData }
                    }
                    InfoStatRow { Layout.fillWidth: true; label: "SEARCH DOMAIN"; value: svc.engAddr.dnsDomain || "—" }
                    InfoStatRow { Layout.fillWidth: true; label: "DHCP SERVER"; value: svc.engAddr.dhcpServer || "—" }
                    InfoStatRow { Layout.fillWidth: true; label: "DHCP LEASE"
                        value: svc.engAddr.leaseHours !== undefined ? svc.engAddr.leaseHours + " h" : "—" }
                }

                // ── ROUTES ─────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    SectionHeader { Layout.fillWidth: true; title: "ROUTES (" + svc.engRoutes.length + ")" }
                    // column legend
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Config.ControlConfig.space2
                        Text { Layout.preferredWidth: 250; text: "DESTINATION"; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; color: Config.ThemeConfig.colors.textDim; opacity: 0.7 }
                        Text { Layout.preferredWidth: 140; text: "VIA / SRC"; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; color: Config.ThemeConfig.colors.textDim; opacity: 0.7 }
                        Text { Layout.preferredWidth: 90; text: "DEV"; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; color: Config.ThemeConfig.colors.textDim; opacity: 0.7 }
                        Text { Layout.preferredWidth: 60; text: "METRIC"; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; color: Config.ThemeConfig.colors.textDim; opacity: 0.7 }
                        Text { Layout.fillWidth: true; text: "PROTO"; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; color: Config.ThemeConfig.colors.textDim; opacity: 0.7 }
                    }
                    Repeater {
                        model: svc.engRoutes
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Config.ControlConfig.space2
                            Text { Layout.preferredWidth: 250; text: modelData.dst; elide: Text.ElideRight
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                                font.bold: modelData.dst === "default"
                                color: modelData.dst === "default" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.text }
                            Text { Layout.preferredWidth: 140; text: modelData.via; elide: Text.ElideRight
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; color: Config.ThemeConfig.colors.textDim }
                            Text { Layout.preferredWidth: 90; text: modelData.dev
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; color: Config.ThemeConfig.colors.textDim }
                            Text { Layout.preferredWidth: 60; text: String(modelData.metric)
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; color: Config.ThemeConfig.colors.textDim }
                            Text { Layout.fillWidth: true; text: modelData.proto; elide: Text.ElideRight
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; color: Config.ThemeConfig.colors.textDim }
                        }
                    }
                }

                // ── COUNTERS ───────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.ControlConfig.space1
                    SectionHeader { Layout.fillWidth: true; title: "INTERFACE COUNTERS" }
                    InfoStatRow { Layout.fillWidth: true; label: "RECEIVED"
                        value: svc.engAddr ? fmtBytes(svc.ifaceStats.rxBytes) : "—" }
                    InfoStatRow { Layout.fillWidth: true; label: "SENT"
                        value: svc.engAddr ? fmtBytes(svc.ifaceStats.txBytes) : "—" }
                    InfoStatRow { Layout.fillWidth: true; label: "RX ERRORS"
                        value: String(svc.ifaceStats.rxErrors !== undefined ? svc.ifaceStats.rxErrors : "—")
                        accentValue: svc.ifaceStats.rxErrors > 0 }
                    InfoStatRow { Layout.fillWidth: true; label: "TX ERRORS"
                        value: String(svc.ifaceStats.txErrors !== undefined ? svc.ifaceStats.txErrors : "—")
                        accentValue: svc.ifaceStats.txErrors > 0 }
                    InfoStatRow { Layout.fillWidth: true; label: "RX DROPPED"
                        value: String(svc.ifaceStats.rxDropped !== undefined ? svc.ifaceStats.rxDropped : "—")
                        accentValue: svc.ifaceStats.rxDropped > 0 }
                    InfoStatRow { Layout.fillWidth: true; label: "TX DROPPED"
                        value: String(svc.ifaceStats.txDropped !== undefined ? svc.ifaceStats.txDropped : "—")
                        accentValue: svc.ifaceStats.txDropped > 0 }
                }

                // ── NEIGHBORS ──────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    SectionHeader { Layout.fillWidth: true; title: "NEIGHBORS (" + svc.engNeighbors.length + ")" }
                    Repeater {
                        model: svc.engNeighbors
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Config.ControlConfig.space2
                            Text { Layout.preferredWidth: 180; text: modelData.ip
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; color: Config.ThemeConfig.colors.text; elide: Text.ElideRight }
                            Text { Layout.preferredWidth: 170; text: modelData.mac
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; color: Config.ThemeConfig.colors.textDim; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: modelData.dev
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; color: Config.ThemeConfig.colors.textDim }
                        }
                    }
                }

                // ── LISTENERS ──────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    SectionHeader { Layout.fillWidth: true; title: "LISTENERS (" + svc.engListeners.length + ")" }
                    Repeater {
                        model: svc.engListeners
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Config.ControlConfig.space2
                            Text { Layout.preferredWidth: 60; text: modelData.proto.toUpperCase()
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                                color: modelData.proto === "tcp" ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim }
                            Text { Layout.fillWidth: true; text: modelData.local
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                                color: Config.ThemeConfig.colors.text; elide: Text.ElideRight }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // right-edge scroll indicator (same idiom as SettingsModule's ScrollColumn)
            Rectangle {
                visible: scroll.contentHeight > scroll.height + 1
                anchors.right: parent.right
                anchors.rightMargin: 2
                width: 3
                radius: 1.5
                color: Config.ThemeConfig.colors.outlineVariant
                opacity: 0.9
                y: {
                    var track = scroll.height - height - 4
                    var frac = scroll.contentY / Math.max(1, scroll.contentHeight - scroll.height)
                    return 2 + Math.max(0, Math.min(track, frac * track))
                }
                height: Math.max(24, scroll.height * (scroll.height / Math.max(1, scroll.contentHeight)) - 4)
            }
        }
    }

    Text {
        visible: !viewRoot.hasIface
        anchors.centerIn: parent
        text: "no interface — connect on the WIFI page first"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
    }

    function fmtBytes(b) {
        if (b === undefined || b === null) return "—"
        if (b < 1024) return b + " B"
        if (b < 1048576) return (b / 1024).toFixed(1) + " KB"
        if (b < 1073741824) return (b / 1048576).toFixed(1) + " MB"
        return (b / 1073741824).toFixed(2) + " GB"
    }
}
