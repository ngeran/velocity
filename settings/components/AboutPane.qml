// =============================================================================
// AboutPane.qml — SETTINGS tab's ABOUT / HEALTH pane (P4.9)
// =============================================================================
// One honest health page, four sections, zero private state:
//   RUNTIME CHECK — the LAST tools/check-runtime verdict, read from
//     $XDG_STATE_HOME/velocity/check-runtime.json (FileView, watched — a
//     terminal run updates this page live). The script RESTARTS the bar and
//     this window lives in the bar process, so the page deliberately offers
//     no "run now" button — run it from a terminal.
//   SERVICES — systemd user-unit state for the shells' units (one probe).
//   TOOLS — tools/check-tools verdict + its missing list (parsed verbatim:
//     the tier list lives THERE, never duplicated here).
//   FONTS — fc-list presence probes for the two families the bar names.
//
// All probes are one-shot Processes kicked on first show + the REFRESH pill;
// each renders an honest "—" until its answer lands.
// =============================================================================

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root

    readonly property string _homeDir: ("" + Quickshell.env("HOME"))
    readonly property string statePath:
        (Quickshell.env("XDG_STATE_HOME") || root._homeDir + "/.local/state") + "/velocity/check-runtime.json"
    readonly property string toolsScript: {
        var u = "" + Qt.resolvedUrl("../../tools/check-tools")
        return u.indexOf("file://") === 0 ? u.substring(7) : ""
    }

    // probe results (null = not landed yet → render "…")
    property var lastRun: null            // parsed check-runtime.json
    property bool lastRunMissing: true    // cleared by the first good parse
    property var units: null              // [{name,state,enabled}]
    property var tools: null              // {ok, verdict, missing:[{tool,tier,note}]}
    property var fonts: null              // [{family,found,count}]

    onVisibleChanged: if (visible) root.refreshAll()

    function refreshAll() {
        root._loaded = false
        runFile.reload()
        unitsProc.running = true
        toolsProc.running = true
        fontsProc.running = true
    }

    Component.onCompleted: Services.SearchIndex.register({
        title: "About & Health", tab: "settings", section: "about",
        keywords: "about health runtime check units tools fonts diagnostics", item: null })
    Component.onDestruction: Services.SearchIndex.unregister(this)

    // ── last check-runtime summary ───────────────────────────────────────
    property bool _loaded: false
    function _ingestRun(text) {
        if (root._loaded) return
        root._loaded = true
        try {
            var doc = JSON.parse(text)
            if (!doc || !doc.ts) throw new Error("no ts")
            root.lastRun = doc
            root.lastRunMissing = false
        } catch (e) {
            root.lastRun = null
            root.lastRunMissing = true
        }
    }
    FileView {
        id: runFile
        path: root.statePath
        watchChanges: true
        // A missing/garbage file never flips `loaded`, so lastRunMissing
        // starts TRUE ("no summary yet") and only a good parse clears it.
        onLoadedChanged: if (loaded && !root._loaded) root._ingestRun(text())
        onFileChanged: { root._loaded = false; reload() }
    }

    // ── units probe ──────────────────────────────────────────────────────
    // "name state enabled" lines (is-enabled "not-found"/"" → unknown)
    Process {   // unbounded-ok: one-shot probe on show/refresh
        id: unitsProc
        running: false
        command: ["sh", "-c",
            'for u in quickshell-bar hypridle; do ' +
            'printf "%s %s %s\\n" "$u" "$(systemctl --user is-active "$u" 2>/dev/null)" ' +
            '"$(systemctl --user is-enabled "$u" 2>/dev/null || echo unknown)"; done']
        stdout: SplitParser {
            onRead: function(data) {
                var parts = data.trim().split(/\s+/)
                if (parts.length < 3) return
                var row = { name: parts[0], state: parts[1],
                            enabled: parts[2] === "unknown" ? "unknown" : parts[2] }
                var next = (root.units || []).filter(function(r) { return r.name !== row.name })
                next.push(row)
                root.units = next
            }
        }
    }

    // ── tools probe — run the REAL gate, parse its verdict ───────────────
    Process {   // unbounded-ok: one-shot probe on show/refresh
        id: toolsProc
        running: false
        command: root.toolsScript === "" ? ["true"] : ["bash", root.toolsScript]
        property string _buf: ""
        stdout: SplitParser {
            onRead: function(data) { toolsProc._buf += data + "\n" }
        }
        onExited: function(code) {
            var missing = []
            var lines = toolsProc._buf.split("\n")
            var verdict = ""
            var ok = code === 0
            for (var i = 0; i < lines.length; i++) {
                var ln = lines[i]
                var m = ln.match(/^check-tools: (?:FAIL: (?:required|feature)|warn:) '([^']+)' missing(?: — ([^(]+))?/)
                if (m) {
                    missing.push({ tool: m[1], tier: ln.indexOf("warn:") !== -1 ? "optional" : "feature",
                                   note: (m[2] || "").trim() })
                    continue
                }
                if (ln.indexOf("check-tools: OK") === 0 || ln.indexOf("check-tools: FAIL —") === 0)
                    verdict = ln.replace(/^check-tools: /, "")
            }
            root.tools = { ok: ok, verdict: verdict, missing: missing }
            toolsProc._buf = ""
        }
    }

    // ── fonts probe — the two families the bar names (BarConfig) ─────────
    Process {   // unbounded-ok: one-shot probe on show/refresh
        id: fontsProc
        running: false
        command: ["sh", "-c",
            'command -v fc-list >/dev/null 2>&1 || { echo "err fc-list missing"; exit 0; }; ' +
            'echo "fam JetBrainsMono Nerd Font $(fc-list 2>/dev/null | grep -ci "JetBrainsMono Nerd Font")"; ' +
            'echo "fam Symbols Nerd Font $(fc-list 2>/dev/null | grep -ci "Symbols Nerd Font")"']
        stdout: SplitParser {
            onRead: function(data) {
                var parts = data.trim().split(" ")
                if (parts[0] === "err") {
                    root.fonts = [{ family: parts[1] || "fc-list", found: false, count: 0 }]
                    return
                }
                if (parts[0] !== "fam" || parts.length < 3) return
                var count = parseInt(parts[parts.length - 1], 10)
                var family = parts.slice(1, parts.length - 1).join(" ")
                var next = (root.fonts || []).filter(function(r) { return r.family !== family })
                next.push({ family: family, found: count > 0, count: count })
                root.fonts = next
            }
        }
    }

    // ── presentational helpers ───────────────────────────────────────────
    function _fmt(n) { return n === null || n === undefined ? "…" : String(n) }
    component StatRow: RowLayout {
        property string label: ""
        property string value: "…"
        property string kind: "idle"   // StatusBadge kind for the value chip
        Layout.fillWidth: true
        spacing: Config.ControlConfig.space2
        Text {
            text: label
            color: Config.ThemeConfig.colors.textDim
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
            font.bold: true; font.letterSpacing: 1.0
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            elide: Text.ElideRight
        }
        StatusBadge { label: value; kind: kind }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.ControlConfig.space4
        spacing: Config.ControlConfig.space4

        SettingsHeaderCard {
            Layout.fillWidth: true
            eyebrow: "SETTINGS"; title: "About & Health"
            subtitle: "velocity shell · one bar process (bar + control center + settings + plugins)"
            StatusBadge {
                label: root.lastRun === null ? "NO DATA" : (root.lastRun.ok ? "HEALTHY" : "DEGRADED")
                kind: root.lastRun === null ? "idle" : (root.lastRun.ok ? "ok" : "err")
            }
            Pill { text: "REFRESH"; accentStyle: true; onActivated: root.refreshAll() }
        }

        // ── RUNTIME CHECK (last summary) ─────────────────────────────────
        Card {
            variant: "core"
            Layout.fillWidth: true
            accent: Config.ControlConfig.accent
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.ControlConfig.space2

                SectionHeader {
                    Layout.fillWidth: true
                    title: "Runtime check"
                    value: root.lastRun === null ? "" : root.lastRun.ts
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.lastRun === null
                    text: root.lastRunMissing
                          ? "no summary yet — run tools/check-runtime from a terminal (it restarts the bar, so this page never runs it)"
                          : "reading " + root.statePath + " …"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    wrapMode: Text.Wrap
                }
                StatRow { label: "BOOT WARNINGS"; kind: root.lastRun !== null && Number(root.lastRun.warnings) === 0 ? "ok" : "err"
                          value: root.lastRun === null ? "…" : String(root.lastRun.warnings) }
                StatRow { label: "IDLE CPU"; kind: "idle"
                          value: root.lastRun === null ? "…" : root.lastRun.cpu + "%" }
                StatRow { label: "RSS"; kind: "idle"
                          value: root.lastRun === null ? "…" : root.lastRun.rss }
                StatRow { label: "SPAWNS/MIN"; kind: root.lastRun !== null && Number(root.lastRun.spawns) <= 2 ? "ok" : "warn"
                          value: root.lastRun === null ? "…" : String(root.lastRun.spawns) }
                StatRow { label: "QA SUITE"; kind: root.lastRun !== null && root.lastRun.qa !== "skip" ? "ok" : "warn"
                          value: root.lastRun === null ? "…" : root.lastRun.qa }
            }
        }

        // ── SERVICES ─────────────────────────────────────────────────────
        Card {
            variant: "core"
            Layout.fillWidth: true
            accent: Config.ControlConfig.accent
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.ControlConfig.space2

                SectionHeader { Layout.fillWidth: true; title: "Services" }
                Repeater {
                    model: root.units === null ? [{ name: "…", state: "…", enabled: "…" }] : root.units
                    delegate: RowLayout {
                        property var unit: modelData
                        Layout.fillWidth: true
                        spacing: Config.ControlConfig.space2
                        Text {
                            text: unit.name
                            color: Config.ThemeConfig.colors.text
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 11; font.bold: true
                            Layout.fillWidth: true; Layout.minimumWidth: 0
                            elide: Text.ElideRight
                        }
                        StatusBadge {
                            label: unit.state
                            kind: unit.state === "active" ? "ok" : unit.state === "…" ? "idle" : "err"
                        }
                        StatusBadge {
                            label: unit.enabled === "enabled" ? "enabled"
                                 : unit.enabled === "…" ? "…" : unit.enabled
                            kind: unit.enabled === "enabled" ? "accent" : unit.enabled === "…" ? "idle" : "warn"
                        }
                    }
                }
            }
        }

        // ── TOOLS (check-tools verdict + missing) ────────────────────────
        Card {
            variant: "core"
            Layout.fillWidth: true
            accent: Config.ControlConfig.accent
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.ControlConfig.space2

                SectionHeader {
                    Layout.fillWidth: true
                    title: "Tool closure"
                    value: root.tools === null ? "" : (root.tools.ok ? "complete" : "incomplete")
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.tools === null || root.tools.missing.length === 0
                    text: root.tools === null
                          ? "running tools/check-tools …"
                          : "every gated tool resolves in the session PATH"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                }
                Repeater {
                    model: root.tools === null ? [] : root.tools.missing
                    delegate: RowLayout {
                        property var miss: modelData
                        Layout.fillWidth: true
                        spacing: Config.ControlConfig.space2
                        Text {
                            text: miss.tool
                            color: Config.ThemeConfig.colors.warning
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                            Layout.minimumWidth: 0
                        }
                        Text {
                            text: miss.tier
                            color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                        }
                        Text {
                            text: miss.note
                            color: Config.ThemeConfig.colors.textDim
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true; Layout.minimumWidth: 0
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.tools !== null && root.tools.verdict !== ""
                    text: root.tools === null ? "" : root.tools.verdict
                    color: Config.ThemeConfig.colors.textDim; opacity: 0.7
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
                    wrapMode: Text.Wrap
                }
            }
        }

        // ── FONTS ────────────────────────────────────────────────────────
        Card {
            variant: "core"
            Layout.fillWidth: true
            accent: Config.ControlConfig.accent
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.ControlConfig.space2

                SectionHeader { Layout.fillWidth: true; title: "Fonts" }
                Repeater {
                    model: root.fonts === null
                           ? [{ family: "…", found: false, count: 0 }]
                           : (root.fonts.length === 0 ? [{ family: "…", found: false, count: 0 }] : root.fonts)
                    delegate: StatRow {
                        label: modelData.family
                        value: modelData.found ? modelData.count + " faces" : "MISSING"
                        kind: modelData.found ? "ok" : "err"
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: "the bar names these families (BarConfig fontFamily/fontNerd) — a MISS renders fallback boxes"
                    color: Config.ThemeConfig.colors.textDim; opacity: 0.7
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                }
            }
        }
    }
}
