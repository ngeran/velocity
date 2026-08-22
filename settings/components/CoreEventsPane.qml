// =============================================================================
// CoreEventsPane.qml — system event timeline (Core tab, EVENTS)
// =============================================================================
// The "what happened, and what changed before it" pane. Reads the log the
// bar's EventService collector maintains (via EventsReader): GPU Xids, NVRM
// errors, filesystem errors, boots, and nixos-rebuild switches — the
// update↔incident correlation axis that the 2026-08-22 GPU freeze turned
// from journald forensics into a glance.
//
// Layout mirrors the Core-tab siblings (CoreGpuSection): SPEC STRIP →
// main body → STATUS FOOTER. The body is a severity-colored event list
// (newest first); crit rows glow error-red, switches/boots stay calm.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root
    spacing: 12

    function sevColor(sev, type) {
        if (sev === "crit") return Config.ThemeConfig.colors.error
        if (type === "nix-switch") return Config.ThemeConfig.colors.primary
        return Config.ThemeConfig.colors.secondary
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
        spacing: 8

        Repeater {
            model: [
                { label: "LAST GPU XID", value: Services.EventsReader.lastXidText,
                  sub: Services.EventsReader.lastXidWhen || "no Xid on record",
                  accent: Services.EventsReader.critCount > 0
                          ? Config.ThemeConfig.colors.error
                          : Config.ThemeConfig.colors.secondary },
                { label: "CRITICAL EVENTS", value: "" + Services.EventsReader.critCount,
                  sub: "in tracked history",
                  accent: Services.EventsReader.critCount > 0
                          ? Config.ThemeConfig.colors.warning
                          : Config.ThemeConfig.colors.secondary },
                { label: "LAST SWITCH", value: Services.EventsReader.lastSwitchText
                          .replace(/^.*nixos-btw-/, ""),
                  sub: "generation (nixpkgs)",
                  accent: Config.ThemeConfig.colors.primary }
            ]
            delegate: Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 58
                color: Config.ThemeConfig.colors.background
                border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
                ColumnLayout { anchors.fill: parent; anchors.margins: 8; spacing: 3
                    Text { text: modelData.label; color: modelData.accent
                           font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                           font.bold: true; font.letterSpacing: 1.0 }
                    Text { text: modelData.value; color: Config.ThemeConfig.colors.text
                           font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                           elide: Text.ElideRight
                           Layout.fillWidth: true }
                    Text { text: modelData.sub; color: Config.ThemeConfig.colors.textDim
                           font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
                }
            }
        }
    }

    // ── 2. EVENT TIMELINE ───────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 420
        color: Config.ThemeConfig.colors.background
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 6

            Text {
                text: "EVENT TIMELINE // NEWEST FIRST"
                color: Config.ThemeConfig.colors.warning
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8
                font.bold: true; font.letterSpacing: 1.0
            }

            ListView {
                id: listView
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; boundsBehavior: Flickable.StopAtBounds
                model: Services.EventsReader.events

                // no visible ScrollBar — wheel-scroll, like every sibling
                // pane (and the Basic-style import it needs fails to load
                // under this Quickshell — not worth the fight for v1)

                delegate: Rectangle {
                    width: listView.width
                    height: 34
                    color: mouse.containsMouse
                           ? Config.ThemeConfig.colors.secondary : "transparent"
                    opacity: mouse.containsMouse ? 0.08 : 1.0

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 10

                        Text { text: shortTime(model.ts)
                               color: Config.ThemeConfig.colors.textDim
                               font.family: Config.ControlConfig.fontMono; font.pixelSize: 9 }

                        Rectangle { Layout.preferredWidth: badgeText.implicitWidth + 10
                                    Layout.preferredHeight: 16
                                    radius: 2
                                    color: "transparent"
                                    border.width: 1
                                    border.color: root.sevColor(model.sev, model.type)
                            Text { id: badgeText; anchors.centerIn: parent
                                   text: root.typeBadge(model.type)
                                   color: root.sevColor(model.sev, model.type)
                                   font.family: Config.ControlConfig.fontMono
                                   font.pixelSize: 8; font.bold: true } }

                        Text { Layout.fillWidth: true
                               text: model.data
                               color: model.sev === "crit"
                                      ? Config.ThemeConfig.colors.text
                                      : Config.ThemeConfig.colors.textDim
                               font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                               elide: Text.ElideMiddle }
                    }
                    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !Services.EventsReader.loaded
                    text: "reading event log…"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                }
            }
        }
    }

    // ── 3. STATUS FOOTER — what this is and where it lives ──────────────
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 40
        color: "transparent"
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1
        RowLayout { anchors.fill: parent; anchors.margins: 8; spacing: 16
            Text { text: "TRACKED: " + (Services.EventsReader.events.count) + " EVENTS"
                   color: Config.ThemeConfig.colors.textDim
                   font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
            Text { text: "BOOTS: " + Services.EventsReader.bootCount
                   color: Config.ThemeConfig.colors.textDim
                   font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
            Text { text: "SWITCHES: " + Services.EventsReader.switchCount
                   color: Config.ThemeConfig.colors.textDim
                   font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
            Item { Layout.fillWidth: true }
            Text { text: "collector: bar/EventService · log: events.jsonl"
                   color: Config.ThemeConfig.colors.textDim; opacity: 0.6
                   font.family: Config.ControlConfig.fontMono; font.pixelSize: 8 }
        }
    }
}
