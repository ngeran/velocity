// =============================================================================
// CoreEngineTab.qml — "Core Engine" tab (tab 4): side-nav + content swap.
// =============================================================================
// Left side-nav (Overview / Processors / Memory & Env / LCD Control) swaps
// the right-hand pane by key — each section is its OWN page,
// not a scroll-within-one-column (mirrors the Control tab's nav pattern).
// Colours are theme tokens (primary/secondary/warning); fonts are the shell's
// (Inter display + JetBrains Mono). Section cards size to content (CoreCard).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root

    property string active: "overview"

    readonly property var navItems: [
        { key: "overview",      label: "OVERVIEW" },
        { key: "processors",    label: "PROCESSORS" },
        { key: "memoryenv",     label: "MEMORY & ENV" },
        { key: "lcd",           label: "LCD CONTROL" }
    ]

    // ── left side-nav ───────────────────────────────────────────────────
    Rectangle {
        id: sideNav
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 160
        color: Config.ThemeConfig.colors.background
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: Config.ThemeConfig.colors.border }

        Column {
            anchors.fill: parent; anchors.margins: 14; spacing: 6
            Item { width: parent.width; height: 46
                Column { spacing: 2
                    Text { text: "CORE ENGINE"; color: Config.ThemeConfig.colors.primary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true; font.italic: true }
                    Text { text: "STABLE V2.4.0 // CMD_CTR_PRO"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; opacity: 0.7 }
                }
            }
            Item { width: parent.width; height: 10 }
            Repeater {
                model: root.navItems
                delegate: Item {
                    width: sideNav.width - 28; height: 36
                    property bool isActive: root.active === modelData.key
                    Rectangle { anchors.fill: parent; visible: parent.isActive || navMa.containsMouse
                        color: parent.isActive ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.secondary
                        opacity: parent.isActive ? 0.12 : 0.06; Behavior on opacity { NumberAnimation { duration: 120 } } }
                    Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2; color: Config.ThemeConfig.colors.primary; visible: parent.isActive }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12
                        text: modelData.label; font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                        color: parent.isActive ? Config.ThemeConfig.colors.primary : (navMa.containsMouse ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim) }
                    MouseArea { id: navMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.active = modelData.key }
                }
            }
            Item { width: parent.width; Layout.fillHeight: true }
            Rectangle { width: parent.width; height: 56; color: "transparent"; border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                Column { anchors.fill: parent; anchors.margins: 8; spacing: 3
                    Text { text: "SESSION"; color: Config.ThemeConfig.colors.warning; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.0 }
                    Text { text: "USER: " + Services.SysInfoService.userName.toUpperCase(); color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                    Text { text: "HOST: " + Services.SysInfoService.hostname.toUpperCase(); color: Config.ThemeConfig.colors.textDim; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                }
            }
        }
    }

    // ── content: one pane per section (swap by active key) ──────────────
    Item {
        id: contentArea
        anchors.left: sideNav.right; anchors.top: parent.top; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 12

        // OVERVIEW — compact at-a-glance summary (no per-core matrix)
        Flickable {
            anchors.fill: parent; visible: root.active === "overview"
            contentWidth: width; contentHeight: ovWrap.implicitHeight + 24; clip: true; boundsBehavior: Flickable.StopAtBounds
            ColumnLayout { id: ovWrap; width: parent.width; spacing: 0
                CoreOverviewPane { Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 12; Layout.bottomMargin: 12 }
            }
        }

        // PROCESSORS — CPU only
        Flickable {
            anchors.fill: parent; visible: root.active === "processors"
            contentWidth: width; contentHeight: procCol.implicitHeight + 24; clip: true; boundsBehavior: Flickable.StopAtBounds
            ColumnLayout { id: procCol; width: parent.width; spacing: 14
                CoreCpuSection { Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 12; Layout.bottomMargin: 12 }
            }
        }

        // MEMORY & ENV — combined memory bank + environmental (HudCard aesthetic)
        Flickable {
            anchors.fill: parent; visible: root.active === "memoryenv"
            contentWidth: width; contentHeight: memEnvCol.implicitHeight + 24; clip: true; boundsBehavior: Flickable.StopAtBounds
            ColumnLayout { id: memEnvCol; width: parent.width; spacing: 14
                CoreMemoryEnvPane { Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 12; Layout.bottomMargin: 12 }
            }
        }

        // LCD CONTROL — physical AIO LCD preferences
        Flickable {
            anchors.fill: parent; visible: root.active === "lcd"
            contentWidth: width; contentHeight: lcdCol.implicitHeight + 24; clip: true; boundsBehavior: Flickable.StopAtBounds
            ColumnLayout { id: lcdCol; width: parent.width; spacing: 14
                CoreLcdPane { Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 12; Layout.bottomMargin: 12 }
            }
        }
    }
}
