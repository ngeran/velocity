// =============================================================================
// DisplayControlView.qml — DISPLAY section view (tactical HUD, LIVE controls)
// =============================================================================
// Replaces the read-only BrightnessControlView. Control model ported from
// omarchy-screens (single-monitor scope): mode/refresh picker, HDR + Tune,
// VRR, scale stepper, DPMS toggle — all applied LIVE via MonitorService's
// `hyprctl eval hl.monitor({...})` mechanism, with a 10s Keep/Revert window
// for the risky changes (mode/scale) and a PERSIST card that stages the live
// state into ~/.omni-nix/configs/hypr/monitors.lua (survives reload only via
// the user's omni-apply).
//
// Stack (~440px wide, scrolls with the parent Flickable):
//   1. Header            — title + clickable DPMS pill + monitor name
//   2. Keep/Revert banner (only while a risky change is pending)
//   3. MODE_CARD         — refresh segments for the current resolution +
//                          other-resolution rows (Keep/Revert on apply)
//   4. COLOR_CARD        — HDR OFF/AUTO/ALWAYS, cm preset pills, bit depth,
//                          Tune sliders (SDR brightness/sat/floor/peak)
//   5. VRR_CARD          — OFF/ALWAYS/FULLSCREEN/GAMES
//   6. SCALE_CARD        — stepper + sharp-scale indicator (Keep/Revert)
//   7. PERSIST_CARD      — stage live settings into omni-nix
//   8. Backlight note    — honest "unavailable" line (no DDC path chosen)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 10

    readonly property var mon: Services.MonitorService.primary
    readonly property bool hdrOn: mon && mon.colorPreset !== "" && mon.colorPreset !== "srgb"

    // Countdown display for the Keep/Revert window (the service owns the
    // deadline + auto-revert; this just re-renders the number).
    property int revertSecsLeft: 0
    Timer {
        interval: 250; running: Services.MonitorService.revertPending; repeat: true
        onTriggered: if (Services.MonitorService.pendingRevert)
            view.revertSecsLeft = Math.max(0, Math.ceil((Services.MonitorService.pendingRevert.deadline - Date.now()) / 1000))
    }

    // ── shared bits ────────────────────────────────────────────────────────
    component Chip: Rectangle {
        property string text: ""
        property color chipColor: Config.ThemeConfig.colors.textDim
        height: 16
        width: chipLbl.implicitWidth + 12
        color: Config.ThemeConfig.tint(chipColor, 0.10)
        border.color: chipColor
        border.width: 1
        Text {
            id: chipLbl; anchors.centerIn: parent
            text: parent.text
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
            color: chipColor
        }
    }

    // Segmented control pill; `active` highlights, `when` gates visibility.
    component Seg: Rectangle {
        property string text: ""
        property bool active: false
        signal chosen()
        height: 20
        width: segLbl.implicitWidth + 14
        color: active ? Config.ThemeConfig.tint(segColor, 0.18) : Qt.rgba(1, 1, 1, 0.03)
        property color segColor: Config.ThemeConfig.colors.secondary
        border.color: active ? segColor : Config.ThemeConfig.colors.border
        border.width: 1
        Text {
            id: segLbl; anchors.centerIn: parent
            text: parent.text
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
            color: parent.active ? parent.segColor : Config.ThemeConfig.colors.textDim
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: if (!parent.active) parent.chosen()
        }
    }

    // Slim HUD slider (no QtQuick.Controls — Basic import is broken in this
    // build). Drag or click; emits `moved` continuously (rules are queued).
    component HudSlider: ColumnLayout {
        id: slider
        property string label: ""
        property real from: 0
        property real to: 1
        property real step: 0.05
        property real value: 0
        signal moved(real val)
        spacing: 4

        function quant(v) {
            var q = Math.round((v - from) / step) * step + from
            return Math.max(from, Math.min(to, +q.toFixed(4)))
        }
        readonly property real frac: (value - from) / Math.max(0.0001, to - from)

        RowLayout {
            Layout.fillWidth: true
            Text { text: slider.label; font.family: Config.ControlConfig.fontMono
                font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                color: Config.ThemeConfig.colors.textDim }
            Item { Layout.fillWidth: true }
            Text { text: (+slider.value).toFixed(slider.step < 0.01 ? 3 : 2)
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                color: Config.ThemeConfig.colors.text }
        }
        Rectangle {
            id: track
            Layout.fillWidth: true
            height: 8
            radius: 2
            color: Qt.rgba(0, 0, 0, 0.4)
            border.color: Config.ThemeConfig.colors.border; border.width: 1
            Rectangle {
                width: Math.round(parent.width * slider.frac); height: parent.height - 2
                anchors.verticalCenter: parent.verticalCenter
                y: 1; x: 1
                radius: 1
                color: Config.ThemeConfig.colors.secondary
            }
            Rectangle {
                width: 6; height: parent.height + 2
                x: Math.round(parent.width * slider.frac) - 3
                anchors.verticalCenter: parent.verticalCenter
                radius: 1
                color: Config.ThemeConfig.colors.text
                border.color: Config.ThemeConfig.colors.border; border.width: 1
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                function apply(x) {
                    var f = Math.max(0, Math.min(1, x / track.width))
                    slider.value = slider.quant(slider.from + f * (slider.to - slider.from))
                    slider.moved(slider.value)
                }
                onClicked: function(mouse) { apply(mouse.x) }
                onPositionChanged: function(mouse) { if (pressed) apply(mouse.x) }
            }
        }
    }

    // =========================================================================
    // 1. HEADER — DPMS pill is now a toggle
    // =========================================================================
    RowLayout {
        width: parent.width
        spacing: 8

        Rectangle { width: 3; height: 16; color: Config.ControlConfig.accent; Layout.alignment: Qt.AlignVCenter }

        Text {
            text: "DISPLAY"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 13; font.bold: true
            color: Config.ThemeConfig.colors.text
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: stateLbl.implicitWidth + 14; height: 16
            color: view.mon && view.mon.dpms
                   ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.12)
                   : Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.10)
            border.color: view.mon && view.mon.dpms ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
            border.width: 1
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: Services.MonitorService.setDpms(!(view.mon && view.mon.dpms))
            }
            Text {
                id: stateLbl; anchors.centerIn: parent
                text: view.mon && view.mon.dpms ? "● ACTIVE ⇄" : "○ STANDBY ⇄"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                color: view.mon && view.mon.dpms ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: view.mon ? ((view.mon.make + " " + view.mon.model).trim() || view.mon.name) : "—"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.textDim
            elide: Text.ElideRight
        }
    }

    // =========================================================================
    // 2. KEEP / REVERT BANNER (risky change pending)
    // =========================================================================
    Rectangle {
        width: parent.width
        visible: Services.MonitorService.revertPending
        height: bannerRow.implicitHeight + 14
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.warning, 0.10)
        border.color: Config.ThemeConfig.colors.warning; border.width: 1

        RowLayout {
            id: bannerRow
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 8

            Text { text: "󰦜"; font.family: Config.ControlConfig.fontMono; font.pixelSize: 12
                color: Config.ThemeConfig.colors.warning }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: Services.MonitorService.pendingRevert
                          ? Services.MonitorService.pendingRevert.label : ""
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                    color: Config.ThemeConfig.colors.warning
                }
                Text {
                    Layout.fillWidth: true
                    text: "reverting in " + view.revertSecsLeft + "s unless kept"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                    color: Config.ThemeConfig.colors.textDim
                }
            }

            Rectangle {
                width: keepLbl.implicitWidth + 14; height: 20
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.15)
                border.color: Config.ThemeConfig.colors.success; border.width: 1
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: Services.MonitorService.confirmKeep() }
                Text { id: keepLbl; anchors.centerIn: parent; text: "KEEP"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                    color: Config.ThemeConfig.colors.success }
            }
            Rectangle {
                width: revLbl.implicitWidth + 14; height: 20
                color: Qt.rgba(1, 1, 1, 0.03)
                border.color: Config.ThemeConfig.colors.border; border.width: 1
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: Services.MonitorService.revertNow() }
                Text { id: revLbl; anchors.centerIn: parent; text: "REVERT"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                    color: Config.ThemeConfig.colors.textDim }
            }
        }
    }

    // =========================================================================
    // 3. MODE_CARD — refresh segments (current res) + other resolutions
    // =========================================================================
    HudCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.primary

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text { text: "MODE"; font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                    color: Config.ThemeConfig.colors.textDim }
                Item { Layout.fillWidth: true }
                Text { text: view.mon ? (view.mon.w + "×" + view.mon.h + " · " + Math.round(view.mon.refreshHz) + "Hz") : "—"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                    color: Config.ThemeConfig.colors.primary }
            }

            // Refresh options for the CURRENT resolution.
            Flow {
                Layout.fillWidth: true; spacing: 6
                visible: view.mon !== null
                Repeater {
                    // modes[] is sorted pixels-desc hz-desc; keep this res only.
                    model: view.mon ? view.mon.modes.filter(function(m) { return m.w === view.mon.w && m.h === view.mon.h }) : []
                    delegate: Seg {
                        required property var modelData
                        text: parseFloat(modelData.hz.toFixed(2)) + " Hz"
                        active: Math.abs(view.mon.refreshHz - modelData.hz) < 0.05
                        segColor: Config.ThemeConfig.colors.primary
                        onChosen: Services.MonitorService.applyWithRevert(
                            "MODE " + modelData.w + "x" + modelData.h + "@" + modelData.hz,
                            { mode: modelData.w + "x" + modelData.h + "@" + parseFloat(modelData.hz.toFixed(2)) })
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

            // Other resolutions as compact rows (label + best refresh).
            Repeater {
                model: {
                    if (!view.mon) return []
                    var seen = {}, out = []
                    var ms = view.mon.modes
                    for (var i = 0; i < ms.length; i++) {
                        if (ms[i].w === view.mon.w && ms[i].h === view.mon.h) continue
                        var k = ms[i].w + "x" + ms[i].h
                        if (!seen[k]) { seen[k] = true; out.push(ms[i]) }
                    }
                    return out.slice(0, 5)   // keep the card compact; full list on request
                }
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 26
                    color: modeMa.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.08) : "transparent"
                    border.color: Config.ThemeConfig.colors.border; border.width: 1
                    MouseArea {
                        id: modeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Services.MonitorService.applyWithRevert(
                            "MODE " + modelData.w + "x" + modelData.h + "@" + modelData.hz,
                            { mode: modelData.w + "x" + modelData.h + "@" + parseFloat(modelData.hz.toFixed(2)) })
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        Text { text: modelData.w + " × " + modelData.h
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                            color: Config.ThemeConfig.colors.text }
                        Item { Layout.fillWidth: true }
                        Text { text: "@" + parseFloat(modelData.hz.toFixed(2)) + " Hz"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                            color: Config.ThemeConfig.colors.textDim }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 4. COLOR_CARD — HDR mode, cm preset, bit depth, Tune
    // =========================================================================
    HudCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.warning
        visible: Services.MonitorService.hdrCapable

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text { text: "COLOR · HDR"; font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                    color: Config.ThemeConfig.colors.textDim }
                Item { Layout.fillWidth: true }
                Text { text: view.hdrOn ? "HDR " + (view.mon ? view.mon.colorPreset.toUpperCase() : "") : "SDR"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                    color: view.hdrOn ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.textDim }
            }

            // HDR mode: OFF (SDR) / AUTO (fullscreen) / ALWAYS (per-output PQ)
            RowLayout {
                spacing: 6
                Seg { text: "OFF"; active: !view.hdrOn && Services.MonitorService.cmAutoHdr === 0
                    segColor: Config.ThemeConfig.colors.warning
                    onChosen: { Services.MonitorService.cmAutoHdr = 0
                                Services.MonitorService.applyGlobalConfig("hl.config({ render = { cm_auto_hdr = 0 } })")
                                Services.MonitorService.applyRule({ cm: "srgb" }) } }
                Seg { text: "AUTO"; active: Services.MonitorService.cmAutoHdr === 1
                    segColor: Config.ThemeConfig.colors.warning
                    onChosen: { Services.MonitorService.cmAutoHdr = 1
                                Services.MonitorService.applyGlobalConfig("hl.config({ render = { cm_auto_hdr = 1 } })")
                                Services.MonitorService.applyRule({ cm: "srgb" }) } }
                Seg { text: "ALWAYS"; active: view.hdrOn
                    segColor: Config.ThemeConfig.colors.warning
                    onChosen: Services.MonitorService.applyRule({ cm: "hdredid" }) }
            }

            // Colour preset pills
            Flow {
                Layout.fillWidth: true; spacing: 6
                visible: view.hdrOn
                Repeater {
                    model: [
                        { label: "EDID", value: "edid" },
                        { label: "P3", value: "dcip3" },
                        { label: "WIDE", value: "wide" },
                        { label: "HDR-EDID", value: "hdredid" },
                        { label: "HDR-WIDE", value: "hdr" }
                    ]
                    delegate: Seg {
                        required property var modelData
                        text: modelData.label
                        active: view.mon && view.mon.colorPreset === modelData.value
                        segColor: Config.ThemeConfig.colors.warning
                        onChosen: Services.MonitorService.applyRule({ cm: modelData.value })
                    }
                }
            }

            // Bit depth + live scanout truth
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: "BIT DEPTH"; font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                    color: Config.ThemeConfig.colors.textDim }
                Item { Layout.fillWidth: true }
                Text { text: "scanout " + (view.mon ? view.mon.format : "—")
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                    color: Config.ThemeConfig.colors.textDim }
                Seg { text: "8"; segColor: Config.ThemeConfig.colors.warning
                    active: Services.MonitorService.liveBitdepth() === 8
                    onChosen: Services.MonitorService.applyRule({ bitdepth: 8 }) }
                Seg { text: "10"; segColor: Config.ThemeConfig.colors.warning
                    active: Services.MonitorService.liveBitdepth() === 10
                    onChosen: Services.MonitorService.applyRule({ bitdepth: 10 }) }
            }

            // Tune sliders (live, queued single-flight in the service)
            HudSlider {
                Layout.fillWidth: true
                visible: view.hdrOn
                label: "SDR BRIGHTNESS"; from: 0.8; to: 2.0; step: 0.05
                value: view.mon ? view.mon.sdrBrightness : 1
                onMoved: function(val) { Services.MonitorService.applyRule({ sdrbrightness: val }) }
            }
            HudSlider {
                Layout.fillWidth: true
                visible: view.hdrOn
                label: "SDR SATURATION"; from: 0.5; to: 2.0; step: 0.05
                value: view.mon ? view.mon.sdrSaturation : 1
                onMoved: function(val) { Services.MonitorService.applyRule({ sdrsaturation: val }) }
            }
            HudSlider {
                Layout.fillWidth: true
                visible: view.hdrOn
                label: "BLACK FLOOR (NITS)"; from: 0; to: 0.2; step: 0.005
                value: view.mon ? view.mon.sdrMinLuminance : 0.2
                onMoved: function(val) { Services.MonitorService.applyRule({ sdr_min_luminance: val }) }
            }
            HudSlider {
                Layout.fillWidth: true
                visible: view.hdrOn
                label: "SDR PEAK (NITS)"; from: 80; to: 400; step: 10
                value: view.mon ? view.mon.sdrMaxLuminance : 80
                onMoved: function(val) { Services.MonitorService.applyRule({ sdr_max_luminance: val }) }
            }

            Text {
                Layout.fillWidth: true; visible: !view.hdrOn
                text: "ALWAYS switches the output to HDR (PQ) — Tune sliders unlock."
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                color: Config.ThemeConfig.colors.textDim; wrapMode: Text.WordWrap
            }
        }
    }

    // =========================================================================
    // 5. VRR_CARD
    // =========================================================================
    HudCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.success
        visible: Services.MonitorService.vrrCapable

        ColumnLayout {
            Layout.fillWidth: true; spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text { text: "VRR"; font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                    color: Config.ThemeConfig.colors.textDim }
                Item { Layout.fillWidth: true }
                // monitors -j's vrr bool reads false on the desktop while
                // vrr=2 (fullscreen) is configured — label it as such.
                Text { text: view.mon && view.mon.vrr ? "ACTIVE" : "IDLE (DESKTOP)"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                    color: view.mon && view.mon.vrr ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.textDim }
            }
            RowLayout {
                spacing: 6
                Repeater {
                    model: [ { label: "OFF", v: 0 }, { label: "ALWAYS", v: 1 },
                             { label: "FULLSCREEN", v: 2 }, { label: "GAMES", v: 3 } ]
                    delegate: Seg {
                        required property var modelData
                        text: modelData.label
                        segColor: Config.ThemeConfig.colors.success
                        active: Services.MonitorService.vrrMode === modelData.v
                        onChosen: { Services.MonitorService.vrrMode = modelData.v
                                    Services.MonitorService.applyRule({ vrr: modelData.v }) }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 6. SCALE_CARD — stepper + sharp indicator
    // =========================================================================
    HudCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.info

        ColumnLayout {
            Layout.fillWidth: true; spacing: 6

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "SCALE"; font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                    color: Config.ThemeConfig.colors.textDim }
                Item { Layout.fillWidth: true }
                Text { text: view.mon ? view.mon.scale.toFixed(3) : "—"
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 16; font.bold: true
                    color: Config.ThemeConfig.colors.info }
                Rectangle { width: sMinus.implicitWidth + 12; height: 22
                    color: Qt.rgba(1, 1, 1, 0.03); border.color: Config.ThemeConfig.colors.border; border.width: 1
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: view.stepScale(-0.125) }
                    Text { id: sMinus; anchors.centerIn: parent; text: "−"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 11; font.bold: true
                        color: Config.ThemeConfig.colors.text } }
                Rectangle { width: sPlus.implicitWidth + 12; height: 22
                    color: Qt.rgba(1, 1, 1, 0.03); border.color: Config.ThemeConfig.colors.border; border.width: 1
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: view.stepScale(0.125) }
                    Text { id: sPlus; anchors.centerIn: parent; text: "+"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 11; font.bold: true
                        color: Config.ThemeConfig.colors.text } }
            }
            Text {
                Layout.fillWidth: true
                // Sharp = logical pixels land on integers (plugin's 0.051 rule).
                text: view.mon && view.scaleIsSharp
                      ? "SHARP — logical " + Math.round(view.mon.w / view.mon.scale) + "×" + Math.round(view.mon.h / view.mon.scale)
                      : "SOFT — logical pixels are fractional (slight blur)"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                color: view.mon && view.scaleIsSharp ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.warning
            }
        }
    }

    readonly property bool scaleIsSharp: {
        if (!mon || mon.scale <= 0) return false
        var lw = mon.w / mon.scale, lh = mon.h / mon.scale
        return Math.abs(lw - Math.round(lw)) < 0.051 && Math.abs(lh - Math.round(lh)) < 0.051
    }

    function stepScale(d) {
        if (!mon) return
        var next = Math.max(1.0, Math.min(2.0, +(mon.scale + d).toFixed(3)))
        if (Math.abs(next - mon.scale) < 0.001) return
        Services.MonitorService.applyWithRevert("SCALE " + next, { scale: next })
    }

    // =========================================================================
    // 7. PERSIST_CARD — stage live settings into the nix source
    // =========================================================================
    HudCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.secondary

        ColumnLayout {
            Layout.fillWidth: true; spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text { text: "PERSISTENCE"; font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                    color: Config.ThemeConfig.colors.textDim }
                Item { Layout.fillWidth: true }
                Chip {
                    text: Services.MonitorService.persistState === "dirty" ? "UNSTAGED CHANGES" : "IN SYNC WITH NIX"
                    chipColor: Services.MonitorService.persistState === "dirty"
                        ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.success
                }
            }

            Text {
                Layout.fillWidth: true
                text: Services.MonitorService.persistState === "dirty"
                      ? "Live settings differ from monitors.lua — a reload or reboot reverts them. Stage them to survive."
                      : "Live settings match the nix source. Staged changes land on the next omni-apply."
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                color: Config.ThemeConfig.colors.textDim; wrapMode: Text.WordWrap
            }

            Rectangle {
                width: stageLbl.implicitWidth + 16; height: 22
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.12)
                border.color: Config.ThemeConfig.colors.secondary; border.width: 1
                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Services.MonitorService.stageToNix() }
                Text { id: stageLbl; anchors.centerIn: parent; text: "STAGE CURRENT SETTINGS"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                    color: Config.ThemeConfig.colors.secondary }
            }
        }
    }

    // =========================================================================
    // 8. BACKLIGHT NOTE — honest "unavailable" (DDC unlock declined for now)
    // =========================================================================
    Rectangle {
        width: parent.width
        height: blRow.implicitHeight + 16
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.06)
        border.color: Config.ThemeConfig.colors.outlineVariant
        border.width: 1

        RowLayout {
            id: blRow
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 8

            Text { text: "󰃜"; font.family: Config.ControlConfig.fontMono; font.pixelSize: 13
                color: Config.ThemeConfig.colors.error }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { Layout.fillWidth: true; text: "BACKLIGHT: NONE"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                    color: Config.ThemeConfig.colors.error }
                Text { Layout.fillWidth: true
                    text: "no /sys/class/backlight, no DDC/CI (ddcutil missing) — use the monitor OSD"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                    color: Config.ThemeConfig.colors.textDim; wrapMode: Text.WordWrap }
            }
        }
    }
}
