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
        { key: "processors", label: "PROCESSORS", icon: "󰻠" },
        { key: "gpu",        label: "GPU",        icon: "󰢮" },
        { key: "memoryenv",  label: "MEMORY",     icon: "󰑭" },
        { key: "lcd",        label: "LCD",        icon: "󰍹" },
        { key: "events",     label: "EVENTS",     icon: "󰈔" }
    ]

    // ── left side-nav — the SHARED SideNav (same component/UX as the Control
    // tab: icon chips + labels + active dot; collapses to 56px icon-only at
    // the compact breakpoint). Session info rides the footer slot.
    SideNav {
        id: sideNav
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Config.UIScale.compact ? 56 : Config.ControlConfig.sidenavWidth
        items: root.navItems
        activeSection: root.active
        onSectionSelected: function(key) { root.active = key }

        // Footer slot: tab title + session
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
