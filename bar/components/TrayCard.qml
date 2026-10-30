// =============================================================================
// TrayCard.qml
// Natural extension of the bar — same background, no border.
// All corners are sharp (radius 0).
// =============================================================================

import QtQuick
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
    // Keyboard-inert by default (ryoku finding — None): since H1 no tray body
    // takes text input; joining lives in the settings app.

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
    // The bar ShellRoot (injected by shell.qml) — the hosted settings
    // dashboard's functions hang off it since P2.1; verb names match the
    // SettingsWindow IPC functions (openControlNetwork/…).
    property var shellApi: null
    function openSettings(verb) {
        if (shellApi) shellApi.settingsCall(verb)
        card.closeRequested()
    }
    signal closeRequested()
    // Swap the open body in place (Control Center drill-down / back).
    signal switchRequested(string tray)
    // True while a body was reached from the Control Center (shows ‹ back).
    property bool fromControl: false

    // I8 lazy bodies: each body file instantiates on its first open and then
    // lives for the card's lifetime (sizing reads loader.item, guarded).
    property bool _btEverOpened: false
    property bool _volumeEverOpened: false
    property bool _privacyEverOpened: false
    property bool _controlEverOpened: false

    // HOVER-OUT DISMISSAL: lives in the Popover primitive (hoverClose +
    // hoverCloseNeedsEntry — the entered-guard idiom this card introduced).
    onActiveTrayChanged: {
        if (activeTray !== "") lastTray = activeTray
        // Lazy bodies: arm on the tray's first open.
        if (activeTray === "bluetooth") _btEverOpened = true
        if (activeTray === "volume")    _volumeEverOpened = true
        if (activeTray === "privacy")   _privacyEverOpened = true
        if (activeTray === "control")   _controlEverOpened = true
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
                             btLoader.item ? btLoader.item.implicitWidth : 0,
                             volLoader.item ? volLoader.item.implicitWidth : 0,
                             privacyLoader.item ? privacyLoader.item.implicitWidth : 0,
                             controlLoader.item ? controlLoader.item.implicitWidth : 0) + 24 + bodyPad
        // Keyed on lastTray so the height stays frozen through the fade-out.
        // The QR credentials view replaces the network body and has its own
        // height budget. Lazy bodies contribute 0 until first open; once a
        // body has opened, its loader.item lives for the card's lifetime.
        cardHeight: card.lastTray === "network" ? networkBody.implicitHeight + 59 + bodyPad
              : card.lastTray === "volume" ? (volLoader.item ? volLoader.item.implicitHeight : 0) + 59 + bodyPad
              : card.lastTray === "bluetooth" ? (btLoader.item ? btLoader.item.implicitHeight : 0) + 59 + bodyPad
              : card.lastTray === "privacy" ? (privacyLoader.item ? privacyLoader.item.implicitHeight : 0) + 59 + bodyPad
              : card.lastTray === "control" ? (controlLoader.item ? controlLoader.item.implicitHeight : 0) + 59 + bodyPad
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

            // ── Network ── (C3: signal hero · AP list · inline password ·
            // speed test — see NetworkCardBody.qml header)
            NetworkCardBody {
                id: networkBody
                tray: card
                onSettingsRequested: function(verb) { card.openSettings(verb) }
            }


            // ── Bluetooth ── mockup port: adapter row (ON pill · UP state ·
            // DISCOVERABLE chip), connected-device cards with battery bars,
            // PAIRED & NEARBY list with CONNECT/PAIR, DISABLE footer.
            // (I8: BluetoothBody.qml, instantiated on the body's first open.)
            Loader {
                id: btLoader
                active: card._btEverOpened
                Layout.fillWidth: true; Layout.margins: Config.PopupMetrics.px(16)
                sourceComponent: BluetoothBody {
                    tray: card
                    onSettingsRequested: function(verb) { card.openSettings(verb) }
                }
            }

            // ── Volume ── mockup port: hero %, dB scale, OUTPUT SINK picker,
            // MUTE footer. Outputs, mic and per-app streams live in Settings.
            // (I8: VolumeBody.qml, instantiated on the body's first open.)
            Loader {
                id: volLoader
                active: card._volumeEverOpened
                Layout.fillWidth: true; Layout.margins: Config.PopupMetrics.px(16)
                sourceComponent: VolumeBody {
                    tray: card
                    onSettingsRequested: function(verb) { card.openSettings(verb) }
                }
            }

            // ── Control Center ──
            // (I8: instantiated on the body's first open.)
            Loader {
                id: controlLoader
                active: card._controlEverOpened
                Layout.fillWidth: true; Layout.margins: Config.PopupMetrics.px(16)
                sourceComponent: ControlCenterBody {
                    shellApi: card.shellApi
                    onDrill: function(tray) { card.fromControl = true; card.switchRequested(tray) }
                    onDone: card.closeRequested()
                }
            }
        }

        // ── PRIVACY BODY — who is watching or listening ──
        // Reads PrivacyService (native PipeWire link graph): one section per
        // active kind, each app that holds a capture stream under it.
        // (I8: PrivacyBody.qml, instantiated on the body's first open. The
        // poll demand is a binding on lastTray now — value-equal to the old
        // onVisibleChanged handler; lastTray freezes through the fade-out, so
        // the demand outlives close exactly as before.)
        Loader {
            id: privacyLoader
            active: card._privacyEverOpened
            visible: card.lastTray === "privacy"
            Layout.fillWidth: true; Layout.margins: Config.PopupMetrics.px(16)
            sourceComponent: PrivacyBody {}
        }
        // Body open → PrivacyService polls; closed → it may idle again. A
        // Binding element (a bare `Services.X.prop:` line parses as attached-
        // property syntax and fails). lastTray freezes through the fade-out,
        // so the demand outlives close exactly as the old handler did.
        Binding {
            target: Services.PrivacyService
            property: "bodyDemanded"
            value: card.lastTray === "privacy"
        }

    }   // content ColumnLayout
    }   // dropdown Rectangle
}
