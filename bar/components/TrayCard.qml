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
import Quickshell.Io
import "../services" as Services
import "../engine" as Engine
import "../config" as Config

PanelWindow {
    id: card
    // Keep the window alive through the fade-out (opacity > 0 while closing).
    // Island style: the body is presented inside the island (embedHost set
    // by the shell for the owner's screen) and this window never maps.
    visible: !dropdown.embedHost && !dropdown.embedded
             && (activeTray !== "" || dropdown.cardOpacity > 0)
    property var embedHost: null

    // Full-screen transparent overlay. A click landing anywhere outside the
    // dropdown closes it — the same click-outside dismissal the
    // Fastfetch/ZaiUsage/Keybinds overlays use. The card itself is drawn above
    // the backdrop and swallows clicks so interacting with it stays put.
    anchors { top: true; bottom: true; left: true; right: true }
    // Leave the bar strip itself interactive — excluded on the bar's edge.
    margins.top: Config.BarConfig.barAtBottom ? 0 : Config.BarConfig.barHeight
    margins.bottom: Config.BarConfig.barAtBottom ? Config.BarConfig.barHeight : 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    property string activeTray: ""
    // Hairline width, snapped to device pixels (PopupMetrics.hairline) — one
    // read for the whole card: every item inside shares the window's screen.
    readonly property real hair: Config.PopupMetrics.hairline(dropdown)
    // The tray icon that opened this card (set by shell.qml on the owning
    // bar) — the Popover centers the card under it.
    property Item anchorItem: null
    // The tray that is open OR was last open — stays frozen during the fade-out
    // so the closing view's content, header and height don't flash to another
    // body while the 140ms fade runs.
    property string lastTray: ""
    // "OPEN IN SETTINGS ›" — the full manager for each body lives in the
    // settings app (single source); literal call strings for tools/check-ipc.
    readonly property var _settingsCalls: ({
        openControlNetwork: "quickshell ipc -c settings call SettingsWindow openControlNetwork",
        openControlBluetooth: "quickshell ipc -c settings call SettingsWindow openControlBluetooth",
        openControlAudio: "quickshell ipc -c settings call SettingsWindow openControlAudio"
    })
    function openSettings(verb) {
        settingsLauncher.command = ["sh", "-c", card._settingsCalls[verb] + " 2>/dev/null || " +
            "setsid quickshell -c settings >/dev/null 2>&1 &"]
        settingsLauncher.running = true
        card.closeRequested()
    }
    Process {   // unbounded-ok: one-shot ipc call / detached spawn — exits at once
        id: settingsLauncher
        command: []
    }
    component SettingsLink: Item {
        id: link
        property string verb: ""
        signal activated(string verb)
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(10)
        implicitHeight: Config.PopupMetrics.px(20)
        implicitWidth: linkTxt.implicitWidth
        Text {
            id: linkTxt
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: "OPEN IN SETTINGS ›"
            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
            font.bold: true; font.letterSpacing: 1.5
            color: linkArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
        }
        MouseArea { id: linkArea; anchors.fill: linkTxt; anchors.margins: -4; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: link.activated(link.verb) }
    }
    signal closeRequested()
    // Swap the open body in place (Control Center drill-down / back).
    signal switchRequested(string tray)
    // True while a body was reached from the Control Center (shows ‹ back).
    property bool fromControl: false

    // HOVER-OUT DISMISSAL: lives in the Popover primitive (hoverClose +
    // hoverCloseNeedsEntry — the entered-guard idiom this card introduced).
    onActiveTrayChanged: {
        if (activeTray !== "") lastTray = activeTray
        if (activeTray === "" || activeTray === "control") fromControl = false
        if (activeTray === "control") {
            Services.BrightnessService.refresh()
            Services.PowerProfileService.refresh()
        }
        // Popup-gated polling: detail probes run only while their popup is the
        // active one (fetch fires immediately on open; timers stop on close).
        Services.NetworkService.popupOpen = activeTray === "network"
        Services.BluetoothService.popupOpen = activeTray === "bluetooth"
        _publishConnected()
    }

    // Notch-lobe plumbing (mirrors PluginPopup): publish caret geometry while
    // a tray card is open so the lobe carves under it. Keyed "tray.<id>" —
    // plugin panels use their manifest id, so the two classes never collide.
    // Owner-checked clear keeps a successor's publish safe. Host-owned window
    // (mounted by shell.qml), so this survives style swaps — but clear anyway
    // on close: the notch style may have changed while we were open.
    function _publishConnected() {
        Engine.PopupCoordinator.publish("tray." + lastTray, activeTray === "" ? null
            : { screen: card.screen ? card.screen.name : "", caretX: dropdown.cardCenterX })
    }
    Connections {
        target: dropdown
        // Clamp/anchor shifts move the card — keep the carve under the caret.
        function onCardCenterXChanged() {
            if (card.activeTray !== "") card._publishConnected()
        }
    }

    readonly property string headerIcon: {
        if (lastTray === "network")
            return Services.NetworkService.isConnected
                ? (Services.NetworkService.connectionType === "wifi" ? "󰖩" : "󰈀") : "󰖪"
        if (lastTray === "bluetooth") return Services.BluetoothService.powered ? "󰂯" : "󰂲"
        if (lastTray === "volume")    return Services.AudioService.muted ? "󰝟" : "󰕾"
        if (lastTray === "privacy")   return "󰍍"
        if (lastTray === "control")   return "󰒓"
        return ""
    }
    readonly property string headerTitle: {
        if (lastTray === "network")   return "NETWORK"
        if (lastTray === "bluetooth") return "BLUETOOTH"
        if (lastTray === "volume")    return "VOLUME"
        if (lastTray === "privacy")   return "PRIVACY"
        if (lastTray === "control")   return "CONTROL CENTER"
        return ""
    }

    // -------------------------------------------------------------------------
    // DROPDOWN CARD — Popover primitive, anchored under the trigger icon.
    // Sharp-cornered seamless bar extension: no border, gap 0 (the overlay
    // already starts below the bar), edgeMargin 5. External state: activeTray
    // owns opened; backdrop/hover dismissals route back via dismissRequested.
    // -------------------------------------------------------------------------
    Popover {
        id: dropdown
        externalState: true
        opened: card.activeTray !== ""
        embedHost: card.embedHost
        onDismissRequested: card.closeRequested()
        hoverClose: true
        hoverCloseNeedsEntry: true
        showBorder: false
        padding: 0
        gap: 0
        edgeMargin: 5
        anchorItem: card.anchorItem
        // CONTENT-FITTED: width and height derive from the ACTIVE body's
        // implicit size + chrome. A layout's implicit size EXCLUDES its own
        // Layout.margins (the parent reserves that space), so the bodies'
        // px(16) margins are added explicitly on top of the trayContent
        // chrome (12px content margins ×2 + 34 header + 1 hairline = 59).
        // Without the body term every card ran 32px short — the footer pill
        // (DISABLE BLUETOOTH / MUTE / DISABLE WI-FI) clipped exactly — and
        // 12px narrow, squeezing every row.
        readonly property real bodyPad: 2 * Config.PopupMetrics.px(16)
        cardWidth: Math.max(300, networkBody.implicitWidth,
                             btBody.implicitWidth,
                             volumeBody.implicitWidth,
                             privacyBody.implicitWidth,
                             controlBody.implicitWidth) + 24 + bodyPad
        // Keyed on lastTray so the height stays frozen through the fade-out.
        // The QR credentials view replaces the network body and has its own
        // height budget.
        cardHeight: card.lastTray === "network" ? networkBody.implicitHeight + 59 + bodyPad
              : card.lastTray === "volume" ? volumeBody.implicitHeight + 59 + bodyPad
              : card.lastTray === "bluetooth" ? btBody.implicitHeight + 59 + bodyPad
              : card.lastTray === "privacy" ? privacyBody.implicitHeight + 59 + bodyPad
              : card.lastTray === "control" ? controlBody.implicitHeight + 59 + bodyPad
              : 220

        // Tray geometry is card-internal (per-body sizing) — flow through the
        // fill slot, not the primitive's padding column.
        cardArea: trayContent

    // -------------------------------------------------------------------------
    // CONTENT
    // -------------------------------------------------------------------------
    ColumnLayout {
        id: trayContent
        anchors.fill: parent
        anchors.margins: Config.PopupMetrics.px(12)
        spacing: 0

        // ── HEADER ──
        Item {
            Layout.fillWidth: true
            height: Config.PopupMetrics.px(34)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Config.PopupMetrics.px(12)
                anchors.rightMargin: Config.PopupMetrics.px(10)
                spacing: Config.PopupMetrics.px(8)

                Text {
                    // back to the Control Center grid
                    visible: card.fromControl && card.lastTray !== "control"
                    text: "‹"
                    font.pixelSize: Config.PopupMetrics.px(16)
                    color: backArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
                    MouseArea {
                        id: backArea
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: card.switchRequested("control")
                    }
                }
                Text {
                    text: card.headerIcon
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: Config.PopupMetrics.px(14)
                    color: Config.BarConfig.colorAccent
                }
                Text {
                    text: card.headerTitle
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: Config.PopupMetrics.px(10)
                    font.bold: true
                    font.letterSpacing: 2.5
                    color: Config.BarConfig.colorText
                    Layout.fillWidth: true
                }
                Text {
                    // volume tray: node id label (mockup "hw:0,0" slot)
                    visible: card.lastTray === "volume" && Services.AudioService.hasAudio
                    text: Services.AudioService.hwLabel
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
                    color: Config.BarConfig.colorTextDim
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: Config.PopupMetrics.px(110)
                }
                Text {
                    text: "✕"
                    font.pixelSize: Config.PopupMetrics.px(11)
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
            height: card.hair
            color: Config.ThemeConfig.hairline
        }

        // ── BODY ──
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: {
                if (card.lastTray === "bluetooth") return 1
                if (card.lastTray === "volume")    return 2
                if (card.lastTray === "control")   return 3
                return 0
            }

            // ── Network ──
            ColumnLayout {
                id: networkBody
                Layout.fillWidth: true
                Layout.margins: Config.PopupMetrics.px(16)
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
                    font.pixelSize: Config.PopupMetrics.px(28)
                    color: Config.BarConfig.colorTextDim
                }

                RowLayout {
                    visible: Services.NetworkService.hasNetwork
                    Layout.fillWidth: true; spacing: Config.PopupMetrics.px(6)
                    Rectangle {
                        width: connLbl.implicitWidth + 18; height: Config.PopupMetrics.px(24)
                        radius: Config.PopupMetrics.px(5)
                        color: Services.NetworkService.isConnected ? Config.ThemeConfig.accentTint : Config.ThemeConfig.fillRest
                        border.color: Services.NetworkService.isConnected ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorBorder
                        border.width: card.hair
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { id: connLbl; anchors.centerIn: parent
                            text: Services.NetworkService.isConnected ? "CONNECTED" : "DISCONNECTED"
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8); font.bold: true; font.letterSpacing: 1.5
                            color: Services.NetworkService.isConnected ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorTextDim }
                    }
                    Item { Layout.fillWidth: true }
                }
                Item { height: 12; visible: Services.NetworkService.hasNetwork }
                // Named state (Omarchy): radio-off otherwise reads as a broken
                // "everything empty" popup — say why it's empty.
                Text {
                    visible: Services.NetworkService.hasNetwork && !Services.NetworkService.wifiRadio && !Services.NetworkService.isConnected
                    Layout.fillWidth: true
                    text: "Wi-Fi radio is off — enable it below"
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(10); font.italic: true
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
                    Layout.preferredHeight: Config.PopupMetrics.px(28)
                    Text {
                        id: lblTxt
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.label
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(10)
                        font.letterSpacing: 1
                        color: Config.BarConfig.colorTextDim
                    }
                    Text {
                        id: valTxt
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.value
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(13)
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
                    Layout.preferredHeight: Config.PopupMetrics.px(28)
                    spacing: 0
                    Text {
                        text: "SIGNAL"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(10)
                        font.letterSpacing: 1
                        color: Config.BarConfig.colorTextDim
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Services.NetworkService.signalStrength + "%"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(13); font.bold: true
                        color: Config.BarConfig.colorText
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { width: 10 }
                    Item {
                        Layout.preferredWidth: sigBars.implicitWidth
                        Layout.preferredHeight: Config.PopupMetrics.px(16)
                        Layout.alignment: Qt.AlignVCenter
                        Row {
                            id: sigBars
                            anchors.bottom: parent.bottom
                            spacing: Config.PopupMetrics.px(2)
                            Repeater {
                                model: 4
                                Rectangle {
                                    width: Config.PopupMetrics.px(4)
                                    height: Config.PopupMetrics.px(5) + index * 3
                                    color: Services.NetworkService.signalStrength > index * 25
                                           ? Config.ThemeConfig.colors.primary
                                           : Config.ThemeConfig.hairlineSoft
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }
                        }
                    }
                }
                NetRow {
                    visible: Services.NetworkService.isConnected
                    label: "↓ DOWNLOAD"
                    value: Services.NetworkService.rxRate === "" ? "—"
                          : Services.NetworkService.rxRate + "  ·  " + Services.NetworkService.rxTotal
                    valueBold: false
                }
                NetRow {
                    visible: Services.NetworkService.isConnected
                    label: "↑ UPLOAD"
                    value: Services.NetworkService.txRate === "" ? "—"
                          : Services.NetworkService.txRate + "  ·  " + Services.NetworkService.txTotal
                    valueBold: false
                }
                Item { height: Config.PopupMetrics.px(4); visible: Services.NetworkService.isConnected }
                Rectangle { visible: Services.NetworkService.isConnected; Layout.fillWidth: true; height: card.hair; color: Config.ThemeConfig.hairline }
                Item { height: Config.PopupMetrics.px(8); visible: Services.NetworkService.isConnected }
                // ── Wi-Fi radio on/off toggle (mockup: full-width pill) ──
                Item { height: 10; visible: Services.NetworkService.hasNetwork }
                Rectangle {
                    visible: Services.NetworkService.hasNetwork
                    Layout.fillWidth: true; height: Config.PopupMetrics.px(34); radius: Config.PopupMetrics.px(6)
                    color: {
                        if (wifiBtnArea.containsMouse)
                            return Services.NetworkService.wifiRadio ? Config.ThemeConfig.fillHover : Config.ThemeConfig.accentTint
                        return Services.NetworkService.wifiRadio ? Config.ThemeConfig.fillRest : Config.ThemeConfig.accentTintSoft
                    }
                    border.color: Services.NetworkService.wifiRadio ? Config.BarConfig.colorBorder : Config.BarConfig.colorAccent
                    border.width: card.hair
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout { anchors.centerIn: parent; spacing: Config.PopupMetrics.px(6)
                        Text { text: Services.NetworkService.wifiRadio ? "󰖲" : "󰖩"; font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(12); color: Services.NetworkService.wifiRadio ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent }
                        Text { text: Services.NetworkService.wifiRadio ? "DISABLE WI-FI" : "ENABLE WI-FI"; font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8); font.bold: true; font.letterSpacing: 1.5; color: Services.NetworkService.wifiRadio ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent }
                    }
                    MouseArea { id: wifiBtnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Services.NetworkService.toggleRadio() }
                }

                SettingsLink { visible: Services.NetworkService.hasNetwork; verb: "openControlNetwork"; onActivated: function(v) { card.openSettings(v) } }
                Item { Layout.fillHeight: true; visible: Services.NetworkService.hasNetwork }
            }


            // ── Bluetooth ── mockup port: adapter row (ON pill · UP state ·
            // DISCOVERABLE chip), connected-device cards with battery bars,
            // PAIRED & NEARBY list with CONNECT/PAIR, DISABLE footer.
            ColumnLayout {
                id: btBody
                Layout.fillWidth: true; Layout.margins: Config.PopupMetrics.px(16); spacing: 0

                // bluetoothctl absent — dim dash instead of a misleading "OFF" pill
                Text {
                    visible: !Services.BluetoothService.hasBluetooth
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "—"
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: Config.PopupMetrics.px(28)
                    color: Config.BarConfig.colorTextDim
                }

                // ── adapter row: ON pill · UP state · DISCOVERABLE chip ──
                RowLayout {
                    visible: Services.BluetoothService.hasBluetooth
                    Layout.fillWidth: true; spacing: Config.PopupMetrics.px(10)

                    Rectangle {
                        width: btLbl.implicitWidth + 20; height: Config.PopupMetrics.px(26)
                        radius: Config.PopupMetrics.px(5)
                        color: Services.BluetoothService.powered ? Config.ThemeConfig.accentTint : Config.ThemeConfig.fillRest
                        border.color: Services.BluetoothService.powered ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorBorder
                        border.width: card.hair
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { id: btLbl; anchors.centerIn: parent
                            text: Services.BluetoothService.powered ? "ON" : "OFF"
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(9); font.bold: true; font.letterSpacing: 1.5
                            color: Services.BluetoothService.powered ? Config.ThemeConfig.colors.primary : Config.BarConfig.colorTextDim }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.BluetoothService.togglePower()
                        }
                    }
                    Text {
                        text: Services.BluetoothService.powered ? "adapter: UP" : "adapter: DOWN"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(10)
                        color: Config.BarConfig.colorTextDim
                    }
                }
                Item { height: 10; visible: Services.BluetoothService.hasBluetooth }
                Rectangle { visible: Services.BluetoothService.hasBluetooth; Layout.fillWidth: true; height: card.hair; color: Config.ThemeConfig.hairline }
                Item { height: Config.PopupMetrics.px(8); visible: Services.BluetoothService.hasBluetooth }

                // ── CONNECTED section header ──
                RowLayout {
                    visible: Services.BluetoothService.hasBluetooth
                    Layout.fillWidth: true
                    Text {
                        text: Services.BluetoothService.deviceCount + " DEVICE" + (Services.BluetoothService.deviceCount !== 1 ? "S" : "") + " CONNECTED"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8); font.bold: true
                        font.letterSpacing: 1.5
                        color: Config.BarConfig.colorTextDim
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "BATTERY"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8); font.bold: true
                        font.letterSpacing: 1.5
                        color: Config.BarConfig.colorTextDim
                    }
                }
                Item { height: Config.PopupMetrics.px(6); visible: Services.BluetoothService.hasBluetooth }

                // ── connected device cards ──
                Repeater {
                    visible: Services.BluetoothService.hasBluetooth
                    model: Services.BluetoothService.connectedDevices.slice(0, 4)

                    delegate: Rectangle {
                        required property var modelData
                        readonly property var batt: Services.BluetoothService.deviceBatteries[modelData.address]
                        Layout.fillWidth: true
                        Layout.preferredHeight: Config.PopupMetrics.px(46)
                        Layout.bottomMargin: Config.PopupMetrics.px(8)
                        radius: Config.PopupMetrics.px(6)
                        color: rowHover.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                        border.color: Config.BarConfig.colorBorder; border.width: card.hair
                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Config.PopupMetrics.px(12); anchors.rightMargin: Config.PopupMetrics.px(12)
                            spacing: Config.PopupMetrics.px(10)

                            Text { text: modelData.icon; font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(14); color: Config.BarConfig.colorAccent }
                            ColumnLayout {
                                spacing: Config.PopupMetrics.px(1)
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true
                                    color: Config.BarConfig.colorText
                                    elide: Text.ElideRight; Layout.maximumWidth: Config.PopupMetrics.px(190)
                                }
                                Text {
                                    text: modelData.address
                                    font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
                                    color: Config.BarConfig.colorTextDim
                                    elide: Text.ElideMiddle; Layout.maximumWidth: Config.PopupMetrics.px(190)
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                visible: batt !== undefined
                                text: batt + "%"
                                font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true
                                color: Config.BarConfig.colorText
                            }
                            // battery bar (mockup) — green when healthy
                            Rectangle {
                                visible: batt !== undefined
                                width: Config.PopupMetrics.px(22); height: 11; radius: Config.PopupMetrics.px(2)
                                color: Config.ThemeConfig.hairlineSoft
                                border.color: Config.BarConfig.colorBorder; border.width: card.hair
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top; anchors.bottom: parent.top
                                    anchors.margins: Config.PopupMetrics.px(2)
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
                                font.pixelSize: Config.PopupMetrics.px(10)
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
                          ? "No devices connected"
                          : "Bluetooth is off"
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(9); font.italic: true
                    color: Config.BarConfig.colorTextDim
                }
                Item { height: 10; visible: Services.BluetoothService.hasBluetooth }

                // ── DISABLE / ENABLE BLUETOOTH footer (mockup full-width pill) ──
                Rectangle {
                    visible: Services.BluetoothService.hasBluetooth
                    Layout.fillWidth: true; height: Config.PopupMetrics.px(32)
                    radius: Config.PopupMetrics.px(6)
                    color: btBtnArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                    border.color: Config.BarConfig.colorBorder; border.width: card.hair
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout { anchors.centerIn: parent; spacing: Config.PopupMetrics.px(6)
                        Text { text: Services.BluetoothService.powered ? "󰂲" : "󰂯"; font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(12); color: Config.BarConfig.colorTextDim }
                        Text { text: Services.BluetoothService.powered ? "DISABLE BLUETOOTH" : "ENABLE BLUETOOTH"; font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8); font.bold: true; font.letterSpacing: 1.5; color: Config.BarConfig.colorText }
                    }
                    MouseArea { id: btBtnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Services.BluetoothService.togglePower() }
                }
                SettingsLink { visible: Services.BluetoothService.hasBluetooth; verb: "openControlBluetooth"; onActivated: function(v) { card.openSettings(v) } }
            }

            // ── Volume ── mockup port: hero %, dB scale, OUTPUT SINK picker,
            // MUTE footer. Outputs, mic and per-app streams live in Settings.
            ColumnLayout {
                id: volumeBody
                Layout.fillWidth: true; Layout.margins: Config.PopupMetrics.px(16); spacing: 0

                // wpctl absent — dim dash instead of a misleading "0%"
                Text {
                    visible: !Services.AudioService.hasAudio
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "—"
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: Config.PopupMetrics.px(28)
                    color: Config.BarConfig.colorTextDim
                }

                // ── HERO — big glyph + huge % ──
                RowLayout {
                    visible: Services.AudioService.hasAudio
                    Layout.fillWidth: true; spacing: Config.PopupMetrics.px(12)

                    Text {
                        text: Services.AudioService.muted ? "󰝟" : (Services.AudioService.volume > 66 ? "󰕾" : "󰕿")
                        font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(30)
                        color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.ThemeConfig.colors.primary
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        text: Math.round(Services.AudioService.volume) + "%"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(52); font.bold: true
                        color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.BarConfig.colorText
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Item { Layout.fillWidth: true }
                }
                Item { height: Config.PopupMetrics.px(6); visible: Services.AudioService.hasAudio }

                // ── master slider ──
                Slider {
                    id: volSlider
                    visible: Services.AudioService.hasAudio
                    Layout.fillWidth: true
                    Layout.preferredHeight: Config.PopupMetrics.px(28)        // generous vertical click band
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
                        implicitHeight: Config.PopupMetrics.px(6); width: volSlider.availableWidth; radius: 0
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
                        width: 18; height: Config.PopupMetrics.px(20); radius: Config.PopupMetrics.px(4)
                        color: Config.BarConfig.colorBackground
                        border.color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.ThemeConfig.colors.primary
                        border.width: Config.PopupMetrics.px(2)
                        scale: volSlider.pressed ? 1.15 : (volSlider.hovered ? 1.1 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }
                }
                Item { height: 12; visible: Services.AudioService.hasAudio }

                // ── MUTE footer ──
                Rectangle {
                    visible: Services.AudioService.hasAudio
                    Layout.fillWidth: true; height: Config.PopupMetrics.px(32)
                    radius: Config.PopupMetrics.px(6)
                    color: {
                        if (muteBtnArea.containsMouse)
                            return Services.AudioService.muted ? Config.ThemeConfig.accentTint : Config.ThemeConfig.fillHover
                        return Services.AudioService.muted ? Config.ThemeConfig.accentTintSoft : Config.ThemeConfig.fillRest
                    }
                    border.color: Services.AudioService.muted ? Config.BarConfig.colorAccent : Config.BarConfig.colorBorder
                    border.width: card.hair
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout { anchors.centerIn: parent; spacing: Config.PopupMetrics.px(6)
                        Text { text: Services.AudioService.muted ? "󰕾" : "󰝟"; font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(12); color: Services.AudioService.muted ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim }
                        Text { text: Services.AudioService.muted ? "UNMUTE" : "MUTE"; font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8); font.bold: true; font.letterSpacing: 1.5; color: Services.AudioService.muted ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim }
                    }
                    MouseArea { id: muteBtnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: {
                        Services.AudioService.toggleMute()
                        Services.OsdService.showMute(Services.AudioService.muted)
                    } }
                }
                SettingsLink { visible: Services.AudioService.hasAudio; verb: "openControlAudio"; onActivated: function(v) { card.openSettings(v) } }
            }

            // ── Control Center ──
            ControlCenterBody {
                id: controlBody
                Layout.fillWidth: true
                Layout.margins: Config.PopupMetrics.px(16)
                onDrill: function(tray) { card.fromControl = true; card.switchRequested(tray) }
                onDone: card.closeRequested()
            }
        }

        // ── PRIVACY BODY — who is watching or listening ──
        // Reads PrivacyService (native PipeWire link graph): one section per
        // active kind, each app that holds a capture stream under it.
        ColumnLayout {
            id: privacyBody
            visible: card.lastTray === "privacy"
            Layout.fillWidth: true; Layout.margins: Config.PopupMetrics.px(16); spacing: 0

            readonly property var kindRows: {
                var defs = [
                    { key: "mic", glyph: "󰋎", label: "MICROPHONE" },
                    { key: "camera", glyph: "󰍛", label: "CAMERA" },
                    { key: "screen", glyph: "󰍹", label: "SCREEN" }
                ]
                var out = []
                for (var i = 0; i < defs.length; i++) {
                    var apps = Services.PrivacyService.appsFor(defs[i].key)
                    if (apps.length > 0)
                        out.push({ glyph: defs[i].glyph, label: defs[i].label, apps: apps })
                }
                return out
            }

            Text {
                visible: !Services.PrivacyService.hasActive && !Services.PrivacyService.hasInhibitors
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Nothing is watching or listening."
                font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(12)
                color: Config.BarConfig.colorTextDim
            }

            // ── SLEEP INHIBITORS — what is keeping the machine awake ──
            ColumnLayout {
                visible: Services.PrivacyService.hasInhibitors
                Layout.fillWidth: true
                spacing: Config.PopupMetrics.px(6)

                RowLayout {
                    Layout.fillWidth: true; spacing: Config.PopupMetrics.px(8)
                    Text {
                        text: "󰌾"
                        font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(13)
                        color: Config.ThemeConfig.colors.warning
                    }
                    Text {
                        text: "KEPT AWAKE"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
                        font.bold: true; font.letterSpacing: 1.5
                        color: Config.BarConfig.colorTextDim
                    }
                    Item { Layout.fillWidth: true }
                }

                Repeater {
                    model: Services.PrivacyService.inhibitors

                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true; Layout.leftMargin: Config.PopupMetrics.px(21); spacing: Config.PopupMetrics.px(8)
                        Text {
                            text: modelData.who
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(12)
                            color: Config.BarConfig.colorText
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: modelData.why !== ""
                            text: modelData.why
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(9)
                            color: Config.BarConfig.colorTextDim
                            elide: Text.ElideRight
                            Layout.maximumWidth: Config.PopupMetrics.px(140)
                        }
                    }
                }

                Item { height: 10 }
            }

            Repeater {
                model: privacyBody.kindRows

                delegate: ColumnLayout {
                    id: kindSection
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Config.PopupMetrics.px(6)

                    RowLayout {
                        Layout.fillWidth: true; spacing: Config.PopupMetrics.px(8)
                        Text {
                            text: kindSection.modelData.glyph
                            font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(13)
                            color: Config.ThemeConfig.colors.error
                        }
                        Text {
                            text: kindSection.modelData.label
                            font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
                            font.bold: true; font.letterSpacing: 1.5
                            color: Config.BarConfig.colorTextDim
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle { width: Config.PopupMetrics.px(6); height: Config.PopupMetrics.px(6); radius: Config.PopupMetrics.px(3); color: Config.ThemeConfig.colors.error }
                    }

                    Repeater {
                        model: kindSection.modelData.apps

                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true; Layout.leftMargin: Config.PopupMetrics.px(21); spacing: Config.PopupMetrics.px(8)
                            Text {
                                text: modelData.app || "Unknown app"
                                font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(12)
                                color: Config.BarConfig.colorText
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                visible: modelData.pid !== null
                                text: "pid " + modelData.pid
                                font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(9)
                                color: Config.BarConfig.colorTextDim
                            }
                        }
                    }

                    Item { height: 10 }
                }
            }
        }

    }   // content ColumnLayout
    }   // dropdown Rectangle
}
