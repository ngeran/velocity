// =============================================================================
// KeybindsPane.qml — SETTINGS tab's KEYBINDS pane (P4.9, read-only)
// =============================================================================
// A VIEW of the keybinds single source (D2/D3, P3.6 pattern — the same
// ingest the bar's KeybindsOverlay runs): ~/.config/velocity/keybinds.json
// as rendered by programs.velocity from tools/keybinds-default.json. Dev
// checkouts without the HM render fall back to the embedded copy in
// ../lib/keybinds-default.mjs (synced from shared/; check-ipc keeps it in
// lockstep with the json). Nothing here writes — the nix module is the
// writer; reload-after-omni-apply is why watchChanges is on.
// =============================================================================

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services
import "../lib/keybinds-default.mjs" as KeybindsLib

Item {
    id: root

    readonly property string _homeDir: ("" + Quickshell.env("HOME"))
    readonly property string keybindsPath: root._homeDir + "/.config/velocity/keybinds.json"

    // Grouped model: [{ sectionName, binds: [{key,label,available,order,…] }] }
    property var keybindModel: KeybindsLib.keybindsSections(KeybindsLib.KEYBINDS_DEFAULT)
    // "json" (the HM render) | "embedded" (fallback) — shown honestly in the header
    property string sourceKind: "embedded"
    property bool _loaded: false

    function _ingest(text) {
        if (root._loaded) return
        root._loaded = true
        try {
            var doc = JSON.parse(text)
            if (!doc || !doc.binds || !doc.binds.length) throw new Error("no binds")
            root.keybindModel = KeybindsLib.keybindsSections(doc.binds)
            root.sourceKind = "json"
        } catch (e) {
            // Missing/unparsable render → keep the embedded copy. One line,
            // not silent: the pane must never show a stale lie.
            console.warn("[KeybindsPane] keybinds.json unreadable (" + e + ") — using embedded default")
            root.sourceKind = "embedded"
        }
    }

    FileView {
        id: keybindsFile
        path: root.keybindsPath
        watchChanges: true
        // reload() is ASYNC — text() inside onFileChanged reads stale
        // (BarConfig lesson); flip the gate and let onLoadedChanged re-ingest.
        onLoadedChanged: if (loaded && !root._loaded) root._ingest(text())
        onFileChanged: { root._loaded = false; root.sourceKind = "embedded"; reload() }
    }
    // Re-read on every pane visit — the render lands after `omni-apply`, and
    // a file change while the settings tab was hidden must not show stale rows.
    function refresh() { root._loaded = false; root.sourceKind = "embedded"; keybindsFile.reload() }
    Component.onCompleted: {
        Services.SearchIndex.register({
            title: "Keybinds", tab: "settings", section: "keybinds",
            keywords: "keybinds keys shortcuts super hyper cheat sheet", item: null })
        if (keybindsFile.loaded) root._ingest(keybindsFile.text())
    }
    Component.onDestruction: Services.SearchIndex.unregister(this)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.ControlConfig.space4
        spacing: Config.ControlConfig.space4

        SettingsHeaderCard {
            Layout.fillWidth: true
            eyebrow: "SETTINGS"; title: "Keybinds"
            subtitle: root.sourceKind === "json"
                      ? "rendered from ~/.config/velocity/keybinds.json (read-only — owned by omni-nix)"
                      : "embedded default table (no ~/.config/velocity/keybinds.json — run omni-apply)"
        }

        Card {
            variant: "core"
            Layout.fillWidth: true
            Layout.fillHeight: true
            accent: Config.ControlConfig.accent

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: fl
                    anchors.fill: parent
                    anchors.rightMargin: 8
                    contentWidth: width
                    contentHeight: sectionsCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: sectionsCol
                        width: fl.width
                        spacing: Config.ControlConfig.space4

                        Repeater {
                            model: root.keybindModel
                            delegate: ColumnLayout {
                                id: sec
                                property string sectionTitle: modelData.sectionName
                                property var sectionBinds: modelData.binds
                                Layout.fillWidth: true
                                spacing: Config.ControlConfig.space1

                                SectionHeader {
                                    Layout.fillWidth: true
                                    title: sec.sectionTitle
                                    value: sec.sectionBinds.length + ""
                                }

                                Repeater {
                                    model: sec.sectionBinds
                                    delegate: RowLayout {
                                        id: row
                                        // plain property (not `required`) — JS-array
                                        // delegates lose modelData otherwise (P0 lesson)
                                        property var bind: modelData
                                        Layout.fillWidth: true
                                        spacing: Config.ControlConfig.space2

                                        Rectangle {
                                            Layout.preferredWidth: keyLbl.implicitWidth + 16
                                            Layout.preferredHeight: 20
                                            radius: Config.ControlConfig.radiusPill
                                            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.6)
                                            border.color: Config.ThemeConfig.colors.outlineVariant
                                            border.width: 1
                                            Text {
                                                id: keyLbl
                                                anchors.centerIn: parent
                                                text: row.bind.key
                                                color: Config.ThemeConfig.colors.text
                                                font.family: Config.ControlConfig.fontMono
                                                font.pixelSize: 9; font.bold: true
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            text: row.bind.label
                                            color: row.bind.available === false
                                                   ? Config.ThemeConfig.colors.textDim
                                                   : Config.ThemeConfig.colors.text
                                            opacity: row.bind.available === false ? 0.55 : 1.0
                                            font.family: Config.ControlConfig.fontSans
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            visible: row.bind.available === false
                                            text: "P7"
                                            color: Config.ThemeConfig.colors.textDim
                                            font.family: Config.ControlConfig.fontMono
                                            font.pixelSize: 9; font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Hand-rolled 3px indicator (house idiom — no Controls import).
                Rectangle {
                    visible: fl.contentHeight > fl.height + 1
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    width: 3
                    radius: 1.5
                    color: Config.ThemeConfig.colors.outlineVariant
                    opacity: 0.9
                    y: {
                        var track = fl.height - height - 4
                        var frac = fl.contentY / Math.max(1, fl.contentHeight - fl.height)
                        return 2 + Math.max(0, Math.min(track, frac * track))
                    }
                    height: Math.max(24, fl.height * (fl.height / Math.max(1, fl.contentHeight)) - 4)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "keybinds are owned by omni-nix (tools/keybinds-default.json → velocity-binds.lua) · edits land on the next omni-apply"
            color: Config.ThemeConfig.colors.textDim; opacity: 0.7
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
        }
    }
}
