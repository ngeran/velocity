// =============================================================================
// BarSettingsPane.qml — SETTINGS tab's BAR pane (P4.9)
// =============================================================================
// Hosts the bar tree's BarSettingsBody — the ONE host since the Control
// Center's removal (it used to mount the same body as its BAR page: style /
// edge / OSD / height / dots / guards / modules + uiScale and motion). There
// is no second settings copy.
//
// The settings tree must not `import "../bar/…"` (import-split law: a
// directory under two specifiers yields two singleton instances), so the body
// arrives through a file:// Loader: its own relative imports keep resolving
// inside the bar tree, so it reads and writes the LIVE bar singletons of this
// same process (BarConfig, BarConfigWriter, PluginRegistry). The settings tree
// is always disk-loaded (it lives outside the bar config root's VFS), so
// Qt.resolvedUrl from here lands on the repo root.
//
// PLUGINS › inside the body jumps to the dashboard's own plugin manager
// (CONTROL › plugins) via the shell root passed down as `dash` — the same
// convention as TerminalBody.dash's cross-tab jump links.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root

    // SettingsWindowShell root — cross-tab jump target (TerminalBody idiom).
    property var dash: null

    Component.onCompleted: Services.SearchIndex.register({
        title: "Bar", tab: "settings", section: "bar",
        keywords: "bar style edge osd height dots guards modules ui scale motion", item: null })
    Component.onDestruction: Services.SearchIndex.unregister(this)

    // Up two levels from settings/components/ = the repo root. Guard the qrc
    // case: if this component were ever loaded inside a VFS the resolved URL
    // is unreadable — fail the Loader visibly, never silently.
    readonly property string bodyUrl: {
        var u = "" + Qt.resolvedUrl("../../")
        return u.indexOf("file://") === 0
               ? u + "bar/components/BarSettingsBody.qml" : ""
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.ControlConfig.space4
        spacing: Config.ControlConfig.space4

        SettingsHeaderCard {
            Layout.fillWidth: true
            eyebrow: "SETTINGS"; title: "Bar"
            subtitle: "Style, edge, OSD, height, dots, guards, modules, scale"
        }

        Card {
            variant: "core"
            Layout.fillWidth: true
            Layout.fillHeight: true
            accent: Config.ControlConfig.accent

            // Plain-Item filler: layout-managed, so children may anchor freely.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: bodyLoader
                    anchors.fill: parent
                    source: root.bodyUrl
                    onLoaded: {
                        // No in-card ‹ BACK row here (the rail is the navigation).
                        item.showBack = false
                        item.pluginsRequested.connect(function() {
                            if (root.dash && root.dash.openControlTab)
                                root.dash.openControlTab("plugins")
                        })
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: bodyLoader.source === "" || bodyLoader.status === Loader.Error
                    text: bodyLoader.source === ""
                          ? "bar body unavailable (no disk URL)"
                          : "bar body failed to load — see journal"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
                }
            }
        }
    }
}
