// =============================================================================
// PluginsView.qml — CONTROL ▸ PLUGINS: plugin manager (theme-aware)
// =============================================================================
// Compact rows ordered like the bar (left → center → right, then headless
// plugins), search-as-you-type, status chips (ERROR carries the live
// failure count — load errors surface from the bar's registry), and
// per-row lifecycle: enable/disable,
// section chip (bar widgets: click cycles LEFT → CENTER → RIGHT), reorder
// within the section (▲▼), a settings form generated from the manifest
// schema (⚙), and DEL → trash (user/bundled plugins only) with RESTORE
// below. Data comes from PluginManagerService: state and settings through
// the BAR's plugins IPC (the bar is their single writer), file ops through
// bin/velocity-plugin.
//
// The settings form (SettingsForm) renders whatever the manifest declares:
// string/number/list as text inputs, bool as a toggle, enum as a
// PanelDropdown of the declared options — every write goes through
// plugins setSetting, so the value is coerced by the same schema the
// plugin sees and a rejection is reported AT the form (the engine logs
// the precise reason). RESET DEFAULTS writes the manifest defaults back.
// Reloads only rebuild the field delegates when the schema keys actually
// change — a value-only reload keeps focus in the input you were editing.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: view
    spacing: Config.ControlConfig.space3

    readonly property var mgr: Services.PluginManagerService
    // The one row whose settings form is open ("" = none).
    property string settingsOpen: ""
    property string newKind: "bar-widget"
    readonly property var kinds: ["bar-widget", "overlay", "service"]
    readonly property var sections: ["left", "center", "right"]

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
            var plugin = ps[i]
            if (view.statusFilter === "enabled" && !plugin.enabled) continue
            if (view.statusFilter === "disabled" && plugin.enabled) continue
            // ERROR catches both "error" (load failed in the bar) and
            // "invalid" (manifest rejected at scan) — the row dot paints
            // both red.
            if (view.statusFilter === "error" && plugin.status !== "error" && plugin.status !== "invalid") continue
            if (q !== "" && (plugin.id + " " + plugin.name + " " + (plugin.description || "")).toLowerCase().indexOf(q) === -1) continue
            out.push(plugin)
        }
        // Bar order: sections left → center → right, then unplaced/headless.
        var rank = function(plugin) {
            var s = view.sections.indexOf(plugin.section || "")
            return (s === -1 ? 3 : s) * 1000 + (plugin.position >= 0 ? plugin.position : 999)
        }
        return out.sort(function(a, b) { return rank(a) - rank(b) || (a.id < b.id ? -1 : 1) })
    }

    // Errored or invalid rows (same states the dot paints red) — the ERROR
    // chip carries the count so a failed load is visible without filtering.
    readonly property int errorCount: {
        var n = 0
        var ps = view.mgr.plugins
        for (var i = 0; i < ps.length; i++)
            if (ps[i].status === "error" || ps[i].status === "invalid") n++
        return n
    }

    function isBarWidget(plugin) { return plugin.kinds.indexOf("bar-widget") !== -1 }
    function hasSettings(plugin) { return plugin.settings && Object.keys(plugin.settings).length > 0 }
    function removable(plugin) { return plugin.source === "user" || plugin.source === "bundled" }
    function nextSection(plugin) {
        var i = view.sections.indexOf(plugin.section || plugin.defaultSection || "right")
        return view.sections[(i + 1) % view.sections.length]
    }

    // ── schema-driven settings form (one per open row) ───────────────────────
    // Reads and writes through the bar's SettingsStore (mgr.loadSettings /
    // setSetting), so values are coerced by the same schema the plugin sees.
    component SettingsForm: ColumnLayout {
        id: form
        property string pluginId: ""
        property var schema: ({})
        property var values: ({})
        property bool loaded: false
        // Last rejected write, shown at the form ("key: reason") — the
        // engine keeps the precise coercion error in the bar's journal.
        property string error: ""
        // Schema keys, reassigned only when the CONTENT changes: the field
        // Repeater models this, so a value-only reload never rebuilds
        // delegates (focus survives editing several fields in a row).
        property var _keys: []
        spacing: 4

        function _setKeys(next) {
            var cur = form._keys
            if (cur.length === next.length) {
                var same = true
                for (var i = 0; i < next.length; i++)
                    if (cur[i] !== next[i]) { same = false; break }
                if (same) return
            }
            form._keys = next
        }
        function reload() {
            view.mgr.loadSettings(form.pluginId, function(j) {
                if (!form) return
                form.schema = j.schema || {}
                form.values = j.values || {}
                form._setKeys(Object.keys(form.schema))
                form.loaded = true
            })
        }
        function commit(key, value) {
            view.mgr.setSetting(form.pluginId, key, value, function(ok) {
                if (!form) return
                if (ok) { form.error = ""; form.reload() }
                else form.error = view.mgr.lastError
            })
        }
        // Write every declared default back (one IPC per key), then reload
        // once. A failed key aborts the loop and reports at the form.
        function applyDefaults() {
            var keys = Object.keys(form.schema)
            var i = 0
            var step = function() {
                if (!form) return
                if (i >= keys.length) { form.reload(); return }
                var k = keys[i++]
                view.mgr.setSetting(form.pluginId, k, form.schema[k].default, function(ok) {
                    if (!form) return
                    if (!ok) { form.error = view.mgr.lastError; return }
                    step()
                })
            }
            form.error = ""
            step()
        }
        Component.onCompleted: reload()

        Text {
            visible: !form.loaded
            text: "loading settings…"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.textDim
        }

        // form header: eyebrow + reset (kept narrow — this pane has a
        // ~544px floor; wide rows here become the whole pane's minimum)
        RowLayout {
            visible: form.loaded
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "PLUGIN SETTINGS"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 8; font.bold: true
                font.letterSpacing: 1.0
                color: Config.ThemeConfig.colors.textDim
                Layout.minimumWidth: 0
            }
            Item { Layout.fillWidth: true }
            Pill { text: "RESET DEFAULTS"; onActivated: form.applyDefaults() }
        }

        Repeater {
            model: form.loaded ? form._keys : []

            RowLayout {
                id: field
                readonly property string key: modelData
                readonly property var spec: form.schema[modelData] || {}
                readonly property var value: form.values[modelData]
                readonly property bool textual: spec.type === "string" || spec.type === "number" || spec.type === "list"
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: (field.spec.label || field.key).toUpperCase()
                    Layout.preferredWidth: 160
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 9; font.bold: true
                    color: Config.ThemeConfig.colors.textDim
                }

                Rectangle {
                    visible: field.textual
                    Layout.preferredWidth: 240; Layout.minimumWidth: 0
                    Layout.fillWidth: field.textual
                    Layout.maximumWidth: 280
                    Layout.preferredHeight: 22
                    radius: Config.ControlConfig.radiusSmall
                    color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.7)
                    border.color: fieldInput.activeFocus ? Config.ControlConfig.accent : Config.ThemeConfig.colors.outlineVariant
                    border.width: 1
                    TextInput {
                        id: fieldInput
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        selectByMouse: true
                        color: Config.ThemeConfig.colors.text
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                        text: field.value === undefined ? ""
                              : (field.spec.type === "list" ? field.value.join(", ") : String(field.value))
                        onEditingFinished: {
                            if (field.spec.type === "number") form.commit(field.key, Number(text))
                            else if (field.spec.type === "list")
                                form.commit(field.key, text.split(",").map(function(x) { return x.trim() }).filter(function(x) { return x !== "" }))
                            else form.commit(field.key, text)
                        }
                    }
                }

                ToggleSwitch {
                    visible: field.spec.type === "bool"
                    checked: field.value === true
                    onToggled: form.commit(field.key, !(field.value === true))
                }

                // enum: the declared options as a dropdown (the old cycle
                // pill needed N clicks to wrap an N-option list). value is
                // synced imperatively — PanelDropdown assigns its own value
                // on pick, which would break a declarative binding.
                PanelDropdown {
                    id: enumDrop
                    visible: field.spec.type === "enum"
                    Layout.preferredWidth: 240; Layout.minimumWidth: 0
                    Layout.maximumWidth: 280
                    showLabel: false
                    options: field.spec.options || []
                    function _sync() {
                        value = String(field.value === undefined ? "" : field.value)
                    }
                    Component.onCompleted: _sync()
                    Connections {
                        target: field
                        function onValueChanged() { enumDrop._sync() }
                    }
                    onChanged: function(v) { form.commit(field.key, v) }
                }

                Text {
                    visible: field.spec.type === "number" && (field.spec.min !== undefined || field.spec.max !== undefined)
                    text: (field.spec.min !== undefined ? field.spec.min : "…") + " – " + (field.spec.max !== undefined ? field.spec.max : "…")
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                    color: Config.ThemeConfig.colors.textDim
                }
                Item { Layout.fillWidth: true }
            }
        }

        Text {
            visible: form.error !== ""
            text: "⚠ " + form.error
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            elide: Text.ElideRight
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.error
        }
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

    // ── scaffold + install rows ───────────────────────────────────────────────
    // Two rows, not one: combined they set a ~850px implicit width, which
    // became this pane's effective minimum and pushed every plugin row's
    // toggle past the card edge on the 720px-floor dashboard card (pane
    // cell ~544). Inputs flex (minimumWidth + fillWidth, capped) so each
    // row's implicit stays well under the narrowest pane.
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text { text: "NEW ID"
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 9
            font.bold: true; color: Config.ThemeConfig.colors.textDim }
        Rectangle {
            Layout.preferredWidth: 170; Layout.minimumWidth: 60
            Layout.fillWidth: true; Layout.maximumWidth: 200
            Layout.preferredHeight: 24
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
        // kind: click cycles bar-widget → overlay → service
        Pill {
            text: view.newKind.toUpperCase()
            onActivated: view.newKind = view.kinds[(view.kinds.indexOf(view.newKind) + 1) % view.kinds.length]
        }
        Pill { text: "NEW PLUGIN"; accentStyle: true; onActivated: view.mgr.scaffold(scaffoldInput.text, view.newKind) }
        Item { Layout.fillWidth: true }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text { text: "INSTALL FROM GIT"
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 9
            font.bold: true; color: Config.ThemeConfig.colors.textDim }
        Rectangle {
            Layout.preferredWidth: 300; Layout.minimumWidth: 80
            Layout.fillWidth: true; Layout.maximumWidth: 340
            Layout.preferredHeight: 24
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

    // ── status filter ────────────────────────────────────────────────────────
    // statusFilter existed but nothing ever set it — the ERROR view was
    // unreachable and a failed load was only visible as red row text you
    // had to be looking at. The ERROR chip carries the live count.
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                { key: "all", label: "ALL" },
                { key: "enabled", label: "ENABLED" },
                { key: "disabled", label: "DISABLED" },
                { key: "error", label: "ERROR" }
            ]
            Pill {
                readonly property bool isErr: modelData.key === "error"
                text: isErr && view.errorCount > 0 ? "ERROR " + view.errorCount : modelData.label
                accentStyle: view.statusFilter === modelData.key
                // Pill paints danger over accentStyle, so an errored ERROR
                // chip reads red whether or not it's the active filter.
                danger: isErr && view.errorCount > 0
                onActivated: view.statusFilter = modelData.key
            }
        }
        Item { Layout.fillWidth: true }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PLUGIN ROWS — one compact line per plugin (+ its settings form if open)
    // ═════════════════════════════════════════════════════════════════════════
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Config.ControlConfig.radiusCard
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
        border.color: Config.ThemeConfig.colors.outlineVariant
        border.width: 1
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 6
            contentHeight: rows.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: rows
                width: parent.width
                spacing: 2

                Repeater {
                    model: view.visiblePlugins

                    Rectangle {
                        id: row
                        readonly property var plugin: modelData
                        readonly property bool isErr: plugin.status === "error" || plugin.status === "invalid"
                        readonly property bool formOpen: view.settingsOpen === plugin.id
                        width: rows.width
                        height: 34 + (formOpen ? formLoader.implicitHeight + 10 : 0)
                        radius: Config.ControlConfig.radiusSmall
                        color: rowMa.containsMouse || formOpen
                               ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.7)
                               : "transparent"

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        RowLayout {
                            x: 10; width: parent.width - 20; height: 34
                            spacing: 10

                            Rectangle {
                                width: 7; height: 7; radius: 3.5
                                color: row.plugin.enabled
                                       ? (row.isErr ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.success)
                                       : Config.ThemeConfig.colors.textDim
                            }

                            Text {
                                text: row.plugin.name + "  " + row.plugin.version
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                                font.bold: row.plugin.enabled
                                color: row.plugin.enabled ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
                                elide: Text.ElideRight
                                Layout.maximumWidth: 180
                                Layout.minimumWidth: 0
                            }
                            Text {
                                text: row.plugin.id
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                                color: Config.ThemeConfig.colors.textDim
                                elide: Text.ElideRight
                                Layout.maximumWidth: 200
                                Layout.minimumWidth: 0
                            }
                            // where it comes from: user / system / bundled / builtin
                            Text {
                                text: (row.plugin.source || "").toUpperCase()
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                                font.letterSpacing: 0.8
                                color: row.plugin.source === "builtin" ? Config.ControlConfig.accent : Config.ThemeConfig.colors.textDim
                            }
                            Text {
                                visible: row.plugin.commands.length > 0
                                text: "⌗ " + row.plugin.commands.join(" ")
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                                color: Config.ThemeConfig.colors.warning
                                elide: Text.ElideRight
                                Layout.maximumWidth: 120
                                Layout.minimumWidth: 0
                            }
                            Text {
                                visible: row.isErr
                                text: row.plugin.error
                                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                                color: Config.ThemeConfig.colors.error
                                elide: Text.ElideMiddle
                                Layout.maximumWidth: 160
                                Layout.minimumWidth: 0
                            }

                            Item { Layout.fillWidth: true }

                            // bar section — click moves it to the next one (appended)
                            Pill {
                                visible: view.isBarWidget(row.plugin)
                                text: (row.plugin.section || row.plugin.defaultSection || "right").toUpperCase()
                                onActivated: view.mgr.place(row.plugin.id, view.nextSection(row.plugin))
                            }
                            // reorder within the section (the bar clamps at the edges)
                            Pill { visible: view.isBarWidget(row.plugin) && !!row.plugin.section; text: "▲"; onActivated: view.mgr.move(row.plugin.id, -1) }
                            Pill { visible: view.isBarWidget(row.plugin) && !!row.plugin.section; text: "▼"; onActivated: view.mgr.move(row.plugin.id, 1) }

                            Pill {
                                visible: view.hasSettings(row.plugin)
                                text: "⚙"
                                accentStyle: row.formOpen
                                onActivated: view.settingsOpen = row.formOpen ? "" : row.plugin.id
                            }

                            ToggleSwitch {
                                checked: row.plugin.enabled
                                Layout.alignment: Qt.AlignVCenter
                                onToggled: view.mgr.setEnabled(row.plugin.id, !row.plugin.enabled)
                            }

                            // DEL → trash (two-step confirm); built-in/system can't be removed
                            ConfirmDialog {
                                visible: view.removable(row.plugin)
                                label: "DEL"
                                confirmLabel: "SURE?"
                                Layout.alignment: Qt.AlignVCenter
                                onConfirmed: view.mgr.remove(row.plugin.id)
                            }
                        }

                        Loader {
                            id: formLoader
                            x: 28; y: 38
                            width: parent.width - 40
                            active: row.formOpen
                            sourceComponent: SettingsForm { pluginId: row.plugin.id }
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: view.visiblePlugins.length === 0 && !view.mgr.busy
            text: view.mgr.plugins.length === 0
                  ? "// no plugins — is the bar running? (qs -c bar)"
                  : "// no match for this filter"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TRASH — removed plugins, restorable
    // ═════════════════════════════════════════════════════════════════════════
    Rectangle {
        visible: view.mgr.trash.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: trashCol.implicitHeight + 12
        radius: Config.ControlConfig.radiusSmall
        color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.4)
        border.color: Config.ThemeConfig.colors.outlineVariant
        border.width: 1

        Column {
            id: trashCol
            x: 12; y: 6
            width: parent.width - 24
            spacing: 2

            Text {
                text: "TRASH"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 9; font.bold: true
                color: Config.ThemeConfig.colors.textDim
            }
            Repeater {
                model: view.mgr.trash.slice(0, 5)
                RowLayout {
                    width: trashCol.width
                    spacing: 10
                    Text {
                        text: modelData.id
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.text
                    }
                    Text {
                        text: modelData.entry
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                        color: Config.ThemeConfig.colors.textDim
                    }
                    Pill { text: "RESTORE"; onActivated: view.mgr.restore(modelData.entry) }
                }
            }
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
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "New and installed plugins go to " + view.mgr.userDir + "/<author.name>/ · terminal: velocity-plugin help"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.textDim
            elide: Text.ElideRight
        }
    }
}
