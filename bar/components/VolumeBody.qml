// =============================================================================
// VolumeBody.qml — TrayCard audio body (P4.3 rework on the I8 extraction)
// =============================================================================
// HERO % + OUTPUT (master slider, mute, output picker) + INPUT (mic slider,
// mute, input picker) + NOW PLAYING (Mpris transport) + APPS (per-stream
// volume) + OPEN IN SETTINGS link. Pure view — state lives in AudioService
// (native PipeWire) and MprisService (native MPRIS); feedback via OsdService.
// Interface follows NetworkCardBody: the card is injected as `tray`, settings
// deep links come back through settingsRequested(verb). Instantiated lazily
// by TrayCard on the body's first open.
//
// Lists use the frozen-slice pattern (array-identity law): the Repeater
// models reassign only on membership change, while per-row volume/mute read
// LIVE through the *_row() lookups — a drag or mute flip never rebuilds the
// row under the pointer.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../config" as Config

ColumnLayout {
    id: body

    property var tray: null                    // owning TrayCard (hair, openSettings)
    signal settingsRequested(string verb)

    readonly property bool _ok: tray !== null
    readonly property real _hair: _ok ? tray.hair : 1

    // Layout law: shared primitives as layout children need BOTH their own
    // implicitWidth AND Layout.fillWidth from the caller (ListRow carries the
    // first half; the frame callers do the second).
    Layout.fillWidth: true; spacing: 0

    // ── live lookups — re-evaluate when the service recomputes its rows ──────
    function sinkRow(id) {
        const rows = Services.AudioService.sinks
        for (let i = 0; i < rows.length; i++) if (rows[i].id === id) return rows[i]
        return null
    }
    function sourceRow(id) {
        const rows = Services.AudioService.sources
        for (let i = 0; i < rows.length; i++) if (rows[i].id === id) return rows[i]
        return null
    }
    function appRow(id) {
        const rows = Services.AudioService.sinkInputs
        for (let i = 0; i < rows.length; i++) if (rows[i].id === id) return rows[i]
        return null
    }

    // ── frozen slices (membership-diffed; seeds + Connections below) ─────────
    property var _sinkList: []
    property string _sinkKey: ""
    property var _sourceList: []
    property string _sourceKey: ""
    property var _appList: []
    property string _appKey: ""

    function _resinkSinks() {
        const rows = Services.AudioService.sinks
        let key = ""
        for (let i = 0; i < rows.length; i++)
            key += rows[i].id + "|" + rows[i].name + "|" + (rows[i].isDefault ? 1 : 0) + ";"
        if (key === body._sinkKey) return
        body._sinkKey = key
        body._sinkList = rows
    }
    function _resinkSources() {
        const rows = Services.AudioService.sources
        let key = ""
        for (let i = 0; i < rows.length; i++)
            key += rows[i].id + "|" + rows[i].name + "|" + (rows[i].isDefault ? 1 : 0) + ";"
        if (key === body._sourceKey) return
        body._sourceKey = key
        body._sourceList = rows
    }
    function _resinkApps() {
        const rows = Services.AudioService.sinkInputs
        let key = ""
        for (let i = 0; i < rows.length; i++)
            key += rows[i].id + "|" + rows[i].app + ";"
        if (key === body._appKey) return
        body._appKey = key
        body._appList = rows
    }

    Component.onCompleted: {
        body._resinkSinks(); body._resinkSources(); body._resinkApps()
    }
    Connections {
        target: Services.AudioService
        function onSinksChanged()      { body._resinkSinks() }
        function onSourcesChanged()    { body._resinkSources() }
        function onSinkInputsChanged() { body._resinkApps() }
    }

    // Transport glyph button (NOW PLAYING) — text only, no fills (QD-OLED).
    component MediaButton: Text {
        signal activated()
        font.family: Config.BarConfig.fontNerd
        font.pixelSize: Config.PopupMetrics.px(14)
        color: enabled ? (area.containsMouse ? Config.BarConfig.colorAccent
                                             : Config.BarConfig.colorText)
                       : Config.BarConfig.colorTextDim
        opacity: enabled ? 1.0 : 0.3
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: area
            anchors.fill: parent; anchors.margins: -8
            enabled: parent.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.activated()
        }
    }

    // wpctl/PipeWire absent — dim dash instead of a misleading "0%"
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

    // ── HERO — big glyph (tap = mute) + huge % ──
    RowLayout {
        visible: Services.AudioService.hasAudio
        Layout.fillWidth: true; spacing: Config.PopupMetrics.px(12)

        Text {
            text: Services.AudioService.muted ? "󰝟" : (Services.AudioService.volume > 66 ? "󰕾" : "󰕿")
            font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(30)
            color: Services.AudioService.muted ? Config.BarConfig.colorTextDim : Config.ThemeConfig.colors.primary
            Behavior on color { ColorAnimation { duration: 120 } }
            MouseArea {
                anchors.fill: parent; anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Services.AudioService.toggleMute()
                    Services.OsdService.showMute(Services.AudioService.muted)
                }
            }
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

    // ── OUTPUT — master slider + mute + output picker ──
    CardFrame {
        visible: Services.AudioService.hasAudio
        title: "OUTPUT"
        uiScale: Config.PopupMetrics.scale
        titleColor: Config.BarConfig.colorTextDim
        hairlineColor: Config.ThemeConfig.hairline
        Layout.fillWidth: true

        CardSlider {
            Layout.fillWidth: true
            value: Services.AudioService.volume
            dim: Services.AudioService.muted
            uiScale: Config.PopupMetrics.scale
            accentColor: Config.ThemeConfig.colors.primary
            dimColor: Config.BarConfig.colorTextDim
            textColor: Config.BarConfig.colorText
            grooveColor: Config.ThemeConfig.hairlineSoft
            onDragged: function(v) {
                Services.AudioService.setVolume(v)
                Services.OsdService.showVolume(v, Services.AudioService.muted)
            }
        }
        ListRow {
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText
            detailColor: Config.BarConfig.colorTextDim
            accentColor: Config.BarConfig.colorAccent
            glyph: "\u{f028}"
            glyphColor: Config.BarConfig.colorTextDim
            title: "MUTE OUTPUT"
            detail: Services.AudioService.muted ? "muted" : "live"
            onClicked: {
                Services.AudioService.toggleMute()
                Services.OsdService.showMute(Services.AudioService.muted)
            }
            CardToggle {
                checked: Services.AudioService.muted
                uiScale: Config.PopupMetrics.scale
                accentColor: Config.ThemeConfig.colors.primary
                textColor: Config.BarConfig.colorText
                outlineColor: Config.BarConfig.colorBorder
                onToggled: {
                    Services.AudioService.toggleMute()
                    Services.OsdService.showMute(Services.AudioService.muted)
                }
            }
        }
        Repeater {
            model: body._sinkList.length > 1 ? body._sinkList : []

            delegate: ListRow {
                // Inline member access only (a bare `property var x: modelData`
                // capture does not resolve — Repeater idiom).
                uiScale: Config.PopupMetrics.scale
                textColor: Config.BarConfig.colorText
                detailColor: Config.BarConfig.colorTextDim
                accentColor: Config.BarConfig.colorAccent
                glyph: "\u{f028}"
                glyphColor: modelData.isDefault ? Config.BarConfig.colorAccent
                                                : Config.BarConfig.colorTextDim
                title: modelData.name
                readonly property var live: body.sinkRow(modelData.id)
                detail: (modelData.isDefault ? "DEFAULT · " : "")
                        + (live ? (live.mute ? "muted" : live.volume + "%") : "—")
                dimmed: false
                onClicked: if (!modelData.isDefault)
                               Services.AudioService.setDefaultSink(modelData.id)
                CardToggle {
                    checked: live ? live.mute : false
                    uiScale: Config.PopupMetrics.scale
                    accentColor: Config.ThemeConfig.colors.primary
                    textColor: Config.BarConfig.colorText
                    outlineColor: Config.BarConfig.colorBorder
                    onToggled: Services.AudioService.toggleSinkMute(modelData.id)
                }
            }
        }
    }
    Item { height: Config.PopupMetrics.px(4); visible: Services.AudioService.hasAudio }

    // ── INPUT — mic slider + mute + input picker ──
    CardFrame {
        visible: Services.AudioService.hasMic
        title: "INPUT"
        uiScale: Config.PopupMetrics.scale
        titleColor: Config.BarConfig.colorTextDim
        hairlineColor: Config.ThemeConfig.hairline
        Layout.fillWidth: true

        CardSlider {
            Layout.fillWidth: true
            value: Services.AudioService.micVolume
            dim: Services.AudioService.micMuted
            uiScale: Config.PopupMetrics.scale
            accentColor: Config.ThemeConfig.colors.primary
            dimColor: Config.BarConfig.colorTextDim
            textColor: Config.BarConfig.colorText
            grooveColor: Config.ThemeConfig.hairlineSoft
            onDragged: function(v) { Services.AudioService.setMicVolume(v) }
        }
        ListRow {
            uiScale: Config.PopupMetrics.scale
            textColor: Config.BarConfig.colorText
            detailColor: Config.BarConfig.colorTextDim
            accentColor: Config.BarConfig.colorAccent
            glyph: "\u{f130}"
            glyphColor: Config.BarConfig.colorTextDim
            title: "MUTE INPUT"
            detail: Services.AudioService.micMuted ? "muted" : "live"
            onClicked: Services.AudioService.toggleMicMute()
            CardToggle {
                checked: Services.AudioService.micMuted
                uiScale: Config.PopupMetrics.scale
                accentColor: Config.ThemeConfig.colors.primary
                textColor: Config.BarConfig.colorText
                outlineColor: Config.BarConfig.colorBorder
                onToggled: Services.AudioService.toggleMicMute()
            }
        }
        Repeater {
            model: body._sourceList.length > 1 ? body._sourceList : []

            delegate: ListRow {
                uiScale: Config.PopupMetrics.scale
                textColor: Config.BarConfig.colorText
                detailColor: Config.BarConfig.colorTextDim
                accentColor: Config.BarConfig.colorAccent
                glyph: "\u{f130}"
                glyphColor: modelData.isDefault ? Config.BarConfig.colorAccent
                                                : Config.BarConfig.colorTextDim
                title: modelData.name
                readonly property var live: body.sourceRow(modelData.id)
                detail: (modelData.isDefault ? "DEFAULT · " : "")
                        + (live ? (live.mute ? "muted" : live.volume + "%") : "—")
                onClicked: if (!modelData.isDefault)
                               Services.AudioService.setDefaultSource(modelData.id)
                CardToggle {
                    checked: live ? live.mute : false
                    uiScale: Config.PopupMetrics.scale
                    accentColor: Config.ThemeConfig.colors.primary
                    textColor: Config.BarConfig.colorText
                    outlineColor: Config.BarConfig.colorBorder
                    onToggled: Services.AudioService.toggleSourceMute(modelData.id)
                }
            }
        }
    }
    Item { height: Config.PopupMetrics.px(4); visible: Services.AudioService.hasMic }

    // ── NOW PLAYING — Mpris transport strip ──
    CardFrame {
        visible: Services.MprisService.hasPlayers && Services.MprisService.active !== null
        title: "NOW PLAYING · " + (Services.MprisService.active ?
                                   Services.MprisService.active.identity.toUpperCase() : "")
        uiScale: Config.PopupMetrics.scale
        titleColor: Config.BarConfig.colorTextDim
        hairlineColor: Config.ThemeConfig.hairline
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.PopupMetrics.px(10)

            Text {
                text: "\u{f001}"
                font.family: Config.BarConfig.fontNerd
                font.pixelSize: Config.PopupMetrics.px(16)
                color: Services.MprisService.active && Services.MprisService.active.isPlaying
                       ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Config.PopupMetrics.px(1)

                Text {
                    text: Services.MprisService.active && Services.MprisService.active.title !== ""
                          ? Services.MprisService.active.title : "Unknown track"
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: Config.PopupMetrics.px(11); font.bold: true
                    color: Config.BarConfig.colorText
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
                Text {
                    text: Services.MprisService.active
                          ? (Services.MprisService.active.artist !== ""
                             ? Services.MprisService.active.artist
                             : Services.MprisService.active.identity)
                          : ""
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: Config.PopupMetrics.px(9)
                    color: Config.BarConfig.colorTextDim
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
            }
            RowLayout {
                spacing: Config.PopupMetrics.px(10)
                MediaButton {
                    text: "\u{f04a}"
                    enabled: Services.MprisService.active && Services.MprisService.active.canGoPrevious
                    onActivated: Services.MprisService.previous(
                                     Services.MprisService.active.id)
                }
                MediaButton {
                    text: Services.MprisService.active && Services.MprisService.active.isPlaying
                          ? "\u{f04c}" : "\u{f04b}"
                    enabled: Services.MprisService.active && Services.MprisService.active.canTogglePlaying
                    onActivated: Services.MprisService.togglePlay(
                                     Services.MprisService.active.id)
                }
                MediaButton {
                    text: "\u{f04e}"
                    enabled: Services.MprisService.active && Services.MprisService.active.canGoNext
                    onActivated: Services.MprisService.next(
                                     Services.MprisService.active.id)
                }
            }
        }
    }
    Item {
        height: Config.PopupMetrics.px(4)
        visible: Services.MprisService.hasPlayers && Services.MprisService.active !== null
    }

    // ── APPS — per-stream volume ──
    CardFrame {
        visible: body._appList.length > 0
        title: "APPS"
        uiScale: Config.PopupMetrics.scale
        titleColor: Config.BarConfig.colorTextDim
        hairlineColor: Config.ThemeConfig.hairline
        Layout.fillWidth: true

        Repeater {
            model: body._appList

            delegate: ListRow {
                uiScale: Config.PopupMetrics.scale
                textColor: Config.BarConfig.colorText
                detailColor: Config.BarConfig.colorTextDim
                accentColor: Config.BarConfig.colorAccent
                glyph: "\u{f2d0}"
                glyphColor: Config.BarConfig.colorTextDim
                title: modelData.app
                readonly property var live: body.appRow(modelData.id)
                detail: live ? (live.mute ? "muted" : live.volume + "%") : "—"
                CardSlider {
                    Layout.preferredWidth: Math.round(96 * Config.PopupMetrics.scale)
                    value: live ? live.volume : 0
                    dim: live ? live.mute : false
                    uiScale: Config.PopupMetrics.scale
                    accentColor: Config.ThemeConfig.colors.primary
                    dimColor: Config.BarConfig.colorTextDim
                    textColor: Config.BarConfig.colorText
                    grooveColor: Config.ThemeConfig.hairlineSoft
                    onDragged: function(v) {
                        Services.AudioService.setSinkInputVolume(modelData.id, v)
                    }
                }
                CardToggle {
                    checked: live ? live.mute : false
                    uiScale: Config.PopupMetrics.scale
                    accentColor: Config.ThemeConfig.colors.primary
                    textColor: Config.BarConfig.colorText
                    outlineColor: Config.BarConfig.colorBorder
                    onToggled: Services.AudioService.toggleSinkInputMute(modelData.id)
                }
            }
        }
    }

    SettingsLink {
        visible: Services.AudioService.hasAudio
        verb: "openControlAudio"
        onActivated: function(v) { body.settingsRequested(v) }
    }
}
