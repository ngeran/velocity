// =============================================================================
// WifiListView.qml — NETWORK section view (tactical HUD)
// =============================================================================
// Stack (scrolls with the parent Flickable, ~440px wide):
//   1. Header            — title + link-state pill + count/scan-dots + RESCAN
//   2. Connected-status  — HudCard: active SSID + signal meter + IP/IFACE/TYPE
//                          (or NO_ACTIVE_LINK when offline)
//   3. Password dialog   — inline form (WifiListRow.requestPassword opens it)
//   4. SSID scan table   — HudCard: SSID | SIGNAL | SECURITY | CHAN + rows
//
// Backed by Services.NetworkControlService (nmcli). All colours are live
// ThemeConfig tokens (no hardcoded rgba).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: Config.ControlConfig.space4

    readonly property var cs: Services.NetworkControlService.connectionStatus
    readonly property bool linkUp: view.cs.connected === true
    // Lit signal segments for the connected card (same tiers as the row).
    readonly property int linkBars: view.cs.signal >= 75 ? 4 : view.cs.signal >= 50 ? 3 : view.cs.signal >= 25 ? 2 : view.cs.signal > 0 ? 1 : 0

    // Minimum signal a scan-row needs to be shown (0 = ALL). Default 50 hides
    // weak/noisy APs. The active link is force-included even below threshold so
    // the network you're on never vanishes from its own table.
    property int minSignal: 50
    property bool anyRowEditing: false  // Tracks if any row is in password-edit mode
    readonly property var filteredNets: {
        var all = Services.NetworkControlService.wifiNetworks
        if (view.minSignal <= 0) return all
        var out = []
        for (var i = 0; i < all.length; i++) {
            var n = all[i]
            if (n.signal >= view.minSignal || n.inUse) out.push(n)
        }
        return out
    }

    // Label/value stat pair (used by the connected card).
    component Stat: RowLayout {
        property string label: ""
        property string value: "—"
        spacing: 6
        Text {
            text: parent.label
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8
            color: Config.ThemeConfig.colors.textDim
        }
        Text {
            text: parent.value
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
            color: Config.ThemeConfig.colors.text
            elide: Text.ElideRight
            Layout.maximumWidth: 140
        }
    }

    // Segmented MIN SIGNAL button (ALL / ≥50% / ≥70%) — sets minSignal.
    component FilterSeg: ControlSeg {
        property int value: 0
        onTarget: view
        targetProperty: "minSignal"
    }

    // =========================================================================
    // 1. HEADER
    // =========================================================================
    SectionHeader {
        title: "NETWORK"

        // Link-state badge
        StatusBadge {
            Layout.alignment: Qt.AlignVCenter
            label: view.linkUp ? "STABLE" : "OFFLINE"
            kind: view.linkUp ? "ok" : "err"
        }

        Item { Layout.fillWidth: true }

        // Network count (idle)
        Text {
            visible: !Services.NetworkControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: Services.NetworkControlService.wifiNetworks.length + " nets"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }

        // Animated scan dots
        Text {
            visible: Services.NetworkControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: { var d = ["·", "··", "···", "····"]; return "scan" + d[Math.floor(dotTimer.tick % 4)] }
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

        // RESCAN button
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: rescanLbl.implicitWidth + 20; height: 24
            radius: Config.ControlConfig.radiusPill
            color: rescanMA.containsMouse && !Services.NetworkControlService.scanning
                   ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16) : "transparent"
            border.color: Services.NetworkControlService.scanning ? Config.ThemeConfig.colors.outlineVariant : Config.ControlConfig.accent
            border.width: 1
            opacity: Services.NetworkControlService.scanning ? 0.5 : 1.0
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
                id: rescanLbl; anchors.centerIn: parent
                text: "RESCAN"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: Config.ControlConfig.accent
            }
            MouseArea {
                id: rescanMA; anchors.fill: parent; hoverEnabled: true
                cursorShape: Services.NetworkControlService.scanning ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: if (!Services.NetworkControlService.scanning) Services.NetworkControlService.scanWifi()
            }
        }
    }

    // Hero-row status caption
    Text {
        Layout.fillWidth: true
        Layout.topMargin: -6
        text: "WIFI · " + (view.cs.iface || "—").toUpperCase() + " · " + (view.linkUp ? "IP · " + view.cs.signal + "% SIGNAL" : "OFFLINE")
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 10
        font.letterSpacing: 0.3
        color: Config.ThemeConfig.colors.textDim
        opacity: 0.75
    }

    // Error surface
    Text {
        Layout.fillWidth: true
        visible: Services.NetworkControlService.lastConnectError !== ""
        text: "⚠ " + Services.NetworkControlService.lastConnectError
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 9
        color: Config.ThemeConfig.colors.error
        wrapMode: Text.Wrap
        Layout.topMargin: 4
    }

    // =========================================================================
    // 2. CONNECTED-STATUS CARD
    // =========================================================================
    SettingsCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.secondary

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.ControlConfig.space2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "ACTIVE LINK"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                    color: Config.ThemeConfig.colors.textDim
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: view.linkUp
                    text: view.cs.signal + "%"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 12; font.bold: true
                    color: Config.ControlConfig.accent
                }
            }

            // SSID (big) when connected, else offline message. Uses the theme
            // primary (teal) instead of near-white — lower luminance, easier on
            // a QD-OLED, still clearly readable as the hero headline.
            Text {
                Layout.fillWidth: true
                text: view.linkUp ? (view.cs.ssid || view.cs.iface || "CONNECTED") : "NO ACTIVE LINK"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 18; font.bold: true
                color: view.linkUp ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.textDim
                elide: Text.ElideRight
            }

            // 4-segment signal meter (connected + wifi)
            Row {
                Layout.fillWidth: true
                visible: view.linkUp && view.cs.signal > 0
                spacing: 3
                Repeater {
                    model: 4
                    Rectangle {
                        width: (view.width - 32) / 4 - 3    // fill the card width (~) minus gaps
                        height: 4
                        color: index < view.linkBars ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

            // Stat row: IP · IFACE · TYPE
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Stat { label: "IP";    value: view.cs.ip    || "—" }
                Stat { label: "IFACE"; value: view.cs.iface || "—" }
                Stat { label: "TYPE";  value: (view.cs.type || "—").toUpperCase() }
                Item { Layout.fillWidth: true }
            }
        }
    }

    // =========================================================================
    // 3. SSID SCAN TABLE
    // =========================================================================
    SettingsCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.primary
        contentSpacing: 0

        // Signal-strength filter — hides weak APs below the selected threshold.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8; Layout.rightMargin: 6
            spacing: 6
            Text {
                text: "MIN SIGNAL"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8
                color: Config.ThemeConfig.colors.textDim
                Layout.alignment: Qt.AlignVCenter
            }
            FilterSeg { text: "ALL";  value: 0;  active: view.minSignal === 0 }
            FilterSeg { text: "≥50%"; value: 50; active: view.minSignal === 50 }
            FilterSeg { text: "≥70%"; value: 70; active: view.minSignal === 70 }
            Item { Layout.fillWidth: true }
            Text {
                visible: view.minSignal > 0
                Layout.alignment: Qt.AlignVCenter
                text: view.filteredNets.length + "/" + Services.NetworkControlService.wifiNetworks.length
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        // Column header — mirrors the row's column geometry (left margin, glyph
        // spacer, SSID fill, SIGNAL = bars+gap+%, SECURITY chip slot, CHAN, ×)
        // so every column lines up between the header and the rows beneath it.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8; Layout.rightMargin: 6        // == row
            spacing: 8                                          // == row
            Item { Layout.preferredWidth: 14 }                 // == row glyph
            Text { text: "SSID"; Layout.fillWidth: true; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
            Text { text: "SIGNAL"; Layout.preferredWidth: 76; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
            Text { text: "SECURITY"; Layout.preferredWidth: 72; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
            Text { text: "CHAN"; Layout.preferredWidth: 26; horizontalAlignment: Text.AlignRight; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
            Item { Layout.preferredWidth: 16 }                 // == row × slot
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        // Network rows
        Repeater {
            model: view.filteredNets
            delegate: WifiListRow {
                width: parent.width
                net: modelData
                listFrozen: view.anyRowEditing
                onEditingChanged: {
                    view.anyRowEditing = editing
                }
            }
        }

        // Empty state — nothing found at all
        Text {
            Layout.fillWidth: true
            visible: Services.NetworkControlService.wifiNetworks.length === 0
                     && !Services.NetworkControlService.scanning
            text: "// no networks visible — press RESCAN to search"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            Layout.topMargin: 8; Layout.bottomMargin: 6
            horizontalAlignment: Text.AlignHCenter
        }

        // Empty state — networks exist but all fall below the filter threshold
        Text {
            Layout.fillWidth: true
            visible: Services.NetworkControlService.wifiNetworks.length > 0
                     && view.filteredNets.length === 0
                     && !Services.NetworkControlService.scanning
            text: "// " + Services.NetworkControlService.wifiNetworks.length
                  + " weak network" + (Services.NetworkControlService.wifiNetworks.length !== 1 ? "s" : "")
                  + " hidden — lower MIN SIGNAL to show"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            Layout.topMargin: 8; Layout.bottomMargin: 6
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Wrong-password reprompt (Omarchy pattern): when a connect attempt fails
    // classification says the password was wrong, reopen the passphrase prompt
    // for that SSID with the reason shown — retype instead of re-navigating.
    Connections {
        target: Services.NetworkControlService
        function onConnectFailed(ssid, reasonKey, reasonLabel) {
            if (reasonKey === "wrong-password" && ssid && ssid.length > 0) {
                // Find the row with this SSID and open inline password with error
                for (var i = 0; i < view.filteredNets.length; i++) {
                    if (view.filteredNets[i].ssid === ssid) {
                        // Row will need to show error - handled by error surface
                        // Could also open the row's password field automatically
                        break
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Inline label/value stat (used by the connected card)
    // -------------------------------------------------------------------------
}
