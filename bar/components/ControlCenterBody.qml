// =============================================================================
// ControlCenterBody.qml — quick-settings grid (TrayCard body "control")
// =============================================================================
// PAGES (P4.7): "main" — the tile grid + level sliders; "bar" — the extracted
// BarSettingsBody (style/edge/OSD/height/scale/motion/guards/modules), reached
// via the record of the same body and by `controlCenter.page bar` (shell →
// TrayCard.openControlPage). Tiles toggle on click; the › on a tile (or
// right-click) drills into that tray body; the DND tile's › opens the
// notification center.
// QD-OLED: no strokes — state is a tinted fill, inactive content is dimmed,
// and everything lives only while the card is open.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import bar.engine as Engine
import bar.services as Services
import bar.config as Config

ColumnLayout {
    id: root
    spacing: Config.PopupMetrics.px(10)

    property string page: "main"               // "main" | "bar" (P4.7)
    signal drill(string tray)
    signal done()

    // The bar ShellRoot (injected by TrayCard's loader) — verb names match
    // the SettingsWindow IPC functions (openSettings/openThemeTab).
    property var shellApi: null
    function openSettings(verb) {
        if (shellApi) shellApi.settingsCall(verb)
        root.done()
    }
    // P4.6: the DND tile's › hands over to the notification center — the
    // tray card closes (done()) so only the center's window stays up.
    function openCenter() {
        if (shellApi) shellApi.toggleNotificationCenter()
        root.done()
    }

    // RECORD tile source (P4.7): the headless velocity.record service root,
    // mounted by PluginHost — null while the module is disabled (tile hides).
    // Property reads through the var reference stay live (recording/elapsed).
    property var _rec: null
    Component.onCompleted: {
        root._rec = Engine.PluginRegistry.instance("velocity.record", "service")
    }

    component Tile: Rectangle {
        id: tile
        property string glyph: ""
        property string title: ""
        property string detail: ""
        property bool lit: false
        property string drillTo: ""
        signal toggled()
        signal drillRequested()

        Layout.preferredWidth: Config.PopupMetrics.px(112)
        Layout.preferredHeight: Config.PopupMetrics.px(58)
        radius: Config.PopupMetrics.px(10)
        color: tile.lit ? Qt.rgba(Config.BarConfig.colorAccent.r, Config.BarConfig.colorAccent.g, Config.BarConfig.colorAccent.b, tileArea.containsMouse ? 0.22 : 0.16)
                       : tileArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
        Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(m) {
                if (m.button === Qt.RightButton && tile.drillTo !== "") tile.drillRequested()
                else tile.toggled()
            }
        }

        Text {
            x: Config.PopupMetrics.px(10); y: Config.PopupMetrics.px(8)
            text: tile.glyph
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.PopupMetrics.px(15)
            color: tile.lit ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
        }
        Text {
            visible: tile.drillTo !== ""
            anchors.right: parent.right; anchors.top: parent.top
            anchors.rightMargin: Config.PopupMetrics.px(8); anchors.topMargin: Config.PopupMetrics.px(4)
            text: "›"
            font.pixelSize: Config.PopupMetrics.px(16)
            color: drillArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
            MouseArea {
                id: drillArea
                anchors.fill: parent; anchors.margins: -Config.PopupMetrics.px(6)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.drillRequested()
            }
        }
        Column {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: Config.PopupMetrics.px(10)
            spacing: 1
            Text {
                width: parent.width
                text: tile.title
                elide: Text.ElideRight
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(9); font.bold: true; font.letterSpacing: 1.2
                color: tile.lit ? Config.BarConfig.colorText : Config.BarConfig.colorTextDim
            }
            Text {
                width: parent.width
                text: tile.detail
                elide: Text.ElideRight
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(8)
                color: Config.BarConfig.colorTextDim
            }
        }
    }

    // P4.10 adoption: the slider INSIDE the row is the shared CardSlider
    // primitive now (the row keeps glyph / micro-caption / drill chrome;
    // CardSlider carries its own % readout).
    component LevelSlider: RowLayout {
        id: lvl
        property string glyph: ""
        property string label: ""          // optional micro-caption (H2: BACKLIGHT)
        property bool dim: false
        property real value: 0
        property string drillTo: ""
        signal moved(real v)
        signal glyphClicked()
        signal drillRequested()
        Layout.fillWidth: true
        spacing: Config.PopupMetrics.px(8)

        Text {
            text: lvl.glyph
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.PopupMetrics.px(14)
            color: lvl.dim ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent
            Layout.preferredWidth: Config.PopupMetrics.px(18)
            MouseArea {
                anchors.fill: parent; anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: lvl.glyphClicked()
            }
        }
        Text {
            visible: lvl.label !== ""
            text: lvl.label
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: Config.PopupMetrics.px(8)
            color: Config.BarConfig.colorTextDim
            Layout.alignment: Qt.AlignVCenter
        }
        CardSlider {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            value: lvl.value
            dim: lvl.dim
            uiScale: Config.PopupMetrics.scale
            accentColor: Config.ThemeConfig.colors.primary
            dimColor: Config.BarConfig.colorTextDim
            textColor: Config.BarConfig.colorText
            grooveColor: Config.ThemeConfig.hairlineSoft
            onDragged: function(v) { lvl.moved(v) }
        }
        Text {
            visible: lvl.drillTo !== ""
            text: "›"
            font.pixelSize: Config.PopupMetrics.px(16)
            color: lvlDrill.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
            MouseArea {
                id: lvlDrill
                anchors.fill: parent; anchors.margins: -Config.PopupMetrics.px(6)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: lvl.drillRequested()
            }
        }
    }

    // ── MAIN PAGE ────────────────────────────────────────────────────────────
    ColumnLayout {
        id: mainPage
        visible: root.page === "main"
        Layout.fillWidth: true
        // Nested-layout law: an explicit 0 minimum lets the card shrink this
        // page (its implicit is a floor otherwise).
        Layout.minimumWidth: 0
        spacing: Config.PopupMetrics.px(10)

        GridLayout {
            id: tileGrid
            columns: 3
            columnSpacing: Config.PopupMetrics.px(8)
            rowSpacing: Config.PopupMetrics.px(8)

            Tile {
                visible: Services.NetworkService.hasNetwork
                glyph: Services.NetworkService.wifiRadio ? "󰖩" : "󰖪"
                title: "WI-FI"
                lit: Services.NetworkService.wifiRadio
                detail: !Services.NetworkService.wifiRadio ? "Off"
                      : Services.NetworkService.isConnected ? (Services.NetworkService.ssid || "Wired") : "Not connected"
                drillTo: "network"
                onDrillRequested: root.drill("network")
                onToggled: Services.NetworkService.toggleRadio()
            }
            Tile {
                visible: Services.BluetoothService.hasBluetooth
                glyph: Services.BluetoothService.powered ? "󰂯" : "󰂲"
                title: "BLUETOOTH"
                lit: Services.BluetoothService.powered
                detail: !Services.BluetoothService.powered ? "Off"
                      : Services.BluetoothService.connectedDevices.length > 0
                        ? Services.BluetoothService.connectedDevices.length + " connected" : "On"
                drillTo: "bluetooth"
                onDrillRequested: root.drill("bluetooth")
                onToggled: Services.BluetoothService.togglePower()
            }
            Tile {
                glyph: Services.NotificationService.dnd ? "󰂛" : "󰂚"
                title: "DND"                       // renamed from FOCUS (P4.7)
                lit: Services.NotificationService.dnd
                detail: Services.NotificationService.dnd ? "Do not disturb" : "Off"
                drillTo: "notifications"           // › opens the notification center (P4.6)
                onToggled: Services.NotificationService.setDnd(!Services.NotificationService.dnd)
                onDrillRequested: root.openCenter()
            }
            Tile {
                visible: Services.AudioService.hasMic
                glyph: Services.AudioService.micMuted ? "󰍭" : "󰍬"
                title: "MICROPHONE"
                lit: !Services.AudioService.micMuted
                detail: Services.AudioService.micMuted ? "Muted" : "Live"
                onToggled: Services.AudioService.toggleMicMute()
            }
            Tile {
                visible: Services.PowerProfileService.available
                glyph: Services.PowerProfileService.profile === "power-saver" ? "󰌪"
                     : Services.PowerProfileService.profile === "performance" ? "󰓅" : "󰾅"
                title: "POWER"
                lit: Services.PowerProfileService.profile !== "balanced"
                detail: Services.PowerProfileService.label
                onToggled: Services.PowerProfileService.cycle()
            }
            Tile {
                visible: root._rec !== null && root._rec.supported === true
                glyph: "\u{f0369}"
                title: "RECORD"
                lit: root._rec ? root._rec.recording : false
                detail: root._rec ? (root._rec.recording ? root._rec.elapsedLabel : "Idle") : ""
                onToggled: if (root._rec) root._rec.toggle("")
            }
            Tile {
                glyph: "󰏘"
                title: "THEME"
                detail: "Open themes"
                onToggled: root.openSettings("openThemeTab")
            }
        }

        // ── levels ───────────────────────────────────────────────────────────
        LevelSlider {
            visible: Services.AudioService.hasAudio
            glyph: Services.AudioService.muted ? "󰝟" : "󰕾"
            dim: Services.AudioService.muted
            value: Services.AudioService.volume
            drillTo: "volume"
            onDrillRequested: root.drill("volume")
            onMoved: function(v) {
                Services.AudioService.setVolume(v)
                Services.OsdService.showVolume(v, Services.AudioService.muted)
            }
            onGlyphClicked: {
                Services.AudioService.toggleMute()
                Services.OsdService.showMute(Services.AudioService.muted)
            }
        }
        LevelSlider {
            visible: Services.BrightnessService.available
            glyph: "󰃟"
            label: "BACKLIGHT"               // H2: named here, hidden with no backlight/DDC device
            value: Services.BrightnessService.percent
            onMoved: function(v) { Services.BrightnessService.setPercent(v) }
        }

        // ── footer: BAR page + deep link into the settings app ──────────────
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Config.PopupMetrics.px(8)

            // BAR › — in-body page switch (P4.7)
            Rectangle {
                implicitWidth: barFootRow.implicitWidth + Config.PopupMetrics.px(20)
                implicitHeight: Config.PopupMetrics.px(24)
                radius: height / 2
                color: barFootArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                Row {
                    id: barFootRow
                    anchors.centerIn: parent
                    spacing: Config.PopupMetrics.px(6)
                    Text { text: "󰐥"; font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(10)
                           color: Config.BarConfig.colorTextDim; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "BAR ›"; font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
                           font.bold: true; font.letterSpacing: 1.5
                           color: barFootArea.containsMouse ? Config.BarConfig.colorText : Config.BarConfig.colorTextDim
                           anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: barFootArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.page = "bar" }
            }

            Rectangle {
                implicitWidth: footRow.implicitWidth + Config.PopupMetrics.px(20)
                implicitHeight: Config.PopupMetrics.px(24)
                radius: height / 2
                color: footArea.containsMouse ? Config.ThemeConfig.fillHover : Config.ThemeConfig.fillRest
                Row {
                    id: footRow
                    anchors.centerIn: parent
                    spacing: Config.PopupMetrics.px(6)
                    Text { text: "󰒓"; font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(10)
                           color: Config.BarConfig.colorTextDim; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "SETTINGS ›"; font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
                           font.bold: true; font.letterSpacing: 1.5
                           color: footArea.containsMouse ? Config.BarConfig.colorText : Config.BarConfig.colorTextDim
                           anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: footArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.openSettings("openSettings") }
            }
        }
    }

    // ── BAR PAGE (P4.7 — the extracted sections body) ────────────────────────
    BarSettingsBody {
        visible: root.page === "bar"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        showBack: true
        viewportHeight: Config.PopupMetrics.px(440)
        onBackRequested: root.page = "main"
        onPluginsRequested: root.openSettings("openControlPlugins")
    }
}
