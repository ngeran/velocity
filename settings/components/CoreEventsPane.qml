// =============================================================================
// CoreEventsPane.qml — system event timeline (Core tab; Shibumi viewport-fit)
// =============================================================================
// The "what happened, and what changed before it" pane. Reads the log the
// bar's EventService collector maintains (via EventsReader): GPU Xids, NVRM
// errors, filesystem errors, boots, and nixos-rebuild switches.
//
// Fixed composition (§6.1 — no scrolling): spec tiles → event timeline card
// (rows visibility-clamped with honest counts) → stats footer. Crit rows
// glow error-red; switches/boots stay calm.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root
    spacing: Config.ControlConfig.space3

    function sevColor(sev, type) {
        if (sev === "crit") return Config.ThemeConfig.colors.error
        if (type === "nix-switch") return Config.ThemeConfig.colors.primary
        return Config.ControlConfig.accent
    }

    function typeBadge(type) {
        var map = {
            "gpu-xid": "XID", "gpu-nvrm": "NVRM", "fs-error": "FS",
            "nix-switch": "SWITCH", "boot": "BOOT"
        }
        return map[type] || type.toUpperCase()
    }

    function shortTime(iso) {
        // "2026-08-22T12:56:55.623Z" → "08-22 12:56" (local)
        var d = new Date(iso)
        if (isNaN(d.getTime())) return ""
        function p(n) { return (n < 10 ? "0" : "") + n }
        return p(d.getMonth() + 1) + "-" + p(d.getDate()) + " " +
               p(d.getHours()) + ":" + p(d.getMinutes())
    }

    // ── 1. SPEC STRIP — the three glanceable answers ────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.ControlConfig.space2

        Repeater {
            model: [
                { label: "LAST GPU XID", value: Services.EventsReader.lastXidText,
                  sub: Services.EventsReader.lastXidWhen || "no Xid on record",
                  accent: Services.EventsReader.critCount > 0
                          ? Config.ThemeConfig.colors.error
                          : Config.ControlConfig.accent },
                { label: "CRITICAL EVENTS", value: "" + Services.EventsReader.critCount,
                  sub: "in tracked history",
                  accent: Services.EventsReader.critCount > 0
                          ? Config.ThemeConfig.colors.warning
                          : Config.ControlConfig.accent },
                { label: "LAST SWITCH", value: Services.EventsReader.lastSwitchText
                          .replace(/^.*nixos-btw-/, ""),
                  sub: "generation (nixpkgs)",
                  accent: Config.ThemeConfig.colors.primary }
            ]
            delegate: Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 56
                radius: Config.ControlConfig.radiusPill
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
                border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 3
                    Text { text: modelData.label; color: modelData.accent
                           font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                           font.bold: true; font.letterSpacing: 1.0 }
                    Text { text: modelData.value; color: Config.ThemeConfig.colors.text
                           font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                           elide: Text.ElideRight
                           Layout.fillWidth: true }
                    Text { text: modelData.sub; color: Config.ThemeConfig.colors.textDim
                           font.family: Config.ControlConfig.fontSans; font.pixelSize: 10 }
                }
            }
        }
    }

    // ── 2. EVENT TIMELINE (visibility-clamped — no scrolling) ───────────
    Rectangle {
        id: timelineCard
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Config.ControlConfig.radiusCard
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5)
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1

        // Rows are 32px; hide beyond capacity (NEVER slice the model — the
        // §6.1 CRITICAL rule; delegates persist, counts stay honest).
        readonly property int capacity: Math.max(3, Math.floor(timelineViewport.height / 32))
        readonly property int visibleCount: Math.min(Services.EventsReader.events.count, capacity)

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: Config.ControlConfig.space2

            RowLayout {
                Layout.fillWidth: true
                Text { text: "EVENT TIMELINE"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    font.bold: true; font.letterSpacing: 1.0 }
                Item { Layout.fillWidth: true }
                Text { text: "NEWEST FIRST"; color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.letterSpacing: 0.8 }
            }

            Item {
                id: timelineViewport
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    Repeater {
                        model: Services.EventsReader.events
                        delegate: Rectangle {
                            width: parent.width
                            visible: index < timelineCard.capacity
                            height: 32
                            radius: Config.ControlConfig.radiusSmall
                            color: mouse.containsMouse
                                   ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.08)
                                   : "transparent"

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                spacing: 10

                                Text { text: root.shortTime(model.ts)
                                       color: Config.ThemeConfig.colors.textDim
                                       font.family: Config.ControlConfig.fontMono; font.pixelSize: 10 }

                                Rectangle { Layout.preferredWidth: badgeText.implicitWidth + 10
                                            Layout.preferredHeight: 16
                                            radius: Config.ControlConfig.radiusSmall
                                            color: "transparent"
                                            border.width: 1
                                            border.color: root.sevColor(model.sev, model.type)
                                    Text { id: badgeText; anchors.centerIn: parent
                                           text: root.typeBadge(model.type)
                                           color: root.sevColor(model.sev, model.type)
                                           font.family: Config.ControlConfig.fontMono
                                           font.pixelSize: 10; font.bold: true } }

                                Text { Layout.fillWidth: true
                                       text: model.data
                                       color: model.sev === "crit"
                                              ? Config.ThemeConfig.colors.text
                                              : Config.ThemeConfig.colors.textDim
                                       font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                                       elide: Text.ElideMiddle }
                            }
                            MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !Services.EventsReader.loaded
                    text: "reading event log…"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                }

                Text {
                    anchors.centerIn: parent
                    visible: Services.EventsReader.loaded && Services.EventsReader.events.count === 0
                    text: "no events on record"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                }
            }

            Text {
                Layout.fillWidth: true
                visible: timelineCard.visibleCount < Services.EventsReader.events.count
                text: "+ " + (Services.EventsReader.events.count - timelineCard.visibleCount) + " earlier hidden"
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    // ── 3. STATS FOOTER ─────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; spacing: Config.ControlConfig.space3

        Text { text: "TRACKED " + (Services.EventsReader.events.count)
               color: Config.ThemeConfig.colors.textDim
               font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
        Text { text: "BOOTS " + Services.EventsReader.bootCount
               color: Config.ThemeConfig.colors.textDim
               font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
        Text { text: "SWITCHES " + Services.EventsReader.switchCount
               color: Config.ThemeConfig.colors.textDim
               font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true }
        Item { Layout.fillWidth: true }
        Text { text: "collector: bar/EventService · log: events.jsonl"
               color: Config.ThemeConfig.colors.textDim; opacity: 0.7
               font.family: Config.ControlConfig.fontSans; font.pixelSize: 10 }
    }
}
