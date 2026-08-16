// =============================================================================
// TrayCard.qml
// Natural extension of the bar — same background, no border.
// All corners are sharp (radius 0).
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../services" as Services
import "../config" as Config

PanelWindow {
    id: card
    // Keep the window alive through the fade-out (opacity > 0 while closing).
    visible: activeTray !== "" || dropdown.opacity > 0

    // Full-screen transparent overlay. A click landing anywhere outside the
    // dropdown closes it — the same click-outside dismissal the
    // Fastfetch/ZaiUsage/Keybinds overlays use. The card itself is drawn above
    // the backdrop and swallows clicks so interacting with it stays put.
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Config.BarConfig.barHeight   // leave the bar itself interactive
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    property string activeTray: ""
    // The tray that is open OR was last open — stays frozen during the fade-out
    // so the closing view's content, header and height don't flash to another
    // body while the 140ms fade runs.
    property string lastTray: ""
    signal closeRequested()

    // HOVER-OUT DISMISSAL
    // The card closes shortly after the cursor leaves the dropdown — but only
    // once the cursor has actually entered it. This guard means opening a tray
    // (cursor still on the bar icon) doesn't immediately start the close timer;
    // you have to move into the card and back out for it to dismiss on hover.
    property bool hasHoveredDropdown: false
    onActiveTrayChanged: {
        if (activeTray !== "") lastTray = activeTray
        hoverCloseTimer.stop()        // any open / switch / close cancels a pending close
        card.hasHoveredDropdown = false
        // Popup-gated polling: detail probes run only while their popup is the
        // active one (fetch fires immediately on open; timers stop on close).
        Services.NetworkService.popupOpen = activeTray === "network"
        Services.BluetoothService.popupOpen = activeTray === "bluetooth"
    }
    Timer {
        id: hoverCloseTimer
        interval: 450
        onTriggered: if (card.activeTray !== "") card.closeRequested()
    }

    readonly property string headerIcon: {
        if (lastTray === "network")
            return Services.NetworkService.isConnected
                ? (Services.NetworkService.connectionType === "wifi" ? "󰖩" : "󰈀") : "󰖪"
        if (lastTray === "bluetooth") return Services.BluetoothService.powered ? "󰂯" : "󰂲"
        if (lastTray === "volume")    return Services.AudioService.muted ? "󰝟" : "󰕾"
        if (lastTray === "power")     return Services.BatteryService.glyph
        return ""
    }
    readonly property string headerTitle: {
        if (lastTray === "network")   return "NETWORK"
        if (lastTray === "bluetooth") return "BLUETOOTH"
        if (lastTray === "volume")    return "VOLUME"
        if (lastTray === "power")     return "POWER"
        return ""
    }

    // Click-catcher spanning the whole screen. Only clicks that miss the card
    // land here (the card is stacked above it) → close.
    MouseArea {
        anchors.fill: parent
        onClicked: card.closeRequested()
    }

    // -------------------------------------------------------------------------
    // DROPDOWN CARD — pinned under the bar, top-right. Sharp corners (radius 0).
    // -------------------------------------------------------------------------
    Rectangle {
        id: dropdown
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 0   // overlay already starts below the bar
        width: 260
        // Both network and bluetooth share the network body's height so the two
        // popups are the same size (+55 = header 34 + separator 1 + outer
        // margins 20). Since the bluetooth device list moved into a ListView
        // with an explicit capped height, btBody.implicitHeight is reliable —
        // the Math.max() keeps the bluetooth box at the wifi height while never
        // shrinking below its own content (relevant when Wi-Fi is off, which
        // collapses networkBody to ~147px).
        // Keyed on lastTray so the height stays frozen through the fade-out.
        height: card.lastTray === "network" ? (networkBody.implicitHeight + 55)
              : card.lastTray === "bluetooth" ? Math.max(networkBody.implicitHeight + 55,
                                                          btBody.implicitHeight + 55)
              : 220
        color: Config.BarConfig.colorBackground
        radius: 0   // sharp corners

        // 140ms OutCubic fade (Omarchy popup idiom); the window's keep-alive
        // visibility (visible: activeTray !== "" || opacity > 0) lets this run.
        opacity: card.activeTray !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        // Swallow clicks inside the card so they don't bubble to the backdrop.
        MouseArea { anchors.fill: parent }

        // Hover tracking drives the hover-out dismissal. HoverHandler is a
        // passive pointer handler, so it doesn't steal clicks/hover from the
        // slider or buttons inside the card — it just reports whether the
        // cursor is within the dropdown's bounds.
        HoverHandler {
            id: ddHover
            onHoveredChanged: {
                if (hovered) {
                    hoverCloseTimer.stop()
                    card.hasHoveredDropdown = true
                } else if (card.hasHoveredDropdown) {
                    hoverCloseTimer.restart()
                }
            }
        }

    // -------------------------------------------------------------------------
    // CONTENT
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 0

        // ── HEADER ──
        Item {
            Layout.fillWidth: true
            height: 34

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: card.headerIcon
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: 14
                    color: Config.BarConfig.colorAccent
                }
                Text {
                    text: card.headerTitle
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 2.5
                    color: Config.BarConfig.colorText
                    Layout.fillWidth: true
                }
                Text {
                    text: "✕"
                    font.pixelSize: 11
                    color: closeArea.containsMouse
                           ? Config.BarConfig.colorAccent
                           : Config.BarConfig.colorTextDim
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: card.closeRequested()
                    }
                }
            }
        }

        // Subtle separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Config.ThemeConfig.hairline
        }

        // ── BODY ──
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: {
                if (card.lastTray === "bluetooth") return 1
                if (card.lastTray === "volume")    return 2
                if (card.lastTray === "power")     return 3
                return 0
            }

            // ── Network ──
            ColumnLayout {
                id: networkBody
                Layout.fillWidth: true
                Layout.margins: 12
                spacing: 0

                // nmcli absent — dim dash instead of a misleading "DISCONNECTED" pill
                Text {
                    visible: !Services.NetworkService.hasNetwork
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "—"
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: 28
                    color: Config.BarConfig.colorTextDim
                }

                RowLayout {
                    visible: Services.NetworkService.hasNetwork
                    Layout.fillWidth: true; spacing: 6
                    Rectangle {
                        width: typeLbl.implicitWidth + 12; height: 18
                        radius: 0
                        color: Services.NetworkService.isConnected ? Config.ThemeConfig.accentTint : Config.ThemeConfig.fillRest
                        border.color: Services.NetworkService.isConnected ? Config.BarConfig.colorAccent : Config.BarConfig.colorBorder
                        border.width: 1
                        Text { id: typeLbl; anchors.centerIn: parent
                            text: !Services.NetworkService.isConnected ? "NONE" : (Services.NetworkService.connectionType === "wifi" ? "WIFI" : "ETH")
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                            color: Services.NetworkService.isConnected ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim }
                    }
                    Rectangle {
                        width: connLbl.implicitWidth + 14; height: 18
                        radius: 0
                        color: Services.NetworkService.isConnected ? Config.BarConfig.colorAccent : Config.ThemeConfig.fillRest
                        border.color: Services.NetworkService.isConnected ? Config.BarConfig.colorAccent : Config.BarConfig.colorBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { id: connLbl; anchors.centerIn: parent
                            text: Services.NetworkService.isConnected ? "CONNECTED" : "DISCONNECTED"
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                            color: Services.NetworkService.isConnected ? Config.BarConfig.colorBackground : Config.BarConfig.colorTextDim }
                    }
                    Item { Layout.fillWidth: true }
                }
                Item { height: 14; visible: Services.NetworkService.hasNetwork }
                // Named state (Omarchy): radio-off otherwise reads as a broken
                // "everything empty" popup — say why it's empty.
                Text {
                    visible: Services.NetworkService.hasNetwork && !Services.NetworkService.wifiRadio && !Services.NetworkService.isConnected
                    Layout.fillWidth: true
                    text: "Wi-Fi radio is off — enable it below"
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 10; font.italic: true
                    color: Config.BarConfig.colorTextDim
                }
                RowLayout { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; spacing: 0
                    Text { text: "SSID"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 40 }
                    Text { text: Services.NetworkService.ssid; font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; font.bold: true; color: Config.BarConfig.colorText; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                Item { height: 8; visible: Services.NetworkService.isConnected }
                RowLayout { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; spacing: 0
                    Text { text: "IP"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 40 }
                    Text { text: Services.NetworkService.ipAddress; font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; color: Config.BarConfig.colorText; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                Item { height: 8; visible: Services.NetworkService.isConnected && Services.NetworkService.connectionType === "wifi" }
                RowLayout {
                    visible: Services.NetworkService.isConnected && Services.NetworkService.connectionType === "wifi"
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "SIGNAL"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 40 }
                    Text { text: Services.NetworkService.signalStrength + "%"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; color: Config.BarConfig.colorText }
                    Item { Layout.fillWidth: true }
                    // 4-bar signal meter — bars fill from the bottom (classic
                    // phone-style strength), active past each 25% threshold.
                    Item {
                        height: 14
                        width: sigBars.implicitWidth
                        Row {
                            id: sigBars
                            anchors.bottom: parent.bottom
                            spacing: 2
                            Repeater {
                                model: 4
                                Rectangle {
                                    width: 4
                                    height: 4 + index * 3
                                    radius: 0
                                    color: Services.NetworkService.signalStrength > index * 25
                                           ? Config.BarConfig.colorAccent
                                           : Config.ThemeConfig.hairlineSoft
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }
                        }
                    }
                }
                // ── link diagnostics: gateway / DNS / latency ──
                Item { height: 10; visible: Services.NetworkService.isConnected }
                Rectangle { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.hairline }
                Item { height: 8; visible: Services.NetworkService.isConnected }
                RowLayout { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; spacing: 0
                    Text { text: "GATEWAY"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 56 }
                    Text { text: Services.NetworkService.gateway ? Services.NetworkService.gateway : "—"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; color: Config.BarConfig.colorText; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                Item { height: 8; visible: Services.NetworkService.isConnected }
                RowLayout { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; spacing: 0
                    Text { text: "DNS"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 56 }
                    Text { text: Services.NetworkService.dns ? Services.NetworkService.dns : "—"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; color: Config.BarConfig.colorText; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                Item { height: 8; visible: Services.NetworkService.isConnected }
                RowLayout { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; spacing: 0
                    Text { text: "LATENCY"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 56 }
                    Text {
                        text: Services.NetworkService.latencyMs >= 0 ? (Math.round(Services.NetworkService.latencyMs) + " ms") : "—"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; font.bold: true
                        color: Services.NetworkService.latencyMs < 0 ? Config.BarConfig.colorTextDim
                              : Services.NetworkService.latencyMs < 50 ? Config.ThemeConfig.colors.success
                              : Services.NetworkService.latencyMs < 150 ? Config.ThemeConfig.colors.warning
                              : Config.ThemeConfig.colors.error
                    }
                }

                // ── live throughput: rate · cumulative since iface up ──
                Item { height: 8; visible: Services.NetworkService.isConnected }
                RowLayout { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; spacing: 0
                    Text { text: "RX"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 56 }
                    Text {
                        // Empty rate = no sample yet (distinguished from a
                        // genuine 0 B/s idle line).
                        text: Services.NetworkService.rxRate === "" ? "—"
                              : Services.NetworkService.rxRate + "  ·  " + Services.NetworkService.rxTotal
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; color: Config.BarConfig.colorText
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                }
                Item { height: 8; visible: Services.NetworkService.isConnected }
                RowLayout { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; spacing: 0
                    Text { text: "TX"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 56 }
                    Text {
                        text: Services.NetworkService.txRate === "" ? "—"
                              : Services.NetworkService.txRate + "  ·  " + Services.NetworkService.txTotal
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; color: Config.BarConfig.colorText
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                }

                // ── Wi-Fi radio on/off toggle ──
                Item { height: 10; visible: Services.NetworkService.hasNetwork }
                Rectangle {
                    visible: Services.NetworkService.hasNetwork
                    Layout.fillWidth: true; height: 26; radius: 0
                    color: {
                        if (wifiBtnArea.containsMouse)
                            return Services.NetworkService.wifiRadio ? Config.ThemeConfig.fillHover : Config.ThemeConfig.accentTint
                        return Services.NetworkService.wifiRadio ? Config.ThemeConfig.fillRest : Config.ThemeConfig.accentTintSoft
                    }
                    border.color: Services.NetworkService.wifiRadio ? Config.BarConfig.colorBorder : Config.BarConfig.colorAccent
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout { anchors.centerIn: parent; spacing: 6
                        Text { text: Services.NetworkService.wifiRadio ? "󰖲" : "󰖩"; font.family: Config.BarConfig.fontNerd; font.pixelSize: 12; color: Services.NetworkService.wifiRadio ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent }
                        Text { text: Services.NetworkService.wifiRadio ? "DISABLE WI-FI" : "ENABLE WI-FI"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Services.NetworkService.wifiRadio ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent }
                    }
                    MouseArea { id: wifiBtnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Services.NetworkService.toggleRadio() }
                }

                Item { Layout.fillHeight: true; visible: Services.NetworkService.hasNetwork }
            }

            // ── Bluetooth ──
            ColumnLayout {
                id: btBody
                Layout.fillWidth: true; Layout.margins: 12; spacing: 0

                // bluetoothctl absent — dim dash instead of a misleading "OFF" pill
                Text {
                    visible: !Services.BluetoothService.hasBluetooth
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "—"
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: 28
                    color: Config.BarConfig.colorTextDim
                }

                RowLayout { visible: Services.BluetoothService.hasBluetooth; Layout.fillWidth: true; spacing: 6
                    Rectangle {
                        width: btLbl.implicitWidth + 12; height: 18
                        radius: 0
                        color: Services.BluetoothService.powered ? Config.BarConfig.colorAccent : Config.ThemeConfig.fillRest
                        border.color: Services.BluetoothService.powered ? Config.BarConfig.colorAccent : Config.BarConfig.colorBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { id: btLbl; anchors.centerIn: parent; text: Services.BluetoothService.powered ? "ON" : "OFF"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Services.BluetoothService.powered ? Config.BarConfig.colorBackground : Config.BarConfig.colorTextDim }
                    }
                    Item { Layout.fillWidth: true }
                }
                Item { height: 10; visible: Services.BluetoothService.hasBluetooth }
                Rectangle { visible: Services.BluetoothService.hasBluetooth; Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.hairline }
                Item { height: 8; visible: Services.BluetoothService.hasBluetooth }
                Text { visible: Services.BluetoothService.hasBluetooth; text: Services.BluetoothService.deviceCount + " DEVICE" + (Services.BluetoothService.deviceCount !== 1 ? "S" : "") + " CONNECTED"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim }
                Item { height: 6; visible: Services.BluetoothService.hasBluetooth }
                // Capped ListView instead of an unbounded Repeater: sizes to its
                // content up to ~4 rows and scrolls beyond that — and because
                // the height is explicit, btBody.implicitHeight becomes
                // reliable (Repeater delegates never were, which is what forced
                // the old hand-tuned height formula in the dropdown binding).
                ListView {
                    id: btDeviceList
                    visible: Services.BluetoothService.hasBluetooth
                    Layout.fillWidth: true
                    Layout.preferredHeight: count > 0 ? Math.min(contentHeight, 64) : 0
                    clip: true
                    interactive: contentHeight > height
                    spacing: 0
                    model: Services.BluetoothService.devices
                    delegate: Item {
                        width: btDeviceList.width
                        height: 18
                        required property var modelData

                        // Subtle row hover fill — pairs with the revealed
                        // disconnect affordance.
                        Rectangle {
                            anchors.fill: parent
                            color: rowHover.containsMouse ? Config.ThemeConfig.fillHover : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        // Hover catcher sits UNDER the content row so the
                        // disconnect button (with its own MouseArea) still gets
                        // clicks; plain Texts pass hover through.
                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 6
                            Text { text: "󰂱"; font.family: Config.BarConfig.fontNerd; font.pixelSize: 11; color: Config.BarConfig.colorAccent }
                            Text {
                                text: modelData.name
                                font.family: Config.BarConfig.fontFamily; font.pixelSize: 11
                                color: Config.BarConfig.colorText
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            // Battery % when the device reports one (MX-style
                            // mice/headsets do), dim right-aligned.
                            Text {
                                visible: Services.BluetoothService.deviceBatteries[modelData.address] !== undefined
                                text: Services.BluetoothService.deviceBatteries[modelData.address] + "%"
                                font.family: Config.BarConfig.fontFamily; font.pixelSize: 9
                                color: Config.BarConfig.colorTextDim
                            }
                            // Hover-revealed disconnect (Omarchy row idiom).
                            Text {
                                visible: rowHover.containsMouse
                                text: "✕"
                                font.pixelSize: 10
                                color: disconnectArea.containsMouse ? Config.ThemeConfig.colors.error : Config.BarConfig.colorTextDim
                                Behavior on color { ColorAnimation { duration: 100 } }
                                MouseArea {
                                    id: disconnectArea
                                    anchors.fill: parent
                                    anchors.margins: -6   // generous hit target
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: Services.BluetoothService.disconnectDevice(modelData.address)
                                }
                            }
                        }
                    }
                }
                // Named empty states (Omarchy): off vs powered-but-nothing say
                // different things, and point at where full management lives.
                Text {
                    visible: Services.BluetoothService.hasBluetooth && Services.BluetoothService.deviceCount === 0
                    text: Services.BluetoothService.powered ? "No devices connected — pairing lives in Settings ▸ Control"
                                                           : "Bluetooth is off"
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 10; color: Config.BarConfig.colorTextDim; font.italic: true
                }
                Item { Layout.fillHeight: true; visible: Services.BluetoothService.hasBluetooth }
                Rectangle {
                    visible: Services.BluetoothService.hasBluetooth
                    Layout.fillWidth: true; height: 26
                    radius: 0
                    color: {
                        if (btBtnArea.containsMouse)
                            return Services.BluetoothService.powered ? Config.ThemeConfig.fillHover : Config.ThemeConfig.accentTint
                        return Services.BluetoothService.powered ? Config.ThemeConfig.fillRest : Config.ThemeConfig.accentTintSoft
                    }
                    border.color: Services.BluetoothService.powered ? Config.BarConfig.colorBorder : Config.BarConfig.colorAccent
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout { anchors.centerIn: parent; spacing: 6
                        Text { text: Services.BluetoothService.powered ? "󰂲" : "󰂯"; font.family: Config.BarConfig.fontNerd; font.pixelSize: 12; color: Services.BluetoothService.powered ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent }
                        Text { text: Services.BluetoothService.powered ? "DISABLE" : "ENABLE"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Services.BluetoothService.powered ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent }
                    }
                    MouseArea { id: btBtnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Services.BluetoothService.togglePower() }
                }

                // Nudge the DISABLE/ENABLE button 15px up from the bottom edge of
                // the (wifi-matching) box so it isn't flush against it.
                Item { height: 15; visible: Services.BluetoothService.hasBluetooth }
            }

            // ── Volume ──
            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 0

                // wpctl absent — dim dash instead of a misleading "0%"
                Text {
                    visible: !Services.AudioService.hasAudio
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "—"
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: 28
                    color: Config.BarConfig.colorTextDim
                }

                RowLayout {
                    visible: Services.AudioService.hasAudio
                    Layout.fillWidth: true; spacing: 10
                    Text {
                        text: Services.AudioService.muted ? "󰝟" : (Services.AudioService.volume > 66 ? "󰕾" : "󰕿")
                        font.family: Config.BarConfig.fontNerd; font.pixelSize: 22
                        color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        text: Math.round(Services.AudioService.volume) + "%"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 30; font.bold: true
                        color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorText
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Item { Layout.fillWidth: true }
                }
                Item { height: 14; visible: Services.AudioService.hasAudio }
                Slider {
                    id: volSlider
                    visible: Services.AudioService.hasAudio
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28        // generous vertical click band
                    hoverEnabled: true
                    from: 0; to: 100
                    value: Services.AudioService.volume
                    onMoved: {
                        Services.AudioService.setVolume(value)
                        Services.OsdService.showVolume(value, Services.AudioService.muted)
                    }
                    background: Rectangle {
                        x: volSlider.leftPadding
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitHeight: 6; width: volSlider.availableWidth; radius: 0
                        color: Config.ThemeConfig.hairlineSoft
                        Rectangle {
                            height: parent.height
                            width: volSlider.visualPosition * parent.width
                            radius: 0
                            color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                    handle: Rectangle {
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        width: 18; height: 18; radius: 0
                        color: Config.BarConfig.colorBackground
                        border.color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent
                        border.width: 2
                        // Grow on hover / press so the grab target reads as interactive.
                        scale: volSlider.pressed ? 1.15 : (volSlider.hovered ? 1.1 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }
                }
                Item { height: 12; visible: Services.AudioService.hasAudio }
                Rectangle {
                    visible: Services.AudioService.hasAudio
                    Layout.fillWidth: true; height: 26
                    radius: 0
                    color: {
                        if (muteBtnArea.containsMouse)
                            return Services.AudioService.muted ? Config.ThemeConfig.accentTint : Config.ThemeConfig.fillHover
                        return Services.AudioService.muted ? Config.ThemeConfig.accentTintSoft : Config.ThemeConfig.fillRest
                    }
                    border.color: Services.AudioService.muted ? Config.BarConfig.colorAccent : Config.BarConfig.colorBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout { anchors.centerIn: parent; spacing: 6
                        Text { text: Services.AudioService.muted ? "󰕾" : "󰝟"; font.family: Config.BarConfig.fontNerd; font.pixelSize: 12; color: Services.AudioService.muted ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim }
                        Text { text: Services.AudioService.muted ? "UNMUTE" : "MUTE"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Services.AudioService.muted ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim }
                    }
                    MouseArea { id: muteBtnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: {
                        Services.AudioService.toggleMute()
                        Services.OsdService.showMute(Services.AudioService.muted)
                    } }
                }
            }

            // ── Power ──
            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 0
                RowLayout { Layout.fillWidth: true; spacing: 6
                    Rectangle {
                        width: pwrLbl.implicitWidth + 16; height: 18
                        radius: 0
                        color: {
                            if (!Services.BatteryService.hasBattery)      return Config.ThemeConfig.accentTint
                            if (Services.BatteryService.charging)          return Config.ThemeConfig.successTint
                            if (Services.BatteryService.percentage <= 20)  return Config.ThemeConfig.errorTint
                            return Config.ThemeConfig.fillRest
                        }
                        border.color: {
                            if (!Services.BatteryService.hasBattery)      return Config.BarConfig.colorAccent
                            if (Services.BatteryService.charging)          return Config.ThemeConfig.colors.success
                            if (Services.BatteryService.percentage <= 20)  return Config.ThemeConfig.colors.error
                            return Config.BarConfig.colorBorder
                        }
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Text { id: pwrLbl; anchors.centerIn: parent; text: Services.BatteryService.stateLabel
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                            color: { if (!Services.BatteryService.hasBattery) return Config.BarConfig.colorAccent; if (Services.BatteryService.charging) return Config.ThemeConfig.colors.success; if (Services.BatteryService.percentage <= 20) return Config.ThemeConfig.colors.error; return Config.BarConfig.colorTextDim }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
                Item { height: 14 }
                RowLayout { visible: Services.BatteryService.hasBattery; Layout.fillWidth: true; spacing: 0
                    Text { text: "CHARGE"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 52 }
                    Text { text: Services.BatteryService.percentage + "%"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 13; font.bold: true
                        color: { if (Services.BatteryService.charging) return Config.ThemeConfig.colors.success; if (Services.BatteryService.percentage <= 20) return Config.ThemeConfig.colors.error; if (Services.BatteryService.percentage <= 50) return Config.ThemeConfig.colors.warning; return Config.BarConfig.colorText }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
                Item { height: 8; visible: Services.BatteryService.hasBattery }
                RowLayout { Layout.fillWidth: true; spacing: 0
                    Text { text: "SOURCE"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorTextDim; Layout.preferredWidth: 52 }
                    Text { text: Services.BatteryService.onAc ? "AC / Wall" : "Battery"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 12; color: Config.BarConfig.colorText }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
    }   // dropdown Rectangle
}
