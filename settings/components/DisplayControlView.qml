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
import QtQuick.Controls
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: Config.ControlConfig.space4

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

    // Segmented control pill; `active` highlights, `when` gates visibility.
    component Seg: ControlSeg {}

    // Slim HUD slider (no QtQuick.Controls — Basic import is broken in this
    // build). Drag or click; emits `previewed` continuously, `committed` on release.
    component HudSlider: ColumnLayout {
        id: slider
        property string label: ""
        property real from: 0
        property real to: 1
        property real step: 0.05
        property real value: 0
        signal previewed(real val)  // Live preview during drag
        signal committed(real val)  // Apply on mouse release
        spacing: 4

        function quant(v) {
            var q = Math.round((v - from) / step) * step + from
            return Math.max(from, Math.min(to, +q.toFixed(4)))
        }
        readonly property real frac: (value - from) / Math.max(0.0001, to - from)

        RowLayout {
            Layout.fillWidth: true
            Text { text: slider.label; font.family: Config.ControlConfig.fontSans
                font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8
                color: Config.ThemeConfig.colors.textDim }
            Item { Layout.fillWidth: true }
            Text { text: (+slider.value).toFixed(slider.step < 0.01 ? 3 : 2)
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: Config.ThemeConfig.colors.text }
        }
        Rectangle {
            id: track
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
            border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
            Rectangle {
                width: Math.round(parent.width * slider.frac); height: parent.height - 2
                anchors.verticalCenter: parent.verticalCenter
                y: 1; x: 1
                radius: 3
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
                property real dragStartValue: slider.value

                function apply(x) {
                    var f = Math.max(0, Math.min(1, x / track.width))
                    slider.value = slider.quant(slider.from + f * (slider.to - slider.from))
                    slider.previewer(slider.value)  // Live preview during drag
                }
                onPressed: mouse => {
                    dragStartValue = slider.value
                    apply(mouse.x)
                }
                onReleased: {
                    slider.committed(slider.value)  // Apply on release
                }
                onClicked: function(mouse) { apply(mouse.x) }
                onPositionChanged: function(mouse) {
                    if (pressed) apply(mouse.x)
                }
            }
        }
    }

    // =========================================================================
    // 1. HEADER — DPMS pill is now a toggle
    // =========================================================================
    SectionHeader {
        title: "DISPLAY"

        // Clickable DPMS badge (wrap StatusBadge for the click surface)
        Item {
            Layout.alignment: Qt.AlignVCenter
            width: dpmsBadge.implicitWidth; height: dpmsBadge.implicitHeight
            StatusBadge {
                id: dpmsBadge
                label: view.mon && view.mon.dpms ? "ACTIVE ⇄" : "STANDBY ⇄"
                kind: view.mon && view.mon.dpms ? "ok" : "err"
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: Services.MonitorService.setDpms(!(view.mon && view.mon.dpms))
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: view.mon ? ((view.mon.make + " " + view.mon.model).trim() || view.mon.name) : "—"
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            elide: Text.ElideRight
        }
    }

    // Hero-row status caption
    Text {
        Layout.fillWidth: true
        Layout.topMargin: -6
        text: "DISPLAY · " + (view.mon && view.mon.dpms ? "ACTIVE" : "STANDBY") + (view.mon ? " · " + view.mon.make + " " + view.mon.model : "")
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 10
        font.letterSpacing: 0.3
        color: Config.ThemeConfig.colors.textDim
        opacity: 0.75
    }

    // Error surface (display/monitor errors)
    Text {
        Layout.fillWidth: true
        visible: false  // TODO: Bind to service error property when available
        text: "⚠ Display operation failed"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 9
        color: Config.ThemeConfig.colors.error
        wrapMode: Text.Wrap
        Layout.topMargin: 4
    }

    // =========================================================================
    // 2. KEEP / REVERT BANNER (risky change pending)
    // =========================================================================
    Rectangle {
        width: parent.width
        visible: Services.MonitorService.revertPending
        height: bannerRow.implicitHeight + 16
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
                    Layout.fillWidth: true
                    text: "reverting in " + view.revertSecsLeft + "s unless kept"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    color: Config.ThemeConfig.colors.textDim
                }
            }

            Rectangle {
                width: keepLbl.implicitWidth + 18; height: 24
                radius: Config.ControlConfig.radiusPill
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.15)
                border.color: Config.ThemeConfig.colors.success; border.width: 1
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: Services.MonitorService.confirmKeep() }
                Text { id: keepLbl; anchors.centerIn: parent; text: "KEEP"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                    color: Config.ThemeConfig.colors.success }
            }
            Rectangle {
                width: revLbl.implicitWidth + 18; height: 24
                radius: Config.ControlConfig.radiusPill
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
                border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: Services.MonitorService.revertNow() }
                Text { id: revLbl; anchors.centerIn: parent; text: "REVERT"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                    color: Config.ThemeConfig.colors.textDim }
            }
        }
    }

    // =========================================================================
    // RESPONSIVE CARD GRID — 2 columns at the 4K pane, 1 column when narrow.
    // Children auto-flow (no pinned row/column) so capability-hidden cards
    // (HDR/VRR) never leave grid holes.
    // =========================================================================
    GridLayout {
        width: parent.width
        columns: Math.max(1, Math.floor(width / 360))
        columnSpacing: Config.ControlConfig.space3
        rowSpacing: Config.ControlConfig.space3

        // =========================================================================
        // MODE_CARD — resolution + refresh rate
        // =========================================================================
        SettingsCard {
            Layout.fillWidth: true
            accent: Config.ThemeConfig.colors.primary

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.ControlConfig.space2

                PanelSectionHeader {
                    Layout.fillWidth: true
                    label: "MODE"
                    value: view.mon ? (view.mon.w + "×" + view.mon.h) : "—"
                }

                PanelDropdown {
                    Layout.fillWidth: true
                    visible: view.mon !== null && view.mon.modes.length > 1
                    showLabel: false
                    value: view.mon ? Math.round(view.mon.refreshHz) + " Hz" : "—"

                    property var filteredModes: view.mon ? view.mon.modes.filter(function(m) { return m.w === view.mon.w && m.h === view.mon.h }) : []

                    options: filteredModes.map(function(m) {
                        return { label: parseFloat(m.h.toFixed(2)) + " Hz", value: parseFloat(m.h.toFixed(2)) }
                    })

                    onChanged: function(newValue) {
                        Services.MonitorService.applyWithRevert(
                            "MODE " + view.mon.w + "x" + view.mon.h + "@" + newValue,
                            { mode: view.mon.w + "x" + view.mon.h + "@" + parseFloat(newValue) })
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
                        height: 34
                        radius: Config.ControlConfig.radiusSmall
                        color: modeMa.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.10)
                               : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.35)
                        border.color: modeMa.containsMouse ? Config.ThemeConfig.colors.primary
                                                           : Config.ThemeConfig.colors.outlineVariant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        MouseArea {
                            id: modeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Services.MonitorService.applyWithRevert(
                                "MODE " + modelData.w + "x" + modelData.h + "@" + modelData.hz,
                                { mode: modelData.w + "x" + modelData.h + "@" + parseFloat(modelData.hz.toFixed(2)) })
                        }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            Text { text: modelData.w + " × " + modelData.h
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                                color: Config.ThemeConfig.colors.text }
                            Item { Layout.fillWidth: true }
                            Text { text: "@" + parseFloat(modelData.hz.toFixed(2)) + " Hz"
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                                color: Config.ThemeConfig.colors.textDim }
                        }
                    }
                }
            }
        }

        // =========================================================================
        // COLOR_CARD — HDR mode, color preset
        // =========================================================================
        SettingsCard {
            Layout.fillWidth: true
            accent: Config.ThemeConfig.colors.warning
            visible: Services.MonitorService.hdrCapable

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.ControlConfig.space2

            PanelSectionHeader {
                Layout.fillWidth: true
                label: "HDR"
                value: view.hdrOn ? "HDR " + (view.mon ? view.mon.colorPreset.toUpperCase() : "") : "SDR"
                color: view.hdrOn ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.textDim
            }

            // HDR mode: OFF (SDR) / AUTO (fullscreen) / ALWAYS (per-output PQ)
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
                onChanged: function(newValue) {
                    Services.MonitorService.applyRule({ cm: newValue })
                }
            }
        }
    }

        // =========================================================================
        // VRR_CARD
        // =========================================================================
        SettingsCard {
            Layout.fillWidth: true
            accent: Config.ThemeConfig.colors.success
            visible: Services.MonitorService.vrrCapable

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.ControlConfig.space2

                PanelSectionHeader {
                    Layout.fillWidth: true
                    label: "VRR"
                    value: view.mon && view.mon.vrr ? "ACTIVE" : "IDLE (DESKTOP)"
                    color: view.mon && view.mon.vrr ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.textDim
                }

                PanelDropdown {
                    Layout.fillWidth: true
                    showLabel: false
                    value: Services.MonitorService.vrrMode === 0 ? "OFF"
                          : (Services.MonitorService.vrrMode === 1 ? "ALWAYS"
                          : (Services.MonitorService.vrrMode === 2 ? "FULLSCREEN" : "GAMES"))
                    options: [
                        { label: "OFF", value: "OFF" },
                        { label: "ALWAYS", value: "ALWAYS" },
                        { label: "FULLSCREEN", value: "FULLSCREEN" },
                        { label: "GAMES", value: "GAMES" }
                    ]
                    onChanged: function(newValue) {
                        if (newValue === "OFF") Services.MonitorService.vrrMode = 0
                        else if (newValue === "ALWAYS") Services.MonitorService.vrrMode = 1
                        else if (newValue === "FULLSCREEN") Services.MonitorService.vrrMode = 2
                        else if (newValue === "GAMES") Services.MonitorService.vrrMode = 3
                        Services.MonitorService.applyRule({ vrr: Services.MonitorService.vrrMode })
                    }
                }
            }
        }

        // =========================================================================
        // SCALE_CARD — scale stepper
        // =========================================================================
        SettingsCard {
            Layout.fillWidth: true
            accent: Config.ThemeConfig.colors.info

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.ControlConfig.space2

                PanelSectionHeader {
                    Layout.fillWidth: true
                    label: "SCALE"
                    value: view.mon ? view.mon.scale.toFixed(2) : "—"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 34; height: 26
                        radius: Config.ControlConfig.radiusSmall
                        color: scaleDownMA.containsMouse ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16)
                               : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
                        border.color: Config.ThemeConfig.colors.outlineVariant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        MouseArea {
                            id: scaleDownMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.stepScale(-0.125)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "−"
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 12; font.bold: true
                            color: Config.ThemeConfig.colors.text
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: view.mon ? (view.mon.scale * 100).toFixed(0) + "%" : "—"
                        font.family: Config.SettingsConfig.fontFamily
                        font.pixelSize: 16; font.bold: true
                        color: Config.ThemeConfig.colors.info
                    }

                    Rectangle {
                        width: 34; height: 26
                        radius: Config.ControlConfig.radiusSmall
                        color: scaleUpMA.containsMouse ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16)
                               : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
                        border.color: Config.ThemeConfig.colors.outlineVariant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        MouseArea {
                            id: scaleUpMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.stepScale(0.125)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 12; font.bold: true
                            color: Config.ThemeConfig.colors.text
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: view.mon && view.scaleIsSharp
                          ? "SHARP"
                          : "SOFT"
                    font.family: Config.ControlConfig.fontSans
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 0.6
                    horizontalAlignment: Text.AlignHCenter
                    color: view.mon && view.scaleIsSharp ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.warning
                }
            }
        }
    }

    // =========================================================================
    // Remaining cards (full-width below grid)
    // =========================================================================

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
    // PERSIST_CARD — stage live settings into the nix source
    // =========================================================================
    SettingsCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.secondary

        ColumnLayout {
            Layout.fillWidth: true; spacing: Config.ControlConfig.space2

            RowLayout {
                Layout.fillWidth: true
                Text { text: "PERSISTENCE"; font.family: Config.ControlConfig.fontSans
                    font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
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
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim; wrapMode: Text.WordWrap
            }

            Rectangle {
                width: stageLbl.implicitWidth + 20; height: 26
                radius: Config.ControlConfig.radiusPill
                color: stageMA.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.16)
                       : Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.10)
                border.color: Config.ThemeConfig.colors.secondary; border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                MouseArea { id: stageMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Services.MonitorService.stageToNix() }
                Text { id: stageLbl; anchors.centerIn: parent; text: "STAGE CURRENT SETTINGS"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                    color: Config.ThemeConfig.colors.secondary }
            }
        }
    }

    // =========================================================================
    // BACKLIGHT NOTE — honest "unavailable" (DDC unlock declined for now)
    // =========================================================================
    Rectangle {
        width: parent.width
        height: blRow.implicitHeight + 16
        radius: Config.ControlConfig.radiusCard
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.06)
        border.color: Config.ThemeConfig.colors.outlineVariant
        border.width: 1

        RowLayout {
            id: blRow
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 8

            Text { text: "󰃜"; font.family: Config.ControlConfig.fontNerd; font.pixelSize: 14
                color: Config.ThemeConfig.colors.error }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { Layout.fillWidth: true; text: "BACKLIGHT: NONE"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                    color: Config.ThemeConfig.colors.error }
                Text { Layout.fillWidth: true
                    text: "no /sys/class/backlight, no DDC/CI (ddcutil missing) — use the monitor OSD"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    color: Config.ThemeConfig.colors.textDim; wrapMode: Text.WordWrap }
            }
        }
    }
}
