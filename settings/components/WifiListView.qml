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
        height: visible ? 36 : 0
        visible: false
        clip: true

        property string targetSsid: ""

        function open(ssid) {
            targetSsid = ssid
            passField.text = ""
            passField.echoMode = TextInput.Password
            visible = true
            passField.forceActiveFocus()
        }
        function close() {
            visible = false
            passField.text = ""
            targetSsid = ""
        }
        function submit() {
            if (passField.text.length === 0) return
            Services.NetworkControlService.connectWifi(pwDialog.targetSsid, passField.text)
            pwDialog.close()
        }

        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

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
            model: Services.NetworkControlService.wifiNetworks
            delegate: WifiListRow {
                width: parent.width
                net: modelData
                onRequestPassword: function(ssid) {
                    if (pwDialog.visible && pwDialog.targetSsid !== ssid) pwDialog.close()
                    pwDialog.open(ssid)
                }
            }
        }

        // Empty state
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
    }

    // -------------------------------------------------------------------------
    // Inline label/value stat (used by the connected card)
    // -------------------------------------------------------------------------
}
