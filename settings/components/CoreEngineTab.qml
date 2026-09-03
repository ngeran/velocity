// =============================================================================
// CoreEngineTab.qml — "Core Engine" tab (tab 4): shared SideNav + content swap
// =============================================================================
// Consolidated nav (user request): SYSTEM (unified CPU+GPU+MEM+drives) is the
// default pane; GPU (processes detail), LCD, EVENTS remain separate.
// Telemetry gating preserved: coreVisible construct/destruct.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root

    property string active: "system"

    // Telemetry session (Shibumi consumer-refcount, single-consumer case):
    // this tab's Loader instantiation IS the CoreEngine/Gpu/Thermal gate.
    Component.onCompleted: Services.CoreEngineService.coreVisible = true
    Component.onDestruction: Services.CoreEngineService.coreVisible = false

    readonly property var navItems: [
        { key: "system", label: "SYSTEM",    icon: "󰇅" },
        { key: "lcd",    label: "LCD",       icon: "󰍹" },
        { key: "events", label: "EVENTS",    icon: "󰈔" }
    ]

    SideNav {
        id: sideNav
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Config.UIScale.compact ? 56 : Config.ControlConfig.sidenavWidth
        items: root.navItems
        activeSection: root.active
        onSectionSelected: function(key) { root.active = key }

        // Footer slot: session info
        Rectangle {
            visible: !Config.UIScale.compact
            width: parent.width - Config.ControlConfig.space2
            height: 58
            radius: Config.ControlConfig.radiusPill
            color: "transparent"
            border.color: Config.ThemeConfig.colors.outlineVariant
            border.width: 1
            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 3
                Text { text: "SESSION"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0 }
                Text { text: Services.SysInfoService.userName.toUpperCase(); color: Config.ThemeConfig.colors.text
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width - 8 }
                Text { text: Services.SysInfoService.hostname.toUpperCase(); color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width - 8 }
            }
        }
    }

    // ── content: one pane per section ────────────────────────────────────
    Item {
        id: contentArea
        anchors.left: sideNav.right; anchors.top: parent.top; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 12

        // SYSTEM — consolidated CPU + GPU + memory + drives (no scrolling)
        Item {
            anchors.fill: parent; visible: root.active === "system"
            CoreSystemPane { anchors.fill: parent; anchors.margins: 12 }
        }

        // LCD — physical AIO LCD preferences (no scrolling)
        Item {
            anchors.fill: parent; visible: root.active === "lcd"
            CoreLcdPane { anchors.fill: parent; anchors.margins: 12 }
        }

        // EVENTS — system event timeline (no scrolling)
        Item {
            anchors.fill: parent; visible: root.active === "events"
            CoreEventsPane { anchors.fill: parent; anchors.margins: 12 }
        }
    }
}
