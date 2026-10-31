// =============================================================================
// settings/components/SidebarNav.qml — the dashboard's left rail (HUD chrome)
// =============================================================================
// TWO modes (mock: 256px labeled sidebar; compact fallback is the legacy
// 64px icon rail, unchanged):
//
//   labeled  (≥ 1440 logical): logo block · labeled nav items · CORE renders
//            a nested submenu (TELEMETRY + LCD / MYSTIQUE AIO / EVENTS —
//            Config.ControlConfig.coreSections, keys are contract) · search
//            chip · SESSION card.
//   compact: today's icon rail verbatim — submenu hidden, CORE click lands on
//            "system" (CoreEngineTab's compact rail handles section switching).
//
// TAB MODEL IS CONTRACT: tabModel keys/order/indices drive the index-signficant
// Loaders in SettingsWindowShell — never reorder here.
//
// PUBLIC API:
//   property int currentIndex
//   signal tabSelected(int index)
//   signal searchRequested()
//   property string coreSection        // live mirror of the Core pane
//   signal coreSectionSelected(string key)
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: sidebarRoot

    // =========================================================================
    // PUBLIC API
    // =========================================================================
    property int currentIndex: 0
    signal tabSelected(int index)
    signal searchRequested()
    property string coreSection: "system"
    signal coreSectionSelected(string key)

    readonly property var tabModel: [
        { key: "dashboard",  label: "SYS INFO",    icon: "⊞" },   // index 0
        { key: "themes",     label: "THEMES",      icon: "◑" },   // index 1
        { key: "wallpapers", label: "WALLPAPERS",  icon: "⬚" },   // index 2
        { key: "control",    label: "CONTROL",     icon: "⋮" },   // index 3
        { key: "core",       label: "CORE",        icon: "▦" },   // index 4  (plain Unicode — renders under Inter; was a Nerd Font PUA glyph that showed as a box)
        { key: "logs",       label: "LOGS",        icon: "≡" },   // index 5  (in-app journal tab)
        { key: "settings",   label: "SETTINGS",    icon: "⚙" }    // index 6
    ]

    readonly property bool compact: Config.UIScale.compact
    readonly property var metrics: Services.HostBridge.metrics
    readonly property bool lcdOnline: !!metrics && metrics.lcdPresent

    width: compact ? 64 : 232
    // Transparent — the shell's HUD card (pure black) shows beneath; painting
    // this column opaque would square off the window's left corners.
    color: "transparent"
    radius: 0

    // Right border separates sidebar from content area.
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        color: sidebarRoot.compact ? Config.ThemeConfig.colors.border
                                   : Config.HudConfig.borderHi
    }

    // =========================================================================
    // LAYOUT — logo block → nav (+ CORE submenu) → spacer → search → session
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 4

        // --- Logo block (mock: amber diamond in a bordered box + title) ------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: sidebarRoot.compact ? 40 : 44

            RowLayout {
                anchors.centerIn: parent
                spacing: 10

                Rectangle {
                    width: 28; height: 28; radius: 4
                    color: Config.HudConfig.well
                    border.color: Config.ThemeConfig.tint(Config.HudConfig.amber, 0.70)
                    border.width: 1
                    // soft amber halo (mock shadow-[0_0_10px_rgba(255,122,0,.3)])
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 10; height: parent.height + 10
                        radius: 8
                        color: Config.ThemeConfig.tint(Config.HudConfig.amber, 0.10)
                        z: -1
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 12
                        rotation: 45
                        color: Config.HudConfig.amber
                    }
                }

                ColumnLayout {
                    visible: !sidebarRoot.compact
                    spacing: 1
                    Text {
                        text: "NIXOS CONTROL"
                        color: Config.HudConfig.textHi
                        font.family: Config.HudConfig.fontData
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.6
                    }
                    Text {
                        text: "REV " + (sidebarRoot.metrics && sidebarRoot.metrics.osVersion !== ""
                                        ? sidebarRoot.metrics.osVersion : "HUD") + " · HUD"
                        color: Config.HudConfig.textFaint
                        font.family: Config.HudConfig.fontData
                        font.pixelSize: 8
                        font.letterSpacing: 1.0
                    }
                }
            }
        }

        // --- Divider ----------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 8
            Layout.bottomMargin: 12
            color: sidebarRoot.compact ? Config.ThemeConfig.colors.border
                                       : Config.HudConfig.borderHi
        }

        // --- NAV ITEMS + CORE submenu ----------------------------------------
        Repeater {
            model: sidebarRoot.tabModel

            delegate: ColumnLayout {
                id: navItem
                Layout.fillWidth: true
                spacing: 0

                readonly property int  tabIndex: index
                readonly property bool isActive: sidebarRoot.currentIndex === tabIndex
                readonly property bool isCore: modelData.key === "core"

                // ---- the item itself ----
                Item {
                    Layout.fillWidth: true
                    height: sidebarRoot.compact ? 56 : 34

                    // Left accent border — top-level active indicator.
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 2
                        color: navItem.isActive ? Config.HudConfig.amber : "transparent"
                        Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    }

                    // compact: icon-over-label (legacy, unchanged)
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        visible: sidebarRoot.compact

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            font.pixelSize: 18
                            font.family: Config.SettingsConfig.fontFamily
                            color: navItem.isActive
                                   ? Config.ThemeConfig.colors.secondary
                                   : navHover.containsMouse
                                     ? Config.ThemeConfig.colors.text
                                     : Config.ThemeConfig.colors.textDim
                            Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutQuad } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            font.pixelSize: 6
                            font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 0.5
                            color: navItem.isActive
                                   ? Config.ThemeConfig.colors.secondary
                                   : Config.ThemeConfig.colors.textDim
                            Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutQuad } }
                        }
                    }

                    // labeled: icon · label · (CORE: glow dot)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 10
                        visible: !sidebarRoot.compact

                        Text {
                            text: modelData.icon
                            font.pixelSize: 13
                            font.family: Config.SettingsConfig.fontFamily
                            color: navItem.isActive ? Config.HudConfig.amber
                                  : navHover.containsMouse ? Config.HudConfig.textBody
                                  : Config.HudConfig.textMid
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            font.family: Config.HudConfig.fontData
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.4
                            color: navItem.isActive ? Config.HudConfig.textHi
                                  : navHover.containsMouse ? Config.HudConfig.textBody
                                  : Config.HudConfig.textMid
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        // CORE group marker: amber glow dot when the tab is open
                        Rectangle {
                            visible: navItem.isCore && navItem.isActive
                            width: 6; height: 6; radius: 3
                            color: Config.HudConfig.amber
                            Rectangle {
                                anchors.centerIn: parent
                                width: 12; height: 12; radius: 6
                                color: Config.ThemeConfig.tint(Config.HudConfig.amber, 0.25)
                                z: -1
                            }
                        }
                    }

                    MouseArea {
                        id: navHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sidebarRoot.tabSelected(navItem.tabIndex)
                    }
                }

                // ---- CORE submenu (labeled only) ----
                Repeater {
                    model: (!sidebarRoot.compact && navItem.isCore)
                           ? Config.ControlConfig.coreSections : []

                    delegate: Item {
                        id: subItem
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.preferredHeight: 28

                        readonly property string subKey: modelData.key
                        readonly property bool subActive: sidebarRoot.coreSection === subKey
                        // MYSTIQUE AIO row pulses its dot while the daemon feeds
                        readonly property bool isLcd: subKey === "lcd"

                        // connector line (mock's border-l rail)
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            anchors.leftMargin: -16
                            width: 1
                            color: Config.HudConfig.borderHi
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 3
                            color: subItem.subActive
                                   ? Config.ThemeConfig.tint(Config.HudConfig.amber, 0.12) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 8

                            Rectangle {
                                width: subItem.subActive ? 6 : 4
                                height: subItem.subActive ? 6 : 4
                                radius: subItem.subActive ? 3 : 2
                                color: subItem.subActive ? Config.HudConfig.amber
                                      : (subItem.isLcd && sidebarRoot.lcdOnline) ? Config.HudConfig.cyan
                                      : Config.HudConfig.textFaint
                                // pulse while the LCD daemon is live
                                SequentialAnimation on opacity {
                                    running: subItem.isLcd && sidebarRoot.lcdOnline
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 0.3; duration: 1200 }
                                    NumberAnimation { from: 0.3; to: 1.0; duration: 1200 }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                font.family: Config.HudConfig.fontData
                                font.pixelSize: 9
                                font.bold: subItem.subActive
                                font.letterSpacing: 1.0
                                color: subItem.subActive ? Config.HudConfig.amber
                                      : subHover.containsMouse ? Config.HudConfig.textBody
                                      : Config.HudConfig.textMid
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            // right tag: ACTIVE / 2.8" TFT · OFFLINE / blank
                            Text {
                                visible: subItem.subActive || (subItem.isLcd && sidebarRoot.lcdOnline)
                                text: subItem.subActive ? "ACTIVE"
                                      : subItem.isLcd ? "2.8\" TFT" : ""
                                font.family: Config.HudConfig.fontData
                                font.pixelSize: 7
                                font.bold: true
                                font.letterSpacing: 0.8
                                color: subItem.subActive ? Config.ThemeConfig.tint(Config.HudConfig.amber, 0.25)
                                      : Config.ThemeConfig.tint(Config.HudConfig.cyan, 0.30)
                            }
                        }

                        MouseArea {
                            id: subHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sidebarRoot.coreSectionSelected(subItem.subKey)
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }   // push everything up

        // --- SEARCH — labeled: full-width chip; compact: legacy 40px icon -----
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 44

            // compact legacy chip
            Rectangle {
                id: searchChip
                anchors.centerIn: parent
                visible: sidebarRoot.compact
                width: 40; height: 40
                radius: Config.ControlConfig.radiusSmall
                color: searchArea.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.12)
                                                : "transparent"
                border.color: searchArea.containsMouse ? Config.ThemeConfig.colors.secondary
                                                       : Config.ThemeConfig.colors.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "󰍉"
                    font.family: Config.ControlConfig.fontNerd
                    font.pixelSize: 16
                    color: searchArea.containsMouse ? Config.ThemeConfig.colors.secondary
                                                    : Config.ThemeConfig.colors.textDim
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            // labeled full-width chip (mock: search button + bordered well)
            Rectangle {
                anchors { left: parent.left; right: parent.right }
                visible: !sidebarRoot.compact
                height: 34
                radius: 4
                color: Config.HudConfig.wellDeep
                border.color: searchArea.containsMouse
                              ? Config.ThemeConfig.tint(Config.HudConfig.amber, 0.45)
                              : Config.HudConfig.borderHi
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8
                    Text {
                        text: "󰍉"
                        font.family: Config.ControlConfig.fontNerd
                        font.pixelSize: 13
                        color: searchArea.containsMouse ? Config.HudConfig.amber
                                                        : Config.HudConfig.textDim
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        text: "SEARCH"
                        font.family: Config.HudConfig.fontData
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: Config.HudConfig.textFaint
                    }
                }
            }

            MouseArea {
                id: searchArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sidebarRoot.searchRequested()
            }
        }

        // --- SESSION card (labeled; moved from the Core tab footer) ----------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            visible: !sidebarRoot.compact
            radius: 4
            color: Config.HudConfig.wellDeep
            border.color: Config.HudConfig.borderHi
            border.width: 1
            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3
                Text {
                    text: "SESSION"
                    color: Config.HudConfig.textFaint
                    font.family: Config.HudConfig.fontData
                    font.pixelSize: 7
                    font.bold: true
                    font.letterSpacing: 1.2
                }
                Text {
                    text: (sidebarRoot.metrics ? sidebarRoot.metrics.userName : "").toUpperCase()
                    color: Config.HudConfig.textHi
                    font.family: Config.HudConfig.fontData
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: (sidebarRoot.metrics ? sidebarRoot.metrics.hostname : "").toUpperCase()
                    color: Config.HudConfig.amber
                    font.family: Config.HudConfig.fontData
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }
    }
}
