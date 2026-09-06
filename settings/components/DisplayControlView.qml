// =============================================================================
// DisplayControlView.qml — DISPLAY section: Display Manager (mockup-faithful)
// =============================================================================
//   header        breadcrumb · Display Manager · count + sync badges · actions
//   canvas        arrangement tiles (click to TARGET a monitor) · identify
//   telemetry     selected panel summary + status pills + 6-tile spec grid
//   config grid   MODE (res/refresh/orientation) · SCALE · HDR & COLOR ·
//                 VRR + QD-OLED GUARD (burn-in safe preset, blank timer)
//   persistence   stage live settings → omni-nix monitors.lua
//
// All applies ride MonitorService's verified `hyprctl eval hl.monitor({...})`
// mechanism; risky changes get the 10s Keep/Revert window; STAGE persists via
// omni-apply. QD-OLED defaults are burn-in-first: 10-bit, VRR on, HDR with
// conservative SDR-white (≤250 nits, preset sets 203), auto-blank ≤10 min.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: view
    spacing: Config.ControlConfig.space2

    // The TARGETED monitor (selected on the canvas, else focused/first)
    readonly property var mon: Services.MonitorService.target
    readonly property bool hdrOn: mon && mon.colorPreset !== "" && mon.colorPreset !== "srgb"
    readonly property bool isTargetSelected: Services.MonitorService.selectedName !== ""

    // Keep/Revert countdown (service owns the deadline)
    property int revertSecsLeft: 0
    Timer {
        interval: 250; running: Services.MonitorService.revertPending; repeat: true
        onTriggered: if (Services.MonitorService.pendingRevert)
            view.revertSecsLeft = Math.max(0, Math.ceil((Services.MonitorService.pendingRevert.deadline - Date.now()) / 1000))
    }

    // Unique resolutions (label + best refresh at that res)
    readonly property var resolutions: {
        if (!view.mon) return []
        var seen = {}, out = []
        var ms = view.mon.modes
        for (var i = 0; i < ms.length; i++) {
            var k = ms[i].w + "x" + ms[i].h
            if (!seen[k]) { seen[k] = true; out.push({ w: ms[i].w, h: ms[i].h, hz: ms[i].hz }) }
        }
        return out
    }
    // Distinct refresh rates at the CURRENT resolution (desc, max 5 segs)
    readonly property var refreshOptions: {
        if (!view.mon) return []
        var seen = {}, out = []
        var ms = view.mon.modes
        for (var i = 0; i < ms.length; i++) {
            if (ms[i].w !== view.mon.w || ms[i].h !== view.mon.h) continue
            var hz = parseFloat(ms[i].hz.toFixed(2))
            if (!seen[hz]) { seen[hz] = true; out.push(hz) }
        }
        out.sort(function(a, b) { return b - a })
        return out.slice(0, 5)
    }

    // ── canvas geometry: logical extents → uniform scale-to-fit ────────────
    readonly property real canvasK: {
        var spanW = 1, spanH = 1
        var ms = Services.MonitorService.monitors
        for (var i = 0; i < ms.length; i++) {
            var lw = ms[i].w / ms[i].scale, lh = ms[i].h / ms[i].scale
            spanW = Math.max(spanW, ms[i].x + lw)
            spanH = Math.max(spanH, ms[i].y + lh)
        }
        if (canvasArea.width < 10 || canvasArea.height < 10) return 0.05
        return Math.min((canvasArea.width - 24) / spanW, (canvasArea.height - 20) / spanH)
    }

    // ── QD-OLED burn-in guard — live-computed checklist ────────────────────
    readonly property var guardItems: [
        { label: "10-BIT COLOR DEPTH", ok: view.mon ? Services.MonitorService.liveBitdepth() === 10 : false },
        { label: "VRR ENABLED", ok: Services.MonitorService.vrrMode !== 0 },
        { label: "AUTO BLANK ≤ 10 MIN", ok: Services.HypridleService.displayOffTimeout <= 600 },
        { label: "HDR SDR-WHITE ≤ 250 NITS", ok: !view.hdrOn || view.mon.sdrMaxLuminance <= 250 },
        { label: "SDR BRIGHTNESS ≤ 1.2", ok: !view.hdrOn || (view.mon.sdrBrightness || 1) <= 1.2 }
    ]
    readonly property int guardOk: {
        var n = 0
        for (var i = 0; i < view.guardItems.length; i++) if (view.guardItems[i].ok) n++
        return n
    }

    function applyOledPreset() {
        var s = Services.MonitorService
        // Burn-in-first QD-OLED baseline: 10-bit, VRR on, HDR with reference
        // SDR white (203 nits), neutral saturation, plus a 5-min auto-blank.
        s.applyRule({ bitdepth: 10, vrr: s.vrrMode === 0 ? 2 : s.vrrMode, cm: "hdredid",
                      sdrbrightness: 1.0, sdrsaturation: 1.0,
                      sdr_min_luminance: 0.2, sdr_max_luminance: 203 })
        if (Services.HypridleService.displayOffTimeout > 600) {
            Services.HypridleService.displayOffTimeout = 300
            Services.HypridleService.saveConfig()
        }
        CommandService.pushLog("[display] QD-OLED safe preset applied", "success")
    }

    // ── reusable bits ────────────────────────────────────────────────────────
    component Chip: Rectangle {
        property string text: ""
        property color chipColor: Config.ThemeConfig.colors.textDim
        height: 18
        width: chipLbl.implicitWidth + 14
        radius: Config.ControlConfig.radiusSmall
        color: Config.ThemeConfig.tint(chipColor, 0.10)
        border.color: chipColor
        border.width: 1
        Text {
            id: chipLbl; anchors.centerIn: parent
            text: parent.text
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
            color: chipColor
        }
    }

    component ActionPill: Rectangle {
        id: pill
        property string text: ""
        property bool accentStyle: false
        signal activated()
        Layout.alignment: Qt.AlignVCenter
        width: pillLbl.implicitWidth + 22; height: 26
        radius: Config.ControlConfig.radiusPill
        color: accentStyle ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.18)
                           : (pma.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.08)
                                                : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5))
        border.color: accentStyle ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
        border.width: 1
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            id: pillLbl; anchors.centerIn: parent
            text: pill.text
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
            color: pill.accentStyle ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
        }
        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor; onClicked: pill.activated() }
    }

    component SpecTile: Rectangle {
        id: tile
        property string label: ""
        property string value: "—"
        property color valueColor: Config.ThemeConfig.colors.text
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: Config.ControlConfig.radiusSmall
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
        border.color: Config.ThemeConfig.colors.outlineVariant
        border.width: 1
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 5; spacing: 0
            Text { text: tile.label; font.family: Config.ControlConfig.fontSans
                font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.8
                color: Config.ThemeConfig.colors.textDim }
            Text { text: tile.value; font.family: Config.ControlConfig.fontMono
                font.pixelSize: 11; font.bold: true; color: tile.valueColor
                elide: Text.ElideMiddle; Layout.maximumWidth: tile.width - 12 }
        }
    }

    component GuardRow: RowLayout {
        property string label: ""
        property bool ok: false
        spacing: 6
        Text { text: parent.ok ? "✓" : "✗"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 11; font.bold: true
            color: parent.ok ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error }
        Text { text: parent.label
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: parent.ok ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.warning }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 1. HEADER — breadcrumb · Display Manager · badges · global actions
    // ═════════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: "CONTROLS  /  HARDWARE & DISPLAY OUTPUTS"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                font.letterSpacing: 1.2; color: Config.ThemeConfig.colors.textDim
            }
            RowLayout {
                spacing: 10
                Text {
                    text: "Display Manager"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 20
                    font.bold: true; color: Config.ThemeConfig.colors.text
                }
                Chip {
                    visible: Services.MonitorService.monitors.length > 0
                    text: Services.MonitorService.monitors.length + " DISPLAY" +
                          (Services.MonitorService.monitors.length !== 1 ? "S" : "") + " ACTIVE"
                    chipColor: Config.ThemeConfig.colors.success
                }
                Chip {
                    text: Services.MonitorService.persistState === "dirty"
                          ? "UNSTAGED CHANGES" : "IN SYNC WITH NIXOS"
                    chipColor: Services.MonitorService.persistState === "dirty"
                          ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.success
                }
            }
        }

        ActionPill { text: "DETECT"; onActivated: Services.MonitorService.refresh() }
        ActionPill { text: "IDENTIFY"; onActivated: Services.MonitorService.identify() }
        ActionPill {
            text: "STAGE & APPLY"
            accentStyle: Services.MonitorService.persistState === "dirty"
            onActivated: Services.MonitorService.stageToNix()
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 2. KEEP / REVERT BANNER (risky change pending)
    // ═════════════════════════════════════════════════════════════════════════
    Rectangle {
        Layout.fillWidth: true
        visible: Services.MonitorService.revertPending
        height: visible ? bannerRow.implicitHeight + 14 : 0
        radius: Config.ControlConfig.radiusPill
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.warning, 0.10)
        border.color: Config.ThemeConfig.colors.warning; border.width: 1

        RowLayout {
            id: bannerRow
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 8

            Text { text: "󰦜"; font.family: Config.ControlConfig.fontNerd; font.pixelSize: 13
                color: Config.ThemeConfig.colors.warning }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: Services.MonitorService.pendingRevert
                          ? Services.MonitorService.pendingRevert.label : ""
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                    color: Config.ThemeConfig.colors.warning
                }
                Text {
                    text: "reverting in " + view.revertSecsLeft + "s unless kept"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    color: Config.ThemeConfig.colors.textDim
                }
            }
            ActionPill { text: "KEEP"; accentStyle: true; onActivated: Services.MonitorService.confirmKeep() }
            ActionPill { text: "REVERT"; onActivated: Services.MonitorService.revertNow() }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 3. TOP ZONE — arrangement canvas (left half) · telemetry (right half)
    // ═════════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 168
        spacing: Config.ControlConfig.space2

        SettingsCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        accent: Config.ThemeConfig.colors.info
        contentSpacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 8
                RowLayout { spacing: 6
                    Rectangle { width: 7; height: 7; radius: 3.5; color: Config.ThemeConfig.colors.info }
                    Text { Layout.fillWidth: false; text: "VISUAL LAYOUT & WORKSPACE MAPPING"
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                        font.bold: true; font.letterSpacing: 1.0; color: Config.ThemeConfig.colors.text }
                }
                Item { Layout.fillWidth: true }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: "click a display to target it"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                    color: Config.ThemeConfig.colors.textDim
                }
            }

            // Canvas
            Item {
                id: canvasArea
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                Layout.fillHeight: true
                Layout.leftMargin: 12; Layout.rightMargin: 12
                clip: true
                Rectangle {
                    anchors.fill: parent
                    radius: Config.ControlConfig.radiusSmall
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.8)
                    border.color: Config.ThemeConfig.colors.outlineVariant
                    border.width: 1
                }

                Repeater {
                    model: Services.MonitorService.monitors
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool selected: Services.MonitorService.selectedName === modelData.name
                                                         || (Services.MonitorService.selectedName === "" && modelData.focused)
                        readonly property real lw: modelData.w / modelData.scale
                        readonly property real lh: modelData.h / modelData.scale
                        x: (canvasArea.width - spanW * view.canvasK) / 2 + modelData.x * view.canvasK
                        y: (canvasArea.height - spanH * view.canvasK) / 2 + modelData.y * view.canvasK
                        width: Math.max(60, lw * view.canvasK)
                        height: Math.max(40, lh * view.canvasK)
                        radius: 4
                        color: selected ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.info, 0.14)
                                        : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
                        border.color: selected ? Config.ThemeConfig.colors.info : Config.ThemeConfig.colors.outlineVariant
                        border.width: selected ? 2 : 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        // spanW/spanH re-computed here from the same source as canvasK
                        readonly property real spanW: {
                            var s = 1
                            var ms = Services.MonitorService.monitors
                            for (var i = 0; i < ms.length; i++)
                                s = Math.max(s, ms[i].x + ms[i].w / ms[i].scale)
                            return s
                        }
                        readonly property real spanH: {
                            var s = 1
                            var ms = Services.MonitorService.monitors
                            for (var i = 0; i < ms.length; i++)
                                s = Math.max(s, ms[i].y + ms[i].h / ms[i].scale)
                            return s
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            width: Math.min(parent.width - 10, implicitWidth)
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: (tile.modelData.make + " " + tile.modelData.model).trim() || tile.modelData.name
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: tile.selected
                                color: tile.selected ? Config.ThemeConfig.colors.info : Config.ThemeConfig.colors.text
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: tile.modelData.w + "×" + tile.modelData.h + " @ " + Math.round(tile.modelData.refreshHz) + " Hz"
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                                color: Config.ThemeConfig.colors.textDim
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                visible: tile.modelData.activeWs > 0
                                text: "WS " + tile.modelData.activeWs
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                                color: Config.ThemeConfig.colors.textDim
                            }
                        }

                        // name tag + PRIMARY marker (top corners)
                        Text {
                            anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 4
                            text: tile.modelData.name
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                            color: tile.selected ? Config.ThemeConfig.colors.info : Config.ThemeConfig.colors.textDim
                        }
                        Chip {
                            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 4
                            visible: tile.modelData.focused
                            text: "PRIMARY"
                            chipColor: Config.ThemeConfig.colors.info
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.MonitorService.selectedName = tile.modelData.name
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Services.MonitorService.monitors.length === 0
                    text: "// no monitors detected"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                    color: Config.ThemeConfig.colors.textDim
                }
            }
        }
    }

        SettingsCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1.2
        accent: Config.ThemeConfig.colors.primary
        contentSpacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 8
                spacing: 10
                Rectangle { width: 8; height: 8; radius: 4
                    color: view.mon && view.mon.dpms ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error }
                ColumnLayout {
                    spacing: 0
                    RowLayout { spacing: 8
                        Text {
                            text: view.mon ? ((view.mon.make + " " + view.mon.model).trim() || view.mon.name) : "NO MONITOR"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 12; font.bold: true
                            color: Config.ThemeConfig.colors.text
                            elide: Text.ElideRight
                        }
                        Chip { text: "CURRENT TARGET"; chipColor: Config.ControlConfig.accent }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: view.mon ? "Connector: " + view.mon.name + " · " + (view.mon.desc || "unknown EDID") : "—"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                        color: Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // Spec grid — 4×2 (res/refresh promoted here from the old pills)
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.bottomMargin: 10
                columns: 4
                columnSpacing: 6; rowSpacing: 6
                SpecTile { label: "RESOLUTION"
                    value: view.mon ? view.mon.w + "×" + view.mon.h : "—"
                    valueColor: Config.ThemeConfig.colors.info }
                SpecTile { label: "REFRESH"
                    value: view.mon ? Math.round(view.mon.refreshHz) + " Hz" : "—"
                    valueColor: Config.ThemeConfig.colors.success }
                SpecTile { label: "COLOR DEPTH"
                    value: view.mon ? (Services.MonitorService.liveBitdepth() === 10 ? "10-bit" : "8-bit") : "—"
                    valueColor: Services.MonitorService.liveBitdepth() === 10 ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.warning }
                SpecTile { label: "COLOR SPACE"
                    value: view.mon ? (view.mon.colorPreset !== "" ? view.mon.colorPreset.toUpperCase() : "SDR") : "—"
                    valueColor: Config.ThemeConfig.colors.info }
                SpecTile { label: "ORIENTATION"
                    value: view.mon ? (["LANDSCAPE", "PORTRAIT 90°", "FLIPPED 180°", "PORTRAIT 270°"][view.mon.transform] || "LANDSCAPE") : "—" }
                SpecTile { label: "POWER"
                    value: view.mon ? (view.mon.dpms ? "ON" : "STANDBY") : "—"
                    valueColor: view.mon && view.mon.dpms ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error }
                SpecTile { label: "PANEL SIZE"
                    value: view.mon && view.mon.physW > 0
                           ? Math.round(view.mon.physW / 25.4) + '"' + " × " + Math.round(view.mon.physH / 25.4) + '"' : "—" }
                SpecTile { label: view.hdrOn ? "SDR WHITE (HDR)" : "SCALE FACTOR"
                    value: view.mon ? (view.hdrOn ? Math.round(view.mon.sdrMaxLuminance) + " nits"
                                                  : view.mon.scale.toFixed(2) + "×") : "—"
                    valueColor: view.mon && view.hdrOn && view.mon.sdrMaxLuminance > 250
                                ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.text }
            }
        }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 5. CONFIG ROW — MODE · SCALE · HDR & COLOR · VRR + QD-OLED GUARD.
    // Single row of fill-height cards: SettingsCard sizes to content, so
    // stacked rows collapsed and painted over each other — one row can't.
    // ═════════════════════════════════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Config.ControlConfig.space2

        // ── A: MODE — resolution / refresh / orientation ────────────────────
        SettingsCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            accent: Config.ThemeConfig.colors.info

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Config.ControlConfig.space2

                PanelSectionHeader {
                    Layout.fillWidth: true
                    label: "MODE"
                    value: ""
                }

                PanelDropdown {
                    Layout.fillWidth: true
                    visible: view.mon !== null
                    label: "RESOLUTION"
                    showLabel: false
                    value: view.mon ? view.mon.w + " × " + view.mon.h : "—"
                    options: view.resolutions.map(function(r) {
                        return { label: r.w + " × " + r.h, value: r.w + "x" + r.h } })
                    onChanged: function(newValue) {
                        var parts = newValue.split("x")
                        var best = view.mon.modes.filter(function(m) {
                            return m.w === parseInt(parts[0]) && m.h === parseInt(parts[1]) })
                        best.sort(function(a, b) { return b.hz - a.hz })
                        if (best.length === 0) return
                        Services.MonitorService.applyWithRevert(
                            "MODE " + parts[0] + "x" + parts[1] + "@" + parseFloat(best[0].hz.toFixed(2)),
                            { mode: parts[0] + "x" + parts[1] + "@" + parseFloat(best[0].hz.toFixed(2)) })
                    }
                }

                PanelDropdown {
                    Layout.fillWidth: true
                    showLabel: false
                    label: "REFRESH RATE"
                    value: view.mon ? parseFloat(view.mon.refreshHz.toFixed(2)) + " Hz" : "—"
                    options: view.refreshOptions.map(function(hz) {
                        return { label: parseFloat(hz) + " Hz", value: hz } })
                    onChanged: function(newValue) {
                        Services.MonitorService.applyWithRevert(
                            "MODE " + view.mon.w + "x" + view.mon.h + "@" + newValue,
                            { mode: view.mon.w + "x" + view.mon.h + "@" + newValue })
                    }
                }

                PanelDropdown {
                    Layout.fillWidth: true
                    showLabel: false
                    label: "ORIENTATION"
                    value: view.mon ? (["LANDSCAPE", "PORTRAIT 90°", "FLIPPED 180°", "PORTRAIT 270°"][view.mon.transform] || "LANDSCAPE") : "—"
                    options: [
                        { label: "LANDSCAPE", value: 0 },
                        { label: "PORTRAIT 90°", value: 1 },
                        { label: "FLIPPED 180°", value: 2 },
                        { label: "PORTRAIT 270°", value: 3 }
                    ]
                    onChanged: function(newValue) { Services.MonitorService.applyRule({ transform: newValue }) }
                }

                // Power + identity — uses the empty lower half of the card
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text { text: "POWER"
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 9
                        font.bold: true; color: Config.ThemeConfig.colors.textDim }
                    ControlSeg { text: "ON"; active: view.mon && view.mon.dpms
                        onChosen: Services.MonitorService.setDpms(true) }
                    ControlSeg { text: "STANDBY"; active: view.mon && !view.mon.dpms
                        onChosen: Services.MonitorService.setDpms(false) }
                    Item { Layout.fillWidth: true }
                }

                Text {
                    Layout.fillWidth: true
                    text: view.mon ? (view.mon.desc || view.mon.name) : ""
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                    color: Config.ThemeConfig.colors.textDim
                    elide: Text.ElideMiddle
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ── B: SCALE — stepper + presets + sharpness ────────────────────────
        SettingsCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            accent: Config.ThemeConfig.colors.secondary

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Config.ControlConfig.space2

                PanelSectionHeader {
                    Layout.fillWidth: true
                    label: "SCALING"
                    value: ""
                    color: view.mon && view.scaleIsSharp ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.warning
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        width: 34; height: 28; radius: Config.ControlConfig.radiusSmall
                        color: scaleDownMA.containsMouse ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16)
                               : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
                        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        MouseArea { id: scaleDownMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: view.stepScale(-0.25) }
                        Text { anchors.centerIn: parent; text: "−"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 13; font.bold: true
                            color: Config.ThemeConfig.colors.text }
                    }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        text: view.mon ? (view.mon.scale * 100).toFixed(0) + "%" : "—"
                        font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 18; font.bold: true
                        color: Config.ThemeConfig.colors.secondary
                    }
                    Rectangle {
                        width: 34; height: 28; radius: Config.ControlConfig.radiusSmall
                        color: scaleUpMA.containsMouse ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16)
                               : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
                        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        MouseArea { id: scaleUpMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: view.stepScale(0.25) }
                        Text { anchors.centerIn: parent; text: "+"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 13; font.bold: true
                            color: Config.ThemeConfig.colors.text }
                    }
                }

                // 2×2 grid — tidy, and fits the quarter-card width
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 6; rowSpacing: 6
                    Repeater {
                        model: [1.0, 1.25, 1.5, 2.0]
                        delegate: ControlSeg {
                            Layout.fillWidth: true
                            text: parseFloat(modelData) + "×"
                            active: view.mon && Math.abs(view.mon.scale - modelData) < 0.01
                            onChosen: Services.MonitorService.applyWithRevert(
                                "SCALE " + modelData, { scale: modelData })
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: view.mon && view.scaleIsSharp
                          ? "integer-perfect — text renders pixel-sharp"
                          : "fractional — expect slight softness on QD-OLED"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 9
                    color: Config.ThemeConfig.colors.textDim
                }

                // Logical resolution — compact strip under the presets
                Rectangle {
                    Layout.fillWidth: true
                    height: 22
                    radius: Config.ControlConfig.radiusSmall
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
                    border.color: Config.ThemeConfig.colors.outlineVariant
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        Text { text: "LOGICAL"
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 8
                            font.bold: true; font.letterSpacing: 0.8
                            color: Config.ThemeConfig.colors.textDim }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: view.mon ? Math.round(view.mon.w / view.mon.scale) + " × "
                                             + Math.round(view.mon.h / view.mon.scale) : "—"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                            color: Config.ThemeConfig.colors.secondary
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ── C: HDR & COLOR ───────────────────────────────────────────────────
        SettingsCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            accent: Config.ThemeConfig.colors.warning
            visible: Services.MonitorService.hdrCapable

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Config.ControlConfig.space2

                PanelSectionHeader {
                    Layout.fillWidth: true
                    label: "HDR & COLOR"
                    value: view.hdrOn ? "HDR " + (view.mon ? view.mon.colorPreset.toUpperCase() : "") : "SDR"
                    color: view.hdrOn ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.textDim
                }

                PanelDropdown {
                    Layout.fillWidth: true
                    showLabel: false
                    label: "HDR MODE"
                    value: !view.hdrOn && Services.MonitorService.cmAutoHdr === 0 ? "OFF"
                          : (Services.MonitorService.cmAutoHdr === 1 ? "AUTO" : "ALWAYS")
                    options: [
                        { label: "OFF", value: "OFF" },
                        { label: "AUTO", value: "AUTO" },
                        { label: "ALWAYS", value: "ALWAYS" }
                    ]
                    onChanged: function(newValue) {
                        if (newValue === "OFF") {
                            Services.MonitorService.cmAutoHdr = 0
                            Services.MonitorService.applyGlobalConfig("hl.config({ render = { cm_auto_hdr = 0 } })")
                            Services.MonitorService.applyRule({ cm: "srgb" })
                        } else if (newValue === "AUTO") {
                            Services.MonitorService.cmAutoHdr = 1
                            Services.MonitorService.applyGlobalConfig("hl.config({ render = { cm_auto_hdr = 1 } })")
                            Services.MonitorService.applyRule({ cm: "srgb" })
                        } else if (newValue === "ALWAYS") {
                            Services.MonitorService.applyRule({ cm: "hdredid" })
                        }
                    }
                }

                PanelDropdown {
                    Layout.fillWidth: true
                    visible: view.hdrOn
                    showLabel: false
                    value: view.mon ? view.mon.colorPreset.toUpperCase() : "EDID"
                    options: [
                        { label: "EDID", value: "edid" },
                        { label: "P3", value: "dcip3" },
                        { label: "WIDE", value: "wide" },
                        { label: "HDR-EDID", value: "hdredid" },
                        { label: "HDR-WIDE", value: "hdr" }
                    ]
                    onChanged: function(newValue) { Services.MonitorService.applyRule({ cm: newValue }) }
                }

                // SDR-in-HDR tuning — burn-in-relevant (peak luminance pumping)
                ColumnLayout {
                    visible: view.hdrOn
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "SDR BRIGHTNESS"
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 9
                            font.bold: true; color: Config.ThemeConfig.colors.textDim }
                        Item { Layout.fillWidth: true }
                        Text { text: (view.mon ? view.mon.sdrBrightness.toFixed(2) : "—")
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                            color: Config.ThemeConfig.colors.warning }
                    }
                    Slider {
                        id: sdrBSlider
                        Layout.fillWidth: true
                        from: 0.5; to: 2.0; stepSize: 0.05
                        value: view.mon ? view.mon.sdrBrightness : 1.0
                        onMoved: if (view.mon) Services.MonitorService.applyRule({ sdrbrightness: value })
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "SDR WHITE PEAK (NITS)"
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 9
                            font.bold: true; color: Config.ThemeConfig.colors.textDim }
                        Item { Layout.fillWidth: true }
                        Text { text: view.mon ? Math.round(view.mon.sdrMaxLuminance) + " nits" : "—"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                            color: view.mon && view.mon.sdrMaxLuminance > 250
                                   ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.success }
                    }
                    Slider {
                        id: sdrMaxSlider
                        Layout.fillWidth: true
                        from: 80; to: 480; stepSize: 1
                        value: view.mon ? view.mon.sdrMaxLuminance : 203
                        onMoved: if (view.mon) Services.MonitorService.applyRule({ sdr_max_luminance: Math.round(value) })
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "QD-OLED: keep SDR white ≤ 250 nits — lower white = slower wear"
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 8
                        color: Config.ThemeConfig.colors.textDim
                    }
                }

                // SDR-state hint — fills the card when the sliders are hidden
                Text {
                    Layout.fillWidth: true
                    visible: !view.hdrOn
                    text: "AUTO renders HDR for fullscreen media · ALWAYS turns the whole desktop HDR. QD-OLED: prefer AUTO with SDR white ≤ 250 nits."
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 9
                    color: Config.ThemeConfig.colors.textDim
                    wrapMode: Text.WordWrap
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ── D: VRR + QD-OLED GUARD ──────────────────────────────────────────
        SettingsCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            accent: Config.ThemeConfig.colors.success

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Config.ControlConfig.space2

                PanelSectionHeader {
                    Layout.fillWidth: true
                    label: "VRR · OLED GUARD"
                    value: view.guardOk + "/" + view.guardItems.length + " PASS"
                    color: view.guardOk === view.guardItems.length
                           ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.warning
                }

                PanelDropdown {
                    Layout.fillWidth: true
                    showLabel: false
                    value: Services.MonitorService.vrrMode === 0 ? "VRR OFF"
                          : (Services.MonitorService.vrrMode === 1 ? "VRR ALWAYS"
                          : (Services.MonitorService.vrrMode === 2 ? "VRR FULLSCREEN" : "VRR GAMES"))
                    options: [
                        { label: "VRR OFF", value: "OFF" },
                        { label: "VRR ALWAYS", value: "ALWAYS" },
                        { label: "VRR FULLSCREEN", value: "FULLSCREEN" },
                        { label: "VRR GAMES", value: "GAMES" }
                    ]
                    onChanged: function(newValue) {
                        if (newValue === "OFF") Services.MonitorService.vrrMode = 0
                        else if (newValue === "ALWAYS") Services.MonitorService.vrrMode = 1
                        else if (newValue === "FULLSCREEN") Services.MonitorService.vrrMode = 2
                        else if (newValue === "GAMES") Services.MonitorService.vrrMode = 3
                        Services.MonitorService.applyRule({ vrr: Services.MonitorService.vrrMode })
                    }
                }

                // Burn-in guard checklist
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Repeater {
                        model: view.guardItems
                        delegate: GuardRow { label: modelData.label; ok: modelData.ok }
                    }
                }

                // Auto-blank timer (hypridle display-off)
                PanelDropdown {
                    Layout.fillWidth: true
                    showLabel: false
                    label: "AUTO-BLANK (BURN-IN PROTECTION)"
                    value: Math.round(Services.HypridleService.displayOffTimeout / 60) + " MIN"
                    options: [
                        { label: "2 MIN", value: 120 },
                        { label: "5 MIN", value: 300 },
                        { label: "10 MIN", value: 600 },
                        { label: "15 MIN", value: 900 }
                    ]
                    onChanged: function(newValue) {
                        Services.HypridleService.displayOffTimeout = newValue
                        Services.HypridleService.saveConfig()
                    }
                }

                ActionPill {
                    Layout.alignment: Qt.AlignHCenter
                    text: "APPLY QD-OLED SAFE PRESET"
                    accentStyle: true
                    onActivated: view.applyOledPreset()
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 6. PERSISTENCE — stage live settings into the nix source of truth
    // ═════════════════════════════════════════════════════════════════════════
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: Config.ControlConfig.radiusSmall
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.55)
        border.color: Config.ThemeConfig.colors.outlineVariant
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 8
            spacing: 10

            Chip {
                text: Services.MonitorService.persistState === "dirty" ? "PERSISTENCE · UNSTAGED" : "PERSISTENCE · IN SYNC"
                chipColor: Services.MonitorService.persistState === "dirty"
                    ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.success
            }

            Text {
                Layout.fillWidth: true
                text: Services.MonitorService.persistState === "dirty"
                      ? "Live settings differ from ~/.omni-nix/configs/hypr/monitors.lua — a reload reverts them."
                      : "Live settings match the nix source · staged changes land on the next omni-apply."
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                color: Config.ThemeConfig.colors.textDim
                elide: Text.ElideRight
            }

            ActionPill {
                text: "STAGE CURRENT SETTINGS"
                onActivated: Services.MonitorService.stageToNix()
            }
        }
    }

    // ── scale helpers ─────────────────────────────────────────────────────
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
}
