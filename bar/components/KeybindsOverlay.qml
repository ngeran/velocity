// =============================================================================
// KeybindsOverlay.qml — SUPER+K keybinds cheat-sheet (pure QML, no python)
// =============================================================================
// A VIEW of the keybinds single source (D2/D3, P3.6): ~/.config/velocity/
// keybinds.json as rendered by programs.velocity from
// tools/keybinds-default.json. No hard-coded table here — the nix module is
// the writer. Dev checkouts without the HM render fall back to the embedded
// copy in ../lib/keybinds-default.mjs (check-ipc keeps the two in lockstep).
// Toggled via IPC: `qs -c bar ipc call keybinds toggle` (SUPER+K, generated
// velocity-binds.lua). Esc or outside-click closes.
// =============================================================================

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../lib/keybinds-default.mjs" as KeybindsLib

// Shared overlay chrome (DU11): backdrop/Esc/card/timer live in OverlayShell;
// this file contributes the card interior + the keybind model read.
OverlayShell {
    id: root

    // ---- keybinds.json (single source view; HM-rendered) ----
    readonly property string _homeDir: ("" + Quickshell.env("HOME"))
    readonly property string keybindsPath: root._homeDir + "/.config/velocity/keybinds.json"

    // Grouped model: [{ sectionName, binds: [{key,label,available,order,…] }] }
    property var keybindModel: KeybindsLib.keybindsSections(KeybindsLib.KEYBINDS_DEFAULT)
    property bool _loaded: false

    function _ingest(text) {
        if (root._loaded) return
        root._loaded = true
        try {
            var doc = JSON.parse(text)
            if (!doc || !doc.binds || !doc.binds.length) throw new Error("no binds")
            root.keybindModel = KeybindsLib.keybindsSections(doc.binds)
        } catch (e) {
            // Missing/unparsable render → keep the embedded D3 copy. One line,
            // not silent: the overlay must never show a stale lie.
            console.warn("[Keybinds] keybinds.json unreadable (" + e + ") — using embedded default")
        }
    }

    FileView {
        id: keybindsFile
        path: root.keybindsPath
        watchChanges: true
        // reload() is ASYNC — text() inside onFileChanged reads stale
        // (BarConfig lesson); flip the gate and let onLoadedChanged re-ingest.
        onLoadedChanged: if (loaded && !root._loaded) root._ingest(text())
        onFileChanged: { root._loaded = false; reload() }
    }
    // Reload on every open too — the render lands after `omni-apply`, and a
    // file-changed during a hidden overlay must not show stale rows.
    onShownChanged: if (shown) { root._loaded = false; keybindsFile.reload() }
    Component.onCompleted: if (keybindsFile.loaded) root._ingest(keybindsFile.text())

    ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.PopupMetrics.px(24)
            spacing: Config.PopupMetrics.px(12)

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.PopupMetrics.px(8)
                Text {
                    text: "󰬃"
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: Config.PopupMetrics.px(16)
                    color: Config.BarConfig.colorAccent
                }
                Text {
                    text: "KEYBINDINGS"
                    color: Config.ThemeConfig.colors.text
                    font.pixelSize: Config.PopupMetrics.px(16)
                    font.bold: true
                    font.family: Config.BarConfig.fontFamily
                    font.letterSpacing: 2.5
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "ESC to close"
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: Config.PopupMetrics.px(10)
                    font.family: Config.BarConfig.fontFamily
                }
            }
            Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: Config.ThemeConfig.colors.border }

            // ---- scrollable sections ----
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: sectionsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: sectionsCol
                    width: parent.width
                    spacing: Config.PopupMetrics.px(16)

                    Repeater {
                        model: root.keybindModel
                        delegate: ColumnLayout {
                            id: sec
                            // pull the section's data into local props for unambiguous binding
                            property string sectionTitle: modelData.sectionName
                            property var sectionBinds: modelData.binds
                            Layout.fillWidth: true
                            spacing: Config.PopupMetrics.px(6)

                            Text {
                                text: sec.sectionTitle
                                color: Config.ThemeConfig.colors.primary
                                font.pixelSize: Config.PopupMetrics.px(10)
                                font.bold: true
                                font.family: Config.BarConfig.fontFamily
                                font.letterSpacing: 1.8
                            }

                            Repeater {
                                model: sec.sectionBinds
                                delegate: RowLayout {
                                    id: row
                                    // plain property (not `required`) — JS-array
                                    // delegates lose modelData otherwise (P0 lesson)
                                    property var bind: modelData
                                    Layout.fillWidth: true
                                    spacing: Config.PopupMetrics.px(12)
                                    Rectangle {
                                        Layout.preferredWidth: keyLbl.implicitWidth + Config.PopupMetrics.px(18)
                                        Layout.preferredHeight: Config.PopupMetrics.px(20)
                                        color: Config.ThemeConfig.colors.surfaceVariant
                                        border.color: Config.ThemeConfig.colors.border
                                        border.width: Config.PopupMetrics.hairline(parent)
                                        Text {
                                            id: keyLbl
                                            anchors.centerIn: parent
                                            text: row.bind.key
                                            color: Config.ThemeConfig.colors.text
                                            font.pixelSize: Config.PopupMetrics.px(10)
                                            font.bold: true
                                            font.family: Config.BarConfig.fontFamily
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: row.bind.label
                                        color: row.bind.available === false
                                               ? Config.ThemeConfig.colors.textDim
                                               : Config.ThemeConfig.colors.text
                                        opacity: row.bind.available === false ? 0.55 : 1.0
                                        font.pixelSize: Config.PopupMetrics.px(11)
                                        font.family: Config.BarConfig.fontFamily
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
}
