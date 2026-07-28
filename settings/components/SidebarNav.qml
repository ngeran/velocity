// =============================================================================
// settings/components/SidebarNav.qml
// Vertical Sidebar Navigation — Dashboard | Themes | Wallpapers | Control | Core | Settings
//
// PURPOSE:
//   Drop-in replacement for TopNavBar with the same public API (currentIndex,
//   tabSelected(index), tabModel), but laid out as a fixed-width (64px) left
//   sidebar per the SETTINGS_UI_MAP.md mockup, instead of a horizontal bar.
//
// PUBLIC API (unchanged from TopNavBar):
//   property int currentIndex
//   signal tabSelected(int index)
//   readonly property var tabModel
//
// OLED / NO-FILLED-HIGHLIGHT POLICY:
//   Unlike TopNavBar (which fills the active tab background with
//   colors.primary), the active indicator here is a 2px left border + icon/
//   label tint only — no filled background at any state. Matches DashboardCard's
//   existing treatment (border + thin accent line, never a solid fill).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: sidebarRoot

    // =========================================================================
    // PUBLIC API
    // =========================================================================
    property int currentIndex: 0
    signal tabSelected(int index)

    readonly property var tabModel: [
        { key: "dashboard",  label: "DASHBOARD",   icon: "⊞" },   // index 0
        { key: "themes",     label: "THEMES",      icon: "◑" },   // index 1
        { key: "wallpapers", label: "WALLPAPERS",  icon: "⬚" },   // index 2
        { key: "control",    label: "CONTROL",     icon: "⋮" },   // index 3
        { key: "core",       label: "CORE",        icon: "▦" },   // index 4  (plain Unicode — renders under Inter; was a Nerd Font PUA glyph that showed as a box)
        { key: "settings",   label: "SETTINGS",    icon: "⚙" }    // index 5
    ]

    // =========================================================================
    // VISUALS
    // =========================================================================
    width: 64
    color: Config.ThemeConfig.colors.background
    radius: 0

    // Right border separates sidebar from content area (was bottom border on
    // TopNavBar).
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        color: Config.ThemeConfig.colors.border
    }

    // =========================================================================
    // LAYOUT — logo mark (top) → nav icons (stacked) → spacer
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 4

        // --- Logo mark --------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            Rectangle {
                anchors.centerIn: parent
                width: 8; height: 8
                color: Config.ThemeConfig.colors.secondary
                radius: 0
                // Subtle glow instead of a filled panel — a single small dot.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    color: "transparent"
                    border.color: Config.ThemeConfig.colors.secondary
                    border.width: 1
                    opacity: 0.35
                }
            }
        }

        // --- Divider ------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 8
            Layout.bottomMargin: 12
            color: Config.ThemeConfig.colors.border
        }

        // --- NAV ITEMS ----------------------------------------------------------
        Repeater {
            model: sidebarRoot.tabModel

            delegate: Item {
                id: navItem
                Layout.fillWidth: true
                Layout.preferredHeight: 56

                readonly property int  tabIndex: index
                readonly property bool isActive: sidebarRoot.currentIndex === tabIndex

                // Left accent border — the ONLY "active" indicator. No fill.
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 2
                    color: navItem.isActive ? Config.ThemeConfig.colors.secondary : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        font.pixelSize: 18
                        font.family: Config.SettingsConfig.fontFamily
                        color: navItem.isActive
                               ? Config.ThemeConfig.colors.secondary
                               : hoverArea.containsMouse
                                 ? Config.ThemeConfig.colors.text
                                 : Config.ThemeConfig.colors.textDim
                        Behavior on color {
                            ColorAnimation { duration: 120; easing.type: Easing.OutQuad }
                        }
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
                        Behavior on color {
                            ColorAnimation { duration: 120; easing.type: Easing.OutQuad }
                        }
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sidebarRoot.tabSelected(navItem.tabIndex)
                }
            }
        }

        Item { Layout.fillHeight: true }   // push everything up
    }
}
