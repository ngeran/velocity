// =============================================================================
// Osd.qml — bottom-center on-screen display card (live activities).
// =============================================================================
// Renders the PopupCoordinator activity queue's arbitrated winner (J0):
// OsdService mirrors its feedback in as the "osd" entry, plugins/scripts
// publish lower ranks — on non-island styles this card shows all of them.
// Overlay layer + empty input mask = visual-only, fully click-through.
// Measured columns (Omarchy pattern): the icon column is pinned to the widest
// glyph of the set and the readout column to the widest possible text
// ("100%" / "UNMUTED"), so rapid updates never jitter the card.
// =============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services" as Services
import "../config" as Config
import "../engine" as Engine
import "../Ui" as Ui

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
    // Island style: the feedback renders inside the island instead.
    readonly property bool islandOwnsOsd: Object.keys(Engine.PopupCoordinator.islands).length > 0
    // The queue's winner, gated like the island: focusedOnly entries (the
    // OSD) follow the focused output. The gate reads the screen NAME through
    // an imperative copy (P1.11): reading `osdWindow.screen` inside `shown`
    // closes a binding loop (screen re-resolves on visibility; visible reads
    // shown). The copy never resets to "": a window CLOSE nulls `screen`,
    // and an empty name makes the gate PASS — pass → reopen → name set →
    // fail → close → … was the oscillation the engine reported as a loop on
    // `shown`. Holding the last name converges; the first assignment still
    // happens at window creation.
    property string _screenName: ""
    // callLater: the write must NOT land inside the synchronous window-setup
    // pass — visible eval → surface creation → screenChanged → write → shown
    // re-entry was the engine's loop, even with the value held stable across
    // close (the boot-time re-entry at creation needs no value flip).
    onScreenChanged: if (screen !== null) Qt.callLater(function () {
        if (osdWindow.screen !== null) _screenName = osdWindow.screen.name
    })
    readonly property var act: Engine.PopupCoordinator.visibleActivity
    readonly property bool shown: act !== null
        && (!act.focusedOnly
            || Services.HyprlandService.focusedMonitor === ""
            || _screenName === ""
            || Services.HyprlandService.focusedMonitor === _screenName)
    readonly property bool hasTrack: act !== null && act.progress !== undefined
    visible: !islandOwnsOsd && (osdWindow.shown || card.opacity > 0)

    // QD-OLED (J0 doctrine, island-Scene parity): an activity holds full
    // alpha for ≤ 3 s of stillness, then dims to the rest level until its
    // next update — a new winner or an in-place refresh (seq bumps on every
    // publish) resets the clock, so a live-updating card (the REC counter,
    // a moving progress) never stills long enough to dim, while a parked
    // critical peek does. The card is click-through (empty input mask), so
    // unlike the island there is no hover-hold to defer the dim.
    readonly property string actStamp: osdWindow.act
        ? osdWindow.act.key + ":" + osdWindow.act.seq : ""
    property bool actDim: false
    onActStampChanged: actDim = false
    Timer {
        interval: 3000
        running: osdWindow.shown && !osdWindow.actDim
        onTriggered: osdWindow.actDim = true
    }
    readonly property real actAlpha: osdWindow.actDim ? 0.45 : 1

    // Card metrics ride the popup uiScale token (B3/B4): every literal below
    // is px(n), so uiScale 1.0 reproduces the old numbers exactly.
    readonly property int pad: Config.PopupMetrics.px(16)
    readonly property int gap: Config.PopupMetrics.px(16)
    // A glyph next to text reads airier than it measures — ink falls away from
    // the cell — so the text gap takes two thirds (Omarchy).
    readonly property int messageGap: Math.round(gap * 2 / 3)
    readonly property int barWidth: Config.PopupMetrics.px(142)
    readonly property int iconPixelSize: Config.PopupMetrics.px(28)
    // Hairline (border) width, snapped to device pixels — crisp at fractional
    // scales; exactly 1 at dpr 1.0 (see PopupMetrics.hairline).
    readonly property real hair: Config.PopupMetrics.hairline(card)

    // ── measured columns ────────────────────────────────────────────────────
    // Nerd Font glyphs draw outside their monospace cell, so measure by ink
    // (tightBoundingRect) rather than advance width; progress OSDs pin the
    // column to the widest glyph so the bar doesn't shift across thresholds.
    readonly property int iconInkWidth: Math.ceil(iconMetrics.tightBoundingRect.width)
    readonly property int iconInkHeight: Math.ceil(iconMetrics.tightBoundingRect.height)
    readonly property int iconWidth: osdWindow.hasTrack
        ? Math.max(iconInkWidth, Math.ceil(widestIconMetrics.tightBoundingRect.width))
        : iconInkWidth
    readonly property int valueWidth: Math.ceil(Math.max(readoutMetrics.advanceWidth,
                                                          messageMetrics.advanceWidth))
    readonly property int contentWidth: osdWindow.hasTrack
        ? iconWidth + gap + barWidth + gap + valueWidth
        : iconWidth + messageGap + valueWidth

    Rectangle {
        id: card
        width: osdWindow.hair + osdWindow.pad + osdWindow.contentWidth + osdWindow.pad + osdWindow.hair   // hairline border per side
        height: osdWindow.hair + osdWindow.pad + osdWindow.iconPixelSize + osdWindow.pad + osdWindow.hair
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.PopupMetrics.px(67)
        color: Config.BarConfig.colorBackground
        border.color: Config.BarConfig.colorBorder
        border.width: osdWindow.hair
        radius: 0   // sharp corners — bar design language
        opacity: osdWindow.shown ? osdWindow.actAlpha : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Row {
            anchors.fill: parent
            anchors.margins: osdWindow.hair + osdWindow.pad
            spacing: osdWindow.hasTrack ? osdWindow.gap : osdWindow.messageGap

            Item {
                width: Math.max(osdWindow.iconWidth, Math.round(osdWindow.iconPixelSize * 0.9))
                height: parent.height
                // Cell-based centering. The previous ink-metric centering
                // (tightBoundingRect offsets) proved unreliable for these Nerd
                // Font PUA glyphs — the metrics don't match the drawn ink.
                // anchors.centerIn centers the glyph's LINE BOX; with the
                // ink hugging the baseline the old -4 lift rode the glyph
                // ~5px HIGH against the bar/text line (verified by OSD
                // screenshot) — so the net offset is +1 (down 5 from -4).
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1
                    text: osdWindow.act ? osdWindow.act.icon : ""
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: osdWindow.iconPixelSize
                    color: Config.BarConfig.colorText
                }
            }

            // Track — style-split (J5): "bar" = the continuous fill,
            // "segments" = Ui.SegmentTrack (discrete steps, dim-accent unlit
            // cells). Same box (barWidth × 6) either way, so the measured-
            // columns layout is style-independent.
            Rectangle {
                visible: osdWindow.hasTrack && Config.BarConfig.osdStyle !== "segments"
                width: osdWindow.barWidth
                height: Config.PopupMetrics.px(6)
                anchors.verticalCenter: parent.verticalCenter
                color: Config.ThemeConfig.hairlineSoft
                Rectangle {
                    height: parent.height
                    width: parent.width
                        * (osdWindow.hasTrack ? Math.max(0, Math.min(100, osdWindow.act.progress)) : 0) / 100
                    color: (osdWindow.act && osdWindow.act.accent) ? osdWindow.act.accent
                                                                   : Config.BarConfig.colorAccent
                    Behavior on width {
                        enabled: osdWindow.shown
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }
            }
            Ui.SegmentTrack {
                visible: osdWindow.hasTrack && Config.BarConfig.osdStyle === "segments"
                width: osdWindow.barWidth
                height: Config.PopupMetrics.px(6)
                anchors.verticalCenter: parent.verticalCenter
                // The activity's accent (critical = error) wins; unlit cells
                // ride the same accent at 0.28 (transient card — under the
                // 0.45 ornament ceiling with margin).
                segments: 12
                gap: Config.PopupMetrics.px(2)
                accent: (osdWindow.act && osdWindow.act.accent) ? osdWindow.act.accent
                                                                : Config.BarConfig.colorAccent
                dimAlpha: 0.28
                value: osdWindow.hasTrack ? Math.max(0, Math.min(100, osdWindow.act.progress)) : 0
            }

            Text {
                width: osdWindow.valueWidth
                // The readout hugs the card edge so a short percentage doesn't
                // leave a hole in the padding; slack lands after the bar.
                horizontalAlignment: osdWindow.hasTrack ? Text.AlignRight : Text.AlignLeft
                anchors.verticalCenter: parent.verticalCenter
                text: osdWindow.act ? osdWindow.act.label : ""
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(13)
                font.bold: true
                color: osdWindow.hasTrack ? Config.BarConfig.colorText
                      : (osdWindow.act && osdWindow.act.accent) ? osdWindow.act.accent
                      : Config.BarConfig.colorAccent
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    TextMetrics {
        id: iconMetrics
        font.family: Config.BarConfig.fontNerd
        font.pixelSize: osdWindow.iconPixelSize
        text: osdWindow.act ? osdWindow.act.icon : ""
    }
    TextMetrics {
        id: widestIconMetrics
        font: iconMetrics.font
        text: "󰕾󰕿󰝟"   // widest of the volume/mute glyph set
    }
    TextMetrics {
        id: readoutMetrics
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: Config.PopupMetrics.px(13)
        font.bold: true
        text: "100%"    // longest numeric readout
    }
    TextMetrics {
        id: messageMetrics
        font: readoutMetrics.font
        text: osdWindow.act ? osdWindow.act.label : ""
    }
}
