// =============================================================================
// BtDeviceRow.qml — one bluetooth device row (tactical HUD)
// =============================================================================
// Reads `dev`: { mac, name, alias, icon, connected, paired, trusted,
// battery(-1=unknown), rssi(0-100, 0=unknown) } from
// BluetoothControlService.devices. `beacon` selects the card context:
//   • beacon === true  → unpaired scanned device (AVAIL_BEACONS card)
//   • beacon === false → paired device (PAIRED_NODES card)
// Behaviour:
//   • connected row → left accent bar + CONNECTED chip + Disconnect button
//   • busy (pairing/connecting) → Pairing.../Connecting... label + amber tint
//   • paired/disconnected → PAIRED chip + Connect button
//   • unpaired beacon → NEW chip + Confirm button
//   • paired row + hover → [×] forget (BluetoothControlService.remove)
//
// NOTE on click handling: the row MouseArea covers the whole row, so the
// action button / [×] sub-areas would be shadowed. `propagateComposedEvents`
// lets the row decline the click (mouse.accepted = false) so it falls through
// to the buttons beneath — same trick as WifiListRow. All colours are live
// ThemeConfig tokens; none are hardcoded.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: row
    width: parent ? parent.width : 400
    height: 30

    // ── INTERFACE (instantiated by the list view) ──────────────────────────────
    property var dev: ({ mac: "", name: "", alias: "", icon: "",
                         connected: false, paired: false, trusted: false,
                         battery: -1, rssi: 0 })
    property bool beacon: false   // true = AVAIL_BEACONS, false = PAIRED_NODES

    // ── Busy state — driven by the service's serialized action queue ──────────
    readonly property bool pairing:    Services.BluetoothControlService.pairingTo    === dev.mac
    readonly property bool connecting: Services.BluetoothControlService.connectingTo === dev.mac
    readonly property bool busy:       pairing || connecting

    // ── Icon glyph map (dev.icon → Nerd Font). Order matters: "headphone" and
    //    "microphone" must be tested before "phone" (both contain "phone"). ────
    readonly property string iconGlyph: {
        var i = (dev.icon || "").toLowerCase()
        if (i.indexOf("mouse")      !== -1) return "󰍽"
        if (i.indexOf("keyboard")   !== -1) return "󰌌"
        if (i.indexOf("headset")    !== -1) return "󰋋"
        if (i.indexOf("headphone")  !== -1) return "󰟌"
        if (i.indexOf("audio-card") !== -1) return "󰓅"
        if (i.indexOf("speaker")    !== -1) return "󰓃"
        if (i.indexOf("microphone") !== -1) return "󰄰"
        if (i.indexOf("phone")      !== -1) return "󰄞"
        if (i.indexOf("camera")     !== -1) return "󰄜"
        if (i.indexOf("gaming")     !== -1) return "󰊴"
        if (i.indexOf("computer")   !== -1) return "󰢹"
        return "󰂯"   // generic bluetooth glyph (fallback)
    }

    // ── Signal metrics — lit-bar count + colour, derived from rssi (0-100) ────
    // beacon: ceil(rssi/25); paired: prefer rssi thresholds, fall back to battery.
    readonly property int litBeaconBars: dev.rssi > 0 ? Math.ceil(dev.rssi / 25) : 0
    readonly property int litPairedBars: {
        if (dev.rssi > 0)
            return dev.rssi >= 75 ? 4 : dev.rssi >= 50 ? 3 : dev.rssi >= 25 ? 2 : 1
        if (dev.battery >= 75) return 4
        if (dev.battery >= 50) return 3
        if (dev.battery >= 25) return 2
        if (dev.battery > 0)   return 1
        return 0
    }
    readonly property color barColor: (dev.connected || dev.rssi >= 50)
                                       ? Config.ControlConfig.accent
                                       : Config.ThemeConfig.colors.warning

    // ── State chip — text/colour shared via row props so the chip stays the
    //    single consumer of one source of truth. NEW is the "uncoloured" state
    //    (transparent bg + border colours.border; text still textDim). ─────────
    readonly property string stateText: dev.connected ? "CONNECTED"
                                         : row.busy   ? (row.pairing ? "PAIRING" : "CONNECTING")
                                         : dev.paired ? "PAIRED"
                                         : "NEW"
    readonly property color stateColor: dev.connected ? Config.ThemeConfig.colors.success
                                         : row.busy   ? Config.ThemeConfig.colors.warning
                                         : dev.paired ? Config.ControlConfig.accent
                                         : Config.ThemeConfig.colors.textDim
    readonly property bool stateColored: dev.connected || row.busy || dev.paired

    // ── Action button label/border (Disconnect / Connect / Confirm) ───────────────
    readonly property string actionText: dev.connected ? "Disconnect"
                                         : dev.paired  ? "Connect"
                                         : "Confirm"
    readonly property color actionBorderColor: dev.connected ? Config.ThemeConfig.colors.error
                                                : Config.ControlConfig.accent

    // ── Background tint by state ──────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: dev.connected ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.10)
               : row.busy   ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.warning, 0.10)
               : ma.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ── Left accent bar (connected) ───────────────────────────────────────────
    Rectangle {
        visible: dev.connected
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 2
        color: Config.ControlConfig.accent
    }

    // ── Content ─────────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8; anchors.rightMargin: 6
        spacing: 8

        // (1) Icon box — bordered square, Nerd Font glyph from dev.icon.
        Rectangle {
            Layout.preferredWidth: 22; Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            color: "transparent"
            border.color: dev.connected ? Config.ControlConfig.accent
                                        : Config.ThemeConfig.colors.border
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: row.iconGlyph
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                color: dev.connected ? Config.ControlConfig.accent
                                      : Config.ThemeConfig.colors.textDim
            }
        }

        // (2) Name (bold when connected) + caption/MAC beneath.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: dev.name || dev.alias || dev.mac
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                font.bold: dev.connected
                color: row.busy        ? Config.ThemeConfig.colors.warning
                       : dev.connected ? Config.ControlConfig.accent
                       : Config.ThemeConfig.colors.text
                elide: Text.ElideRight
            }
            // Connected caption (visible only when connected)
            Text {
                Layout.fillWidth: true
                visible: dev.connected && dev.battery >= 0
                text: "Connected · " + dev.battery + "%"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                color: Config.ThemeConfig.colors.textDim
                elide: Text.ElideRight
            }
            // MAC address (visible when not connected or no battery)
            Text {
                Layout.fillWidth: true
                visible: (dev.mac || "").length > 0 && (!dev.connected || dev.battery < 0)
                text: dev.mac
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                color: Config.ThemeConfig.colors.textDim
                elide: Text.ElideRight
            }
        }

        // (3) Signal meter — two render modes sharing the 44-wide slot:
        //     • beacon: 4 compact horizontal segments + "−NN dBm" label
        //     • paired: 4 rising vertical bars + "BAT NN%" label
        //     (clip:true guards the right edge if the label runs long.)
        Item {
            Layout.preferredWidth: 60; Layout.preferredHeight: row.height
            Layout.alignment: Qt.AlignVCenter
            clip: true

            // ── beacon mode: horizontal segments + dBm text ──
            RowLayout {
                id: beaconMeter
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                visible: row.beacon
                spacing: 3
                Row {
                    spacing: 1
                    Repeater {
                        model: 4
                        Rectangle {
                            width: 3; height: 2
                            color: index < row.litBeaconBars ? Config.ControlConfig.accent
                                                             : Config.ThemeConfig.colors.border
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                }
                Text {
                    visible: dev.rssi > 0
                    // dBm = round(rssi/2) − 100; rssi 0-100 → -100..-50, so always
                    // negative — show the real minus sign (U+2212) for readability.
                    text: "−" + Math.abs(Math.round(dev.rssi / 2) - 100) + " dBm"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                    color: Config.ThemeConfig.colors.textDim
                    elide: Text.ElideRight
                }
            }

            // ── paired mode: rising vertical bars + BAT% text ──
            RowLayout {
                id: pairedMeter
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                visible: !row.beacon
                spacing: 3
                RowLayout {
                    spacing: 2
                    Repeater {
                        model: 4
                        Rectangle {
                            Layout.preferredWidth: 3
                            Layout.preferredHeight: 4 + index * 2      // 4,6,8,10 — rising bars
                            Layout.alignment: Qt.AlignBottom           // shared baseline
                            color: index < row.litPairedBars ? row.barColor
                                                            : Config.ThemeConfig.colors.border
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                }
                Text {
                    visible: dev.battery >= 0
                    text: "BAT " + dev.battery + "%"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                    color: dev.battery < 20 ? Config.ThemeConfig.colors.error
                                            : Config.ThemeConfig.colors.textDim
                    elide: Text.ElideRight
                }
            }
        }

        // (4) State chip — content-sized (min(70, label+12)), left-aligned in
        //     the 70-wide slot so the ACTION column lines up across rows.
        Item {
            Layout.preferredWidth: 70; Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignVCenter
            Rectangle {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(70, stateLabel.implicitWidth + 12); height: 16
                color: row.stateColored ? Config.ThemeConfig.tint(row.stateColor, 0.10)
                                        : "transparent"
                border.color: row.stateColored ? row.stateColor
                                               : Config.ThemeConfig.colors.border
                border.width: 1
                Text {
                    id: stateLabel
                    anchors.centerIn: parent; width: parent.width - 8
                    text: row.stateText
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                    color: row.stateColor
                    elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // (5) Action button — content-sized (label+16), left-aligned in the
        //     80-wide slot. Hidden while busy; the spinner below takes over.
        Item {
            Layout.preferredWidth: 80; Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            Rectangle {
                visible: !row.busy
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: actionLabel.implicitWidth + 16; height: 18
                color: actionMA.containsMouse ? row.actionBorderColor : "transparent"
                border.color: row.actionBorderColor; border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: row.actionText
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                    color: actionMA.containsMouse ? Config.ThemeConfig.colors.background
                                                  : row.actionBorderColor
                }
                MouseArea {
                    id: actionMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        mouse.accepted = true
                        if (dev.connected)   Services.BluetoothControlService.disconnect(dev.mac)
                        else if (dev.paired) Services.BluetoothControlService.connect(dev.mac)
                        else                 Services.BluetoothControlService.pair(dev.mac)   // pair → trust → connect
                    }
                }
            }
            // Busy state label — replaces the action button while pairing/connecting.
            Text {
                visible: row.busy
                anchors.left: parent.left; anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: row.pairing ? "Pairing..." : "Connecting..."
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                color: Config.ThemeConfig.colors.warning
            }
        }

        // (6) [×] forget — hover only for paired devices (click falls through
        //     from the row MouseArea via propagateComposedEvents).
        //     Two-step inline confirm: the first click arms ("SURE?", 3 s
        //     auto-disarm window), a second click forgets. Forgetting is the
        //     one irreversible action here — disconnects stay one-click.
        Item {
            id: forgetBtn
            Layout.preferredWidth: forgetArmed ? 52 : 16
            Layout.preferredHeight: row.height
            Layout.alignment: Qt.AlignVCenter
            visible: dev.paired && ma.containsMouse && !row.busy

            property bool forgetArmed: false
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

            Timer { id: disarmTimer; interval: 3000; onTriggered: forgetBtn.forgetArmed = false }

            Text {
                anchors.centerIn: parent
                text: forgetBtn.forgetArmed ? "SURE?" : "×"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: forgetBtn.forgetArmed ? 9 : 14
                font.bold: true
                color: forgetBtn.forgetArmed ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.textDim
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    mouse.accepted = true
                    if (!forgetBtn.forgetArmed) {
                        forgetBtn.forgetArmed = true
                        disarmTimer.restart()
                    } else {
                        Services.BluetoothControlService.remove(dev.mac)
                    }
                }
            }
        }
    }

    // ── Row hover (drives background tint + [×] visibility). Declines the click
    //    (mouse.accepted = false) so it falls through to the buttons beneath.
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        propagateComposedEvents: true
        onClicked: mouse.accepted = false
    }
}
