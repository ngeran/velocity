// =============================================================================
// WifiListRow.qml — one wifi network row (tactical HUD)
// =============================================================================
// Reads `net`: { ssid, signal, security, inUse, chan, bssid } from
// NetworkControlService.wifiNetworks. Behaviour:
//   • open network  → click connects immediately  (connectWifi(ssid, ""))
//   • secured net   → click expands row for inline password entry
//   • inUse row     → hover reveals [×] → disconnectWifi()
//   • connecting    → amber spinner + tint  (NetworkControlService.connectingTo)
//
// Inline password mode (M2):
//   • Row expands to show password field + CONNECT/CANCEL buttons
//   • List frozen while editing (other rows disabled)
//   • Password field auto-focuses, connects on Enter, cancels on Escape
//
// NOTE on click handling: the row MouseArea covers the whole row, so the [×]
// sub-area would be shadowed. `propagateComposedEvents` lets the row decline
// the click (mouse.accepted = false on active rows) so it falls through to the
// [×] MouseArea beneath. All colours are live ThemeConfig tokens.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: row
    width: parent ? parent.width : 400
    height: editing ? 66 : 40

    property var net: ({ ssid: "", signal: 0, security: "", inUse: false, chan: "--", bssid: "" })
    property bool editing: false
    property bool listFrozen: false

    // True while nmcli is connecting to this specific network (now wired).
    readonly property bool connecting: Services.NetworkControlService.connectingTo === net.ssid
    // Secured = has a non-empty, non-"--"/"open" security field.
    readonly property bool secured: {
        var s = (net.security || "").toUpperCase()
        return !(s === "" || s === "--" || s === "OPEN")
    }
    // Lit segment count + colour, derived from the 0-100 signal quality.
    readonly property int litBars: net.signal >= 75 ? 4 : net.signal >= 50 ? 3 : net.signal >= 25 ? 2 : net.signal > 0 ? 1 : 0
    readonly property color barColor: net.inUse         ? Config.ThemeConfig.colors.success
                                     : net.signal >= 50 ? Config.ThemeConfig.colors.primary
                                                        : Config.ThemeConfig.colors.warning

    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // ── Background tint by state ──────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Config.ControlConfig.radiusSmall
        color: net.inUse    ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.06)
               : connecting ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.warning, 0.10)
               : row.editing ? Config.ThemeConfig.tint(Config.ControlConfig.colors.info, 0.06)
               : ma.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ── Content (main row + password field below) ─────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 4

        // Main row content — FIXED height so hover never re-centers it (the
        // [×] reveal used to inflate the row's implicit height, shifting the
        // whole row down and over the accent tick).
        RowLayout {
            width: parent.width
            height: row.editing ? row.height - 30 : row.height
            spacing: 8

            // Status glyph: ◌ connecting (spins) · ● in-use (sage) · ○ idle
            Text {
                Layout.preferredWidth: 14; Layout.alignment: Qt.AlignVCenter
                text: connecting ? "◌" : (net.inUse ? "●" : "○")
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                color: connecting ? Config.ThemeConfig.colors.warning
                       : net.inUse ? Config.ThemeConfig.colors.success
                       : Config.ThemeConfig.colors.border
                RotationAnimator on rotation { running: connecting; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
            }

            // SSID (elided) + BSSID beneath — active is just bold text (the
            // sage dot + subtle bg already mark it; no accent flood)
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: 120
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: net.ssid
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                    font.bold: net.inUse || connecting || row.editing
                    color: connecting ? Config.ThemeConfig.colors.warning
                           : row.editing ? Config.ControlConfig.accent
                           : Config.ThemeConfig.colors.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: net.bssid && net.bssid.length > 0 && !row.editing
                    text: net.bssid
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                    color: Config.ThemeConfig.colors.textDim
                    elide: Text.ElideRight
                }
            }

            // Multi-segment signal bars — bottom-aligned (shared baseline, cell-style)
            RowLayout {
                Layout.preferredWidth: 40; Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle {
                        Layout.preferredWidth: 3
                        Layout.preferredHeight: 4 + index * 2      // 4,6,8,10 — rising bars
                        Layout.alignment: Qt.AlignBottom           // shared baseline
                        color: index < row.litBars ? row.barColor : Config.ThemeConfig.colors.border
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }
            }

            // Signal %
            Text {
                Layout.preferredWidth: 32; Layout.alignment: Qt.AlignVCenter
                text: net.signal + "%"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
                horizontalAlignment: Text.AlignRight
            }

            // Security chip — fixed 72-wide slot so the CHAN column lines up across
            // rows regardless of label length (the chip itself stays content-sized).
            Item {
                Layout.preferredWidth: 72; Layout.preferredHeight: 18; Layout.alignment: Qt.AlignVCenter
                Rectangle {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(72, secLabel.implicitWidth + 14); height: 18
                    radius: Config.ControlConfig.radiusSmall
                    color: row.secured ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.info, 0.10) : "transparent"
                    border.color: row.secured ? Config.ThemeConfig.colors.info : Config.ThemeConfig.colors.outlineVariant
                    border.width: 1
                    Text {
                        id: secLabel
                        anchors.centerIn: parent; width: parent.width - 8
                        text: row.secured ? (net.security || "").toUpperCase() : "OPEN"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                        color: row.secured ? Config.ThemeConfig.colors.info : Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Channel
            Text {
                Layout.preferredWidth: 28; Layout.alignment: Qt.AlignVCenter
                text: net.chan || "--"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
                horizontalAlignment: Text.AlignRight
            }

            // [×] disconnect — the 16px slot is ALWAYS RESERVED so nothing
            // shifts on hover; only the glyph fades in on the active row.
            Item {
                Layout.preferredWidth: 16; Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                Text {
                    anchors.centerIn: parent
                    visible: net.inUse && ma.containsMouse && !row.editing
                    text: "×"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 14; font.bold: true
                    color: Config.ThemeConfig.colors.error
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }
                MouseArea {
                    anchors.fill: parent
                    visible: net.inUse && ma.containsMouse && !row.editing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.NetworkControlService.disconnectWifi()
                }
            }
        }

        // Inline password field (visible only when editing)
        RowLayout {
            visible: row.editing
            width: parent.width
            spacing: 6
            Layout.leftMargin: 8; Layout.rightMargin: 6

            Rectangle {
                Layout.fillWidth: true; height: 26
                radius: Config.ControlConfig.radiusSmall
                color: Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.12)
                border.color: passField.activeFocus ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 100 } }

                TextInput {
                    id: passField
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                    color: Config.ThemeConfig.colors.text
                    selectionColor: Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.35)
                    Keys.onReturnPressed: {
                        if (passField.text.length > 0) {
                            Services.NetworkControlService.connectWifi(net.ssid, passField.text)
                            row.closePassword()
                        }
                    }
                    Keys.onEscapePressed: row.closePassword()
                }

                Text {
                    anchors.right: parent.right; anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: passField.echoMode === TextInput.Password ? "👁" : "○"
                    font.pixelSize: 12; color: Config.ThemeConfig.colors.textDim
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: passField.echoMode = (passField.echoMode === TextInput.Password)
                                                        ? TextInput.Normal : TextInput.Password
                    }
                }
            }

            // CONNECT button
            Rectangle {
                width: 66; height: 26
                radius: Config.ControlConfig.radiusPill
                color: connectMA.containsMouse ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16) : "transparent"
                border.color: Config.ControlConfig.accent; border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                    anchors.centerIn: parent; text: "CONNECT"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                    color: Config.ControlConfig.accent
                }
                MouseArea {
                    id: connectMA
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (passField.text.length > 0) {
                            Services.NetworkControlService.connectWifi(net.ssid, passField.text)
                            row.closePassword()
                        }
                    }
                }
            }

            // CANCEL button
            Rectangle {
                width: 58; height: 26
                radius: Config.ControlConfig.radiusPill
                color: cancelMA.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.border, 0.6) : "transparent"
                border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                Text {
                    anchors.centerIn: parent; text: "CANCEL"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                    color: Config.ThemeConfig.colors.textDim
                }
                MouseArea {
                    id: cancelMA
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: row.closePassword()
                }
            }
        }
    }

    function openPassword() {
        row.editing = true
        passField.text = ""
        passField.forceActiveFocus()
    }

    function closePassword() {
        row.editing = false
        passField.text = ""
    }

    // ── Row click → connect / open password (declines on active/editing rows)
    // ─────────────────────────────────────────────────────────────────────────────
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        propagateComposedEvents: true
        enabled: !row.listFrozen
        opacity: row.listFrozen && !row.editing ? 0.5 : 1.0
        onClicked: function(mouse) {
            if (net.inUse || connecting || row.editing) { mouse.accepted = false; return }
            if (row.secured) row.openPassword()
            else Services.NetworkControlService.connectWifi(net.ssid, "")
        }
    }
}
