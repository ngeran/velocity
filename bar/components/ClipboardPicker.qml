// =============================================================================
// ClipboardPicker.qml — clipboard history picker (velocity.clipboard overlay)
// =============================================================================
// LauncherOverlay's window contract with clipboard rows: a bounded
// `cliphist list` fetch at every open (no refresh timer — copies made while
// open appear on the next open), search filter, Enter pastes into the
// previously-focused window.
//
// Paste sequencing matters: the picker holds exclusive keyboard focus while
// mapped, so `hyprctl dispatch paste` must fire only AFTER close() has
// unmapped the surface and focus returned to the target app (pasteDelayMs
// guards the handback; the copy itself is done by then — wl-copy detaches).
//
// Capture: `wl-paste --watch cliphist store` is armed by the wrapper at
// first open (plugin-lifecycle state, not window state) and lives for the
// bar session — a store that only ran while the picker was open would only
// capture copies made while the picker was open. J8 ledger documents the
// deviation from the spec's letter.
//
// Injection rule: clipboard content NEVER enters a shell string. Pipelines
// interpolate only the numeric row id (re-validated by clip.safeId) and
// paths built from XDG_RUNTIME_DIR, passed as POSITIONAL sh args (the
// SettingsStore write-funnel style).
//
// Image previews are lazy: decoded once per session, only when a row is
// first selected, into $XDG_RUNTIME_DIR/velocity/ — binary bytes never cross
// into QML strings (sh redirect + 5 s reaper).
// =============================================================================

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services
import "../lib/clip.mjs" as Clip
import "../lib/launcher-search.mjs" as Launcher

PanelWindow {
    id: root

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property int pasteDelayMs: 260   // unmap → focus handback → dispatch paste

    property bool shown: false
    visible: false
    function open() {
        visible = true
        query = ""
        listProc.run()
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

    // (capture lives in the wrapper — plugin lifecycle, not window state)

    // ── rows + search + selection ────────────────────────────────────────────
    property string query: ""
    property var allRows: []
    property var selection: ({ key: "", index: 0 })
    readonly property int rowCount: Math.min(results.length, 15)
    readonly property var results: Clip.filterRows(allRows, query).slice(0, 15)

    onQueryChanged: {
        var ids = results.map(function(r) { return r.id })
        var idx = ids.indexOf(selection.key)
        selection = { key: idx >= 0 ? selection.key : (ids[0] || ""), index: idx >= 0 ? idx : 0 }
        listScroll.contentY = 0
    }

    function _select(idx) {
        selection = { key: results[idx] ? results[idx].id : "", index: idx }
        _ensurePreview(results[idx])
    }

    function moveSelection(delta) {
        if (rowCount === 0) return
        var idx = selection.index + delta
        if (idx < 0) idx = rowCount - 1
        if (idx >= rowCount) idx = 0
        _select(idx)
        rowRepeater.itemAt(idx) && listScroll.ensureVisibleRow(idx)
    }

    // ── list fetch (bounded, latest-wins — one per open) ────────────────────
    Services.BoundedProcess {
        id: listProc
        timeoutMs: 3000
        maxBytes: 262144   // 256 KB of list text ≈ thousands of rows
        onDone: function(out, err, code) {
            if (code !== 0) {
                console.warn("[velocity.clipboard] cliphist list failed (" + code + "): " + err.trim())
                return
            }
            root.allRows = Clip.parseRows(out)
            root._select(0)
        }
    }

    // ── paste: copy the selection, close, then dispatch paste ───────────────
    function paste(row) {
        var id = Clip.safeId(row)
        if (id === "") return
        // The id/tab separator is an ARGV element, not "\t" in the script:
        // in a grep BRE "\t" is a literal t (GNU grep warns "stray \") and
        // matches nothing — the whole pipeline went dead silently that way.
        copyProc.command = ["sh", "-c",
            'cliphist list | grep "^$1$2" | cliphist decode | wl-copy',
            "sh", id, "\t"]
        copyProc.run()
    }

    Services.BoundedProcess {
        id: copyProc
        timeoutMs: 5000
        onDone: function(out, err, code) {
            if (code !== 0) {
                console.warn("[velocity.clipboard] wl-copy failed (" + code + "): " + err.trim())
                return
            }
            root.close()
            pasteTimer.restart()
        }
    }
    Timer { id: pasteTimer; interval: root.pasteDelayMs; onTriggered: pasteProc.run() }
    Services.BoundedProcess {
        id: pasteProc
        timeoutMs: 3000
        command: ["hyprctl", "dispatch", "paste"]
        onDone: function(out, err, code) {
            if (code !== 0) console.warn("[velocity.clipboard] dispatch paste failed: " + err.trim())
        }
    }

    // ── lazy image previews (once per session, on selection) ────────────────
    property var _previews: ({})   // id → decoded file path
    function _ensurePreview(row) {
        if (!row || !row.isImage) return
        if (_previews[row.id] !== undefined) return
        var dir = runtimeDir + "/velocity"
        var path = Clip.previewFile(runtimeDir, row.id)
        if (path === "") return
        if (prevProc.running) prevProc.running = false   // command reassign needs a stopped process
        prevProc.command = ["sh", "-c",
            'mkdir -p "$1" && cliphist list | grep "^$2$4" | cliphist decode > "$3"',
            "sh", dir, row.id, path, "\t"]   // real-tab argv (see paste)
        _previewPath = path
        _previewId = row.id
        prevReaper.restart()
        prevProc.running = true
    }
    property string _previewPath: ""
    property string _previewId: ""

    Process {   // unbounded-ok: one-shot with a 5 s reaper; binary stdout stays in sh, never QML
        id: prevProc
        running: false
        onExited: function(code, status) {
            prevReaper.stop()
            if (code !== 0 || root._previewId === "") return
            var m = Object.assign({}, root._previews)
            m[root._previewId] = root._previewPath
            root._previews = m   // reassigned — bindings see the new identity
        }
    }
    Timer { id: prevReaper; interval: 5000; onTriggered: prevProc.running = false }

    // ── window: dim backdrop + card (launcher geometry, pure #000) ──────────
    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        opacity: root.shown ? 0.35 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Config.BarConfig.barAtBottom
          ? parent.height - height - Config.PopupMetrics.px(60)
          : Config.PopupMetrics.px(60)
        width: Math.min(Config.PopupMetrics.px(640), parent.width - Config.PopupMetrics.px(48))
        height: Math.min(
            searchRow.implicitHeight + Config.PopupMetrics.px(24) + Math.max(listCol.implicitHeight, hairline.height + Config.PopupMetrics.px(4)),
            parent.height - Config.PopupMetrics.px(120))
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
                    text: "󰃆"
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
                    Text {
                        anchors.fill: parent
                        visible: searchInput.text.length === 0
                        text: "search clipboard…"
                        color: Config.ThemeConfig.colors.textDim
                        font: searchInput.font
                        verticalAlignment: Text.AlignVCenter
                    }
                    Keys.onEscapePressed: root.close()
                    Keys.onDownPressed: root.moveSelection(1)
                    Keys.onUpPressed: root.moveSelection(-1)
                    Keys.onReturnPressed: root.paste(root.results[root.selection.index])
                    Keys.onEnterPressed: root.paste(root.results[root.selection.index])
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

            // ---- rows ----
            Flickable {
                id: listScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: listCol.implicitHeight
                interactive: false
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                function ensureVisibleRow(idx) {
                    var y = listCol.y + idx * rowHeightHint
                    if (y < contentY) contentY = y
                    else if (y + rowHeightHint > contentY + height) contentY = y + rowHeightHint - height
                }
                readonly property real rowHeightHint: Config.PopupMetrics.px(44)

                WheelHandler { onWheel: listScroll.contentY -= wheel.angleDelta.y / 4 }

                ColumnLayout {
                    id: listCol
                    width: listScroll.width
                    spacing: 0

                    Repeater {
                        id: rowRepeater
                        model: Math.min(root.results.length, 15)

                        delegate: Rectangle {
                            id: row
                            // plain property (NOT required): JS-array model
                            property var entry: root.results[index] || null
                            readonly property bool selected: index === root.selection.index
                            readonly property string previewPath:
                                root._previews[entry ? entry.id : ""] || ""

                            Layout.fillWidth: true
                            implicitHeight: listScroll.rowHeightHint
                            color: selected ? Config.ThemeConfig.colors.surfaceVariant : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Config.PopupMetrics.px(8)
                                spacing: Config.PopupMetrics.px(10)

                                Rectangle {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 2
                                    color: Config.BarConfig.colorAccent
                                    opacity: row.selected ? 0.6 : 0.0
                                }

                                // thumbnail slot: decoded image once lazy, kind glyph otherwise
                                Item {
                                    Layout.preferredWidth: Config.PopupMetrics.px(36)
                                    Layout.fillHeight: true
                                    Image {
                                        id: thumb
                                        anchors.centerIn: parent
                                        width: Config.PopupMetrics.px(36)
                                        height: Config.PopupMetrics.px(36)
                                        visible: row.entry && row.entry.isImage && row.previewPath !== ""
                                        source: visible ? row.previewPath : ""
                                        asynchronous: true
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !thumb.visible
                                        text: row.entry && row.entry.isImage ? "󰈃" : "󰆏"
                                        font.family: Config.BarConfig.fontNerd
                                        font.pixelSize: Config.PopupMetrics.px(15)
                                        color: Config.ThemeConfig.colors.textDim
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Repeater {
                                            model: row.entry
                                                   ? Launcher.segments(row.entry.preview,
                                                       Launcher.highlight(row.entry.preview, root.query))
                                                   : []
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
                                        visible: row.entry ? row.entry.isImage : false
                                        text: row.entry ? (row.entry.mime + (row.entry.size ? " · " + row.entry.size : "")) : ""
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
                                onPositionChanged: if (!row.selected) root._select(index)
                                onClicked: root.paste(row.entry)
                            }
                        }
                    }

                    // empty states: dim lines, no bright fill (doctrine)
                    Text {
                        visible: root.results.length === 0
                        Layout.fillWidth: true
                        Layout.topMargin: Config.PopupMetrics.px(14)
                        Layout.bottomMargin: Config.PopupMetrics.px(10)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.allRows.length === 0
                              ? "clipboard history is empty — copy something first"
                              : "no entries match “" + root.query + "”"
                        color: Config.ThemeConfig.colors.textDim
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: Config.PopupMetrics.px(11)
                    }
                }
            }
        }
    }
}
