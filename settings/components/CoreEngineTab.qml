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

    property string active: "processors"

    // Telemetry session (Shibumi consumer-refcount, single-consumer case):
    // this tab's Loader instantiation IS the CoreEngine/Gpu/Thermal gate.
    // While it lives, the 1s engine + feeders tick; torn down (panel close),
    // they stop dead. The Core tab binds properties directly — it never
    // reads metrics.json, so publish() stays LCD-gated inside CoreEngine.
    Component.onCompleted: Services.CoreEngineService.coreVisible = true
    Component.onDestruction: Services.CoreEngineService.coreVisible = false

    readonly property var navItems: [
        { key: "processors",    label: "PROCESSORS" },
        { key: "gpu",           label: "GPU" },
        { key: "memoryenv",     label: "MEMORY & ENV" },
        { key: "lcd",           label: "LCD CONTROL" },
        { key: "events",        label: "EVENTS" }
    ]

    // ── left side-nav ───────────────────────────────────────────────────
    Rectangle {
        id: sideNav
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        // Compact breakpoint (<1440 logical) collapses the rail like Controls'.
        width: Config.UIScale.compact ? 56 : 160
        color: Config.ThemeConfig.colors.surface
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: Config.ThemeConfig.colors.border }

        Column {
            anchors.fill: parent; anchors.margins: 14; spacing: 6
            Item { width: parent.width; height: 46; visible: !Config.UIScale.compact
                Column { spacing: 2
                    Text { text: "CORE ENGINE"; color: Config.ThemeConfig.colors.primary; font.family: Config.SettingsConfig.fontFamily; font.pixelSize: 15; font.bold: true }
                    Text { text: "SYSTEM TELEMETRY"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.letterSpacing: 0.8 }
                }
            }
            Item { width: parent.width; height: 10 }
            Repeater {
                model: root.navItems
                delegate: Item {
                    width: sideNav.width - 12; height: 38
                    x: 6
                    property bool isActive: root.active === modelData.key
                    Rectangle { anchors.fill: parent; radius: Config.ControlConfig.radiusPill
                        visible: parent.isActive || navMa.containsMouse
                        color: parent.isActive ? Config.ControlConfig.accentSoft
                               : Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.05)
                        opacity: parent.isActive ? 1.0 : 0.6
                        border.color: parent.isActive ? Config.ControlConfig.accent : "transparent"; border.width: 1
                        Behavior on opacity { NumberAnimation { duration: 120 } } }
                    Rectangle { anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; radius: 2.5
                        color: Config.ControlConfig.accent; visible: parent.isActive }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12
                        visible: !Config.UIScale.compact
                        text: modelData.label; font.family: Config.ControlConfig.fontSans; font.pixelSize: 11; font.bold: parent.isActive
                        font.letterSpacing: 0.6
                        color: parent.isActive ? Config.ControlConfig.accent : (navMa.containsMouse ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim) }
                    Text { anchors.centerIn: parent; visible: Config.UIScale.compact
                        text: modelData.label.charAt(0); font.family: Config.ControlConfig.fontSans; font.pixelSize: 11; font.bold: true
                        color: parent.isActive ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim }
                    MouseArea { id: navMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.active = modelData.key }
                }
            }
            Item { width: parent.width; Layout.fillHeight: true }
            Rectangle { visible: !Config.UIScale.compact
                width: parent.width; height: 56; radius: Config.ControlConfig.radiusPill
                color: "transparent"; border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                Column { anchors.fill: parent; anchors.margins: 8; spacing: 3
                    Text { text: "SESSION"; color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                    Text { text: Services.SysInfoService.userName.toUpperCase(); color: Config.ThemeConfig.colors.text
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width - 8 }
                    Text { text: Services.SysInfoService.hostname.toUpperCase(); color: Config.ThemeConfig.colors.textDim
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width - 8 }
                }
            }
        }
    }

    // ── content: one pane per section (swap by active key) ──────────────
    Item {
        id: contentArea
        anchors.left: sideNav.right; anchors.top: parent.top; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 12

        // GPU — NVIDIA telemetry (fixed composition, no scrolling §6.1)
        Item {
            anchors.fill: parent; visible: root.active === "gpu"
            CoreGpuSection { anchors.fill: parent; anchors.margins: 12 }
        }

        // PROCESSORS — CPU only (fixed composition, no scrolling §6.1)
        Item {
            anchors.fill: parent; visible: root.active === "processors"
            CoreCpuSection { anchors.fill: parent; anchors.margins: 12 }
        }

        // MEMORY & ENV — memory + environment + storage (fixed, no scrolling)
        Item {
            anchors.fill: parent; visible: root.active === "memoryenv"
            CoreMemoryEnvPane { anchors.fill: parent; anchors.margins: 12 }
        }

        // LCD CONTROL — physical AIO LCD preferences (fixed, no scrolling)
        Item {
            anchors.fill: parent; visible: root.active === "lcd"
            CoreLcdPane { anchors.fill: parent; anchors.margins: 12 }
        }

        // EVENTS — system event timeline (fixed composition, no scrolling)
        Item {
            anchors.fill: parent; visible: root.active === "events"
            CoreEventsPane { anchors.fill: parent; anchors.margins: 12 }
        }
    }
}
