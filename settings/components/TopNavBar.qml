// =============================================================================
// settings/components/TopNavBar.qml
// Navigation Bar — Dashboard | Themes | Wallpapers | Settings
//
// PURPOSE:
//   4-item horizontal nav bar matching the bento grid header. Active tab
//   gets white background / black text. Inactive tabs are muted with hover
//   state. Right end has a search icon box. Emits tabSelected(index) on click.
//
// PUBLIC API:
//   property int currentIndex       — driven from parent (ModernDashboard)
//   signal tabSelected(int index)   — emitted on tab click
//
// TAB MODEL (order is index-significant — must match ModernDashboard.qml):
//   index 0 → Dashboard   (grid icon  "⊞")
//   index 1 → Themes      (palette    "◑")
//   index 2 → Wallpapers  (image      "⬚")
//   index 3 → Control     (menu       "⋮")
//   index 4 → Settings    (gear       "⚙")
//
// HTML REFERENCE:
//   .nav-item.active { background: #ffffff; color: #000000 }
//   .nav-item:hover  { background: #111111; color: #ffffff }
//   .nav-item        { color: #888888; font-size: 11px; font-weight: 700;
//                      text-transform: uppercase; letter-spacing: 0.1em;
//                      border-right: 1px solid #262626 }
//   right-end: search icon in bordered box
//
// CONSTRAINTS:
//   radius: 0 everywhere
//   font.family: Config.SettingsConfig.fontFamily on all Text
//   ColorAnimation { duration: 100 } on background transitions
//   Config.ThemeConfig.colors.* for all colors
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: navRoot

    // =========================================================================
    // PUBLIC API
    // =========================================================================
    property int currentIndex: 0
    signal tabSelected(int index)

    // =========================================================================
    // VISUALS
    // =========================================================================
    color:        Config.ThemeConfig.colors.background
    radius:       0
    // Bottom border separates nav from content area
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color:  Config.ThemeConfig.colors.border
    }

    // =========================================================================
    // TAB MODEL
    // Labels and unicode icon glyphs. Replace glyphs with font icons if a
    // Material Symbols or Nerd Font is loaded (set font.family accordingly).
    // Index order MUST match the tab content mapping in ModernDashboard.qml.
    // =========================================================================
    readonly property var tabModel: [
        { key: "dashboard",  label: "DASHBOARD",   icon: "⊞" },   // index 0
        { key: "themes",     label: "THEMES",      icon: "◑" },   // index 1
        { key: "wallpapers", label: "WALLPAPERS",  icon: "⬚" },   // index 2
        { key: "control",    label: "CONTROL",     icon: "⋮" },   // index 3 — Control module
        { key: "settings",   label: "SETTINGS",    icon: "⚙" }    // index 4 — Settings
    ]

    // =========================================================================
    // LAYOUT — tabs left, search icon right
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        spacing:      0

        // --- TAB ITEMS -------------------------------------------------------
        Repeater {
            model: navRoot.tabModel

            // Each tab is a Rectangle (for background color animation) wrapping
            // an icon + label row. A 1px right-border Rectangle sits on top.
            delegate: Item {
                id: tabItem

                readonly property int   tabIndex: index
                readonly property bool  isActive: navRoot.currentIndex === tabIndex

                Layout.fillHeight: true
                // Minimum width from content; all tabs equal via fillWidth
                Layout.fillWidth:  true
                Layout.maximumWidth: 160   // Cap so search box isn't squeezed

                // Background — animated between states
                Rectangle {
                    id: tabBg
                    anchors.fill: parent
                    radius: 0

                    color: tabItem.isActive
                           ? Config.ThemeConfig.colors.primary       // white when active
                           : hoverArea.containsMouse
                             ? Config.ThemeConfig.colors.surfaceVariant  // #111 on hover
                             : "transparent"

                    // 100ms transition — matches HTML `transition: all 0.1s`
                    Behavior on color {
                        ColorAnimation { duration: 100; easing.type: Easing.OutQuad }
                    }
                }

                // Right-border separator between tabs
                Rectangle {
                    anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                    width: 1
                    color: Config.ThemeConfig.colors.border
                }

                // Icon + label row — centered in the tab
                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    // Icon glyph
                    Text {
                        text:           modelData.icon
                        font.pixelSize: 13
                        font.family: Config.SettingsConfig.fontFamily
                        color:          tabItem.isActive
                                        ? Config.ThemeConfig.colors.background  // black on white
                                        : hoverArea.containsMouse
                                          ? Config.ThemeConfig.colors.primary
                                          : Config.ThemeConfig.colors.textDim

                        Behavior on color {
                            ColorAnimation { duration: 100; easing.type: Easing.OutQuad }
                        }
                    }

                    // Label text
                    Text {
                        text:               modelData.label
                        font.pixelSize:     11
                        font.bold:          true
                        font.family: Config.SettingsConfig.fontFamily
                        font.letterSpacing: 1.2

                        color: tabItem.isActive
                               ? Config.ThemeConfig.colors.background   // black on white active
                               : hoverArea.containsMouse
                                 ? Config.ThemeConfig.colors.primary
                                 : Config.ThemeConfig.colors.textDim    // muted inactive

                        Behavior on color {
                            ColorAnimation { duration: 100; easing.type: Easing.OutQuad }
                        }
                    }
                }

                // Click + hover detection
                MouseArea {
                    id: hoverArea
                    anchors.fill:  parent
                    hoverEnabled:  true
                    cursorShape:   Qt.PointingHandCursor

                    onClicked: navRoot.tabSelected(tabItem.tabIndex)
                }
            }
        }

        // Push tabs to the left (no right-end search box anymore).
        Item { Layout.fillWidth: true }
    }
}
