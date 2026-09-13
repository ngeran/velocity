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
import Quickshell.Io
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
    // NETWORK CREDENTIALS sub-view (QR) — only meaningful for the network tray.
    property bool qrOpen: false
    // Copy feedback (QR view) — auto-resets so the button label reverts.
    property bool copied: false
    property bool copyFailed: false
    Timer {
        id: copyResetTimer
        interval: 1600
        onTriggered: { card.copied = false; card.copyFailed = false }
    }
    Connections {
        target: Services.NetworkService
        function onQrCopyDone(ok) {
            card.copied = ok
            card.copyFailed = !ok
            copyResetTimer.restart()
        }
    }
    signal closeRequested()

    // HOVER-OUT DISMISSAL
    // The card closes shortly after the cursor leaves the dropdown — but only
    // once the cursor has actually entered it. This guard means opening a tray
    // (cursor still on the bar icon) doesn't immediately start the close timer;
    // you have to move into the card and back out for it to dismiss on hover.
    property bool hasHoveredDropdown: false
    onActiveTrayChanged: {
        if (activeTray !== "") lastTray = activeTray
        if (activeTray !== "network") qrOpen = false   // QR view is network-only
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
        return ""
    }
    readonly property string headerTitle: {
        if (lastTray === "network")   return "NETWORK"
        if (lastTray === "bluetooth") return "BLUETOOTH"
        if (lastTray === "volume")    return "VOLUME"
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
        anchors.rightMargin: 5 // 5px breathing room from the screen edge
        // CONTENT-FITTED: width and height derive from the ACTIVE body's
        // implicit size + shared chrome (12px content margins ×2 + 34 header
        // + 1 separator ≈ 59). The 300 floor keeps tiny bodies usable.
        width: Math.max(300, networkBody.implicitWidth,
                             btBody.implicitWidth,
                             volumeBody.implicitWidth) + 44
        // Keyed on lastTray so the height stays frozen through the fade-out.
        // The QR credentials view replaces the network body and has its own
        // height budget.
        height: card.lastTray === "network"
                ? (card.qrOpen ? qrBody.implicitHeight + 66 : networkBody.implicitHeight + 59)
              : card.lastTray === "volume" ? volumeBody.implicitHeight + 59
              : card.lastTray === "bluetooth" ? btBody.implicitHeight + 59
              : 220
        color: Config.BarConfig.colorBackground
        radius: 10

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
        anchors.margins: 12
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
                    // BT scan/re-discover — visible on the bluetooth tray
                    visible: card.lastTray === "bluetooth" && Services.BluetoothService.hasBluetooth
                    text: "󰑐"
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: 13
                    color: hdrScanArea.containsMouse
                           ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: hdrScanArea
                        anchors.fill: parent; anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: Services.BluetoothService.startScan()
                    }
                }
                Text {
                    // QR entry — opens the NETWORK CREDENTIALS view
                    visible: card.lastTray === "network" && Services.NetworkService.isConnected
                    text: "󰀄"
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: 13
                    color: hdrQrArea.containsMouse || card.qrOpen
                           ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: hdrQrArea
                        anchors.fill: parent; anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            card.qrOpen = true
                            Services.NetworkService.generateQr()
                        }
                    }
                }
                Text {
                    // volume tray: node id label (mockup "hw:0,0" slot)
                    visible: card.lastTray === "volume" && Services.AudioService.hasAudio
                    text: Services.AudioService.hwLabel
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 8
                    color: Config.BarConfig.colorTextDim
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: 110
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
                return 0
            }

            // ── Network ──
            ColumnLayout {
                id: networkBody
                Layout.fillWidth: true
                Layout.margins: 16
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
                        width: typeLbl.implicitWidth + 18; height: 24
                        radius: 5
                        color: Services.NetworkService.isConnected ? Config.ThemeConfig.accentTint : Config.ThemeConfig.fillRest
                        border.color: Services.NetworkService.isConnected ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { id: typeLbl; anchors.centerIn: parent
                            text: !Services.NetworkService.isConnected ? "NONE" : (Services.NetworkService.connectionType === "wifi" ? "WIFI" : "ETH")
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                            color: Services.NetworkService.isConnected ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorTextDim }
                    }
                    Rectangle {
                        width: connLbl.implicitWidth + 18; height: 24
                        radius: 5
                        color: Services.NetworkService.isConnected ? Config.ThemeConfig.accentTint : Config.ThemeConfig.fillRest
                        border.color: Services.NetworkService.isConnected ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { id: connLbl; anchors.centerIn: parent
                            text: Services.NetworkService.isConnected ? "CONNECTED" : "DISCONNECTED"
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                            color: Services.NetworkService.isConnected ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorTextDim }
                    }
                    Item { Layout.fillWidth: true }
                    // QR Connect — opens the NETWORK CREDENTIALS view
                    Rectangle {
                        visible: Services.NetworkService.isConnected
                        width: qrConnRow.implicitWidth + 18; height: 24
                        radius: 5
                        color: qrConnArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                        border.color: Config.BarConfig.colorBorder; border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Row {
                            id: qrConnRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "󰀄"; font.family: Config.BarConfig.fontNerd; font.pixelSize: 10; color: Config.BarConfig.colorText; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "QR Connect"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 9; color: Config.BarConfig.colorText; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: qrConnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                card.qrOpen = true
                                Services.NetworkService.generateQr()
                            }
                        }
                    }
                }
                Item { height: 12; visible: Services.NetworkService.hasNetwork }
                // Named state (Omarchy): radio-off otherwise reads as a broken
                // "everything empty" popup — say why it's empty.
                Text {
                    visible: Services.NetworkService.hasNetwork && !Services.NetworkService.wifiRadio && !Services.NetworkService.isConnected
                    Layout.fillWidth: true
                    text: "Wi-Fi radio is off — enable it below"
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 10; font.italic: true
                    color: Config.BarConfig.colorTextDim
                }
                // ── detail rows — label left · value RIGHT (mockup) ──
                component NetRow: Item {
                    property string label: ""
                    property string value: "—"
                    property bool valueBold: true
                    property color valueColor: Config.BarConfig.colorText
                    // content-based width: the card sizes itself from these
                    implicitWidth: lblTxt.implicitWidth + valTxt.implicitWidth + 16
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    Text {
                        id: lblTxt
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.label
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 10
                        font.letterSpacing: 1
                        color: Config.BarConfig.colorTextDim
                    }
                    Text {
                        id: valTxt
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.value
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 13
                        font.bold: parent.valueBold
                        color: parent.valueColor
                        elide: Text.ElideMiddle
                        width: Math.min(implicitWidth, parent.width * 0.7)
                        horizontalAlignment: Text.AlignRight
                    }
                }

                NetRow {
                    visible: Services.NetworkService.isConnected
                    label: "SSID"
                    value: Services.NetworkService.ssid
                }
                NetRow {
                    visible: Services.NetworkService.isConnected
                    label: "IP"
                    value: Services.NetworkService.ipAddress !== "" ? Services.NetworkService.ipAddress : "—"
                }
                // SIGNAL row — % + 4-bar meter on the right (mockup)
                RowLayout {
                    visible: Services.NetworkService.isConnected && Services.NetworkService.connectionType === "wifi"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 0
                    Text {
                        text: "SIGNAL"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 10
                        font.letterSpacing: 1
                        color: Config.BarConfig.colorTextDim
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Services.NetworkService.signalStrength + "%"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 13; font.bold: true
                        color: Config.BarConfig.colorText
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { width: 10 }
                    Item {
                        Layout.preferredWidth: sigBars.implicitWidth
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Row {
                            id: sigBars
                            anchors.bottom: parent.bottom
                            spacing: 2
                            Repeater {
                                model: 4
                                Rectangle {
                                    width: 4
                                    height: 5 + index * 3
                                    color: Services.NetworkService.signalStrength > index * 25
                                           ? Config.ThemeConfig.colors.primary
                                           : Config.ThemeConfig.hairlineSoft
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }
                        }
                    }
                }
                Item { height: 4; visible: Services.NetworkService.isConnected }
                Rectangle { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.hairline }
                Item { height: 4; visible: Services.NetworkService.isConnected }
                NetRow {
                    visible: Services.NetworkService.isConnected
                    label: "GATEWAY"
                    value: Services.NetworkService.gateway !== "" ? Services.NetworkService.gateway : "—"
                }
                NetRow {
                    visible: Services.NetworkService.isConnected
                    label: "DNS"
                    value: Services.NetworkService.dns !== "" ? Services.NetworkService.dns : "—"
                }
                NetRow {
                    visible: Services.NetworkService.isConnected
                    label: "LATENCY"
                    value: Services.NetworkService.latencyMs >= 0 ? (Math.round(Services.NetworkService.latencyMs) + " ms") : "—"
                    valueColor: Services.NetworkService.latencyMs < 0 ? Config.BarConfig.colorTextDim
                              : Services.NetworkService.latencyMs < 50 ? Config.ThemeConfig.colors.success
                              : Config.ThemeConfig.colors.error
                }
                NetRow {
                    visible: Services.NetworkService.isConnected
                    label: "RX"
                    value: Services.NetworkService.rxRate === "" ? "—"
                          : Services.NetworkService.rxRate + "  ·  " + Services.NetworkService.rxTotal
                    valueBold: false
                }
                NetRow {
                    visible: Services.NetworkService.isConnected
                    label: "TX"
                    value: Services.NetworkService.txRate === "" ? "—"
                          : Services.NetworkService.txRate + "  ·  " + Services.NetworkService.txTotal
                    valueBold: false
                }
                Item { height: 4; visible: Services.NetworkService.isConnected }
                Rectangle { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.hairline }
                Item { height: 8; visible: Services.NetworkService.isConnected }
                // ── Wi-Fi radio on/off toggle (mockup: full-width pill) ──
                Item { height: 10; visible: Services.NetworkService.hasNetwork }
                Rectangle {
                    visible: Services.NetworkService.hasNetwork
                    Layout.fillWidth: true; height: 34; radius: 6
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


            // ── Bluetooth ── mockup port: adapter row (ON pill · UP state ·
            // DISCOVERABLE chip), connected-device cards with battery bars,
            // PAIRED & NEARBY list with CONNECT/PAIR, DISABLE footer.
            ColumnLayout {
                id: btBody
                Layout.fillWidth: true; Layout.margins: 16; spacing: 0

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

                // ── adapter row: ON pill · UP state · DISCOVERABLE chip ──
                RowLayout {
                    visible: Services.BluetoothService.hasBluetooth
                    Layout.fillWidth: true; spacing: 10

                    Rectangle {
                        width: btLbl.implicitWidth + 20; height: 26
                        radius: 5
                        color: Services.BluetoothService.powered ? Config.ThemeConfig.accentTint : Config.ThemeConfig.fillRest
                        border.color: Services.BluetoothService.powered ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { id: btLbl; anchors.centerIn: parent
                            text: Services.BluetoothService.powered ? "ON" : "OFF"
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                            color: Services.BluetoothService.powered ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorTextDim }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.BluetoothService.togglePower()
                        }
                    }
                    Text {
                        text: Services.BluetoothService.powered ? "adapter: UP" : "adapter: DOWN"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 10
                        color: Config.BarConfig.colorTextDim
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        visible: Services.BluetoothService.hasBluetooth
                        width: discRow.implicitWidth + 16; height: 24
                        radius: 5
                        color: "transparent"
                        border.color: Config.BarConfig.colorBorder; border.width: 1
                        Row {
                            id: discRow
                            anchors.centerIn: parent; spacing: 6
                            Rectangle {
                                width: 5; height: 5; radius: 2.5
                                color: Config.ThemeConfig.colors.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "DISCOVERABLE"
                                font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true
                                font.letterSpacing: 1.2
                                color: Config.BarConfig.colorText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.BluetoothService.startScan()
                        }
                    }
                }
                Item { height: 10; visible: Services.BluetoothService.hasBluetooth }
                Rectangle { visible: Services.BluetoothService.hasBluetooth; Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.hairline }
                Item { height: 8; visible: Services.BluetoothService.hasBluetooth }

                // ── CONNECTED section header ──
                RowLayout {
                    visible: Services.BluetoothService.hasBluetooth
                    Layout.fillWidth: true
                    Text {
                        text: Services.BluetoothService.deviceCount + " DEVICE" + (Services.BluetoothService.deviceCount !== 1 ? "S" : "") + " CONNECTED"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true
                        font.letterSpacing: 1.5
                        color: Config.BarConfig.colorTextDim
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "BATTERY"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true
                        font.letterSpacing: 1.5
                        color: Config.BarConfig.colorTextDim
                    }
                }
                Item { height: 6; visible: Services.BluetoothService.hasBluetooth }

                // ── connected device cards ──
                Repeater {
                    visible: Services.BluetoothService.hasBluetooth
                    model: Services.BluetoothService.connectedDevices.slice(0, 4)

                    delegate: Rectangle {
                        required property var modelData
                        readonly property var batt: Services.BluetoothService.deviceBatteries[modelData.address]
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        Layout.bottomMargin: 8
                        radius: 6
                        color: rowHover.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                        border.color: Config.BarConfig.colorBorder; border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 10

                            Text { text: modelData.icon; font.family: Config.BarConfig.fontNerd; font.pixelSize: 14; color: Config.BarConfig.colorAccent }
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 11; font.bold: true
                                    color: Config.BarConfig.colorText
                                    elide: Text.ElideRight; Layout.maximumWidth: 190
                                }
                                Text {
                                    text: modelData.address
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 8
                                    color: Config.BarConfig.colorTextDim
                                    elide: Text.ElideMiddle; Layout.maximumWidth: 190
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                visible: batt !== undefined
                                text: batt + "%"
                                font.family: Config.BarConfig.fontFamily; font.pixelSize: 11; font.bold: true
                                color: Config.BarConfig.colorText
                            }
                            // battery bar (mockup) — green when healthy
                            Rectangle {
                                visible: batt !== undefined
                                width: 22; height: 11; radius: 2
                                color: Config.ThemeConfig.hairlineSoft
                                border.color: Config.BarConfig.colorBorder; border.width: 1
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top; anchors.bottom: parent.top
                                    anchors.margins: 2
                                    width: (parent.width - 4) * batt / 100
                                    height: parent.height - 4
                                    color: batt >= 50 ? Config.ThemeConfig.colors.success
                                         : batt >= 25 ? Config.ThemeConfig.colors.warning
                                         : Config.ThemeConfig.colors.error
                                }
                            }
                            // hover-revealed disconnect (kept from the old row)
                            Text {
                                visible: rowHover.containsMouse
                                text: "✕"
                                font.pixelSize: 10
                                color: discArea.containsMouse ? Config.ThemeConfig.colors.error : Config.BarConfig.colorTextDim
                                MouseArea {
                                    id: discArea
                                    anchors.fill: parent; anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Services.BluetoothService.disconnectDevice(modelData.address)
                                }
                            }
                        }
                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }

                Text {
                    visible: Services.BluetoothService.hasBluetooth &&
                             Services.BluetoothService.connectedDevices.length === 0
                    Layout.fillWidth: true
                    text: Services.BluetoothService.powered
                          ? "No devices connected — pairing lives in Settings ▸ Control"
                          : "Bluetooth is off"
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 9; font.italic: true
                    color: Config.BarConfig.colorTextDim
                }
                Item { height: 10; visible: Services.BluetoothService.hasBluetooth }

                // ── PAIRED & NEARBY ──
                RowLayout {
                    visible: Services.BluetoothService.hasBluetooth && Services.BluetoothService.powered
                    Layout.fillWidth: true
                    Text {
                        text: "PAIRED & NEARBY"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true
                        font.letterSpacing: 1.5
                        color: Config.BarConfig.colorTextDim
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Services.BluetoothService.adapter && Services.BluetoothService.adapter.discovering
                              ? "SCANNING…" : "SIGNAL"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true
                        font.letterSpacing: 1.5
                        color: Services.BluetoothService.adapter && Services.BluetoothService.adapter.discovering
                               ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorTextDim
                    }
                }
                Item { height: 6; visible: Services.BluetoothService.hasBluetooth && Services.BluetoothService.powered }

                Repeater {
                    visible: Services.BluetoothService.hasBluetooth && Services.BluetoothService.powered
                    model: Services.BluetoothService.pairedDevices.slice(0, 3)

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        Layout.bottomMargin: 8
                        radius: 6
                        color: pnRow.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                        border.color: Config.BarConfig.colorBorder; border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 10
                            spacing: 10
                            Text { text: modelData.icon; font.family: Config.BarConfig.fontNerd; font.pixelSize: 14; color: Config.BarConfig.colorTextDim }
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 11; font.bold: true
                                    color: Config.BarConfig.colorText
                                    elide: Text.ElideRight; Layout.maximumWidth: 180
                                }
                                Text {
                                    text: "Paired"
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 8
                                    color: Config.BarConfig.colorTextDim
                                }
                            }
                            Rectangle {
                                width: pnLbl.implicitWidth + 16; height: 24
                                radius: 5
                                color: pnRow.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                                border.color: Config.BarConfig.colorBorder; border.width: 1
                                Text { id: pnLbl; anchors.centerIn: parent
                                    text: "CONNECT"
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                                    color: Config.BarConfig.colorText }
                                MouseArea {
                                    id: pnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Services.BluetoothService.connectDevice(modelData.address)
                                }
                            }
                        }
                        MouseArea { id: pnRow; anchors.fill: parent; hoverEnabled: true }
                    }
                }

                Repeater {
                    visible: Services.BluetoothService.hasBluetooth && Services.BluetoothService.powered
                    model: Services.BluetoothService.nearbyDevices.slice(0, 2)

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        Layout.bottomMargin: 8
                        radius: 6
                        color: nbRow.containsMouse ? Config.ThemeConfig.fillHover : "transparent"
                        border.color: Config.BarConfig.colorBorder; border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 10
                            spacing: 10
                            Text { text: modelData.icon; font.family: Config.BarConfig.fontNerd; font.pixelSize: 14; color: Config.BarConfig.colorTextDim }
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 11
                                    color: Config.BarConfig.colorText
                                    elide: Text.ElideRight; Layout.maximumWidth: 180
                                }
                                Text {
                                    text: "New device"
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 8
                                    color: Config.BarConfig.colorTextDim
                                }
                            }
                            Rectangle {
                                width: nbLbl.implicitWidth + 16; height: 24
                                radius: 5
                                color: nbArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                                border.color: Config.BarConfig.colorBorder; border.width: 1
                                Text { id: nbLbl; anchors.centerIn: parent
                                    text: "PAIR"
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                                    color: Config.BarConfig.colorText }
                                MouseArea {
                                    id: nbArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Services.BluetoothService.pairDevice(modelData.address)
                                }
                            }
                        }
                        MouseArea { id: nbRow; anchors.fill: parent; hoverEnabled: true }
                    }
                }
                Item { height: 10; visible: Services.BluetoothService.hasBluetooth && Services.BluetoothService.powered }

                // ── DISABLE / ENABLE BLUETOOTH footer (mockup full-width pill) ──
                Rectangle {
                    visible: Services.BluetoothService.hasBluetooth
                    Layout.fillWidth: true; height: 32
                    radius: 6
                    color: btBtnArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                    border.color: Config.BarConfig.colorBorder; border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout { anchors.centerIn: parent; spacing: 6
                        Text { text: Services.BluetoothService.powered ? "󰂲" : "󰂯"; font.family: Config.BarConfig.fontNerd; font.pixelSize: 12; color: Config.BarConfig.colorTextDim }
                        Text { text: Services.BluetoothService.powered ? "DISABLE BLUETOOTH" : "ENABLE BLUETOOTH"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorText }
                    }
                    MouseArea { id: btBtnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Services.BluetoothService.togglePower() }
                }
            }

            // ── Volume ── mockup port: hero %, dB scale, OUTPUT SINK picker,
            // INPUT SOURCE mic strip, MUTE footer.
            ColumnLayout {
                id: volumeBody
                Layout.fillWidth: true; Layout.margins: 16; spacing: 0

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

                // ── HERO — big glyph + huge % ──
                RowLayout {
                    visible: Services.AudioService.hasAudio
                    Layout.fillWidth: true; spacing: 12

                    Text {
                        text: Services.AudioService.muted ? "󰝟" : (Services.AudioService.volume > 66 ? "󰕾" : "󰕿")
                        font.family: Config.BarConfig.fontNerd; font.pixelSize: 30
                        color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.ThemeConfig.colors.primary
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        text: Math.round(Services.AudioService.volume) + "%"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 52; font.bold: true
                        color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorText
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Item { Layout.fillWidth: true }
                }
                Item { height: 6; visible: Services.AudioService.hasAudio }

                // ── master slider ──
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
                            color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.ThemeConfig.colors.primary
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                    handle: Rectangle {
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        width: 18; height: 20; radius: 4
                        color: Config.BarConfig.colorBackground
                        border.color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.ThemeConfig.colors.primary
                        border.width: 2
                        scale: volSlider.pressed ? 1.15 : (volSlider.hovered ? 1.1 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }
                }
                // ── dB scale labels (mockup) ──
                RowLayout {
                    visible: Services.AudioService.hasAudio
                    Layout.fillWidth: true
                    Text { text: "0 dB"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; color: Config.BarConfig.colorTextDim }
                    Item { Layout.fillWidth: true }
                    Text { text: "+6 dB"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; color: Config.BarConfig.colorTextDim }
                    Item { Layout.fillWidth: true }
                    Text { text: "MAX"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; color: Config.BarConfig.colorTextDim }
                }
                Item { height: 10; visible: Services.AudioService.hasAudio }
                Rectangle { visible: Services.AudioService.hasAudio; Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.hairline }
                Item { height: 10; visible: Services.AudioService.hasAudio }

                // ── OUTPUT SINK (PIPEWIRE) picker ──
                RowLayout {
                    visible: Services.AudioService.hasAudio
                    Layout.fillWidth: true; spacing: 8
                    Text {
                        text: "OUTPUT SINK (PIPEWIRE)"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true
                        font.letterSpacing: 1.5
                        color: Config.BarConfig.colorTextDim
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Services.AudioService.hwLabel
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 9
                        color: Config.ThemeConfig.colors.primary
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 130
                    }
                }
                Item { height: 8; visible: Services.AudioService.hasAudio }

                Repeater {
                    visible: Services.AudioService.hasAudio
                    model: Services.AudioService.sinks

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isDefault: modelData === Services.AudioService.sink
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 6
                        color: sinkMa.containsMouse || isDefault
                               ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                        border.color: isDefault ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 10
                            spacing: 10

                            // selected dot (mockup: ● vs ○)
                            Rectangle {
                                width: 7; height: 7; radius: 3.5
                                color: isDefault ? Config.ThemeConfig.colors.primary : "transparent"
                                border.color: Config.ThemeConfig.colors.primary; border.width: 1
                            }
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.description || modelData.nickname || modelData.name
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 11; font.bold: true
                                    color: isDefault ? Config.BarConfig.colorText : Config.BarConfig.colorTextDim
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: sinkRowWidth - 150
                                }
                                Text {
                                    text: modelData.name
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 8
                                    color: Config.BarConfig.colorTextDim
                                    elide: Text.ElideMiddle
                                    Layout.maximumWidth: sinkRowWidth - 150
                                }
                            }
                            // DEFAULT chip + check, or Select hint
                            Rectangle {
                                visible: isDefault
                                width: defLbl.implicitWidth + 12; height: 17
                                radius: 3
                                color: Config.ThemeConfig.accentTint
                                border.color: Config.ThemeConfig.colors.primary; border.width: 1
                                Text { id: defLbl; anchors.centerIn: parent
                                    text: "DEFAULT"
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 7; font.bold: true; font.letterSpacing: 1
                                    color: Config.ThemeConfig.colors.primary }
                            }
                            Text {
                                visible: isDefault
                                text: "✓"
                                font.pixelSize: 12
                                color: Config.ThemeConfig.colors.primary
                            }
                            Text {
                                visible: !isDefault
                                text: "Select"
                                font.family: Config.BarConfig.fontFamily; font.pixelSize: 9
                                color: sinkMa.containsMouse ? Config.BarConfig.colorText : Config.BarConfig.colorTextDim
                            }
                        }
                        MouseArea {
                            id: sinkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: isDefault ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: if (!isDefault) Services.AudioService.setDefaultSink(modelData)
                        }
                    }
                }
                Item { height: 12; visible: Services.AudioService.hasAudio }
                Rectangle { visible: Services.AudioService.hasAudio; Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.hairline }
                Item { height: 10; visible: Services.AudioService.hasAudio }

                // ── INPUT SOURCE (microphone) ──
                ColumnLayout {
                    visible: Services.AudioService.hasMic
                    Layout.fillWidth: true; spacing: 6

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "󰍬"; font.family: Config.BarConfig.fontNerd; font.pixelSize: 11; color: Config.BarConfig.colorTextDim }
                        Text {
                            text: "INPUT SOURCE"
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true
                            font.letterSpacing: 1.5
                            color: Config.BarConfig.colorTextDim
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(Services.AudioService.micVolume) + "%"
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 10; font.bold: true
                            color: Services.AudioService.micMuted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorText
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Slider {
                            id: micSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            hoverEnabled: true
                            from: 0; to: 100
                            value: Services.AudioService.micVolume
                            onMoved: Services.AudioService.setMicVolume(value)
                            background: Rectangle {
                                x: micSlider.leftPadding
                                y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                                implicitHeight: 4; width: micSlider.availableWidth; radius: 0
                                color: Config.ThemeConfig.hairlineSoft
                                Rectangle {
                                    height: parent.height
                                    width: micSlider.visualPosition * parent.width
                                    color: Services.AudioService.micMuted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorText
                                }
                            }
                            handle: Rectangle {
                                x: micSlider.leftPadding + micSlider.visualPosition * (micSlider.availableWidth - width)
                                y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                                width: 14; height: 14; radius: 7
                                color: Config.BarConfig.colorText
                            }
                        }
                        Rectangle {
                            width: micLbl.implicitWidth + 16; height: 24
                            radius: 6
                            color: micBtnArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                            border.color: Config.BarConfig.colorBorder; border.width: 1
                            Text { id: micLbl; anchors.centerIn: parent
                                text: Services.AudioService.micMuted ? "UNMUTE MIC" : "MUTE MIC"
                                font.family: Config.BarConfig.fontFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                                color: Services.AudioService.micMuted ? Config.ThemeConfig.colors.error : Config.BarConfig.colorText }
                            MouseArea { id: micBtnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Services.AudioService.toggleMicMute() }
                        }
                    }
                }
                Item { height: 12; visible: Services.AudioService.hasAudio }

                // ── MUTE footer ──
                Rectangle {
                    visible: Services.AudioService.hasAudio
                    Layout.fillWidth: true; height: 32
                    radius: 6
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

        }

        // ═════════════════════════════════════════════════════════════════════
        // NETWORK CREDENTIALS (QR) — replaces the body when qrOpen. Card-level
        // overlay: it must cover the header too, and its clicks must not fall
        // through to the tray backdrop.
        // ═══════════════════════════════════════════════════════════════════════
        Item {
            id: qrBody
            anchors.fill: parent
            visible: card.qrOpen && card.lastTray === "network"
            z: 10
            implicitHeight: qrCol.implicitHeight + 24

            // swallow all clicks; buttons below re-stop them explicitly
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: qrCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 0

                // ── header: dot · NETWORK CREDENTIALS · ✕ ──
                Item {
                    Layout.fillWidth: true
                    height: 30
                    RowLayout {
                        anchors.fill: parent
                        spacing: 8
                        Rectangle { width: 6; height: 6; radius: 3; color: Config.BarConfig.colorAccent; Layout.alignment: Qt.AlignVCenter }
                        Text {
                            text: "NETWORK CREDENTIALS"
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 10
                            font.bold: true; font.letterSpacing: 2.5
                            color: Config.BarConfig.colorText
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "✕"
                            font.pixelSize: 11
                            color: qrCloseArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
                            Behavior on color { ColorAnimation { duration: 100 } }
                            MouseArea {
                                id: qrCloseArea
                                anchors.fill: parent; anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: card.qrOpen = false
                            }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.hairline }

                // ── white QR card (scanner contract: light ground, dark modules)
                Item { height: 14 }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: qrGrid.matrix.length > 0 ? qrGrid.matrix[0].length * qrGrid.modulePx + qrGrid.quiet * 2 * qrGrid.modulePx : 200
                    height: qrGrid.matrix.length > 0 ? qrGrid.matrix.length * qrGrid.modulePx + qrGrid.quiet * 2 * qrGrid.modulePx : 120
                    color: "#f2f2f2"
                    radius: 12

                    Grid {
                        id: qrGrid
                        property var matrix: Services.NetworkService.qrMatrix
                        property int modulePx: 6
                        property int quiet: 3
                        anchors.centerIn: parent
                        columns: matrix.length > 0 ? matrix[0].length : 0
                        visible: matrix.length > 0

                        Repeater {
                            model: qrGrid.matrix.length > 0 ? qrGrid.matrix[0].length * qrGrid.matrix.length : 0

                            Rectangle {
                                readonly property int row: Math.floor(index / (qrGrid.matrix.length > 0 ? qrGrid.matrix[0].length : 1))
                                readonly property int col: index % (qrGrid.matrix.length > 0 ? qrGrid.matrix[0].length : 1)
                                readonly property bool dark: {
                                    if (qrGrid.matrix.length === 0 || row >= qrGrid.matrix.length) return false
                                    var line = qrGrid.matrix[row] || ""
                                    return col < line.length && line.charAt(col) === "1"
                                }
                                width: qrGrid.modulePx; height: qrGrid.modulePx
                                color: dark ? "#141414" : "#f2f2f2"
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 20
                        visible: Services.NetworkService.qrMatrix.length === 0
                        text: Services.NetworkService.qrError !== "" ? Services.NetworkService.qrError : "generating…"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 9
                        color: "#141414"
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
                Item { height: 10 }

                // ── ssid • security • band ──
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Text {
                        text: Services.NetworkService.qrSsid !== "" ? Services.NetworkService.qrSsid : "—"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 11; font.bold: true
                        color: Config.BarConfig.colorText
                    }
                    Text { text: "•"; font.pixelSize: 10; color: Config.BarConfig.colorTextDim; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: Services.NetworkService.qrSecurity !== "" ? Services.NetworkService.qrSecurity : "OPEN"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text { text: "•"; font.pixelSize: 10; color: Config.BarConfig.colorTextDim; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: Services.NetworkService.qrBand !== "" ? Services.NetworkService.qrBand : "—"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 10
                        color: Config.BarConfig.colorTextDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Item { height: 10 }

                // ── NETWORK KEY chip + Copy ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 8
                    color: Config.ThemeConfig.fillRest
                    border.color: Config.BarConfig.colorBorder; border.width: 1

                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.top: parent.top; anchors.topMargin: 6
                        text: "NETWORK KEY"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 7
                        font.bold: true; font.letterSpacing: 1.5
                        color: Config.BarConfig.colorTextDim
                    }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                        text: Services.NetworkService.qrPassword !== "" ? Services.NetworkService.qrPassword : "—"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 11; font.bold: true
                        color: Config.BarConfig.colorText
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: copyRow.implicitWidth + 16; height: 24
                        radius: 6
                        color: copyArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                        border.color: Config.BarConfig.colorBorder; border.width: 1
                        Row {
                            id: copyRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text { text: card.copied ? "✓" : "󰆏"; font.family: Config.BarConfig.fontNerd; font.pixelSize: 10; color: card.copied ? Config.ThemeConfig.colors.success : Config.BarConfig.colorText; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: card.copied ? "Copied" : "Copy"; font.family: Config.BarConfig.fontFamily; font.pixelSize: 9; color: Config.BarConfig.colorText; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: copyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.NetworkService.copyQrPassword()
                        }
                    }
                }
                Text {
                    visible: card.copyFailed
                    text: "copy failed — wl-copy is not installed"
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 8
                    color: Config.ThemeConfig.colors.error
                }
                Item { height: 8 }

                // ── footer: hint · Close ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "SCAN CAMERA OR QR READER"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: 7
                        font.bold: true; font.letterSpacing: 1.5
                        color: Config.BarConfig.colorTextDim
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: closeLbl.implicitWidth + 18; height: 24
                        radius: 6
                        color: footerCloseArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                        border.color: Config.BarConfig.colorBorder; border.width: 1
                        Text {
                            id: closeLbl; anchors.centerIn: parent
                            text: "Close"
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: 9
                            color: Config.BarConfig.colorText
                        }
                        MouseArea {
                            id: footerCloseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.qrOpen = false
                        }
                    }
                }
            }
        }
    }   // content ColumnLayout
    }   // dropdown Rectangle
}
