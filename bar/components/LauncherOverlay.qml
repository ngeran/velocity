// =============================================================================
// LauncherOverlay.qml — the native app launcher (velocity.launcher overlay)
// =============================================================================
// Spotlight-style card dropping from under the bar: a search field over app
// results. Ranking is launcher-search.mjs (ryoku's fuzzy port: prefix >
// substring > subsequence, decayed launch frequency breaks ties — the empty
// query is the "most used" list — and learned search terms act as aliases,
// oma-cast-style). The entries index is Quickshell's native DesktopEntries;
// frecency, learned terms and query history live in LauncherFrecency
// (lib/launcher-frecency.mjs math). ↑ on an empty query recalls history,
// Ctrl+1…9 quick-picks, and a bare query with no app match falls back to a
// web-search row.
//
// Hosted as the overlay plugin velocity.launcher (builtins/): the PluginHost
// claims the PopupCoordinator slot ("overlay:velocity.launcher") off `shown`,
// exactly like the keybinds/logs overlays. Window contract is
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
import Quickshell.Io
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
        _histWalk = -1
        Services.LauncherFrecency.refresh()   // decayed scores sag while closed
        shown = true
        clientsProc.running = true   // one-shot open-windows fetch per open (P7 G1)
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

    // ── providers (P7 G1) ────────────────────────────────────────────────────
    // route() picks the provider off the first character; bare queries rank
    // apps (frecency) and put matching OPEN windows on top. The prefixed
    // providers are single-row (the action row); their results arrive from
    // the probes below.
    readonly property var _route: Launcher.route(root.query)

    // open windows: one `hyprctl -j clients` fetch per launcher open
    property var windowRows: []
    property string _clientsBuf: ""
    Process {   // unbounded-ok: one-shot local IPC query on open — answers in ms
        id: clientsProc
        command: ["bash", "-c", "hyprctl -j clients 2>&1"]
        running: false
        stdout: SplitParser { onRead: function(data) { clientsProc.buffer += data + "\n" } }
        property string buffer: ""
        onRunningChanged: {
            if (running) return
            root.windowRows = Launcher.windowEntries(clientsProc.buffer)
            clientsProc.buffer = ""
        }
    }

    // `=` calculator: qalc -t, debounced 150 ms; a generation guard drops the
    // answer of a superseded expression (qalc always exits 0 — it
    // unit-interprets anything, so the output is shown verbatim).
    property string calcOut: ""
    property int _calcGen: 0
    property string _calcBuf: ""
    Timer { id: calcDebounce; interval: 150; onTriggered: root._runCalc() }
    Process {   // unbounded-ok: one-shot qalc evaluation per debounce tick
        id: calcProc
        property int gen: 0
        command: ["qalc", "-t", ""]
        running: false
        stdout: SplitParser { onRead: function(data) { calcProc.buffer += data + "\n" } }
        property string buffer: ""
        onRunningChanged: {
            if (running) return
            var out = calcProc.buffer
            calcProc.buffer = ""
            if (calcProc.gen !== root._calcGen) return   // superseded keystroke
            root.calcOut = out.trim().split("\n")[0]
        }
    }
    function _runCalc() {
        var expr = _route.arg.trim()
        if (expr.length === 0) { calcOut = ""; return }
        var gen = ++_calcGen
        calcProc.gen = gen
        calcProc.command = ["qalc", "-t", expr]
        calcProc.running = true
    }

    // every provider feeds rows through here (provider rides the row for
    // launch(); _src keeps the source entry — Object.assign copies
    // properties but not methods, so execute() must run on it)
    function _tag(provider, e, extra) {
        var row = Object.assign({ resultKey: Launcher.resultKey(provider, e.id), _provider: provider, _src: e }, e)
        if (extra) Object.assign(row, extra)
        return row
    }

    readonly property var results: {
        var r = _route
        var rows = []
        if (r.provider === "calc") {
            if (root.calcOut.length > 0)
                rows.push(root._tag("calc", { id: r.arg, name: root.calcOut },
                                        { genericName: "= " + r.arg + " — Enter copies" }))
            return rows
        }
        if (r.provider === "shell") {
            if (r.arg.length > 0)
                rows.push(root._tag("shell", { id: r.arg, name: r.arg },
                                    { genericName: "shell command — Enter runs in ghostty" }))
            return rows
        }
        if (r.provider === "web") {
            if (r.arg.length > 0)
                rows.push(root._tag("web", { id: r.arg, name: r.arg },
                                    { genericName: "web search — Enter opens the browser" }))
            return rows
        }
        // apps (+ matching open windows above, non-empty query only) —
        // learned terms ride along as an alias tier (launcher-frecency)
        var q = r.arg.trim()
        if (q.length > 0) {
            var wins = Launcher.rank(root.windowRows, q, {})
            for (var i = 0; i < wins.length && i < 4; i++)
                rows.push(root._tag("windows", wins[i]))
        }
        var apps = Launcher.rank(root.entries, q, Services.LauncherFrecency.usage,
                                 Services.LauncherFrecency.terms)
        for (var j = 0; j < apps.length; j++)
            rows.push(root._tag("apps", apps[j]))
        // web fallback (oma-cast): a bare query that matched no app still has
        // somewhere to go — one dim row reusing the web provider dispatch
        if (q.length > 0 && apps.length === 0)
            rows.push(root._tag("web", { id: q, name: q },
                                 { genericName: "no app match — Enter searches the web" }))
        return rows
    }
    // Re-rank selection — runs ONLY on results re-evaluations, never from
    // onQueryChanged: the results binding re-evaluates AFTER the query's own
    // changed-handler (deferred invalidation), so a reconcile there reads the
    // PREVIOUS rows and onResultsChanged gets the last word with a drifted
    // held index (proven live: "chrom" landed on the app row). A keystroke
    // sets _snapNext: if the held row fell out of the fresh rows, the
    // selection starts at the TOP; async arrivals (qalc answer, the open-
    // windows fetch growing the rows after the fact) keep the hold — without
    // it a selection parked at index -1 on empty rows never picks its row up
    // and Enter launched results[-1] (also proven live).
    property bool _snapNext: false
    onQueryChanged: {
        if (!_recalling) _histWalk = -1
        if (_route.provider === "calc") calcDebounce.restart()
        else if (calcOut !== "") calcOut = ""
        _snapNext = true
    }
    onResultsChanged: {
        _reconcile(_snapNext ? 0 : selection.index)
        _snapNext = false
    }
    function _reconcile(fallbackIdx) {
        var next = Launcher.reconcileSelection(results.slice(0, 12), selection.key, fallbackIdx)
        selection = next
        listScroll.contentY = 0
    }

    // ── search-history recall (oma-cast ↑-on-empty) ──────────────────────────
    // ↑ from an empty query at the top row recalls the most recent query and
    // then walks older (while the selection sits at the top); ↓ walks back
    // toward newer, and one ↓ past the newest clears the query. Any real
    // keystroke exits recall mode — the _recalling guard keeps the
    // programmatic query writes from resetting _histWalk mid-walk.
    property int _histWalk: -1
    property bool _recalling: false
    function _recall(q) {
        _recalling = true
        query = q
        _recalling = false
    }
    function _historyUp() {
        var h = Services.LauncherFrecency.history
        if (h.length === 0) return false
        if (_histWalk >= 0) {
            // index -1 (zero results) must keep walking older; index > 0 means
            // the user moved off the top row — normal nav. Note: after a recall
            // that still matches the previously selected row, reconcile lands
            // mid-list and ↑ resumes normal nav until the row returns to top —
            // same follow-the-row behavior as regular typing, by design.
            if (selection.index > 0) return false
            if (_histWalk > 0) _histWalk--
            _recall(h[_histWalk].q)
            return true
        }
        if (query.length > 0 || selection.index > 0) return false
        _histWalk = h.length - 1
        _recall(h[_histWalk].q)
        return true
    }
    function _historyDown() {
        if (_histWalk < 0) return false
        var h = Services.LauncherFrecency.history
        if (_histWalk < h.length - 1) {
            _histWalk++
            _recall(h[_histWalk].q)
        } else {
            _histWalk = -1
            _recall("")
        }
        return true
    }

    // ── actions ─────────────────────────────────────────────────────────────
    // Provider dispatch. Apps: the source DesktopEntry's pre-parsed command
    // via execDetached. P4.8's naive parse read a nonexistent `.exec` —
    // DesktopEntry exposes execString/command/execute() (qmltypes) — so every
    // click/Enter no-op'd and launcher-usage.json was never written; and
    // execute() itself misreports on this build (see launch()). Windows: the
    // Lua dispatcher focus form proven live in P7 (hl.dsp.focus dropped
    // address:-prefixed targets; bare 0x… does not match). Calc: copy via
    // wl-copy. Shell/web: detached ghostty / browser.
    function launch(entry) {
        if (!entry) return
        var provider = entry._provider || "apps"
        // every launch teaches: apps fold a frecency visit and learn the
        // query as a term; the other providers only remember the query
        // (history) — their ids are ephemeral or not apps
        function _record(id) { Services.LauncherFrecency.recordLaunch(id, root.query) }
        if (provider === "windows") { _record(null); _focusWindow(entry.id); close(); return }
        if (provider === "calc") { _record(null); _copyText(entry.name); close(); return }
        if (provider === "shell") {
            _record(null)
            Quickshell.execDetached(["ghostty", "-e", "bash", "-c", entry.name])
            close(); return
        }
        if (provider === "web") {
            _record(null)
            Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(entry.name)])
            close(); return
        }
        var src = entry._src
        if (!src || typeof src.execString !== "string" || src.execString.length === 0) return
        _record(entry.id)
        // execute() is unusable as a gate on this build: it returned false
        // for ghostty WHILE successfully spawning it (systemd app scope in
        // the journal) and false for blender while spawning nothing — the
        // bool cannot tell refusal from success, so execute()+fallback
        // double-spawned (proven live: photocraft ×2). Launch the entry's
        // pre-parsed argv directly through the execDetached path the shell
        // provider proved; strip Exec field codes the parse may keep.
        var raw = src.command
        var argv = []
        if (raw) for (var i = 0; i < raw.length; i++) {
            var t = String(raw[i])
            if (!/^%[a-zA-Z%]$/.test(t)) argv.push(t)
        }
        if (argv.length > 0)
            Quickshell.execDetached(argv)
        else
            console.warn("[launcher] no runnable command for " + (src.id || entry.id))
        close()
    }

    Process {   // unbounded-ok: one-shot hyprctl dispatch on selection
        id: focusProc
        property string buffer: ""
        running: false
        stdout: SplitParser { onRead: function(data) { focusProc.buffer += data + "\n" } }
        onRunningChanged: {
            if (!running) {
                if (focusProc.buffer.indexOf("ok") !== 0)
                    console.warn("[launcher] window focus dispatch failed: " + focusProc.buffer.trim())
                focusProc.buffer = ""
            }
        }
    }
    function _focusWindow(address) {
        // the \\\" survives both the QML literal AND bash's -c re-quote: Lua
        // must receive window = "address:0x…" (unquoted → <name> expected)
        focusProc.command = ["bash", "-c", 'hyprctl dispatch "hl.dsp.focus({ window = \\"$1\\" })" 2>&1',
                             "bash", "address:" + address]
        focusProc.running = true
    }

    Process {   // unbounded-ok: wl-copy serves the clipboard from a detached child
        id: copyProc
        running: false
    }
    function _copyText(t) {
        copyProc.command = ["sh", "-c", 'printf "%s" "$1" | wl-copy', "copy", String(t)]
        copyProc.running = true
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
                        text: "search · = calc · > shell · ? web"
                        color: Config.ThemeConfig.colors.textDim
                        font: searchInput.font
                        verticalAlignment: Text.AlignVCenter
                    }
                    Keys.onEscapePressed: root.close()
                    Keys.onDownPressed: if (!root._historyDown()) root.moveSelection(1)
                    Keys.onUpPressed: if (!root._historyUp()) root.moveSelection(-1)
                    Keys.onReturnPressed: root.launch(root.results[root.selection.index])
                    Keys.onEnterPressed: root.launch(root.results[root.selection.index])
                    // Ctrl+1…9 quick-pick (oma-cast): launch the nth visible
                    // row. Ctrl+digits have no specific handler above, so the
                    // generic onPressed is the one place to catch them.
                    Keys.onPressed: function(event) {
                        if (event.modifiers & Qt.ControlModifier) {
                            var d = event.key - Qt.Key_0
                            if (d >= 1 && d <= 9 && d <= root.rowCount) {
                                event.accepted = true
                                root.launch(root.results[d - 1])
                            }
                        }
                    }
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
                        text: {
                            var r = root._route
                            if (r.provider === "calc")
                                return r.arg.trim().length === 0 ? "type an expression after =" : "…"
                            if (r.provider === "shell")
                                return r.arg.length === 0 ? "type a command after >" : ""
                            if (r.provider === "web")
                                return r.arg.length === 0 ? "type a search after ?" : ""
                            return root.query.length > 0 ? "no apps match “" + root.query + "”" : "no applications found"
                        }
                        color: Config.ThemeConfig.colors.textDim
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: Config.PopupMetrics.px(11)
                    }
                }
            }
        }
    }
}
