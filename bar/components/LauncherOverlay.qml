// =============================================================================
// LauncherOverlay.qml — the native app launcher (velocity.launcher overlay)
// =============================================================================
// Spotlight-style card dropping from under the bar: a search field over app
// results. Ranking is launcher-search.mjs (ryoku's fuzzy port: prefix >
// substring > subsequence, launch frequency breaks ties — the empty query is
// the "most used" list). The entries index is Quickshell's native
// DesktopEntries; launch frequency lives in LauncherFrecency.
//
// Hosted as the overlay plugin velocity.launcher (builtins/): the PluginHost
// claims the PopupCoordinator slot ("overlay:velocity.launcher") off `shown`,
// exactly like the keybinds/fastfetch/logs overlays. Window contract is
// KeybindsOverlay's (shown / visible + fade-out timer); `focusable: true`
// gives the surface exclusive keyboard focus while mapped, and focus returns
// on unmap — no grab handback machinery needed because the window dies closed.
//
// Rendering doctrine: text-only rows (no theme icon resolution yet), hit
// characters take the accent via segment Texts — RichText was rejected so a
// .desktop name can never inject markup. rofi stays wired as the fallback
// entry point (SUPER+SPACE rebind is an omni-nix decision).
// =============================================================================

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services
import "../lib/launcher-search.mjs" as Launcher

PanelWindow {
    id: root

    property bool shown: false
    visible: false
    function open() {
        visible = true
        query = ""
        selection = { key: "", index: 0 }
        shown = true
        searchInput.forceActiveFocus()
    }
    function close() { shown = false; hideTimer.restart() }
    function toggle() { shown ? close() : open() }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    onShownChanged: if (!shown) hideTimer.restart()
    Timer { id: hideTimer; interval: 220; onTriggered: if (!root.shown) root.visible = false }

    // ── the app index ────────────────────────────────────────────────────────
    // Built imperatively, not as a binding: reading `.values` while the model
    // is mid-init throws ("Model size of -2") and a broken binding stays
    // broken — a declarative version of this list latched empty on first
    // contact. Rebuild on every signal the index can produce.
    property var entries: []
    function _rebuildEntries() {
        var out = []
        try {
            var src = DesktopEntries.applications ? DesktopEntries.applications.values : []
            for (var i = 0; i < src.length; i++)
                if (src[i] && !src[i].noDisplay) out.push(src[i])
        } catch (e) { console.warn("[launcher] entries rebuild failed:", e) }
        entries = out
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root._rebuildEntries() }
    }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root._rebuildEntries() }
    }
    Component.onCompleted: _rebuildEntries()

    // ── query + ranking + selection ─────────────────────────────────────────
    property string query: ""
    property var selection: ({ key: "", index: 0 })
    readonly property int rowCount: Math.min(results.length, 12)
    readonly property var results: {
        var ranked = Launcher.rank(root.entries, root.query, Services.LauncherFrecency.usage)
        for (var i = 0; i < ranked.length; i++)
            ranked[i] = Object.assign({ resultKey: Launcher.resultKey("apps", ranked[i].id) }, ranked[i])
        return ranked
    }
    // Re-rank on query change while holding the selection stable
    // (reconcileSelection: follow the row; if it fell out, hold the index).
    onQueryChanged: {
        var rows = results
        var next = Launcher.reconcileSelection(rows.slice(0, 12), selection.key, selection.index)
        selection = next
        listScroll.contentY = 0
    }

    // ── actions ─────────────────────────────────────────────────────────────
    // Naive Exec parsing: strip % field codes, split on whitespace. DesktopEntry
    // exposes no execute() on this Quickshell build, so launch via execDetached.
    function launch(entry) {
        if (!entry || typeof entry.exec !== "string" || entry.exec.length === 0) return
        var argv = entry.exec.replace(/%[a-zA-Z%]/g, "").trim().split(/\s+/)
        if (argv.length === 0 || argv[0].length === 0) return
        Services.LauncherFrecency.bump(entry.id)
        Quickshell.execDetached(argv)
        close()
    }
    function moveSelection(delta) {
        if (rowCount === 0) return
        var idx = selection.index + delta
        if (idx < 0) idx = rowCount - 1
        if (idx >= rowCount) idx = 0
        selection = { key: results[idx] ? results[idx].resultKey : "", index: idx }
        rowRepeater.itemAt(idx) && listScroll.ensureVisibleRow(idx)
    }

    // ---- dim backdrop (click-outside = close) ----
    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        opacity: root.shown ? 0.35 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ---- the spotlight card ----
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        // Spotlight drops from under a top bar; mirrors above a bottom one.
        y: Config.BarConfig.barAtBottom
          ? parent.height - height - Config.PopupMetrics.px(60)
          : Config.PopupMetrics.px(60)
        width: Math.min(Config.PopupMetrics.px(640), parent.width - Config.PopupMetrics.px(48))
        height: Math.min(
            searchRow.implicitHeight + Config.PopupMetrics.px(24) + Math.max(listCol.implicitHeight, hairline.height + Config.PopupMetrics.px(4)),
            parent.height - Config.PopupMetrics.px(120))
        // Pure black (pixels off on QD-OLED) like every ephemeral card.
        color: "#000000"
        radius: Config.PopupMetrics.px(18)
        clip: true
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.98
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
        Behavior on scale { NumberAnimation { duration: Config.MotionConfig.swap; easing.type: Config.MotionConfig.ease } }

        MouseArea { anchors.fill: parent }   // stop click-through to the backdrop

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.PopupMetrics.px(12)
            spacing: 0

            // ---- search row ----
            RowLayout {
                id: searchRow
                Layout.fillWidth: true
                spacing: Config.PopupMetrics.px(10)
                Text {
                    text: "󰍉"
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: Config.PopupMetrics.px(16)
                    color: Config.BarConfig.colorAccent
                }
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    text: root.query
                    onTextChanged: if (text !== root.query) root.query = text
                    color: Config.ThemeConfig.colors.text
                    selectionColor: Config.BarConfig.colorAccent
                    selectedTextColor: "#000000"
                    font.family: Config.BarConfig.fontFamily
                    font.pixelSize: Config.PopupMetrics.px(16)
                    cursorVisible: root.shown
                    clip: true
                    Text { // placeholder (TextInput has none)
                        anchors.fill: parent
                        visible: searchInput.text.length === 0
                        text: "search apps…"
                        color: Config.ThemeConfig.colors.textDim
                        font: searchInput.font
                        verticalAlignment: Text.AlignVCenter
                    }
                    Keys.onEscapePressed: root.close()
                    Keys.onDownPressed: root.moveSelection(1)
                    Keys.onUpPressed: root.moveSelection(-1)
                    Keys.onReturnPressed: root.launch(root.results[root.selection.index])
                    Keys.onEnterPressed: root.launch(root.results[root.selection.index])
                }
                Text {
                    text: "ESC"
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: Config.PopupMetrics.px(9)
                    font.family: Config.BarConfig.fontFamily
                }
            }

            Rectangle {
                id: hairline
                Layout.fillWidth: true
                Layout.topMargin: Config.PopupMetrics.px(10)
                height: Config.PopupMetrics.hairline(parent)
                color: Config.ThemeConfig.colors.border
            }

            // ---- results ----
            Flickable {
                id: listScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: listCol.implicitHeight
                interactive: false   // keyboard-driven; arrows + wheel only
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                function ensureVisibleRow(idx) {
                    var y = listCol.y + idx * rowHeightHint
                    if (y < contentY) contentY = y
                    else if (y + rowHeightHint > contentY + height) contentY = y + rowHeightHint - height
                }
                // Rows are fixed-height (title + subtitle line); used for the
                // keyboard-scroll math only.
                readonly property real rowHeightHint: Config.PopupMetrics.px(44)

                WheelHandler { onWheel: listScroll.contentY -= wheel.angleDelta.y / 4 }

                ColumnLayout {
                    id: listCol
                    width: listScroll.width
                    spacing: 0

                    Repeater {
                        id: rowRepeater
                        model: Math.min(root.results.length, 12)

                        delegate: Rectangle {
                            id: row
                            // plain property (NOT required): JS-array model
                            property var entry: root.results[index] || null
                            readonly property bool selected: index === root.selection.index

                            Layout.fillWidth: true
                            implicitHeight: listScroll.rowHeightHint
                            color: selected ? Config.ThemeConfig.colors.surfaceVariant : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Config.PopupMetrics.px(8)
                                spacing: Config.PopupMetrics.px(10)

                                // selection tick: a 2px accent bar, dim enough for the doctrine
                                Rectangle {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 2
                                    color: Config.BarConfig.colorAccent
                                    opacity: row.selected ? 0.6 : 0.0
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Repeater {
                                            model: row.entry
                                                   ? Launcher.segments(row.entry.name, Launcher.highlight(row.entry.name, root.query))
                                                   : []
                                            // plain context modelData (JS-array model; a
                                            // `required` declaration here breaks resolution)
                                            Text {
                                                text: modelData.text
                                                color: modelData.hit ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.text
                                                font.family: Config.BarConfig.fontFamily
                                                font.pixelSize: Config.PopupMetrics.px(13)
                                                font.bold: modelData.hit
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: (row.entry ? (row.entry.genericName || "") : "").length > 0
                                        text: row.entry ? (row.entry.genericName || "") : ""
                                        color: Config.ThemeConfig.colors.textDim
                                        font.family: Config.BarConfig.fontFamily
                                        font.pixelSize: Config.PopupMetrics.px(10)
                                        elide: Text.ElideRight
                                    }
                                }
                                Text {
                                    text: "↵"
                                    visible: row.selected
                                    color: Config.ThemeConfig.colors.textDim
                                    font.pixelSize: Config.PopupMetrics.px(11)
                                    font.family: Config.BarConfig.fontFamily
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onPositionChanged: if (!row.selected) {
                                    root.selection = { key: row.entry ? row.entry.resultKey : "", index: index }
                                }
                                onClicked: root.launch(row.entry)
                            }
                        }
                    }

                    // empty state: one dim line, no bright fill (doctrine)
                    Text {
                        visible: root.results.length === 0
                        Layout.fillWidth: true
                        Layout.topMargin: Config.PopupMetrics.px(14)
                        Layout.bottomMargin: Config.PopupMetrics.px(10)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.query.length > 0 ? "no apps match “" + root.query + "”" : "no applications found"
                        color: Config.ThemeConfig.colors.textDim
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: Config.PopupMetrics.px(11)
                    }
                }
            }
        }
    }
}
