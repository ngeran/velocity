// =============================================================================
// VolumeBody.qml — TrayCard bluetooth body (I8 extraction)
// =============================================================================
// Hero volume %, master slider, MUTE footer, OPEN IN SETTINGS link. Pure
// view — state lives in AudioService (feedback via OsdService).
// Interface follows NetworkCardBody: the card is injected as `tray`, settings
// deep links come back through settingsRequested(verb). Instantiated lazily
// by TrayCard on the body's first open.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services" as Services
import "../config" as Config
ColumnLayout {
    id: body

    property var tray: null                    // owning TrayCard (hair, openSettings)
    signal settingsRequested(string verb)

    readonly property bool _ok: tray !== null
    readonly property real _hair: _ok ? tray.hair : 1

    Layout.fillWidth: true; spacing: 0

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
        border.width: _hair
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
    SettingsLink { visible: Services.AudioService.hasAudio; verb: "openControlAudio"; onActivated: function(v) { body.settingsRequested(v) } }
}
