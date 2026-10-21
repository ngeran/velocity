// =============================================================================
// nikos.keyboard — keyboard layout pill + layout service (plugin api 2)
// =============================================================================
// Full port of Keyboard-Layout-for-Omarchy v1.2.6 (MIT) onto this shell's
// plugin contract. The pill root doubles as the service (single monitor here;
// switching is idempotent across instances anyway — absolute-index batch).
//
//   state    hyprctl -j devices → typed keyboards, active keymap/index;
//            `activelayout>>` events from ctx.events (the bar owns the ONE
//            socket2 consumer) name the keyboard being typed on
//   file     ~/.omni-nix/configs/hypr/look-and-feel.lua — read/written ONLY
//            through perl/InputLua.pl (Lua-aware scanner, surgical string
//            replacement, rotating backups). NEVER the store symlinks in
//            ~/.config/hypr.
//   effective hyprctl -j --batch getoption input:{kb_layout,kb_variant,
//            kb_options}; the file wins for keys it sets, effective fills
//            the rest
//   switch   hyprctl --batch "switchxkblayout <dev> <abs-index>; …" — EVERY
//            typed keyboard to the same absolute index (devices never drift)
//   apply    InputLua.pl write (backup + optimistic lock) → git add (omni-nix
//            tracks the file; unstaged edits get reverted by deploy sync) →
//            hyprctl eval "hl.config({ input = { … } })" for live apply.
//            NEVER hyprctl reload (reverts to login-time values) and NEVER
//            hyprctl keyword (refused by the Lua wrapper, silent no-op).
//   catalog  xkeyboard-config's evdev.xml (xkbcli is not in the closure)
//   prefs    ~/.cache/quickshell/keyboard-layout/config.json {osd, highlight}
//
// IPC routes through the host's `keyboard` target (shell.qml): next / prev /
// set / status / open — plugins do not register their own IpcHandlers here.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import "./lib/KeyboardLogic.mjs" as Logic

Item {
    id: root

    property var ctx: null

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string luaPath: homeDir + "/.omni-nix/configs/hypr/look-and-feel.lua"
    readonly property string omniDir: homeDir + "/.omni-nix"
    readonly property string configDir: homeDir + "/.cache/quickshell/keyboard-layout"
    readonly property string backupDir: configDir + "/backups"
    readonly property string configPath: configDir + "/config.json"

    function scriptPath(name) {
        // Qt.resolvedUrl yields a QUrl — String() it before .replace.
        return decodeURIComponent(String(Qt.resolvedUrl(name)).replace(/^file:\/\//, ""))
    }

    // ── prefs ────────────────────────────────────────────────────────────────
    property bool prefOsd: false
    property bool prefHighlight: false

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: false
        atomicWrites: true
        printErrors: false
        onLoaded: {
            var r = Logic.parseConfig(text() || "{}")
            if (r.ok) {
                // Content-diff before assign — reassigning equal content still
                // resets every binding that reads these (codebase trap).
                if (root.prefOsd !== r.value.osd) root.prefOsd = r.value.osd
                if (root.prefHighlight !== r.value.highlight) root.prefHighlight = r.value.highlight
            }
        }
    }

    function savePrefs() {
        configFile.setText(Logic.configText({ osd: root.prefOsd, highlight: root.prefHighlight }))
    }

    // ── state ────────────────────────────────────────────────────────────────
    property var fileLua: null          // Logic.parseLua().value
    property var effective: null        // Logic.parseEffective().value
    property var keyboards: []          // typed keyboards [{name,keymap,index,main}]
    property string keyboardName: ""
    property string currentKeymap: ""
    property int currentIndex: 0
    property string namedByEvent: ""    // keyboard the last activelayout named
    property double ownSwitchUntil: 0   // ignore self-inflicted event attribution
    property string lastError: ""
    property string lastAction: ""

    // layout catalog {briefs, entries} — evdev.xml parsed once
    property var catalog: null

    readonly property var layouts: fileLua ? fileLua.layouts : []
    readonly property int layoutCount: layouts.length
    readonly property bool onMainLayout: currentIndex === 0
    readonly property bool ready: currentKeymap !== "" && layoutCount > 0

    // Short bar label: catalog brief for the keymap description ("English
    // (US)" → "en"), else the first word. Uppercased, capped at 3 chars.
    function shortLabel(keymap) {
        var km = String(keymap || "")
        if (catalog && catalog.briefs["$" + km] !== undefined) {
            var brief = catalog.briefs["$" + km].split("-")[0]
            if (brief !== "") return brief.slice(0, 3).toUpperCase()
        }
        var word = km.split(/[ (]/)[0]
        return word === "" ? "⌨" : word.slice(0, 3).toUpperCase()
    }
    readonly property string abbr: shortLabel(currentKeymap)

    // ── pill (hover-reveal idiom: glyph at rest, abbr on hover) ─────────────
    readonly property bool hot: mouseArea.containsMouse
    readonly property bool accentOn: prefHighlight && !onMainLayout && ready

    implicitWidth: pillRow.implicitWidth
    height: ctx ? ctx.bar.barHeight : 30
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    function toggle() { panel.toggle() }
    function open()   { panel.open() }
    function close()  { panel.close() }
    // manifest.ipc verbs: plugins call nikos.keyboard <next|prev|main|set|status|open|toggle> "<arg>"
    function next()   { requestSwitch("next") }
    function prev()   { requestSwitch("prev") }
    function mainLayout() { requestSwitch(0) }
    function main()   { mainLayout() }
    function setLayout(argument) {
        var idx = Logic.resolveSetTarget(argument, layouts)
        if (idx < 0) { lastError = "unknown layout: " + argument; return "unknown layout: " + argument }
        requestSwitch(idx)
        return "ok"
    }
    // index ("1"), layout ("gr") or spec ("gr(polytonic)")
    function set(argument) { return setLayout(argument) }
    function status() { return statusJson() }

    function statusJson() {
        return JSON.stringify({
            keyboard: keyboardName,
            keyboards: keyboards.map(function(k) { return k.name }),
            keymap: currentKeymap,
            abbr: abbr,
            index: currentIndex,
            layouts: layouts.map(Logic.layoutSpec),
            options: fileLua ? fileLua.options : [],
            hotkey: fileLua ? fileLua.hotkey : "none",
            led: fileLua ? fileLua.led : false,
            fromDefaults: fileLua ? !fileLua.hasLayout : true,
            osd: prefOsd,
            highlight: prefHighlight,
            lastError: lastError
        })
    }

    Row {
        id: pillRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.hot ? 6 : 0

        Text {
            text: "󰌌"   // nf-md-keyboard
            font.family: ctx ? ctx.bar.fontNerd : "monospace"
            font.pixelSize: ctx ? ctx.bar.fontSizeIcon : 13
            color: root.accentOn ? ctx.theme.colors.accent
                 : (root.hot ? ctx.theme.colors.accent
                             : (ctx ? ctx.bar.colorText : "#888"))
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            visible: root.hot
            text: root.abbr
            font.family: ctx ? ctx.bar.fontFamily : "monospace"
            font.pixelSize: ctx ? ctx.bar.fontSizeLabel : 11
            font.weight: Font.Bold
            color: ctx ? ctx.theme.colors.text : "#aaa"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        property double lastWheel: 0

        onClicked: function(mouse) {
            // Left = quick switch (EN ↔ GR); right = the layout manager panel.
            if (!root.ready && mouse.button !== Qt.RightButton) return
            if (mouse.button === Qt.LeftButton) root.next()
            else if (mouse.button === Qt.RightButton) root.toggle()
            else if (mouse.button === Qt.MiddleButton) root.mainLayout()
        }
        onWheel: function(wheel) {
            if (!root.ready) return
            var now = Date.now()
            if (now - lastWheel < 150) return   // one flick = one layout
            lastWheel = now
            var delta = wheel.angleDelta.y || wheel.angleDelta.x
            if (delta < 0) root.next()
            else if (delta > 0) root.prev()
        }
    }

    // ── panel ────────────────────────────────────────────────────────────────
    PluginPopup {
        id: panel
        ctx: root.ctx
        anchorItem: root
        title: "KEYBOARD"
        icon: "󰌌"
        contentWidth: 700

        Loader {
            active: root.ctx !== null
            // Stretch to the body slot — without this the loaded ColumnLayout
            // collapses to its implicit (~440px) width and the three columns
            // crush into overlapping text.
            Layout.fillWidth: true
            source: Qt.resolvedUrl("Panel.qml")
            onLoaded: {
                item.service = root
                item.ctx = root.ctx
            }
        }
    }

    // ── events (the bar's single socket2 consumer, via ctx.events) ──────────
    Connections {
        target: root.ctx ? root.ctx.events : null
        function onHyprEvent(line) {
            var ev = "" + line
            if (ev.indexOf("activelayout>>") === 0) {
                var parsed = Logic.parseLayoutEventData(ev.slice("activelayout>>".length))
                if (!parsed) return
                // Within ownSwitchUntil these events are the batch echo, not
                // someone typing — don't re-attribute the tracked keyboard.
                if (Date.now() > root.ownSwitchUntil || parsed.name === root.keyboardName)
                    root.namedByEvent = parsed.name
                // Instant label update; the settle re-probe fixes the index.
                if (parsed.name === root.keyboardName || root.keyboardName === "") {
                    if (root.currentKeymap !== parsed.keymap) {
                        root.currentKeymap = parsed.keymap
                        if (root.prefOsd && root.ctx && root.ctx.osd)
                            root.ctx.osd.showLayout(root.shortLabel(parsed.keymap))
                    }
                }
                settleTimer.restart()
            } else if (ev.indexOf("configreloaded") === 0) {
                root.refresh(true)
                root.requestEffectiveRead()
            }
        }
    }

    Timer { id: settleTimer; interval: 150; onTriggered: root.refresh() }

    // ── probes ───────────────────────────────────────────────────────────────
    function refresh(reloadFile) {
        if (!devicesProc.running) devicesProc.running = true
        if (reloadFile && !fileReadProc.running) fileReadProc.running = true
    }

    Process {   // unbounded-ok: one-shot local hyprctl probe
        id: devicesProc
        command: ["hyprctl", "-j", "devices"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { devicesProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            root.applyDevices(Logic.parseDevices(devicesProc.buffer, root.namedByEvent))
            devicesProc.buffer = ""
            if (devicesProc.pendingSwitch !== "") {
                var act = devicesProc.pendingSwitch
                devicesProc.pendingSwitch = ""
                root.performSwitch(act)
            }
        }
        property string pendingSwitch: ""
    }

    Process {   // unbounded-ok: one-shot local hyprctl probe
        id: effectiveProc
        command: []
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { effectiveProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            root.applyEffective(Logic.parseEffective(effectiveProc.buffer))
            effectiveProc.buffer = ""
        }
    }

    function requestEffectiveRead() {
        if (!effectiveProc.running)
            effectiveProc.command = ["hyprctl", "-j", "--batch",
                "getoption input:kb_layout ; getoption input:kb_variant ; getoption input:kb_options"]
        if (effectiveProc.command.length) effectiveProc.running = true
    }

    Process {   // unbounded-ok: one-shot local perl reader
        id: fileReadProc
        command: ["timeout", "5", "perl", root.scriptPath("perl/InputLua.pl"),
                  "read", root.luaPath, String(Logic.INPUT_MAX_BYTES)]
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { fileReadProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            var r = Logic.parseLua(fileReadProc.buffer)
            fileReadProc.buffer = ""
            if (r.ok) {
                root.fileLua = r.value
                // A restore lands through here: apply the RESTORED values
                // live (the last apply's eval payload is stale by then).
                if (root.restorePendingApply) {
                    root.restorePendingApply = false
                    root.evalProc.lua = root.evalLuaFromFile(r.value)
                    if (root.evalProc.lua !== "") evalTimer.restart()
                    else root.lastBackupAction = "Restored (nothing live to apply)"
                }
            } else if (!root.fileLua) root.fileLua = { layouts: [], options: [], hotkey: "none",
                                                       led: false, hasLayout: false,
                                                       hasVariant: false, hasOptions: false }
        }
    }

    // Live-apply expression built from a parsed file (post-restore path).
    function evalLuaFromFile(fl) {
        var parts = []
        if (fl.hasLayout)
            parts.push("kb_layout = \"" + fl.layouts.map(function(e) { return e.layout }).join(",") + "\"")
        if (fl.hasVariant) {
            var vs = fl.layouts.map(function(e) { return e.variant }).join(",")
            parts.push("kb_variant = \"" + vs + "\"")
        }
        if (fl.hasOptions)
            parts.push("kb_options = \"" + fl.options.join(",") + "\"")
        return parts.length ? "hl.config({ input = { " + parts.join(", ") + " } })" : ""
    }

    // Catalog: newest xkeyboard-config evdev.xml in the store, read bounded.
    Process {   // unbounded-ok: one-shot local probe, head-capped
        id: catalogProc
        command: ["sh", "-c",
            "F=$(ls -t /nix/store/*xkeyboard-config*/share/X11/xkb/rules/evdev.xml 2>/dev/null | head -1); " +
            "[ -n \"$F\" ] && head -c " + Logic.XKB_MAX_BYTES + " \"$F\""]
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { catalogProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            if (catalogProc.buffer !== "") {
                var r = Logic.parseCatalogEvdev(catalogProc.buffer)
                if (r.ok) root.catalog = r.value
            }
            catalogProc.buffer = ""
        }
    }

    // ── apply: probes → state (file wins for keys it sets) ──────────────────
    function applyDevices(r) {
        if (!r.ok) { lastError = r.error; return }
        lastError = ""
        // Content-diff: reassigning equal arrays resets Repeater delegates.
        if (JSON.stringify(r.value.keyboards) !== JSON.stringify(keyboards))
            keyboards = r.value.keyboards
        if (keyboardName !== r.value.keyboardName) keyboardName = r.value.keyboardName
        if (currentIndex !== r.value.currentIndex) currentIndex = r.value.currentIndex
        if (currentKeymap !== r.value.currentKeymap) {
            currentKeymap = r.value.currentKeymap
            if (ready && prefOsd && ctx && ctx.osd) ctx.osd.showLayout(abbr)
        }
    }

    function applyEffective(r) {
        if (r.ok) effective = r.value
    }

    // The settings the panel edits: the file's live keys, effective values
    // for keys the file does not set (defaults show through, honestly).
    readonly property var derivedSettings: {
        var fl = fileLua, ef = effective
        if (!fl) return null
        return {
            layouts: (fl.hasLayout || !ef) ? fl.layouts : ef.layouts,
            options: fl.hasOptions ? fl.options : (ef ? ef.options : []),
            hotkey: fl.hasOptions ? fl.hotkey : (ef ? ef.hotkey : "none"),
            led: fl.hasOptions ? fl.led : (ef ? ef.led : false),
            variantNeeded: fl.hasVariant || (ef ? ef.variantSet : false)
        }
    }

    // ── switching ────────────────────────────────────────────────────────────
    function requestSwitch(action) {
        if (layoutCount < 2) { lastError = "Add a second layout in the panel first"; return }
        if (action === "next" || action === "prev") {
            devicesProc.pendingSwitch = action
            if (!devicesProc.running) devicesProc.running = true
            return
        }
        performSwitch(action)
    }

    function performSwitch(action) {
        var target = Logic.targetIndex(currentIndex, layoutCount, action)
        if (target < 0) return
        currentIndex = target   // optimistic; activelayout events confirm
        if (prefOsd && ctx && ctx.osd)
            ctx.osd.showLayout(shortLabel(currentKeymapOf(target)))
        var batch = Logic.switchBatch(keyboards, target)
        if (batch === "") return
        ownSwitchUntil = Date.now() + 500
        switchProc.command = ["hyprctl", "--batch", batch]
        switchProc.running = true
    }

    function currentKeymapOf(index) {
        // Best-effort label for the optimistic OSD: the brief of the target
        // spec when the catalog knows it, else the current keymap.
        var spec = Logic.layoutSpec(layouts[index])
        if (catalog) {
            for (var i = 0; i < catalog.entries.length; i++)
                if (catalog.entries[i].layout + (catalog.entries[i].variant ? "(" + catalog.entries[i].variant + ")" : "") === spec)
                    return catalog.entries[i].description
        }
        return spec
    }

    Process {   // unbounded-ok: one-shot local hyprctl call
        id: switchProc
        command: []
        onRunningChanged: if (!running) settleTimer.restart()
    }

    // ── apply pipeline (panel Apply button) ──────────────────────────────────
    // writeArguments → InputLua.pl write → git add → hyprctl eval → re-probe.
    readonly property bool applying: applyProc.running
    function applySettings(layoutList, hotkey, useLed) {
        if (applyProc.running) { lastError = "A write is already in progress"; return }
        var ds = derivedSettings
        if (!ds) { lastError = "Still reading the current settings"; return }
        var r = Logic.writeArguments(layoutList, hotkey, useLed, ds.hotkey,
                                     fileLua.hasOptions ? fileLua.options : null,
                                     effective ? effective.options : [],
                                     ds.variantNeeded)
        if (!r.ok) { lastError = r.error; return }

        applyProc.layouts = r.value.layouts
        applyProc.variants = r.value.variants
        applyProc.options = r.value.options
        lastError = ""
        lastAction = "Saving…"
        applyProc.command = ["timeout", "10", "perl", root.scriptPath("perl/InputLua.pl"),
                             "write", root.luaPath, String(Logic.INPUT_MAX_BYTES),
                             root.backupDir, r.value.layouts, r.value.variants,
                             r.value.options, r.value.expected]
        applyProc.running = true
    }

    Process {   // unbounded-ok: one-shot local perl writer
        id: applyProc
        command: []
        property string layouts: ""
        property string variants: "-"
        property string options: ""
        property string buffer: ""
        stderr: SplitParser { onRead: function(d) { applyProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            var err = applyProc.buffer.trim()
            applyProc.buffer = ""
            if (err !== "") {   // exit-code paths all print to stderr
                lastError = "Apply failed: " + err
                lastAction = ""
                return
            }
            // Stage immediately — omni-nix tracks the file and deploy sync
            // reverts unstaged edits. The panel tells the user to commit.
            gitAddProc.running = true
            lastAction = "Saved to look-and-feel.lua — applying…"
            evalProc.lua = "hl.config({ input = { kb_layout = \"" + applyProc.layouts + "\"" +
                (applyProc.variants === "-" ? "" : ", kb_variant = \"" + applyProc.variants + "\"") +
                ", kb_options = \"" + applyProc.options + "\" } })"
            evalTimer.restart()
        }
    }

    Process { id: gitAddProc; command: ["git", "-C", root.omniDir, "add", "configs/hypr/look-and-feel.lua"] }   // unbounded-ok: one-shot local git add

    Process {   // unbounded-ok: one-shot local hyprctl eval
        id: evalProc
        command: []
        property string lua: ""
        onRunningChanged: {
            if (!running) {
                lastAction = "Applied live — commit ~/.omni-nix to persist across deploys"
                refresh(true)
                requestEffectiveRead()
            }
        }
    }
    Timer {
        id: evalTimer
        interval: 400   // let the write land before eval reads it
        onTriggered: {
            evalProc.command = ["hyprctl", "eval", evalProc.lua]
            evalProc.running = true
        }
    }

    // ── backups ──────────────────────────────────────────────────────────────
    property var backups: []
    property string lastBackupAction: ""

    function listBackups() {
        if (!backupsProc.running) backupsProc.running = true
    }
    Process {   // unbounded-ok: one-shot local perl listing
        id: backupsProc
        command: ["timeout", "10", "perl", root.scriptPath("perl/InputLua.pl"),
                  "backups", root.luaPath, String(Logic.BACKUPS_MAX_BYTES), root.backupDir]
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { backupsProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            var r = Logic.parseBackups(backupsProc.buffer)
            backupsProc.buffer = ""
            if (r.ok) {
                if (JSON.stringify(r.value) !== JSON.stringify(backups)) backups = r.value
            }
        }
    }

    function backupNow() {
        if (manualBackupProc.running) return
        lastBackupAction = "Backing up…"
        manualBackupProc.running = true
    }
    Process {   // unbounded-ok: one-shot local perl backup
        id: manualBackupProc
        command: ["timeout", "10", "perl", root.scriptPath("perl/InputLua.pl"),
                  "backup", root.luaPath, String(Logic.INPUT_MAX_BYTES), root.backupDir]
        property string buffer: ""
        stdout: SplitParser { onRead: function(d) { manualBackupProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            var out = manualBackupProc.buffer.trim()
            manualBackupProc.buffer = ""
            try {
                var j = JSON.parse(out)
                lastBackupAction = j.created ? "Backed up as " + j.id : "Unchanged since the newest backup"
            } catch (e) { lastBackupAction = "Backup failed" }
            listBackups()
        }
    }

    property bool restorePendingApply: false

    function restoreBackup(id) {
        if (!Logic.isBackupId(id)) return
        var known = false
        for (var i = 0; i < backups.length; i++) if (backups[i].id === id) { known = true; break }
        if (!known) return
        if (restoreProc.running) return
        restoreProc.id = id
        lastBackupAction = "Restoring " + id + "…"
        restoreProc.running = true
    }
    Process {   // unbounded-ok: one-shot local perl restore
        id: restoreProc
        command: []
        property string id: ""
        property string buffer: ""
        stderr: SplitParser { onRead: function(d) { restoreProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            var err = restoreProc.buffer.trim()
            restoreProc.buffer = ""
            if (err !== "") { lastBackupAction = "Restore failed: " + err; return }
            // The file changed under us; the file read routes the follow-up
            // live-apply (evalLuaFromFile) so the restored values take effect.
            root.restorePendingApply = true
            refresh(true)
        }
    }

    function openBackupFolder() {
        Qt.openUrlExternally("file://" + root.backupDir)
    }

    // ── lifecycle ────────────────────────────────────────────────────────────
    Component.onCompleted: {
        configFile.reload()
        root.refresh(true)
        root.requestEffectiveRead()
        catalogProc.running = true
        listBackups()
    }
}
