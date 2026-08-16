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
    spacing: 10

    readonly property var cs: Services.NetworkControlService.connectionStatus
    readonly property bool linkUp: view.cs.connected === true
    // Lit signal segments for the connected card (same tiers as the row).
    readonly property int linkBars: view.cs.signal >= 75 ? 4 : view.cs.signal >= 50 ? 3 : view.cs.signal >= 25 ? 2 : view.cs.signal > 0 ? 1 : 0

    // Minimum signal a scan-row needs to be shown (0 = ALL). Default 50 hides
    // weak/noisy APs. The active link is force-included even below threshold so
    // the network you're on never vanishes from its own table.
    property int minSignal: 50
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
        spacing: 4
        Text {
            text: parent.label
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
            color: Config.ThemeConfig.colors.textDim
        }
        Text {
            text: parent.value
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
            color: Config.ThemeConfig.colors.text
            elide: Text.ElideRight
            Layout.maximumWidth: 120
        }
    }

    // Segmented MIN SIGNAL button (ALL / ≥50% / ≥70%) — sets minSignal.
    component FilterSeg: Rectangle {
        property string label: ""
        property bool active: false
        property int value: 0
        height: 18
        width: segLbl.implicitWidth + 14
        color: active ? Config.ControlConfig.accent
                      : (segMA.containsMouse ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.10) : "transparent")
        border.color: active ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
        border.width: 1
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            id: segLbl; anchors.centerIn: parent
            text: parent.label
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
            color: parent.active ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.textDim
        }
        MouseArea {
            id: segMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: view.minSignal = value
        }
    }

    // =========================================================================
    // 1. HEADER
    // =========================================================================
    RowLayout {
        width: parent.width
        spacing: 8

        Rectangle { width: 3; height: 16; color: Config.ControlConfig.accent; Layout.alignment: Qt.AlignVCenter }

        Text {
            text: "NETWORK"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 13; font.bold: true
            color: Config.ThemeConfig.colors.text
            Layout.alignment: Qt.AlignVCenter
        }

        // Link-state pill
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: stateLbl.implicitWidth + 14; height: 16
            color: view.linkUp
                   ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.12)
                   : Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.10)
            border.color: view.linkUp ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
            border.width: 1
            Text {
                id: stateLbl; anchors.centerIn: parent
                text: view.linkUp ? "● STABLE" : "○ OFFLINE"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                color: view.linkUp ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
            }
        }

        Item { Layout.fillWidth: true }

        // Network count (idle)
        Text {
            visible: !Services.NetworkControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: Services.NetworkControlService.wifiNetworks.length + " nets"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.textDim
        }

        // Animated scan dots
        Text {
            visible: Services.NetworkControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: { var d = ["·", "··", "···", "····"]; return "scan" + d[Math.floor(dotTimer.tick % 4)] }
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
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
            width: rescanLbl.implicitWidth + 16; height: 20
            color: rescanMA.containsMouse && !Services.NetworkControlService.scanning
                   ? Config.ControlConfig.accent : "transparent"
            border.color: Services.NetworkControlService.scanning ? Config.ThemeConfig.colors.border : Config.ControlConfig.accent
            border.width: 1
            opacity: Services.NetworkControlService.scanning ? 0.5 : 1.0
            Text {
                id: rescanLbl; anchors.centerIn: parent
                text: "RESCAN"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                color: rescanMA.containsMouse && !Services.NetworkControlService.scanning
                       ? Config.ThemeConfig.colors.background : Config.ControlConfig.accent
            }
            MouseArea {
                id: rescanMA; anchors.fill: parent; hoverEnabled: true
                cursorShape: Services.NetworkControlService.scanning ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: if (!Services.NetworkControlService.scanning) Services.NetworkControlService.scanWifi()
            }
        }
    }

    // =========================================================================
    // 2. CONNECTED-STATUS CARD
    // =========================================================================
    HudCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.secondary

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "ACTIVE_LINK"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                    color: Config.ThemeConfig.colors.textDim
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: view.linkUp
                    text: view.cs.signal + "%"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 11; font.bold: true
                    color: Config.ControlConfig.accent
                }
            }

            // SSID (big) when connected, else offline message. Uses the theme
            // primary (teal) instead of near-white — lower luminance, easier on
            // a QD-OLED, still clearly readable as the hero headline.
            Text {
                Layout.fillWidth: true
                text: view.linkUp ? (view.cs.ssid || view.cs.iface || "CONNECTED") : "NO_ACTIVE_LINK"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 16; font.bold: true
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
    // 3. PASSWORD DIALOG — compact inline form (kept verbatim, theme colours)
    // =========================================================================
    Item {
        id: pwDialog
        width: view.width
        height: visible ? (errorText !== "" ? 54 : 36) : 0
        visible: false
        clip: true

        property string targetSsid: ""
        property string errorText: ""   // set when a previous attempt failed

        function open(ssid, errMsg) {
            targetSsid = ssid
            errorText = errMsg || ""
            passField.text = ""
            passField.echoMode = TextInput.Password
            visible = true
            passField.forceActiveFocus()
        }
        function close() {
            visible = false
            passField.text = ""
            targetSsid = ""
            errorText = ""
        }
        function submit() {
            if (passField.text.length === 0) return
            Services.NetworkControlService.connectWifi(pwDialog.targetSsid, passField.text)
            pwDialog.close()
        }

        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        // Failure reason line (e.g. "Wrong password") under the field when the
        // prompt was reopened by a failed attempt.
        Text {
            visible: pwDialog.errorText !== ""
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            anchors.left: parent.left
            anchors.leftMargin: 8
            text: pwDialog.errorText
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.error
        }

        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: 4
            color: Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.06)
            border.color: Config.ControlConfig.accent
            border.width: 1
        }

        Row {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8; anchors.rightMargin: 8
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pwDialog.targetSsid
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: Config.ControlConfig.accent
                elide: Text.ElideRight; width: 130
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
            }
            Rectangle {
                width: 180; height: 22; anchors.verticalCenter: parent.verticalCenter
                color: Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.12)
                border.color: passField.activeFocus ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 100 } }
                TextInput {
                    id: passField
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password; passwordCharacter: "•"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                    color: Config.ThemeConfig.colors.text
                    selectionColor: Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.35)
                    Keys.onReturnPressed: pwDialog.submit()
                    Keys.onEscapePressed: pwDialog.close()
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: passField.echoMode === TextInput.Password ? "👁" : "○"
                font.pixelSize: 12; color: Config.ThemeConfig.colors.textDim
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: passField.echoMode = (passField.echoMode === TextInput.Password)
                                                    ? TextInput.Normal : TextInput.Password
                }
            }
            Rectangle {
                width: 40; height: 22; anchors.verticalCenter: parent.verticalCenter
                color: okMA.containsMouse ? Config.ControlConfig.accent : "transparent"
                border.color: Config.ControlConfig.accent; border.width: 1
                Text {
                    anchors.centerIn: parent; text: "OK"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                    color: okMA.containsMouse ? Config.ThemeConfig.colors.background : Config.ControlConfig.accent
                }
                MouseArea { id: okMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pwDialog.submit() }
            }
            Rectangle {
                width: 28; height: 22; anchors.verticalCenter: parent.verticalCenter
                color: xMA.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.06) : "transparent"
                border.color: Config.ThemeConfig.colors.border; border.width: 1
                Text {
                    anchors.centerIn: parent; text: "×"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                    color: Config.ThemeConfig.colors.textDim
                }
                MouseArea { id: xMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pwDialog.close() }
            }
        }
    }

    // =========================================================================
    // 4. SSID SCAN TABLE
    // =========================================================================
    HudCard {
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
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                color: Config.ThemeConfig.colors.textDim
                Layout.alignment: Qt.AlignVCenter
            }
            FilterSeg { label: "ALL";  value: 0;  active: view.minSignal === 0 }
            FilterSeg { label: "≥50%"; value: 50; active: view.minSignal === 50 }
            FilterSeg { label: "≥70%"; value: 70; active: view.minSignal === 70 }
            Item { Layout.fillWidth: true }
            Text {
                visible: view.minSignal > 0
                Layout.alignment: Qt.AlignVCenter
                text: view.filteredNets.length + "/" + Services.NetworkControlService.wifiNetworks.length
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
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
            Text { text: "SSID"; Layout.fillWidth: true; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Text { text: "SIGNAL"; Layout.preferredWidth: 76; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Text { text: "SECURITY"; Layout.preferredWidth: 72; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Text { text: "CHAN"; Layout.preferredWidth: 26; horizontalAlignment: Text.AlignRight; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Item { Layout.preferredWidth: 16 }                 // == row × slot
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        // Network rows
        Repeater {
            model: view.filteredNets
            delegate: WifiListRow {
                width: parent.width
                net: modelData
                onRequestPassword: function(ssid) {
                    if (pwDialog.visible && pwDialog.targetSsid !== ssid) pwDialog.close()
                    pwDialog.open(ssid)
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
            if (reasonKey === "wrong-password" && ssid && ssid.length > 0)
                pwDialog.open(ssid, reasonLabel)
        }
    }

    // -------------------------------------------------------------------------
    // Inline label/value stat (used by the connected card)
    // -------------------------------------------------------------------------
}
