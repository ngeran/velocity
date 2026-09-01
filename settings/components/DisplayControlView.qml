// =============================================================================
// DisplayControlView.qml — DISPLAY section view (viewport-fit, NO SCROLLING)
// =============================================================================
// Control model ported from omarchy-screens (single-monitor scope): mode/
// refresh picker, HDR, VRR, scale stepper, DPMS toggle — all applied LIVE via
// MonitorService's `hyprctl eval hl.monitor({...})` mechanism, with a 10s
// Keep/Revert window for risky changes (mode/scale) and a compact PERSISTENCE
// row that stages live settings into ~/.omni-nix/configs/hypr/monitors.lua.
//
// Fixed composition per SKILL.md §6.1 — everything fits the pane, no scroll:
//   header row (DPMS badge · monitor name)
//   Keep/Revert banner (only while a risky change is pending)
//   responsive card grid (MODE fills + clamps · HDR · VRR · SCALE)
//   PERSISTENCE compact row · BACKLIGHT compact row
// =============================================================================

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: view
    spacing: Config.ControlConfig.space3

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

    // Other resolutions (label + best refresh), deduped, newest first —
    // capacity-clamped to the MODE card's viewport (viewport-fit pattern).
    readonly property var otherModes: {
        if (!view.mon) return []
        var seen = {}, out = []
        var ms = view.mon.modes
        for (var i = 0; i < ms.length; i++) {
            if (ms[i].w === view.mon.w && ms[i].h === view.mon.h) continue
            var k = ms[i].w + "x" + ms[i].h
            if (!seen[k]) { seen[k] = true; out.push(ms[i]) }
        }
        return out
    }
    readonly property int modeCapacity: Math.max(0, Math.floor(modeViewport.height / 34))
    readonly property var visibleModes: view.otherModes.slice(0, view.modeCapacity)

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

    // =========================================================================
    // 1. HEADER ROW — DPMS badge is a toggle
    // =========================================================================
    SectionHeader {
        Layout.fillWidth: true
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

    // =========================================================================
    // 2. KEEP / REVERT BANNER (risky change pending — conditional)
    // =========================================================================
    Rectangle {
        Layout.fillWidth: true
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
    // 3. RESPONSIVE CARD GRID — 2 columns at the 4K pane, 1 when narrow.
    //    Children auto-flow; capability-hidden cards (HDR/VRR) leave no holes.
    //    MODE fills the height and clamps its resolution rows.
    // =========================================================================
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: Math.max(1, Math.floor(width / 360))
        columnSpacing: Config.ControlConfig.space3
        rowSpacing: Config.ControlConfig.space3

        // MODE_CARD — resolution + refresh rate + other resolutions (clamped)
        SettingsCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            accent: Config.ThemeConfig.colors.primary

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
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

                // Other resolutions — clamped to the visible capacity
                Item {
                    id: modeViewport
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 4
                        Repeater {
                            model: view.visibleModes
                            delegate: Rectangle {
                                required property var modelData
                                width: parent.width
                                height: 30
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

                Text {
                    Layout.fillWidth: true
                    visible: view.visibleModes.length < view.otherModes.length
                    text: "+ " + (view.otherModes.length - view.visibleModes.length) + " more modes hidden"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    color: Config.ThemeConfig.colors.textDim
                    elide: Text.ElideRight
                }
            }
        }

        // COLOR_CARD — HDR mode, color preset
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

                Item { Layout.fillHeight: true }
            }
        }

        // VRR_CARD
        SettingsCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            accent: Config.ThemeConfig.colors.success
            visible: Services.MonitorService.vrrCapable

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
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

                Item { Layout.fillHeight: true }
            }
        }

        // SCALE_CARD — scale stepper
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

                Item { Layout.fillHeight: true }
            }
        }
    }

    // =========================================================================
    // 4. PERSISTENCE — compact single row (stage live settings into nix source)
    // =========================================================================
    SettingsCard {
        Layout.fillWidth: true
        accent: Config.ThemeConfig.colors.secondary
        contentSpacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.ControlConfig.space3

            Text { text: "PERSISTENCE"; font.family: Config.ControlConfig.fontSans
                font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                color: Config.ThemeConfig.colors.textDim }

            Chip {
                text: Services.MonitorService.persistState === "dirty" ? "UNSTAGED CHANGES" : "IN SYNC WITH NIX"
                chipColor: Services.MonitorService.persistState === "dirty"
                    ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.success
            }

            Text {
                Layout.fillWidth: true
                text: Services.MonitorService.persistState === "dirty"
                      ? "Live settings differ from monitors.lua — a reload or reboot reverts them."
                      : "Live settings match the nix source. Staged changes land on the next omni-apply."
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
                elide: Text.ElideRight
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
    // 5. BACKLIGHT — honest "unavailable" one-liner (no DDC path chosen)
    // =========================================================================
    Rectangle {
        Layout.fillWidth: true
        height: 40
        radius: Config.ControlConfig.radiusCard
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.06)
        border.color: Config.ThemeConfig.colors.outlineVariant
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 8

            Text { text: "󰃜"; font.family: Config.ControlConfig.fontNerd; font.pixelSize: 14
                color: Config.ThemeConfig.colors.error }
            Text {
                text: "BACKLIGHT: NONE"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: Config.ThemeConfig.colors.error
            }
            Text {
                Layout.fillWidth: true
                text: "no /sys/class/backlight, no DDC/CI (ddcutil missing) — use the monitor OSD"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
                elide: Text.ElideRight
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
