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
// web-search row. Tier 2 (oma-cast): the empty query renders a grouped view
// (FAVORITES / SUGGESTIONS / APPLICATIONS — captions ride the first row of
// each group, never a row of their own), Ctrl+Return runs the selected app's
// first .desktop secondary action, Ctrl+Shift+F pins/unpins, Ctrl+Shift+X
// hides, and typing "hidden" lists hidden apps for unhiding. Tier 4
// (oma-cast): system command rows (settings/lock/suspend/logout/reboot/
// shutdown — the destructive ones arm on a second Enter instead of a
// dialog) rank alongside apps, a web-search row rides under matched
// results, ctrl+K opens the full .desktop action panel, and ctrl+alt+↑↓
// reorders favorites.
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
    // Tier 4: the plugin host injects itself here (built-ins: ctx.host ===
    // the shell root) — the Settings sys row opens the dashboard through it.
    // Null-guarded: the component must not break hosted without a ctx.
    property var ctx: null
    visible: false
    function open() {
        visible = true
        query = ""
        if (_actionPanel) _exitActionPanel()   // a stale panel never survives
        selection = { key: "", index: 0 }
        _histWalk = -1
        _toast = ""       // a copy-failure toast can land after close() (its
        toastTimer.stop() // onExited is async) — never flash it on the next open
        Services.LauncherFrecency.refresh()   // decayed scores sag while closed
        shown = true
        clientsProc.running = true   // one-shot open-windows fetch per open (P7 G1)
        searchInput.forceActiveFocus()
    }
    function close() {
        shown = false
        hideTimer.restart()
        _toast = ""       // the card is going away; a stale toast must not
        toastTimer.stop() // flash on the next open
        _disarmSys()      // an armed power row must not survive the close
    }
    function toggle() { shown ? close() : open() }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    onShownChanged: if (!shown) hideTimer.restart()
    Timer { id: hideTimer; interval: 220; onTriggered: if (!root.shown) root.visible = false }

    // Tier 3 toast (oma-cast): transient failure line in the card footer,
    // 2.5 s auto-clear; ctrl+shift+c copies it through the stdin-safe
    // clipboard path. Toasts only make sense while the card is open — the
    // failure paths that raise one keep the launcher open.
    property string _toast: ""
    Timer { id: toastTimer; interval: 2500; onTriggered: root._toast = "" }
    function _toastMsg(msg) {
        _toast = msg
        toastTimer.restart()
    }

    // ── Tier 4 two-step arm (oma-cast's confirm gate, dialog-free) ──────────
    // Destructive sys rows (reboot/shutdown) fire only on a second Enter
    // within 3 s of the first. Any query change, close, or selection move
    // off the row disarms; the fire path disarms too, so an auto-repeated
    // Enter can at worst re-arm (toast), never double-fire.
    property string _armedSys: ""
    Timer { id: armTimer; interval: 2500; onTriggered: root._disarmSys() }
    function _armSys(entry) {
        _armedSys = entry.id
        armTimer.restart()
        _toastMsg("press enter again to " + String(entry.name || "").toLowerCase())
    }
    function _disarmSys() {
        _armedSys = ""
        armTimer.stop()
        // a disarm makes the armed toast stale advice — drop it (but leave
        // unrelated toasts, e.g. a clipboard failure, their full 2.5 s)
        if (_toast.indexOf("press enter again") === 0) {
            _toast = ""
            toastTimer.stop()
        }
    }

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

    // ── Tier 4 system rows (oma-cast sys commands) ──────────────────────────
    // Static entries ranked alongside apps on NON-EMPTY queries only (never
    // in the empty/hidden views). argv is constant — nothing user-typed ever
    // reaches a spawn. lock = velocity-lock and suspend = systemctl suspend
    // follow the settings tree's sanctioned commands (PowerStrip); logout is
    // Hyprland's own exit dispatch. keywords are ARRAYS (haystacks() reads
    // e.keywords as a list); argv (null on the settings row) is also the
    // sys-row discriminator in the results binding.
    readonly property var _sysEntries: [
        { id: "sys:settings", name: "Settings",
          genericName: "open the settings dashboard",
          keywords: ["settings", "preferences", "config"], argv: null },
        { id: "sys:lock", name: "Lock",
          genericName: "lock the screen",
          keywords: ["lock", "screen"], argv: ["velocity-lock"] },
        { id: "sys:suspend", name: "Suspend",
          genericName: "suspend to memory",
          keywords: ["suspend", "sleep"], argv: ["systemctl", "suspend"] },
        { id: "sys:logout", name: "Log Out",
          genericName: "end the Hyprland session",
          keywords: ["log", "out", "logout"], argv: ["hyprctl", "dispatch", "exit"] },
        { id: "sys:reboot", name: "Reboot",
          genericName: "restart the machine",
          keywords: ["reboot", "restart"],
          argv: ["systemctl", "reboot"], destructive: true },
        { id: "sys:shutdown", name: "Shut Down",
          genericName: "power off the machine",
          keywords: ["shutdown", "poweroff", "off"],
          argv: ["systemctl", "poweroff"], destructive: true }
    ]

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
    // Tier 3 deferred loading (oma-cast): never flash a pending state —
    // warm qalc answers in ~50 ms. Only a pending that is STILL pending
    // after 500 ms (cold qalc loading its definitions for ~0.5–2 s) gets
    // a dim "working" row instead of a stale answer.
    property bool _calcPending: false
    property bool _calcSlow: false
    Timer {
        id: calcSlowTimer
        interval: 500
        onTriggered: if (root._calcPending) root._calcSlow = true
    }
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
            root._calcPending = false
            root._calcSlow = false
            calcSlowTimer.stop()   // bare id: ids are not root properties
            root.calcOut = out.trim().split("\n")[0]
        }
    }
    function _runCalc() {
        var expr = _route.arg.trim()
        if (expr.length === 0) {
            _calcPending = false
            _calcSlow = false
            calcSlowTimer.stop()
            calcOut = ""
            return
        }
        _calcPending = true
        _calcSlow = false
        calcSlowTimer.restart()
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
        if (root._actionPanel) return root._actionRows   // ctrl+k panel view
        var r = _route
        var rows = []
        if (r.provider === "calc") {
            if (root._calcSlow) {
                // >500 ms without an answer: dim working row (its own
                // provider so Enter can't copy the "…" sentinel)
                rows.push(root._tag("calcpending", { id: r.arg, name: "…" },
                                     { genericName: "= " + r.arg + " — working" }))
                return rows
            }
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
        // apps: the empty query is the grouped Tier 2 view (FAVORITES →
        // SUGGESTIONS → APPLICATIONS, launcher-search.mjs); the literal query
        // "hidden" is the unhide listing; anything else ranks hidden-filtered
        // apps (+ matching open windows above) with learned terms as the
        // alias tier
        var q = r.arg.trim()
        var frec = Services.LauncherFrecency
        if (q.length === 0) {
            var groups = Launcher.groupedEmptyView(root.entries, frec.usage,
                                                   frec.favorites, frec.hidden)
            for (var g = 0; g < groups.length; g++)
                rows.push(root._tag("apps", groups[g].entry,
                                    groups[g].section ? { section: groups[g].section } : null))
            return rows
        }
        if (q.toLowerCase() === "hidden") {
            var hid = Launcher.hiddenRows(root.entries, frec.hidden, frec.usage)
            for (var d = 0; d < hid.length; d++)
                rows.push(root._tag("apps", hid[d].entry, {
                    section: hid[d].section,
                    genericName: "hidden — ctrl+shift+x unhides",
                }))
            return rows
        }
        var wins = Launcher.rank(root.windowRows, q, {})
        for (var i = 0; i < wins.length && i < 4; i++)
            rows.push(root._tag("windows", wins[i]))
        // Tier 4: sys rows join the ranked pool on queries (never empty/
        // hidden views); the argv field discriminates them from app rows
        var pool = Launcher.filterHidden(root.entries, frec.hidden).concat(_sysEntries)
        var apps = Launcher.rank(pool, q, frec.usage, frec.terms)
        for (var j = 0; j < apps.length; j++) {
            var e = apps[j]
            if (e.argv !== undefined)
                rows.push(root._tag("sys", e, {
                    // the armed row shows the second-Enter hint in its subtitle
                    genericName: e.genericName
                                 + (root._armedSys === e.id ? " · enter again" : ""),
                }))
            else
                rows.push(root._tag("apps", e))
        }
        // web fallback (oma-cast): a bare query that matched nothing still has
        // somewhere to go — one dim row reusing the web provider dispatch.
        // Tier 4: the same row rides UNDER matched results (oma-cast's
        // fallback-under-results) so searching is always one Enter away.
        if (q.length > 0) {
            if (apps.length === 0)
                rows.push(root._tag("web", { id: q, name: q },
                                     { genericName: "no app match — Enter searches the web" }))
            else
                rows.push(root._tag("web", { id: q, name: q },
                                     { genericName: "search the web — Enter" }))
        }
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
        if (_actionPanel) _exitActionPanel()   // typing exits the panel, keeps editing
        if (_armedSys !== "") _disarmSys()   // typing disarms armed power rows
        if (_route.provider === "calc") calcDebounce.restart()
        else if (calcOut !== "") calcOut = ""
        _snapNext = true
    }
    onResultsChanged: {
        _reconcile(_snapNext ? 0 : selection.index)
        _snapNext = false
    }
    onSelectionChanged: {
        // an armed power row disarms the moment a different row is selected;
        // re-ranks that keep the armed row selected keep the arm (id match)
        if (_armedSys !== "") {
            var e = results[selection.index]
            if (!e || e.id !== _armedSys) _disarmSys()
        }
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

    // ── Tier 2 toggles (oma-cast favorites / hide) ──────────────────────────
    // Apps rows only — windows/calc/shell/web rows have no persistent
    // identity worth pinning. Hiding re-ranks the results immediately (the
    // service property change re-evaluates the binding); the reconcile
    // machinery holds the selection index when the row vanishes.
    function _selectedApp() {
        var e = results[selection.index]
        return e && e._provider === "apps" ? e : null
    }
    function _toggleFavorite() {
        var e = _selectedApp()
        if (e) Services.LauncherFrecency.toggleFavorite(e.id)
    }
    function _toggleHidden() {
        var e = _selectedApp()
        if (e) Services.LauncherFrecency.toggleHidden(e.id)
    }

    // Tier 4 favorites reorder: ctrl+alt+↑/↓ on a pinned row shifts it in
    // the favorites array (moveId clamps at the ends); the selection then
    // FOLLOWS the row — reconcile picks its resultKey up at the new slot
    function _moveSelectedFavorite(delta) {
        var e = results[selection.index]
        if (!e || e._provider !== "apps") return
        if (Services.LauncherFrecency.favorites.indexOf(e.id) === -1) return
        Services.LauncherFrecency.moveFavorite(e.id, delta)
    }

    // ── Tier 4 action panel (oma-cast ctrl+k) ───────────────────────────────
    // ctrl+k on a selected app row with .desktop actions swaps the results
    // for one row per action (ctrl+return runs only the first; this lists
    // ALL of them). Enter runs the action argv and records the APP launch
    // (the panel rides the query that selected the app); Esc exits the
    // panel without closing the launcher; typing exits and keeps editing;
    // ctrl+k toggles. Windows/web/calc are suppressed while the panel is
    // open. Rows without actions: ctrl+k is a swallowed no-op.
    property bool _actionPanel: false
    property var _actionPanelEntry: null   // the app's source DesktopEntry
    readonly property var _actionRows: {
        if (!_actionPanel || !_actionPanelEntry || !_actionPanelEntry.actions) return []
        var rows = []
        var acts = _actionPanelEntry.actions
        for (var i = 0; i < acts.length; i++) {
            var argv = root._execArgv(acts[i].command)
            if (argv.length === 0) continue   // unspawnable actions never list
            rows.push(root._tag("action",
                                { id: _actionPanelEntry.id + "#" + i,
                                  name: String(acts[i].name || ""), argv: argv },
                                { genericName: _actionPanelEntry.name || "" }))
        }
        return rows
    }
    function _enterActionPanel() {
        var e = results[selection.index]
        var src = e && e._provider === "apps" ? e._src : null
        if (!src || !src.actions || src.actions.length === 0) return
        // an entry whose actions are ALL unspawnable would render an empty
        // panel — open only if at least one action produces a runnable argv
        for (var i = 0; i < src.actions.length; i++) {
            if (root._execArgv(src.actions[i].command).length === 0) continue
            _actionPanelEntry = src
            _actionPanel = true
            selection = { key: "", index: 0 }   // panel rows start at the top
            return
        }
    }
    function _exitActionPanel() {
        _actionPanel = false
        _actionPanelEntry = null
        selection = { key: "", index: 0 }
        _snapNext = true   // the restored rows snap selection to the top
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
    //
    // Exec argv pipeline shared by app launches and .desktop secondary
    // actions (Tier 2): command is the pre-parsed argv; strip Exec field
    // codes the parse may keep, execDetached the rest — never execute(),
    // which misreports and double-spawned (P4.8, proven live: photocraft ×2).
    function _execArgv(raw) {
        var argv = []
        if (raw) for (var i = 0; i < raw.length; i++) {
            var t = String(raw[i])
            if (!/^%[a-zA-Z%]$/.test(t)) argv.push(t)
        }
        return argv
    }

    function launch(entry, secondary, confirmed) {
        if (!entry) return
        var provider = entry._provider || "apps"
        // every launch teaches: apps fold a frecency visit and learn the
        // query as a term; the other providers only remember the query
        // (history) — their ids are ephemeral or not apps
        function _record(id) { Services.LauncherFrecency.recordLaunch(id, root.query) }
        if (provider === "windows") { _record(null); _focusWindow(entry.id); close(); return }
        if (provider === "calcpending") {
            _toastMsg("still working — the answer lands in a moment")
            return
        }
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
        // Tier 4 sys rows: settings opens the hosted dashboard through the
        // plugin host; the rest spawn constant argv. Destructive rows fire
        // only on the second KEYBOARD Enter (two-step arm above) —
        // Ctrl+digits and clicks can arm/refresh but never fire them.
        if (provider === "sys") {
            var sys = entry._src || entry
            if (!sys.argv) {
                if (ctx && ctx.host && ctx.host.settingsCall) {
                    _record(entry.id)
                    ctx.host.settingsCall("toggle")
                    close()
                } else {
                    console.warn("[launcher] settings row without a host")
                    _toastMsg("settings unavailable in this host")
                }
                return
            }
            if (sys.destructive) {
                if (_armedSys !== entry.id || !confirmed) { _armSys(entry); return }
            }
            _disarmSys()
            _record(entry.id)
            Quickshell.execDetached(sys.argv)
            close()
            return
        }
        // Tier 4 action panel rows: run the pre-parsed action argv, record
        // the APP launch ("#n" suffix stripped — the id is the entry's)
        if (provider === "action") {
            if (entry.argv && entry.argv.length > 0) {
                _record(String(entry.id).split("#")[0])
                Quickshell.execDetached(entry.argv)
            }
            close()
            return
        }
        var src = entry._src
        if (!src || typeof src.execString !== "string" || src.execString.length === 0) {
            // nothing spawnable — STAY OPEN with a toast (closing would
            // kill the message with the card; journal keeps the detail).
            // Covers no-Exec entries; the argv-empty corner below is the
            // rarer execString-but-unparseable twin.
            console.warn("[launcher] no runnable command for " + (entry.id))
            _toastMsg("no runnable command for " + entry.name)
            return
        }
        // Tier 2 secondary action (oma-cast Ctrl+Enter): the first .desktop
        // action of the selected app; rows without one fall through to a
        // normal launch
        if (secondary && src.actions && src.actions.length > 0) {
            var actArgv = root._execArgv(src.actions[0].command)
            if (actArgv.length > 0) {
                _record(entry.id)
                Quickshell.execDetached(actArgv)
                close()
                return
            }
        }
        _record(entry.id)
        var argv = root._execArgv(src.command)
        if (argv.length > 0) {
            Quickshell.execDetached(argv)
        } else {
            // nothing spawnable — STAY OPEN with a toast (closing would
            // kill the message with the card; journal keeps the detail)
            console.warn("[launcher] no runnable command for " + (src.id || entry.id))
            _toastMsg("no runnable command for " + entry.name)
            return
        }
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

    Process {   // unbounded-ok: wl-copy takes the text on STDIN — user text
        id: copyProc          // never appears in any argv (/proc cmdline is
        running: false        // world-readable). quickshell 0.3 has no
        stdinEnabled: true    // closeStdin: disabling the channel right
        command: ["wl-copy"]  // after the write IS the EOF (oma-cast
        property string text: ""   // ClipboardWriter pattern)
        onStarted: {
            if (text.length > 0) write(text)
            text = ""
            stdinEnabled = false   // → EOF: wl-copy finishes and exits
        }
        onExited: function(code) {
            if (code !== 0) {
                console.warn("[launcher] wl-copy exited with code " + code)
                root._toastMsg("clipboard copy failed")
            }
        }
        // Spawn failure (wl-copy absent from PATH) is undetectable here:
        // quickshell 0.3's Process exposes no errorOccurred signal (runtime-
        // probed: `onErrorOccurred` is a non-existent property, and a missing
        // binary reports neither started nor exited nor running=true) — same
        // silence as every other Process in this repo if wl-copy vanishes.
    }
    function _copyText(t) {
        // an EOF'd wl-copy exits within milliseconds; the only overlapping
        // pair (calc Enter vs a ctrl+shift+c toast copy) copies near-identical
        // text — drop a race instead of queueing it
        if (copyProc.running) return
        copyProc.text = String(t)
        copyProc.stdinEnabled = true   // re-arm: onStarted closed the channel
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
            searchRow.implicitHeight + Config.PopupMetrics.px(24)
            + Math.max(listCol.implicitHeight, hairline.height + Config.PopupMetrics.px(4))
            // the Tier 3 toast footer grows the card while it shows
            + (root._toast.length > 0 ? Config.PopupMetrics.px(16) : 0),
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
                    Keys.onEscapePressed: if (root._actionPanel) root._exitActionPanel(); else root.close()
                    Keys.onDownPressed: {
                        // Tier 4 favorites reorder: ctrl+alt+↑↓ — accept
                        // always (the combo must never scroll), act only on
                        // a real press; specific handlers outrank the
                        // generic Keys.onPressed so this is the only home
                        if ((event.modifiers & Qt.AltModifier)
                            && (event.modifiers & Qt.ControlModifier)) {
                            event.accepted = true
                            if (!event.isAutoRepeat) root._moveSelectedFavorite(1)
                            return
                        }
                        if (!root._historyDown()) root.moveSelection(1)
                    }
                    Keys.onUpPressed: {
                        if ((event.modifiers & Qt.AltModifier)
                            && (event.modifiers & Qt.ControlModifier)) {
                            event.accepted = true
                            if (!event.isAutoRepeat) root._moveSelectedFavorite(-1)
                            return
                        }
                        if (!root._historyUp()) root.moveSelection(-1)
                    }
                    Keys.onReturnPressed: root.launch(root.results[root.selection.index],
                                                      (event.modifiers & Qt.ControlModifier) !== 0, true)
                    Keys.onEnterPressed: root.launch(root.results[root.selection.index],
                                                     (event.modifiers & Qt.ControlModifier) !== 0, true)
                    // Ctrl+1…9 quick-pick (oma-cast): launch the nth visible
                    // row. Ctrl+digits have no specific handler above, so the
                    // generic onPressed is the one place to catch them — and,
                    // since Tier 2, the Ctrl+Shift+F/X favorites/hide toggles.
                    // Tier 3 adds Ctrl+Shift+C: copy the toast (oma-cast's
                    // copy-error affordance) through the stdin-safe path.
                    Keys.onPressed: function(event) {
                        // Tier 4 ctrl+k action panel (oma-cast): toggle on a
                        // selected app row; swallowed even when it's a no-op
                        // (rows without actions) so the k never leaks
                        if ((event.modifiers & Qt.ControlModifier)
                            && !(event.modifiers & Qt.ShiftModifier)
                            && event.key === Qt.Key_K) {
                            event.accepted = true
                            if (event.isAutoRepeat) return
                            if (root._actionPanel) root._exitActionPanel()
                            else root._enterActionPanel()
                            return
                        }
                        if ((event.modifiers & Qt.ControlModifier)
                            && (event.modifiers & Qt.ShiftModifier)
                            && (event.key === Qt.Key_F || event.key === Qt.Key_X
                                || event.key === Qt.Key_C)) {
                            // accept even on auto-repeat — holding the toggle
                            // must not flap favorite/hidden (a disk write per
                            // flip) through the rows it unmasks/remasks, and
                            // Shift+C must never leak a symbol into the query
                            event.accepted = true
                            if (event.isAutoRepeat) return
                            if (event.key === Qt.Key_F) root._toggleFavorite()
                            else if (event.key === Qt.Key_X) root._toggleHidden()
                            else if (root._toast.length > 0) root._copyText(root._toast)
                            return
                        }
                        if (event.modifiers & Qt.ControlModifier) {
                            var d = event.key - Qt.Key_0
                            if (d >= 1 && d <= 9 && d <= root.rowCount) {
                                // Ctrl+(Shift+)digit: always swallow — Shift
                                // must not leak a symbol into the query; the
                                // launch itself stays the no-Shift combo
                                event.accepted = true
                                if (!(event.modifiers & Qt.ShiftModifier))
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
                    var y = listCol.y + rowTop(idx)
                    var h = rowHeightAt(idx)
                    if (y < contentY) contentY = y
                    else if (y + h > contentY + height) contentY = y + h - height
                }
                // Rows are fixed-height (title + subtitle line); Tier 2
                // section heads grow by the caption height. Used for the
                // keyboard-scroll math only.
                readonly property real rowHeightHint: Config.PopupMetrics.px(44)
                readonly property real sectionHeightHint: Config.PopupMetrics.px(22)

                function rowHeightAt(i) {
                    var e = root.results[i]
                    return rowHeightHint + (e && e.section ? sectionHeightHint : 0)
                }
                function rowTop(idx) {
                    var y = 0
                    for (var i = 0; i < idx; i++) y += rowHeightAt(i)
                    return y
                }

                WheelHandler { onWheel: { root._disarmSys(); listScroll.contentY -= wheel.angleDelta.y / 4 } }

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
                            // Tier 2 section captions ride the group's first
                            // row (which grows by the caption height) — never
                            // a row of their own, so selection indices and
                            // resultKey reconcile stay untouched
                            readonly property bool hasSection: !!(row.entry && row.entry.section)
                            readonly property string actionName: {
                                var src = row.entry && row.entry._provider === "apps" ? row.entry._src : null
                                if (!src || !src.actions || src.actions.length === 0) return ""
                                var a = String(src.actions[0].name || "")
                                return a.length > 18 ? a.slice(0, 17) + "…" : a
                            }

                            Layout.fillWidth: true
                            implicitHeight: listScroll.rowHeightHint
                                             + (hasSection ? listScroll.sectionHeightHint : 0)
                            color: selected ? Config.ThemeConfig.colors.surfaceVariant : "transparent"

                            // section caption (FAVORITES / SUGGESTIONS / …)
                            Text {
                                visible: row.hasSection
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.topMargin: Config.PopupMetrics.px(6)
                                anchors.leftMargin: Config.PopupMetrics.px(10)
                                text: row.entry ? (row.entry.section || "") : ""
                                color: Config.ThemeConfig.colors.textDim
                                font.family: Config.BarConfig.fontFamily
                                font.pixelSize: Config.PopupMetrics.px(9)
                                font.letterSpacing: 1.2
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Config.PopupMetrics.px(8)
                                anchors.topMargin: Config.PopupMetrics.px(8)
                                                + (row.hasSection ? listScroll.sectionHeightHint : 0)
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
                                // Tier 2: first .desktop secondary action hint
                                // on the selected app row (Ctrl+Return runs it)
                                Text {
                                    visible: row.selected && row.actionName.length > 0
                                    text: "ctrl+↵ " + row.actionName
                                    color: Config.ThemeConfig.colors.textDim
                                    font.family: Config.BarConfig.fontFamily
                                    font.pixelSize: Config.PopupMetrics.px(10)
                                }
                                Text {
                                    text: "↵"
                                    visible: row.selected
                                    color: Config.ThemeConfig.colors.textDim
                                    font.pixelSize: Config.PopupMetrics.px(11)
                                    font.family: Config.BarConfig.fontFamily
                                }
                            }

                            // Hover selects only on a REAL pointer move
                            // (oma-cast PointerMoveGate): when rows re-rank
                            // under a stationary cursor — typing, pinning,
                            // hiding — the delegate under it must not steal
                            // the keyboard selection. onPositionChanged fires
                            // only on physical movement; containsPointer
                            // alone would flap on every re-layout.
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
            // ---- toast footer (Tier 3): dim failure line + copy hint ----
            Text {
                id: toastRow
                visible: root._toast.length > 0
                Layout.fillWidth: true
                Layout.topMargin: Config.PopupMetrics.px(4)
                Layout.leftMargin: Config.PopupMetrics.px(4)
                Layout.rightMargin: Config.PopupMetrics.px(4)
                text: root._toast + "  ·  ctrl+shift+c copies"
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(10)
                elide: Text.ElideRight
            }
        }
    }
}
