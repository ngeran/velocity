// =============================================================================
// WifiListView.qml — NETWORK section: Network Monitor (mockup-faithful)
// =============================================================================
// One authoritative header (breadcrumb · Network Monitor · single status badge
// · wifi power + RESCAN), then two 50/50 inspector cards, then the scanner
// table. All section identity lives HERE — TerminalBody's generic header card
// is hidden for this section, killing the old triple-redundancy (pane header +
// section header + card all showing SSID/IP/STABLE).
//
//   ACTIVE LINK INSPECTOR   badge · SSID · signal bars · 3×2 param tiles
//   LIVE NET TELEMETRY      rx/tx badges · sparkline · latency/jitter/loss
//   NETWORKS TABLE          filters · search · rows (WifiListRow) · footer
//
// Backed by Services.NetworkControlService. All colours are live ThemeConfig
// tokens. List freeze/capacity logic preserved verbatim (see memory notes on
// Repeater array identity — do not "simplify" it back to a live binding).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services
import "../services/History.js" as History

ColumnLayout {
    id: view
    spacing: Config.ControlConfig.space2

    readonly property var cs: Services.NetworkControlService.connectionStatus
    readonly property bool linkUp: view.cs.connected === true
    readonly property int linkBars: view.cs.signal >= 75 ? 4 : view.cs.signal >= 50 ? 3 : view.cs.signal >= 25 ? 2 : view.cs.signal > 0 ? 1 : 0
    readonly property string netLabel: view.cs.ssid || view.cs.iface || ""

    // Single authoritative status: OFFLINE · STABLE · NO INTERNET (ping says so)
    readonly property string statusLabel: {
        if (!view.linkUp) return "OFFLINE"
        if (Services.NetworkControlService.lossPct >= 50) return "NO INTERNET"
        return Services.NetworkControlService.latencyMs >= 0 ? "STABLE · INTERNET" : "STABLE"
    }
    readonly property string statusKind: !view.linkUp ? "err"
                                        : Services.NetworkControlService.lossPct >= 50 ? "warn" : "ok"

    // Signal tier — theme tokens so the chip retints with the active scheme.
    // Strong ≥70 → success · fair 40–69 → warning · weak <40 → error.
    readonly property color signalColor: view.cs.signal >= 70 ? Config.ThemeConfig.colors.success
                                        : view.cs.signal >= 40 ? Config.ThemeConfig.colors.warning
                                        : Config.ThemeConfig.colors.error
    // Nerd-font wifi-strength glyphs (4 bars → 1 bar → offline)
    readonly property string signalIcon: !view.linkUp ? "󰤭"
                                        : view.cs.signal >= 70 ? "󰤨"
                                        : view.cs.signal >= 40 ? "󰤥"
                                        : view.cs.signal >= 20 ? "󰤢" : "󰤟"

    function fmtRate(kbps) {
        return kbps < 1024 ? kbps.toFixed(0) + " KB/s" : (kbps / 1024).toFixed(1) + " MB/s"
    }
    function fmtTotal(mb) { return mb >= 1024 ? (mb / 1024).toFixed(2) + " GB" : mb.toFixed(1) + " MB" }

    // ── list state ──────────────────────────────────────────────────────────
    // Default filter is ALL — a signal threshold on by default HIDES networks
    // the user is trying to switch to (the "only two networks" regression).
    property int minSignal: 0
    property string bandFilter: ""      // "" | "5 GHz"
    property string searchText: ""
    property bool anyRowEditing: false

    readonly property var filteredNets: {
        var all = Services.NetworkControlService.wifiNetworks
        var q = view.searchText.toLowerCase()
        var out = []
        for (var i = 0; i < all.length; i++) {
            var n = all[i]
            if (view.minSignal > 0 && n.signal < view.minSignal && !n.inUse) continue
            if (view.bandFilter !== "" && (n.band || "") !== view.bandFilter) continue
            if (q !== "" && n.ssid.toLowerCase().indexOf(q) === -1 &&
                (n.bssid || "").toLowerCase().indexOf(q) === -1) continue
            out.push(n)
        }
        return out
    }

    readonly property var liveSorted: {
        var arr = view.filteredNets.slice(0)
        arr.sort(function(a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
            return b.signal - a.signal
        })
        return arr
    }

    // HELD FROZEN while a row edits its password (array identity resets the
    // Repeater and kills the half-typed password — see file header).
    property var sortedNets: []
    onLiveSortedChanged: if (!anyRowEditing) sortedNets = liveSorted
    onAnyRowEditingChanged: if (!anyRowEditing && sortedNets !== liveSorted) sortedNets = liveSorted
    Component.onCompleted: sortedNets = liveSorted
    readonly property int listCapacity: Math.max(3, Math.floor(listViewport.height / 34) - (view.anyRowEditing ? 1 : 0))
    readonly property int visibleCount: Math.min(view.sortedNets.length, view.listCapacity)

    // ── reusable bits ────────────────────────────────────────────────────────
    component ParamTile: Rectangle {
        id: tile
        property string label: ""
        property string value: "—"
        property string sub: ""
        property color valueColor: Config.ThemeConfig.colors.text
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: Config.ControlConfig.radiusSmall
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
        border.color: Config.ThemeConfig.colors.outlineVariant
        border.width: 1
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 6; spacing: 0
            Text { text: tile.label; font.family: Config.ControlConfig.fontSans
                font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0
                color: Config.ThemeConfig.colors.textDim }
            Text { text: tile.value; font.family: Config.ControlConfig.fontMono
                font.pixelSize: 13; font.bold: true; color: tile.valueColor
                elide: Text.ElideMiddle; Layout.maximumWidth: tile.width - 16 }
            Text { visible: tile.sub !== ""; text: tile.sub
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                color: Config.ThemeConfig.colors.textDim; elide: Text.ElideRight
                Layout.maximumWidth: tile.width - 16 }
        }
    }

    component HeaderPill: Rectangle {
        id: pill
        property string text: ""
        property color textColor: Config.ThemeConfig.colors.text
        property color dotColor: "transparent"
        property bool showDot: false
        property bool bordered: true
        signal activated()
        Layout.alignment: Qt.AlignVCenter
        width: pillRow.implicitWidth + 22; height: 26
        radius: Config.ControlConfig.radiusPill
        color: pma.containsMouse ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.14) : "transparent"
        border.color: bordered ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
        border.width: 1
        opacity: enabled ? 1.0 : 0.5
        Behavior on color { ColorAnimation { duration: 100 } }
        RowLayout { id: pillRow; anchors.centerIn: parent; spacing: 6
            Rectangle { visible: pill.showDot; width: 7; height: 7; radius: 3.5; color: pill.dotColor }
            Text { text: pill.text; font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10; font.bold: true; color: pill.textColor }
        }
        MouseArea {
            id: pma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.activated()
        }
    }

    component ScanFilterSeg: ControlSeg {
        // NOTE: no `value` redeclaration here — shadowing ControlSeg's own
        // `value` made instantiation assigns land on the shadow while the
        // click handler read the base default (0) → filters stuck at ALL.
        onTarget: view
        targetProperty: "minSignal"
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 1. UNIFIED HEADER — breadcrumb · Network Monitor · badge · actions
    // ═════════════════════════════════════════════════════════════════════════
        ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            text: "CONTROLS  /  NETWORK & WIRELESS INTERFACES"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            font.letterSpacing: 1.2; color: Config.ThemeConfig.colors.textDim
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Network Monitor"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 20
                font.bold: true; color: Config.ThemeConfig.colors.text
            }

            StatusBadge {
                Layout.alignment: Qt.AlignVCenter
                label: view.statusLabel
                kind: view.statusKind
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: Services.NetworkControlService.scanning
                text: { var d = ["·", "··", "···", "····"]; return "SCAN" + d[Math.floor(dotTimer.tick % 4)] }
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                color: Config.ControlConfig.accent
                Timer {
                    id: dotTimer; property int tick: 0
                    interval: 300; repeat: true
                    running: Services.NetworkControlService.scanning
                    onTriggered: tick++
                    onRunningChanged: if (!running) tick = 0
                }
            }

            // Wi-Fi radio power — single authoritative toggle
            HeaderPill {
                showDot: true
                dotColor: view.cs.wifiEnabled ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
                text: "WI-FI: " + (view.cs.wifiEnabled ? "ENABLED" : "DISABLED")
                textColor: view.cs.wifiEnabled ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
                onActivated: Services.NetworkControlService.toggleWifi()
            }

            // RESCAN
            HeaderPill {
                text: "RESCAN"
                enabled: !Services.NetworkControlService.scanning
                onActivated: Services.NetworkControlService.scanWifi()
            }
        }
    }

    // Connect-error surface (inline feedback for the connect flow)
    Text {
        Layout.fillWidth: true
        visible: Services.NetworkControlService.lastConnectError !== ""
        text: "⚠ " + Services.NetworkControlService.lastConnectError
        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
        color: Config.ThemeConfig.colors.error
        elide: Text.ElideMiddle
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 2. INSPECTOR ROW — ACTIVE LINK (left) | LIVE TELEMETRY (right)
    // ═════════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.ControlConfig.space3

        // ── CARD 1: ACTIVE LINK INSPECTOR ──────────────────────────────────
        SettingsCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 204
            accent: Config.ThemeConfig.colors.secondary

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        width: badgeLbl.implicitWidth + 14; height: 18; radius: 3
                        color: Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16)
                        border.color: Config.ControlConfig.accent; border.width: 1
                        Text { id: badgeLbl; anchors.centerIn: parent
                            text: view.linkUp ? "ACTIVE " + (view.cs.type === "wifi" ? "WI-FI LINK" : "ETHERNET LINK") : "NO ACTIVE LINK"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                            color: Config.ControlConfig.accent }
                    }
                    Text {
                        visible: view.linkUp && view.cs.band !== ""
                        text: view.cs.band + " BAND"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.textDim
                    }
                    Item { Layout.fillWidth: true }

                    // SIGNAL badge — same chip styling as ACTIVE WI-FI LINK,
                    // tier-coloured by signal strength + strength icon
                    Rectangle {
                        visible: view.linkUp
                        width: sigRow.implicitWidth + 16; height: 18; radius: 3
                        color: Config.ThemeConfig.tint(view.signalColor, 0.16)
                        border.color: view.signalColor; border.width: 1
                        RowLayout {
                            id: sigRow; anchors.centerIn: parent; spacing: 5
                            Text {
                                text: view.signalIcon
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 12
                                color: view.signalColor
                            }
                            Text {
                                text: view.cs.signal + "%"
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                                color: view.signalColor
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: view.linkUp ? (view.netLabel || "CONNECTED") : "—"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 24; font.bold: true
                    color: view.linkUp ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.textDim
                    elide: Text.ElideRight
                }

                // 4-segment signal strength indicator — same tier colour as the badge
                Row {
                    Layout.fillWidth: true
                    visible: view.linkUp && view.cs.signal > 0
                    spacing: 4
                    Repeater {
                        model: 4
                        Rectangle {
                            width: (parent.width) / 4 - 4
                            height: 6; radius: 3
                            color: index < view.linkBars ? view.signalColor : Config.ThemeConfig.colors.border
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }

                // 3×2 parameter grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 6; rowSpacing: 6

                    ParamTile { label: "LOCAL IP";    value: view.cs.ip || "—";        sub: view.cs.ip ? view.cs.subnet + " subnet" : "" }
                    ParamTile { label: "GATEWAY";     value: view.cs.gateway || "—"
                        sub: Services.NetworkControlService.latencyMs >= 0
                             ? "ping " + Services.NetworkControlService.latencyMs.toFixed(1) + " ms" : ""
                        valueColor: Config.ThemeConfig.colors.text }
                    ParamTile { label: "PRIMARY DNS"; value: view.cs.dns || "—"        }
                    ParamTile { label: "INTERFACE";   value: view.cs.iface || "—";     sub: view.cs.type === "wifi" ? "wireless adapter" : "ethernet" }
                    ParamTile { label: "LINK SPEED";  value: view.cs.linkSpeed || "—"; sub: view.cs.linkSpeed ? "phy rate" : "" }
                    ParamTile { label: "MAC ADDRESS"; value: view.cs.mac || "—"
                        sub: view.cs.security !== "" ? "security: " + view.cs.security : "" }
                }
            }
        }

        // ── CARD 2: LIVE NET TELEMETRY ─────────────────────────────────────
        SettingsCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 204
            accent: Config.ThemeConfig.colors.info

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    RowLayout { spacing: 6
                        Text { text: "LIVE NET TELEMETRY"
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                            font.bold: true; font.letterSpacing: 1.0; color: Config.ThemeConfig.colors.text }
                        Rectangle { width: 6; height: 6; radius: 3
                            color: view.linkUp ? Config.ThemeConfig.colors.info : Config.ThemeConfig.colors.outlineVariant }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "LAT " + (Services.NetworkControlService.latencyMs >= 0
                                       ? Services.NetworkControlService.latencyMs.toFixed(0) + "ms" : "—")
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.textDim }
                    Text {
                        text: "JIT " + (Services.NetworkControlService.latencyMs >= 0
                                       ? Services.NetworkControlService.jitterMs.toFixed(1) + "ms" : "—")
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.textDim }
                    Text {
                        text: "LOSS " + Services.NetworkControlService.lossPct.toFixed(0) + "%"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                        color: Services.NetworkControlService.lossPct >= 50 ? Config.ThemeConfig.colors.error
                             : Services.NetworkControlService.lossPct > 0 ? Config.ThemeConfig.colors.warning
                             : Config.ThemeConfig.colors.success }
                }

                // Current throughput badges
                RowLayout {
                    Layout.fillWidth: true; spacing: 24
                    RowLayout { spacing: 8
                        Rectangle { width: 10; height: 10; radius: 2; color: Config.ThemeConfig.colors.info }
                        ColumnLayout { spacing: 0
                            Text { text: "DOWNLOAD (RX)"; font.family: Config.ControlConfig.fontSans
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8
                                color: Config.ThemeConfig.colors.textDim }
                            Text { text: view.fmtRate(Services.NetworkControlService.rxRate)
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 17; font.bold: true
                                color: Config.ThemeConfig.colors.info }
                        }
                    }
                    RowLayout { spacing: 8
                        Rectangle { width: 10; height: 10; radius: 2; color: Config.ThemeConfig.colors.primary }
                        ColumnLayout { spacing: 0
                            Text { text: "UPLOAD (TX)"; font.family: Config.ControlConfig.fontSans
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8
                                color: Config.ThemeConfig.colors.textDim }
                            Text { text: view.fmtRate(Services.NetworkControlService.txRate)
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 17; font.bold: true
                                color: Config.ThemeConfig.colors.primary }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }

                // RX/TX sparkline (grid keeps it reading as an instrument at idle)
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    CoreSparkline {
                        anchors.fill: parent
                        points: Services.NetworkControlService.rxHistory
                        lineColor: Config.ThemeConfig.colors.info
                        gridLevels: [0.25, 0.5, 0.75]
                    }
                    CoreSparkline {
                        anchors.fill: parent
                        points: Services.NetworkControlService.txHistory
                        lineColor: Config.ThemeConfig.colors.primary
                        fillEnabled: false; dashed: true; lineWidth: 1.2
                        gridLevels: []
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "2 min auto-scale window  ·  peak rx "
                          + view.fmtRate(History.peakValue(Services.NetworkControlService.rxHistory) || 0)
                          + "  ·  moved ↓ " + view.fmtTotal(Services.NetworkControlService.rxTotalMB)
                          + "  ↑ " + view.fmtTotal(Services.NetworkControlService.txTotalMB)
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                    color: Config.ThemeConfig.colors.textDim
                    elide: Text.ElideMiddle
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 3. NETWORKS TABLE — toolbar · column header · rows · footer
    // ═════════════════════════════════════════════════════════════════════════
    SettingsCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        accent: Config.ThemeConfig.colors.primary
        contentSpacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Toolbar: count · filter segs · search
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 4; Layout.bottomMargin: 4
                spacing: 8
                Text {
                    text: "NETWORKS (" + Services.NetworkControlService.wifiNetworks.length + ")"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    font.bold: true; font.letterSpacing: 1.0; color: Config.ThemeConfig.colors.text
                }
                ScanFilterSeg { text: "ALL";  value: 0;  active: view.minSignal === 0 }
                ScanFilterSeg { text: "≥50%"; value: 50; active: view.minSignal === 50 }
                ScanFilterSeg { text: "≥70%"; value: 70; active: view.minSignal === 70 }
                // Toggle (not one of ControlSeg's exclusive segs — it must be
                // clickable while active to turn the band filter back off).
                HeaderPill {
                    text: "5 GHZ BANDS"
                    bordered: view.bandFilter !== ""
                    textColor: view.bandFilter !== "" ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
                    onActivated: view.bandFilter = view.bandFilter === "" ? "5 GHz" : ""
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                // SSID / BSSID search box
                Rectangle {
                    Layout.preferredWidth: 200; Layout.preferredHeight: 24
                    radius: Config.ControlConfig.radiusSmall
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.7)
                    border.color: searchInput.activeFocus ? Config.ControlConfig.accent
                                                          : Config.ThemeConfig.colors.outlineVariant
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 5
                        Text { text: "⌕"; font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 12; color: Config.ThemeConfig.colors.textDim }
                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: Config.ThemeConfig.colors.text
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                            clip: true
                            Text { anchors.fill: parent; visible: parent.text === ""
                                text: "filter ssid or bssid…"
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                                color: Config.ThemeConfig.colors.textDim }
                            onTextChanged: view.searchText = text
                        }
                        Text {
                            visible: view.searchText !== ""
                            text: "×"; font.pixelSize: 12; color: Config.ThemeConfig.colors.textDim
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { searchInput.text = ""; view.searchText = "" } }
                        }
                    }
                }
            }

            // Column header — mirrors WifiListRow geometry
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12; Layout.rightMargin: 10
                spacing: 8
                Item { Layout.preferredWidth: 14 }
                Text { text: "SSID / ACCESS POINT"; Layout.fillWidth: true; font.family: Config.ControlConfig.fontSans; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                Text { text: "SIGNAL"; Layout.preferredWidth: 78; font.family: Config.ControlConfig.fontSans; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                Text { text: "SECURITY"; Layout.preferredWidth: 72; font.family: Config.ControlConfig.fontSans; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                Text { text: "FREQ & CHANNEL"; Layout.preferredWidth: 150; font.family: Config.ControlConfig.fontSans; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                Text { text: "BSSID (MAC)"; Layout.preferredWidth: 130; font.family: Config.ControlConfig.fontSans; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                Text { text: "ACTION"; Layout.preferredWidth: 88; horizontalAlignment: Text.AlignRight; font.family: Config.ControlConfig.fontSans; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

            // Row viewport — frozen-model + visibility clamping (unchanged logic)
            Item {
                id: listViewport
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    Repeater {
                        model: view.sortedNets
                        delegate: WifiListRow {
                            width: parent.width
                            visible: index < view.listCapacity
                            net: modelData
                            listFrozen: view.anyRowEditing
                            onEditingChanged: view.anyRowEditing = editing
                            Component.onDestruction: if (editing) view.anyRowEditing = false
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Services.NetworkControlService.wifiNetworks.length === 0
                             && !Services.NetworkControlService.scanning
                    text: "// no networks visible — press RESCAN to search"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                    color: Config.ThemeConfig.colors.textDim
                }

                Text {
                    anchors.centerIn: parent
                    visible: Services.NetworkControlService.wifiNetworks.length > 0
                             && view.filteredNets.length === 0
                             && !Services.NetworkControlService.scanning
                    text: "// no match — clear the filter or lower the signal threshold"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                    color: Config.ThemeConfig.colors.textDim
                }
            }

            // Footer — mockup-style shown-of-total + live-scan note
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                color: "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: "Showing " + view.visibleCount + " of "
                              + Services.NetworkControlService.wifiNetworks.length
                              + " nearby access points"
                              + (view.minSignal > 0 ? " (filtered by ≥ " + view.minSignal + "%)" : "")
                              + (view.bandFilter !== "" ? " (5 GHz only)" : "")
                              + (view.searchText !== "" ? " (search: " + view.searchText + ")" : "")
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                        color: Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight
                    }
                    Text {
                        text: Services.NetworkControlService.scanning ? "scanning…" : "auto-refresh: live while visible"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                        color: Config.ThemeConfig.colors.textDim
                    }
                }
            }
        }
    }

    // Wrong-password reprompt hook (Omarchy pattern) — reopens the editor.
    Connections {
        target: Services.NetworkControlService
        function onConnectFailed(ssid, reasonKey, reasonLabel) {
            if (reasonKey === "wrong-password" && ssid && ssid.length > 0) {
                for (var i = 0; i < view.sortedNets.length; i++) {
                    if (view.sortedNets[i].ssid === ssid) { break }
                }
            }
        }
    }
}
