// =============================================================================
// ControlCenterBody.qml — quick-settings grid (TrayCard body "control")
// =============================================================================
// Tiles toggle on click; the › on a tile (or right-click) drills into that
// tray body. Volume/brightness sliders, deep links into the settings app.
// QD-OLED: no strokes — state is a tinted fill, inactive content is dimmed,
// and everything lives only while the card is open.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../services" as Services
import "../config" as Config

ColumnLayout {
    id: root
    spacing: Config.PopupMetrics.px(10)

    signal drill(string tray)
    signal done()


    // Literal call strings (tools/check-ipc greps for them); launches the
    // settings shell when it isn't running.
    readonly property var _settingsCalls: ({
        openSettings: "quickshell ipc -c settings call SettingsWindow openSettings",
        openThemeTab: "quickshell ipc -c settings call SettingsWindow openThemeTab"
    })
    function openSettings(verb) {
        launcher.command = ["sh", "-c", root._settingsCalls[verb] + " 2>/dev/null || " +
            "setsid quickshell -c settings >/dev/null 2>&1 &"]
        launcher.running = true
        root.done()
    }
    Process {   // unbounded-ok: one-shot ipc call / detached spawn — exits at once
        id: launcher
        command: []
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
        Slider {
            id: s
            Layout.fillWidth: true
            Layout.preferredHeight: Config.PopupMetrics.px(24)
            from: 0; to: 100
            value: lvl.value
            onMoved: lvl.moved(value)
            background: Rectangle {
                x: s.leftPadding
                y: s.topPadding + s.availableHeight / 2 - height / 2
                width: s.availableWidth; implicitHeight: Config.PopupMetrics.px(6)
                radius: height / 2
                color: Config.ThemeConfig.hairlineSoft
                Rectangle {
                    width: s.visualPosition * parent.width; height: parent.height
                    radius: parent.radius
                    color: lvl.dim ? Config.BarConfig.colorTextDim : Config.BarConfig.colorAccent
                }
            }
            handle: Rectangle {
                x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
                y: s.topPadding + s.availableHeight / 2 - height / 2
                width: Config.PopupMetrics.px(14); height: width; radius: width / 2
                color: lvl.dim ? Config.BarConfig.colorTextDim : Config.BarConfig.colorText
                scale: s.pressed ? 1.15 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }
            }
        }
        Text {
            text: Math.round(lvl.value) + "%"
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: Config.PopupMetrics.px(32)
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: Config.PopupMetrics.px(9)
            color: Config.BarConfig.colorTextDim
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

    // ── tiles ────────────────────────────────────────────────────────────────
    GridLayout {
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
            title: "FOCUS"
            lit: Services.NotificationService.dnd
            detail: Services.NotificationService.dnd ? "Do not disturb" : "Off"
            onToggled: Services.NotificationService.setDnd(!Services.NotificationService.dnd)
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
            glyph: "󰏘"
            title: "THEME"
            detail: "Open themes"
            onToggled: root.openSettings("openThemeTab")
        }
    }

    // ── levels ───────────────────────────────────────────────────────────────
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

    // ── footer: deep link into the settings app ─────────────────────────────
    Rectangle {
        Layout.alignment: Qt.AlignRight
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
