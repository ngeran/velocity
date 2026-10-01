// =============================================================================
// SettingsModule.qml — SETTINGS tab (rail + fixed panes, Shibumi viewport-fit)
// =============================================================================
// Same architecture as the Control and Core tabs: the shared SideNav (icon
// chips, active dot, compact collapse) swaps one fixed pane per key. The
// dense panes (DESKTOP, IDLE) scroll internally via ScrollColumn — they
// hold more rows than the smallest viewport (480px card floor) can fit;
// unclipped they used to paint outside the settings window. Extracted from
// ModernDashboard's inline ~730-line
// Flickable block; every write path is byte-identical:
//   APPEARANCE — animation speed, corner radius   (SettingsConfigService + saveSettings)
//   BAR        — bar height, workspace dots       (SettingsConfigService + saveSettings)
//   CLOCK      — city (text input), UTC offset    (SettingsConfigService + saveSettings)
//   IDLE & LOCK— dim/lock/off timeouts, suspend   (HypridleService + saveConfig)
//   DESKTOP    — Hyprland blur/shadows/gaps/borders/opacity (HyprSettingsService)
//   + RESET TO DEFAULTS (resetToDefaults) and the "✓ APPLIED" toast (justSaved)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root

    // Style folders appear without a settings restart: rescan whenever the
    // BAR section is entered (the init-time scan only knows styles that
    // existed when the settings shell started).
    onActiveChanged: {
        if (active === "bar")
            Services.SettingsConfigService.scanBarStyles()
        // The DESKTOP pane follows Hyprland instead of trusting the store —
        // poll only while it is the pane on screen.
        Services.HyprSettingsService.watching = (active === "desktop")
    }

    property string active: "appearance"

    // Search navigation: after the pane switch, scroll the target row into
    // view (panes wrapped in ScrollColumn). Walks ancestors for the wrapper —
    // rows in unwrapped panes just no-op.
    function scrollToItem(item) {
        var p = item ? item.parent : null
        while (p) {
            if (p.revealItem !== undefined) { p.revealItem(item); return }
            p = p.parent
        }
    }

    readonly property var navItems: [
        { key: "appearance", label: "APPEARANCE", icon: "󰀯" },
        { key: "bar",        label: "BAR",        icon: "󰖬" },
        { key: "desktop",    label: "DESKTOP",    icon: "󰍹" },
        { key: "clock",      label: "CLOCK",      icon: "󰥔" },
        { key: "idle",       label: "IDLE & LOCK", icon: "󰌾" }
    ]

    // ── left rail — the SHARED SideNav (identical UX to Control / Core) ──
    SideNav {
        id: sideNav
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Config.UIScale.compact ? 56 : Config.ControlConfig.sidenavWidth
        items: root.navItems
        activeSection: root.active
        onSectionSelected: function(key) { root.active = key }
    }

    // ── content: one fixed pane per section ─────────────────────────────
    Item {
        anchors.left: sideNav.right
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Config.ControlConfig.space3

        // "✓ APPLIED" toast — pulses briefly after every save
        Rectangle {
            anchors.top: parent.top; anchors.topMargin: Config.ControlConfig.space2
            anchors.right: parent.right; anchors.rightMargin: Config.ControlConfig.space2
            width: appliedLabel.implicitWidth + 24; height: 26
            radius: Config.ControlConfig.radiusPill
            color: Config.ControlConfig.accent
            visible: Services.SettingsConfigService.justSaved
            opacity: Services.SettingsConfigService.justSaved ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Text {
                id: appliedLabel; anchors.centerIn: parent
                text: "✓ APPLIED"
                color: Config.ThemeConfig.colors.background
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                font.bold: true; font.letterSpacing: 1.0
            }
        }

        // ── Setting row: eyebrow + live value + option pills ────────────
        // `changed` + onResetRow drive the DESKTOP pane's undo marks: a dot
        // beside the value and a one-click RESET chip, only on a row this
        // window has moved away from what it found there first.
        // SELF-REGISTRATION: every row lands in SearchIndex at creation with
        // its pane key (`section`) and optional `keywords` — new rows show up
        // in search with no index to maintain. The HyprRow variants below
        // derive title/keywords from the catalog instead.
        component SettingRow: ColumnLayout {
            property string label: ""
            property string value: ""
            property bool changed: false
            property string section: ""
            property string keywords: ""
            signal resetRow()
            default property alias options: optionRow.data
            spacing: Config.ControlConfig.space1
            Layout.fillWidth: true   // span the pane; the label column is the shrinker
            Component.onCompleted: if (label !== "")
                Services.SearchIndex.register({ title: label, tab: "settings",
                    section: section, keywords: keywords, item: this })
            Component.onDestruction: Services.SearchIndex.unregister(this)
            RowLayout {
                Layout.fillWidth: true
                // ControlRow doctrine: the text column is the ONLY party that
                // shrinks — label elides before value/reset lose their place.
                Text {
                    text: label
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    font.bold: true; font.letterSpacing: 1.0
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                }
                Text { visible: changed; text: "●"; color: Config.ThemeConfig.colors.warning
                    font.pixelSize: 10 }
                Text { text: value; color: Config.ThemeConfig.colors.text
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 16; font.bold: true }
                Rectangle {
                    visible: changed
                    width: resetLbl.implicitWidth + 14; height: 20
                    radius: height / 2
                    color: resetArea.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.16) : "transparent"
                    border.color: Config.ThemeConfig.colors.error; border.width: 1
                    Text { id: resetLbl; anchors.centerIn: parent
                        text: "RESET"
                        color: Config.ThemeConfig.colors.error
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                        font.bold: true; font.letterSpacing: 0.8 }
                    MouseArea { id: resetArea; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: resetRow() }
                }
            }
            RowLayout {
                id: optionRow
                Layout.fillWidth: true
                spacing: Config.ControlConfig.space1
            }
        }

        // House-style option pill (ControlSeg idiom; picked() carries the write)
        component OptSeg: ControlSeg {
            property string pickedValue: ""
            signal picked()
            height: 26
            onChosen: picked()
        }

        // ── DESKTOP (Hyprland) row helpers ─────────────────────────────
        // One row per catalog entry; choices become pills, bools become a
        // PowerPill. Values read live from Hyprland (one batched getoption),
        // writes apply instantly through hl.config eval — "…" means the
        // readback has not landed, never a fallback number.
        component HyprRow: SettingRow {
            id: hyprRow
            property var def: null
            function fmt(v) {
                if (v === undefined) return "…"
                if (v === true) return "ON"
                if (v === false) return "OFF"
                return String(v)
            }
            label: def.label
            value: fmt(Services.HyprSettingsService.effective(def.key))
            changed: Services.HyprSettingsService.isChanged(def.key)
            onResetRow: Services.HyprSettingsService.reset(def.key)
            section: "desktop"
            keywords: (def && def.keyword ? def.keyword + " " : "") + "hyprland"
            Component.onCompleted: if (def !== null)
                Services.SearchIndex.register({ title: def.label, tab: "settings",
                    section: "desktop", keywords: keywords, item: hyprRow })
            Component.onDestruction: Services.SearchIndex.unregister(hyprRow)

            Repeater {
                model: hyprRow.def ? (hyprRow.def.choices || []) : []
                delegate: OptSeg {
                    required property var modelData
                    text: hyprRow.fmt(modelData)
                    active: Services.HyprSettingsService.effective(hyprRow.def.key) === modelData
                    onPicked: Services.HyprSettingsService.set(hyprRow.def.key, modelData)
                }
            }
        }

        component HyprToggleRow: SettingRow {
            id: hyprToggleRow
            property var def: null
            label: def.label
            value: Services.HyprSettingsService.effective(def.key) === undefined
                   ? "…" : (Services.HyprSettingsService.effective(def.key) ? "ON" : "OFF")
            changed: Services.HyprSettingsService.isChanged(def.key)
            onResetRow: Services.HyprSettingsService.reset(def.key)
            section: "desktop"
            keywords: (def && def.keyword ? def.keyword + " " : "") + "hyprland"
            Component.onCompleted: if (def !== null)
                Services.SearchIndex.register({ title: def.label, tab: "settings",
                    section: "desktop", keywords: keywords, item: hyprToggleRow })
            Component.onDestruction: Services.SearchIndex.unregister(hyprToggleRow)
            PowerPill {
                on: Services.HyprSettingsService.effective(hyprToggleRow.def.key) === true
                enabled: Services.HyprSettingsService.effective(hyprToggleRow.def.key) !== undefined
                onClicked: Services.HyprSettingsService.set(
                    hyprToggleRow.def.key,
                    Services.HyprSettingsService.effective(hyprToggleRow.def.key) !== true)
            }
        }

        component GroupHeader: Text {
            property string title: ""
            text: title
            color: Config.ThemeConfig.colors.textDim; opacity: 0.8
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
            font.bold: true; font.letterSpacing: 1.5
        }

        // ── ScrollColumn: clipped, wheel-scrollable card content ───────────
        // The DESKTOP/IDLE panes hold more rows than the smallest viewport
        // (480px card floor) can fit — unclipped, they used to PAINT OUTSIDE
        // the settings window. The indicator is a hand-rolled 3px bar (no
        // Controls import); revealItem() lets search navigation scroll the
        // target row into view.
        component ScrollColumn: Flickable {
            id: scrollCol
            default property alias content: contentCol.data
            clip: true
            contentWidth: width
            contentHeight: contentCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentCol
                width: scrollCol.width
                spacing: Config.ControlConfig.space3
            }

            Rectangle {
                visible: scrollCol.contentHeight > scrollCol.height + 1
                anchors.right: parent.right
                anchors.rightMargin: 2
                width: 3
                radius: 1.5
                color: Config.ThemeConfig.colors.outlineVariant
                opacity: 0.9
                y: {
                    var track = scrollCol.height - height - 4
                    var frac = scrollCol.contentY / Math.max(1, scrollCol.contentHeight - scrollCol.height)
                    return 2 + Math.max(0, Math.min(track, frac * track))
                }
                height: Math.max(24, scrollCol.height * (scrollCol.height / Math.max(1, scrollCol.contentHeight)) - 4)
            }

            function revealItem(item) {
                if (!item) return
                var y = item.mapToItem(contentCol, 0, 0).y
                contentY = Math.max(0, Math.min(contentHeight - height, y - height / 2 + item.height / 2))
            }
        }

        // ── APPEARANCE ─────────────────────────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.ControlConfig.space4
            visible: root.active === "appearance"
            spacing: Config.ControlConfig.space4

            SettingsHeaderCard { Layout.fillWidth: true; eyebrow: "SETTINGS"; title: "Appearance"
                subtitle: "Animation cadence and corner rounding" }

            CoreCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                accent: Config.ControlConfig.accent
                ColumnLayout {
                    Layout.fillWidth: true; spacing: Config.ControlConfig.space4
                    SettingRow {
                        label: "ANIMATION SPEED"
                        section: "appearance"
                        keywords: "motion cadence speed"
                        value: Services.SettingsConfigService.animationSpeed.toUpperCase()
                        OptSeg { text: "FAST"; pickedValue: "fast"
                            active: Services.SettingsConfigService.animationSpeed === "fast"
                            onPicked: { Services.SettingsConfigService.animationSpeed = "fast"; Services.SettingsConfigService.saveSettings() } }
                        OptSeg { text: "NORMAL"; pickedValue: "normal"
                            active: Services.SettingsConfigService.animationSpeed === "normal"
                            onPicked: { Services.SettingsConfigService.animationSpeed = "normal"; Services.SettingsConfigService.saveSettings() } }
                        OptSeg { text: "SLOW"; pickedValue: "slow"
                            active: Services.SettingsConfigService.animationSpeed === "slow"
                            onPicked: { Services.SettingsConfigService.animationSpeed = "slow"; Services.SettingsConfigService.saveSettings() } }
                    }
                    SettingRow {
                        label: "CORNER RADIUS"
                        section: "appearance"
                        keywords: "rounding corners"
                        value: Services.SettingsConfigService.cornerRadius + "px"
                        Repeater {
                            model: [0, 4, 8, 12]
                            delegate: OptSeg {
                                text: modelData + "px"
                                radius: modelData          // preview the actual radius
                                active: Services.SettingsConfigService.cornerRadius === modelData
                                onPicked: { Services.SettingsConfigService.cornerRadius = modelData; Services.SettingsConfigService.saveSettings() }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    // Keyboard navigation note (kept from the old banner)
                    Text { Layout.fillWidth: true
                        text: "Tab to navigate · Space/Enter to activate · Escape to close"
                        color: Config.ThemeConfig.colors.textDim; opacity: 0.7
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10 }
                }
            }
        }

        // ── BAR ────────────────────────────────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.ControlConfig.space4
            visible: root.active === "bar"
            spacing: Config.ControlConfig.space4

            SettingsHeaderCard { Layout.fillWidth: true; eyebrow: "SETTINGS"; title: "Bar"
                subtitle: "Bar style, top-bar height and workspace dots" }

            CoreCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                accent: Config.ControlConfig.accent
                ColumnLayout {
                    Layout.fillWidth: true; spacing: Config.ControlConfig.space4
                    SettingRow {
                        label: "BAR STYLE"
                        section: "bar"
                        keywords: "theme vector look"
                        value: Services.SettingsConfigService.barStyle.toUpperCase()
                        Repeater {
                            model: Services.SettingsConfigService.barStyles
                            delegate: OptSeg {
                                text: modelData.toUpperCase()
                                active: Services.SettingsConfigService.barStyle === modelData
                                onPicked: {
                                    Services.SettingsConfigService.barStyle = modelData
                                    Services.SettingsConfigService.saveSettings()
                                    Services.SettingsConfigService.scanBarStyles()
                                }
                            }
                        }
                    }
                    SettingRow {
                        label: "BAR HEIGHT"
                        section: "bar"
                        value: Services.SettingsConfigService.barHeight + "px"
                        Repeater {
                            model: [20, 26, 32, 40]
                            delegate: OptSeg {
                                text: modelData + "px"
                                active: Services.SettingsConfigService.barHeight === modelData
                                onPicked: { Services.SettingsConfigService.barHeight = modelData; Services.SettingsConfigService.saveSettings() }
                            }
                        }
                    }
                    SettingRow {
                        label: "WORKSPACE DOTS"
                        section: "bar"
                        value: Services.SettingsConfigService.workspaceCount + " dots"
                        Repeater {
                            model: [3, 5, 7, 9]
                            delegate: OptSeg {
                                text: modelData
                                active: Services.SettingsConfigService.workspaceCount === modelData
                                onPicked: { Services.SettingsConfigService.workspaceCount = modelData; Services.SettingsConfigService.saveSettings() }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ── DESKTOP (Hyprland) ─────────────────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.ControlConfig.space4
            visible: root.active === "desktop"
            spacing: Config.ControlConfig.space4

            SettingsHeaderCard { Layout.fillWidth: true; eyebrow: "SETTINGS"; title: "Desktop"
                subtitle: "Hyprland blur, shadows, gaps, borders, rounding, opacity — applied live" }

            CoreCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                accent: Config.ControlConfig.accent
                ScrollColumn {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GroupHeader { title: "EFFECTS" }
                    HyprToggleRow { def: Services.HyprSettingsService.def("blur") }
                    HyprRow { def: Services.HyprSettingsService.def("blurSize") }
                    HyprRow { def: Services.HyprSettingsService.def("blurPasses") }
                    HyprToggleRow { def: Services.HyprSettingsService.def("blurPopups") }
                    HyprToggleRow { def: Services.HyprSettingsService.def("shadows") }

                    GroupHeader { title: "WINDOWS" }
                    HyprRow { def: Services.HyprSettingsService.def("gapsIn") }
                    HyprRow { def: Services.HyprSettingsService.def("gapsOut") }
                    HyprRow { def: Services.HyprSettingsService.def("borderSize") }
                    HyprRow { def: Services.HyprSettingsService.def("rounding") }
                    HyprRow { def: Services.HyprSettingsService.def("activeOpacity") }
                    HyprRow { def: Services.HyprSettingsService.def("inactiveOpacity") }

                    // Error footer — apply refusals surface verbatim.
                    Text {
                        Layout.fillWidth: true
                        visible: Services.HyprSettingsService.lastError !== ""
                        text: Services.HyprSettingsService.lastError
                        color: Config.ThemeConfig.colors.error; wrapMode: Text.Wrap
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    }

                    // Changed footer — count + the one destructive escape hatch.
                    RowLayout {
                        Layout.fillWidth: true
                        visible: Services.HyprSettingsService.loaded
                        Text {
                            visible: Services.HyprSettingsService.changedCount > 0
                            text: Services.HyprSettingsService.changedCount + " CHANGED"
                            color: Config.ThemeConfig.colors.warning
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                            font.bold: true; font.letterSpacing: 0.8
                        }
                        Item { Layout.fillWidth: true }
                        ConfirmDialog {
                            visible: Services.HyprSettingsService.changedCount > 0
                            label: "RESET ALL"
                            confirmLabel: "CONFIRM?"
                            onConfirmed: Services.HyprSettingsService.resetAll()
                        }
                    }

                    Text { Layout.fillWidth: true
                        text: "Applied live to Hyprland · kept in ~/.config/hypr/velocity-settings.lua · your own config answers again on reset"
                        color: Config.ThemeConfig.colors.textDim; opacity: 0.7
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10 }
                }
            }
        }

        // ── CLOCK ──────────────────────────────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.ControlConfig.space4
            visible: root.active === "clock"
            spacing: Config.ControlConfig.space4

            SettingsHeaderCard { Layout.fillWidth: true; eyebrow: "SETTINGS"; title: "Clock"
                subtitle: "Bar clock city label and UTC offset" }

            CoreCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                accent: Config.ControlConfig.accent
                ColumnLayout {
                    Layout.fillWidth: true; spacing: Config.ControlConfig.space4

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: Config.ControlConfig.space1
                        Text { text: "CITY"; color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                            font.bold: true; font.letterSpacing: 1.0 }
                        Rectangle {
                            id: cityCard
                            Layout.fillWidth: true; Layout.preferredWidth: 220
                            Layout.preferredHeight: 32
                            radius: Config.ControlConfig.radiusPill
                            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                            border.color: cityInput.activeFocus ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 100 } }
                            Component.onCompleted: Services.SearchIndex.register({
                                title: "CITY", tab: "settings", section: "clock",
                                keywords: "city clock label text", item: cityCard })
                            Component.onDestruction: Services.SearchIndex.unregister(cityCard)
                            TextInput {
                                id: cityInput
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                text: Services.SettingsConfigService.clockCity
                                color: Config.ThemeConfig.colors.text
                                font.family: Config.SettingsConfig.fontFamily
                                font.pixelSize: 14
                                selectByMouse: true
                                onAccepted: {
                                    Services.SettingsConfigService.clockCity = text
                                    Services.SettingsConfigService.saveSettings()
                                }
                                onFocusChanged: {
                                    if (!focus) {
                                        Services.SettingsConfigService.clockCity = text
                                        Services.SettingsConfigService.saveSettings()
                                    }
                                }
                            }
                        }
                    }

                    SettingRow {
                        label: "TIMEZONE"
                        section: "clock"
                        keywords: "utc offset"
                        value: Services.SettingsConfigService.clockOffset === 0 ? "LOCAL"
                             : "UTC" + (Services.SettingsConfigService.clockOffset >= 0 ? "+" : "")
                               + Services.SettingsConfigService.clockOffset
                        Repeater {
                            model: [-12, -8, -5, -4, 0, 1, 2, 3, 8, 10, 12]
                            delegate: OptSeg {
                                text: modelData === 0 ? "LOCAL" : (modelData > 0 ? "+" + modelData : "" + modelData)
                                active: Services.SettingsConfigService.clockOffset === modelData
                                onPicked: { Services.SettingsConfigService.clockOffset = modelData; Services.SettingsConfigService.saveSettings() }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ── IDLE & LOCK ────────────────────────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.ControlConfig.space4
            visible: root.active === "idle"
            spacing: Config.ControlConfig.space4

            SettingsHeaderCard { Layout.fillWidth: true; eyebrow: "SETTINGS"; title: "Idle & Lock"
                subtitle: "Hypridle timeouts — applied to hypridle.conf on save" }

            CoreCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                accent: Config.ThemeConfig.colors.warning
                ScrollColumn {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    SettingRow {
                        label: "DIM AFTER"
                        section: "idle"
                        value: Math.round(Services.HypridleService.dimTimeout / 60) + " min"
                        Repeater {
                            model: [1, 2, 3, 5, 10]
                            delegate: OptSeg {
                                text: modelData + "m"
                                active: Services.HypridleService.dimTimeout === modelData * 60
                                onPicked: { Services.HypridleService.dimTimeout = modelData * 60; Services.HypridleService.saveConfig() }
                            }
                        }
                    }
                    SettingRow {
                        label: "LOCK AFTER"
                        section: "idle"
                        keywords: "hyprlock"
                        value: Math.round(Services.HypridleService.lockTimeout / 60) + " min"
                        Repeater {
                            model: [2, 5, 10, 15, 30]
                            delegate: OptSeg {
                                text: modelData + "m"
                                active: Services.HypridleService.lockTimeout === modelData * 60
                                onPicked: { Services.HypridleService.lockTimeout = modelData * 60; Services.HypridleService.saveConfig() }
                            }
                        }
                    }
                    SettingRow {
                        label: "DISPLAY OFF"
                        section: "idle"
                        keywords: "screen off dpms"
                        value: Math.round(Services.HypridleService.displayOffTimeout / 60) + " min"
                        Repeater {
                            model: [5, 10, 15, 20, 30]
                            delegate: OptSeg {
                                text: modelData + "m"
                                active: Services.HypridleService.displayOffTimeout === modelData * 60
                                onPicked: { Services.HypridleService.displayOffTimeout = modelData * 60; Services.HypridleService.saveConfig() }
                            }
                        }
                    }
                    SettingRow {
                        label: "SUSPEND"
                        section: "idle"
                        keywords: "sleep memory"
                        value: Services.HypridleService.suspendEnabled
                               ? (Services.HypridleService.suspendTimeout / 60) + " min" : "OFF"
                        PowerPill {
                            on: Services.HypridleService.suspendEnabled
                            onClicked: {
                                Services.HypridleService.suspendEnabled = !Services.HypridleService.suspendEnabled
                                Services.HypridleService.saveConfig()
                            }
                        }
                    }
                    SettingRow {
                        visible: Services.HypridleService.suspendEnabled
                        label: "SUSPEND AFTER"
                        section: "idle"
                        Repeater {
                            model: [15, 30, 45, 60]
                            delegate: OptSeg {
                                text: modelData + "m"
                                active: Services.HypridleService.suspendTimeout === modelData * 60
                                onPicked: { Services.HypridleService.suspendTimeout = modelData * 60; Services.HypridleService.saveConfig() }
                            }
                        }
                    }

                    // Reset — one-click escape hatch
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: resetLbl.implicitWidth + 20; height: 26
                            radius: Config.ControlConfig.radiusPill
                            color: resetMA.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.16)
                                   : "transparent"
                            border.color: Config.ThemeConfig.colors.error; border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { id: resetLbl; anchors.centerIn: parent
                                text: "RESET TO DEFAULTS"
                                color: Config.ThemeConfig.colors.error
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                                font.bold: true; font.letterSpacing: 0.8 }
                            MouseArea { id: resetMA; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Services.SettingsConfigService.resetToDefaults() }
                        }
                    }
                }
            }
        }
    }
}
