// =============================================================================
// SettingsModule.qml — SETTINGS tab (rail + fixed panes, Shibumi viewport-fit)
// =============================================================================
// Same architecture as the Control and Core tabs: the shared SideNav (icon
// chips, active dot, compact collapse) swaps one fixed pane per key — no
// scrolling (§6.1). Extracted from ModernDashboard's inline ~730-line
// Flickable block; every write path is byte-identical:
//   APPEARANCE — animation speed, corner radius   (SettingsConfigService + saveSettings)
//   BAR        — bar height, workspace dots       (SettingsConfigService + saveSettings)
//   CLOCK      — city (text input), UTC offset    (SettingsConfigService + saveSettings)
//   IDLE & LOCK— dim/lock/off timeouts, suspend   (HypridleService + saveConfig)
//   + RESET TO DEFAULTS (resetToDefaults) and the "✓ APPLIED" toast (justSaved)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root

    property string active: "appearance"

    readonly property var navItems: [
        { key: "appearance", label: "APPEARANCE", icon: "󰀯" },
        { key: "bar",        label: "BAR",        icon: "󰖬" },
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
        component SettingRow: ColumnLayout {
            property string label: ""
            property string value: ""
            default property alias options: optionRow.data
            spacing: Config.ControlConfig.space1
            RowLayout {
                Layout.fillWidth: true
                Text { text: label; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    font.bold: true; font.letterSpacing: 1.0 }
                Item { Layout.fillWidth: true }
                Text { text: value; color: Config.ThemeConfig.colors.text
                    font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 16; font.bold: true }
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
                subtitle: "Top-bar height and workspace dots" }

            CoreCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                accent: Config.ControlConfig.accent
                ColumnLayout {
                    Layout.fillWidth: true; spacing: Config.ControlConfig.space4
                    SettingRow {
                        label: "BAR HEIGHT"
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
                            Layout.fillWidth: true; Layout.preferredWidth: 220
                            Layout.preferredHeight: 32
                            radius: Config.ControlConfig.radiusPill
                            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                            border.color: cityInput.activeFocus ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 100 } }
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
                ColumnLayout {
                    Layout.fillWidth: true; spacing: Config.ControlConfig.space3

                    SettingRow {
                        label: "DIM AFTER"
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
                        Repeater {
                            model: [15, 30, 45, 60]
                            delegate: OptSeg {
                                text: modelData + "m"
                                active: Services.HypridleService.suspendTimeout === modelData * 60
                                onPicked: { Services.HypridleService.suspendTimeout = modelData * 60; Services.HypridleService.saveConfig() }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }

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
