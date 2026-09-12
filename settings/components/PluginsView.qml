// =============================================================================
// PluginsView.qml — CONTROL ▸ PLUGINS: plugin manager (theme-aware)
// =============================================================================
// Compact one-line rows, search-as-you-type, status filter, and per-row
// lifecycle: enable/disable (ToggleSwitch), reorder (▲▼), delete (two-step
// ConfirmDialog). Data comes from PluginManagerService, which drives the BAR
// process over its plugins IPC; the bar is the single writer of state.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: view
    spacing: Config.ControlConfig.space3

    readonly property var mgr: Services.PluginManagerService
    property string deleteArmed: ""

    Component.onCompleted: mgr.sectionVisible = true
    Component.onDestruction: mgr.sectionVisible = false
    onVisibleChanged: mgr.sectionVisible = visible

    // ── search + filter ─────────────────────────────────────────────────────
    property string search: ""
    property string statusFilter: "all"   // all | enabled | disabled | error

    readonly property var visiblePlugins: {
        var out = []
        var q = view.search.toLowerCase()
        var ps = view.mgr.plugins
        for (var i = 0; i < ps.length; i++) {
            var p = ps[i]
            if (view.statusFilter === "enabled" && !p.enabled) continue
            if (view.statusFilter === "disabled" && p.enabled) continue
            if (view.statusFilter === "error" && p.status !== "error") continue
            if (q !== "" && (p.id + " " + p.name + " " + p.description).toLowerCase().indexOf(q) === -1) continue
            out.push(p)
        }
        return out
    }

    // ── reusable pill ─────────────────────────────────────────────────────────
    component Pill: Rectangle {
        id: pill
        property string text: ""
        property bool accentStyle: false
        property bool danger: false
        signal activated()
        Layout.alignment: Qt.AlignVCenter
        width: pillLbl.implicitWidth + 18; height: 24
        radius: Config.ControlConfig.radiusPill
        color: danger ? (pma.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.22)
                                           : Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.12))
                      : accentStyle ? (pma.containsMouse ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.24)
                                                         : Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.14))
                      : (pma.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.08)
                                           : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5))
        border.color: danger ? Config.ThemeConfig.colors.error
                             : accentStyle ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
        border.width: 1
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            id: pillLbl; anchors.centerIn: parent
            text: pill.text
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
            color: pill.danger ? Config.ThemeConfig.colors.error
                               : pill.accentStyle ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
        }
        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor; onClicked: pill.activated() }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // HEADER — breadcrumb · title+count · rescan
    // ═════════════════════════════════════════════════════════════════════════
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            text: "CONTROLS  /  PLUGIN HOST"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            font.letterSpacing: 1.2; color: Config.ThemeConfig.colors.textDim
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Plugin Manager"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 20
                font.bold: true; color: Config.ThemeConfig.colors.text
            }
            Rectangle {
                width: countLbl.implicitWidth + 14; height: 18; radius: 9
                color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.12)
                border.color: Config.ThemeConfig.colors.success; border.width: 1
                Text { id: countLbl; anchors.centerIn: parent
                    text: view.mgr.plugins.length + " DISCOVERED"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                    color: Config.ThemeConfig.colors.success }
            }
            Text {
                visible: view.mgr.busy
                text: "WORKING…"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                color: Config.ControlConfig.accent
            }
            Item { Layout.fillWidth: true }
            Pill { text: "RESCAN"; onActivated: view.mgr.rescan() }
        }
    }

    // ── scaffold + install row ────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text { text: "NEW ID"
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 9
            font.bold: true; color: Config.ThemeConfig.colors.textDim }
        Rectangle {
            Layout.preferredWidth: 170; Layout.preferredHeight: 24
            radius: Config.ControlConfig.radiusSmall
            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.7)
            border.color: scaffoldInput.activeFocus ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
            border.width: 1
            TextInput {
                id: scaffoldInput
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Config.ThemeConfig.colors.text
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                text: "nikos.myplugin"
                selectByMouse: true
            }
        }
        Pill { text: "NEW PLUGIN"; accentStyle: true; onActivated: view.mgr.scaffold(scaffoldInput.text) }
        Item { Layout.fillWidth: true }
        Text { text: "INSTALL FROM GIT"
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 9
            font.bold: true; color: Config.ThemeConfig.colors.textDim }
        Rectangle {
            Layout.preferredWidth: 300; Layout.preferredHeight: 24
            radius: Config.ControlConfig.radiusSmall
            color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.7)
            border.color: gitInput.activeFocus ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
            border.width: 1
            TextInput {
                id: gitInput
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Config.ThemeConfig.colors.text
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                Text { anchors.fill: parent; visible: parent.text === ""
                    text: "https://git-host.com/user/plugin-repo.git"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                    verticalAlignment: Text.AlignVCenter
                    color: Config.ThemeConfig.colors.textDim }
                selectByMouse: true
            }
        }
        Pill { text: "INSTALL"; onActivated: view.mgr.installGit(gitInput.text) }
    }

    // ── search ────────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            text: "⌕"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 11
            color: Config.ThemeConfig.colors.textDim
        }
        TextInput {
            id: searchInput
            Layout.fillWidth: true
            color: Config.ThemeConfig.colors.text
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            clip: true
            Text { anchors.fill: parent; visible: parent.text === ""
                text: "filter by name, id or description…"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                color: Config.ThemeConfig.colors.textDim }
            onTextChanged: view.search = text
        }
        Text {
            visible: view.mgr.lastError !== ""
            text: "⚠ " + view.mgr.lastError
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 9
            color: Config.ThemeConfig.colors.error
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PLUGIN ROWS — one compact line per plugin
    // ═════════════════════════════════════════════════════════════════════════
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Config.ControlConfig.radiusCard
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
        border.color: Config.ThemeConfig.colors.outlineVariant
        border.width: 1
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: view.visiblePlugins

                Rectangle {
                    width: parent ? parent.width : 200
                    height: 34
                    radius: Config.ControlConfig.radiusSmall
                    color: rowMa.containsMouse
                           ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.7)
                           : "transparent"

                    readonly property bool isErr: modelData.status === "error" || modelData.status === "invalid"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            width: 7; height: 7; radius: 3.5
                            color: modelData.enabled
                                   ? (isErr ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.success)
                                   : Config.ThemeConfig.colors.textDim
                        }

                        Text {
                            text: modelData.name + "  " + modelData.version
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                            font.bold: modelData.enabled
                            color: modelData.enabled ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
                            elide: Text.ElideRight
                            Layout.maximumWidth: 180
                        }
                        Text {
                            text: modelData.id
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                            color: Config.ThemeConfig.colors.textDim
                            elide: Text.ElideRight
                            Layout.maximumWidth: 220
                        }
                        Text {
                            visible: modelData.commands.length > 0
                            text: "⌗ " + modelData.commands.join(" ")
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                            color: Config.ThemeConfig.colors.warning
                            elide: Text.ElideRight
                            Layout.maximumWidth: 120
                        }
                        Text {
                            visible: isErr
                            text: modelData.error
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                            color: Config.ThemeConfig.colors.error
                            elide: Text.ElideMiddle
                            Layout.maximumWidth: 160
                        }

                        Item { Layout.fillWidth: true }

                            // enable / disable — themed kit switch
                        ToggleSwitch {
                            checked: modelData.enabled
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: view.mgr.setEnabled(modelData.id, !modelData.enabled)
                        }

                        // reorder (service is a safe no-op at the edges)
                        Pill { text: "▲"; onActivated: view.mgr.move(modelData.id, -1) }
                        Pill { text: "▼"; onActivated: view.mgr.move(modelData.id, 1) }

                        // delete (two-step confirm chip)
                        ConfirmDialog {
                            label: "DEL"
                            confirmLabel: "SURE?"
                            anchors.verticalCenter: parent.verticalCenter
                            onConfirmed: view.mgr.remove(modelData.id)
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: view.visiblePlugins.length === 0 && !view.mgr.busy
            text: view.mgr.plugins.length === 0
                  ? "// no plugins — scaffold one or install from git"
                  : "// no match for this filter"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // FOOTER — where plugins live
    // ═════════════════════════════════════════════════════════════════════════
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        radius: Config.ControlConfig.radiusSmall
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.55)
        border.color: Config.ThemeConfig.colors.outlineVariant
        border.width: 1

        Text {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "Plugins live in ~/.config/quickshell/plugins/<author.name>/ — each folder is self-contained; deleting it removes the plugin."
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.textDim
            elide: Text.ElideRight
            anchors.right: parent.right
            anchors.rightMargin: 12
        }
    }
}
