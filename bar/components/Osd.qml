// =============================================================================
// Osd.qml — bottom-center on-screen display card (volume / mute feedback).
// =============================================================================
// Renders OsdService state. Overlay layer + empty input mask = visual-only,
// fully click-through. Measured columns (Omarchy pattern): the icon column is
// pinned to the widest glyph of the set and the readout column to the widest
// possible text ("100%" / "UNMUTED"), so rapid updates never jitter the card.
// =============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services" as Services
import "../config" as Config

PanelWindow {
    id: osdWindow

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "bar-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Visual-only surface: keep the layer-shell input region empty so the OSD
    // never blocks clicks to the desktop below it.
    mask: Region {}

    // Keep the window alive through the fade-out (opacity > 0 while closing).
    visible: Services.OsdService.active || card.opacity > 0

    readonly property int pad: 16
    readonly property int gap: 16
    // A glyph next to text reads airier than it measures — ink falls away from
    // the cell — so the text gap takes two thirds (Omarchy).
    readonly property int messageGap: Math.round(gap * 2 / 3)
    readonly property int barWidth: 142
    readonly property int iconPixelSize: 28

    // ── measured columns ────────────────────────────────────────────────────
    // Nerd Font glyphs draw outside their monospace cell, so measure by ink
    // (tightBoundingRect) rather than advance width; progress OSDs pin the
    // column to the widest glyph so the bar doesn't shift across thresholds.
    readonly property int iconInkWidth: Math.ceil(iconMetrics.tightBoundingRect.width)
    readonly property int iconWidth: Services.OsdService.hasProgress
        ? Math.max(iconInkWidth, Math.ceil(widestIconMetrics.tightBoundingRect.width))
        : iconInkWidth
    readonly property int valueWidth: Math.ceil(Math.max(readoutMetrics.advanceWidth,
                                                          messageMetrics.advanceWidth))
    readonly property int contentWidth: Services.OsdService.hasProgress
        ? iconWidth + gap + barWidth + gap + valueWidth
        : iconWidth + messageGap + valueWidth

    Rectangle {
        id: card
        width: 1 + osdWindow.pad + osdWindow.contentWidth + osdWindow.pad + 1   // 1px border per side
        height: 1 + osdWindow.pad + osdWindow.iconPixelSize + osdWindow.pad + 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 67
        color: Config.BarConfig.colorBackground
        border.color: Config.BarConfig.colorBorder
        border.width: 1
        radius: 0   // sharp corners — bar design language
        opacity: Services.OsdService.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Row {
            anchors.fill: parent
            anchors.margins: 1 + osdWindow.pad
            spacing: Services.OsdService.hasProgress ? osdWindow.gap : osdWindow.messageGap

            Item {
                width: osdWindow.iconWidth
                height: parent.height
                // Sit the glyph's ink flush in the column, centered when the
                // column is wider than this particular glyph.
                Text {
                    x: Math.round((osdWindow.iconWidth - osdWindow.iconInkWidth) / 2
                                  - iconMetrics.tightBoundingRect.x)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.OsdService.icon
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: osdWindow.iconPixelSize
                    color: Config.BarConfig.colorText
                }
            }

            Rectangle {
                visible: Services.OsdService.hasProgress
                width: osdWindow.barWidth
                height: 6
                anchors.verticalCenter: parent.verticalCenter
                color: Config.ThemeConfig.hairlineSoft
                Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(100, Services.OsdService.value)) / 100
                    color: Config.BarConfig.colorAccent
                    Behavior on width {
                        enabled: Services.OsdService.active
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                width: osdWindow.valueWidth
                // The readout hugs the card edge so a short percentage doesn't
                // leave a hole in the padding; slack lands after the bar.
                horizontalAlignment: Services.OsdService.hasProgress ? Text.AlignRight : Text.AlignLeft
                anchors.verticalCenter: parent.verticalCenter
                text: Services.OsdService.message
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: 13
                font.bold: true
                color: Services.OsdService.hasProgress ? Config.BarConfig.colorText : Config.BarConfig.colorAccent
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    TextMetrics {
        id: iconMetrics
        font.family: Config.BarConfig.fontNerd
        font.pixelSize: osdWindow.iconPixelSize
        text: Services.OsdService.icon
    }
    TextMetrics {
        id: widestIconMetrics
        font: iconMetrics.font
        text: "󰕾󰕿󰝟"   // widest of the volume/mute glyph set
    }
    TextMetrics {
        id: readoutMetrics
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: 13
        font.bold: true
        text: "100%"    // longest numeric readout
    }
    TextMetrics {
        id: messageMetrics
        font: readoutMetrics.font
        text: Services.OsdService.message
    }
}
