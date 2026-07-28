// =============================================================================
// WifiListRow.qml — one wifi network row (tactical HUD)
// =============================================================================
// Reads `net`: { ssid, signal(0-100), security, inUse, chan, bssid } from
// NetworkControlService.wifiNetworks. Behaviour:
//   • open network  → click connects immediately  (connectWifi(ssid, ""))
//   • secured net   → click emits requestPassword(ssid)  (parent opens dialog)
//   • inUse row     → hover reveals [×] → disconnectWifi()
//   • connecting    → amber spinner + tint  (NetworkControlService.connectingTo)
//
// NOTE on click handling: the row MouseArea covers the whole row, so the [×]
// sub-area would be shadowed. `propagateComposedEvents` lets the row decline
// the click (mouse.accepted = false on active rows) so it falls through to the
// [×] MouseArea beneath — this also fixes the previous (silently broken) disc.
// All colours are live ThemeConfig tokens.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: row
    width: parent ? parent.width : 400
    height: 30

    property var net: ({ ssid: "", signal: 0, security: "", inUse: false, chan: "--", bssid: "" })

    signal requestPassword(string ssid)

    // True while nmcli is connecting to this specific network (now wired).
    readonly property bool connecting: Services.NetworkControlService.connectingTo === net.ssid
    // Secured = has a non-empty, non-"--"/"open" security field.
    readonly property bool secured: {
        var s = (net.security || "").toUpperCase()
        return !(s === "" || s === "--" || s === "OPEN")
    }
    // Lit segment count + colour, derived from the 0-100 signal quality.
    readonly property int litBars: net.signal >= 75 ? 4 : net.signal >= 50 ? 3 : net.signal >= 25 ? 2 : net.signal > 0 ? 1 : 0
    readonly property color barColor: (net.inUse || net.signal >= 50) ? Config.ControlConfig.accent
                                                                : Config.ThemeConfig.colors.warning

    // ── Background tint by state ──────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: net.inUse    ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.10)
               : connecting ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.warning, 0.10)
               : ma.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ── Left accent bar (active / connecting) ─────────────────────────────────
    Rectangle {
        visible: net.inUse || connecting
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 2
        color: connecting ? Config.ThemeConfig.colors.warning : Config.ControlConfig.accent
    }

    // ── Content ─────────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8; anchors.rightMargin: 6
        spacing: 8

        // Status glyph: ◌ connecting (spins) · ● in-use · ○ idle
        Text {
            Layout.preferredWidth: 14; Layout.alignment: Qt.AlignVCenter
            text: connecting ? "◌" : (net.inUse ? "●" : "○")
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            color: connecting ? Config.ThemeConfig.colors.warning
                   : net.inUse ? Config.ControlConfig.accent
                   : Config.ThemeConfig.colors.border
            RotationAnimator on rotation { running: connecting; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
        }

        // SSID (elided) + BSSID beneath
        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 120
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: net.ssid
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                font.bold: net.inUse || connecting
                color: connecting ? Config.ThemeConfig.colors.warning
                       : net.inUse ? Config.ControlConfig.accent
                       : Config.ThemeConfig.colors.text
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: net.bssid && net.bssid.length > 0
                text: net.bssid
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
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
            Layout.preferredWidth: 28; Layout.alignment: Qt.AlignVCenter
            text: net.signal + "%"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.textDim
            horizontalAlignment: Text.AlignRight
        }

        // Security chip — fixed 72-wide slot so the CHAN column lines up across
        // rows regardless of label length (the chip itself stays content-sized).
        Item {
            Layout.preferredWidth: 72; Layout.preferredHeight: 16; Layout.alignment: Qt.AlignVCenter
            Rectangle {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(72, secLabel.implicitWidth + 12); height: 16
                color: row.secured ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.10) : "transparent"
                border.color: row.secured ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
                border.width: 1
                Text {
                    id: secLabel
                    anchors.centerIn: parent; width: parent.width - 8
                    text: row.secured ? (net.security || "").toUpperCase() : "OPEN"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                    color: row.secured ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim
                    elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Channel
        Text {
            Layout.preferredWidth: 26; Layout.alignment: Qt.AlignVCenter
            text: net.chan || "--"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.textDim
            horizontalAlignment: Text.AlignRight
        }

        // [×] disconnect — hover only on the active row (click falls through
        // from the row MouseArea via propagateComposedEvents).
        Item {
            Layout.preferredWidth: 16; Layout.preferredHeight: row.height
            Layout.alignment: Qt.AlignVCenter
            visible: net.inUse && ma.containsMouse
            Text {
                anchors.centerIn: parent
                text: "×"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 14; font.bold: true
                color: Config.ThemeConfig.colors.error
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.NetworkControlService.disconnectWifi()
            }
        }
    }

    // ── Row click → connect / request password (declines on active rows so the
    //    [×] beneath can receive the click) ─────────────────────────────────────
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        propagateComposedEvents: true
        onClicked: function(mouse) {
            if (net.inUse || connecting) { mouse.accepted = false; return }   // let [×] through
            if (row.secured) row.requestPassword(net.ssid)
            else Services.NetworkControlService.connectWifi(net.ssid, "")
        }
    }
}
