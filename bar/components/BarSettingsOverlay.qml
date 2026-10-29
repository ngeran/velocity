// =============================================================================
// BarSettingsOverlay.qml — the bar-settings reveal (C4 · velocity.bar-settings)
// =============================================================================
// The logo's left click opens this card (its right click keeps fastfetch).
// In-bar surface for the BAR's own settings, orpheus-style:
//
//   STYLE     every scanned style (bar/styles/*/Scene.qml) as a card — a pick
//             swaps the bar live. The pick is routed THROUGH the settings
//             process (`SettingsWindow.setBarStyle`) so the settings app stays
//             bar-config.json's single writer: the write lands via its proven
//             funnel (extras merge → atomic write → `config reload` nudge) and
//             a later settings-side save can't clobber a bar-side pick. Active
//             state reads the bar's own BarConfig — disk truth, never an
//             optimistic guess.
//   POSITION  top/bottom edge pills, same routing (`setBarPosition`).
//   HEIGHT    slider (drafts locally, commits on release — one fork per
//             drag, not per tick), routed via `setBarHeight`.
//   DOTS      workspace-count pills, routed via `setWorkspaceCount`.
//   GUARD     QD-OLED burn-guard pills — STRIPS (`setBurnGuard strip …`,
//             the shared BurnOrbit on vector/notch/ryoku) and ISLAND (its
//             own dim+orbit knob, shown only while the island style is
//             active). Both routed through the same funnel.
//   MODULES   the plugin engine is IN this process: enable/disable and section
//             placement call PluginRegistry directly (the bar is
//             plugins-state.json's only writer — no fork, no drift). Rows are
//             rebuilt imperatively after every action (array-identity law).
//   PLUGINS › deep link to Settings ▸ Plugins for ordering, per-plugin
//             settings forms and everything beyond quick toggles.
//
// This is the ONE bar-settings surface (the Settings ▸ Bar pane was removed
// in the consolidation) — everything bar-shaped lives here.
//
// Window chrome is the shared OverlayShell (DU11 — was the KeybindsOverlay
// pattern inline): dim backdrop, centered black card, Esc/outside-click close,
// focusable while mapped. Ephemeral — still no bright fills: the accent
// appears as text and borders only (QD-OLED doctrine).
// =============================================================================
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import "../config" as Config
import "../engine" as Engine
import "../services" as Services

OverlayShell {
    id: root

    cardWidth: 560
    cardHeight: 640

    onAboutToOpen: {
        _scanStyles()
        _refresh()
        _heightDraft = Config.BarConfig.barHeight
        _heightCommitted = Config.BarConfig.barHeight
    }

    // Re-seed the draft when BarConfig reloads under us while the card is open
    // (a settings-side save, another host's pick) — never mid-drag (P1.5).
    Connections {
        target: Config.BarConfig
        function onBarHeightChanged() {
            if (!root.shown || heightSlider.pressed) return
            root._heightDraft = Config.BarConfig.barHeight
            root._heightCommitted = Config.BarConfig.barHeight
        }
    }

    // ---- state (rebuilt imperatively — no cross-object bindings) ----
    // _styles seeds with the built-in set (P1.3): the directory scan needs the
    // repo on disk at the deployed path — under `qs -p` (or a moved checkout)
    // it finds nothing and the pre-P1 empty list left the STYLE section blank.
    property var _styles: ["vector", "notch", "ryoku", "island"]
    property var _rows: []
    // Height slider drafts locally (disk truth on open) and commits once on
    // release — onMoved fires per tick and each commit is a settings fork.
    // _heightCommitted makes the release commit a no-op unless the value
    // actually moved (P1.5: every release was a settings fork).
    property int _heightDraft: Config.BarConfig.barHeight
    property int _heightCommitted: Config.BarConfig.barHeight

    // Repo-relative (P1.3): PluginRegistry already solves the qrc-VFS vs
    // file:// vs deployed-path resolution — don't fork it via StandardPaths.
    readonly property string _stylesDir: Engine.PluginRegistry.repoDir + "/bar/styles"

    // ---- engine actions (same process; the bar owns plugins-state.json) ----
    function _refresh() {
        var rows = []
        var ps = Engine.PluginRegistry.plugins
        var rank = { left: 0, center: 1, right: 2 }
        for (var i = 0; i < ps.length; i++) {
            if (ps[i].kinds.indexOf("bar-widget") === -1) continue
            var sec = Engine.PluginRegistry.sectionOf(ps[i].id) || ""
            rows.push({ pid: ps[i].id, pname: ps[i].name || ps[i].id,
                        penabled: ps[i].enabled === true, psection: sec,
                        prank: rank[sec] !== undefined ? rank[sec] : 3 })
        }
        rows.sort(function (a, b) {
            if (a.prank !== b.prank) return a.prank - b.prank
            return a.pname < b.pname ? -1 : (a.pname > b.pname ? 1 : 0)
        })
        root._rows = rows
    }

    function _toggleModule(pid, enabled) {
        Engine.PluginRegistry.setEnabled(pid, !enabled)
        _refresh()
    }

    function _placeModule(pid, section) {
        Engine.PluginRegistry.place(pid, section, -1)   // end of the target section
        _refresh()
    }

    // ---- settings-process writes (the single bar-config writer) ----
    // A non-zero exit means the settings PROCESS is gone (unit stopped /
    // crashed): the pre-P1 form only logged it, so every pick silently did
    // nothing. Now the failure surfaces as the inline row (below) with a
    // START button; a subsequent good call heals it (P1.4).
    property bool _settingsDown: false
    property string _failedArgv: "[]"
    Services.BoundedProcess {
        id: settingsCall
        property bool expectOk: true
        onDone: function (out, err, code) {
            // `qs ipc call` exits 0 even on rejected calls — output is the truth.
            var t = String(out).trim()
            if (code !== 0) {
                root._failedArgv = JSON.stringify(settingsCall.command)
                root._settingsDown = true
                return
            }
            if (expectOk && t.indexOf("ok") !== 0)
                console.log("[BarSettingsOverlay] settings write failed:", t || "(no output)", String(err).trim())
            root._settingsDown = false
        }
    }
    Services.BoundedProcess {   // one-shot unit start, then retry the write once
        id: settingsStart
        timeoutMs: 15000
        onDone: function (out, err, code) {
            if (code !== 0) {
                console.log("[BarSettingsOverlay] quickshell-settings start failed:", String(err).trim())
                return   // the row stays up; the user can press START again
            }
            root._settingsIpc(JSON.parse(root._failedArgv), true)
        }
    }
    function _startSettingsProcess() {
        settingsStart.command = ["systemctl", "--user", "start", "quickshell-settings"]
        settingsStart.run()
    }

    // argv passed LITERALLY at each call site — check-ipc's internal-class
    // scan keys on the literal `"call", "Target", "fn"` spelling.
    function _settingsIpc(argv, expectOk) {
        settingsCall.expectOk = expectOk !== false
        settingsCall.command = argv
        settingsCall.run()
    }

    function _pickStyle(name) { _settingsIpc(["qs", "-c", "settings", "ipc", "call", "SettingsWindow", "setBarStyle", name]) }
    function _pickPosition(p) { _settingsIpc(["qs", "-c", "settings", "ipc", "call", "SettingsWindow", "setBarPosition", p]) }
    function _pickOsdStyle(s) { _settingsIpc(["qs", "-c", "settings", "ipc", "call", "SettingsWindow", "setOsdStyle", s]) }
    function _pickHeight(h) { _settingsIpc(["qs", "-c", "settings", "ipc", "call", "SettingsWindow", "setBarHeight", String(h)]) }
    function _pickDots(n) { _settingsIpc(["qs", "-c", "settings", "ipc", "call", "SettingsWindow", "setWorkspaceCount", String(n)]) }
    function _pickGuard(scope, on) { _settingsIpc(["qs", "-c", "settings", "ipc", "call", "SettingsWindow", "setBurnGuard", scope, on ? "on" : "off"]) }
    function _openPlugins() {
        _settingsIpc(["qs", "-c", "settings", "ipc", "call", "SettingsWindow", "openControlPlugins"], false)
        root.close()   // the settings window takes over; free the screen + keys
    }

    Services.BoundedProcess {
        id: scanProc
        command: ["sh", "-c",
                  "ls -1d '" + root._stylesDir + "/'*/Scene.qml 2>/dev/null | sed 's|.*/styles/||; s|/Scene.qml||' | sort"]
        onDone: function (out, err, code) {
            var found = String(out).split("\n").filter(function (l) { return l.length > 0 })
            if (code !== 0 || found.length === 0) return   // keep the fallback seed
            // array-identity law: an equal-content reassign destroys and
            // rebuilds every card for nothing — diff before assigning
            var same = found.length === root._styles.length &&
                found.every(function (s, i) { return s === root._styles[i] })
            if (!same) root._styles = found
        }
    }
    function _scanStyles() { scanProc.run() }

    // (backdrop + centered card shell are OverlayShell's; 560×640 card set
    //  via cardWidth/cardHeight. Interior below.)

        // ---- pills ----------------------------------------------------------
        component SegPill: Rectangle {
            id: pill
            property string label: ""
            property bool active: false
            signal picked()
            // layouts manage child width/height — the preferred* attached
            // props are the only form that survives inside RowLayout
            Layout.preferredWidth: Config.PopupMetrics.px(84)
            Layout.preferredHeight: Config.PopupMetrics.px(24)
            radius: Config.PopupMetrics.px(6)
            color: pill.active ? Config.ThemeConfig.colors.surfaceVariant : "transparent"
            border.color: pill.active ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.border
            border.width: Config.PopupMetrics.hairline(pill)
            Text {
                anchors.centerIn: parent
                text: pill.label
                color: pill.active ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.textDim
                font.pixelSize: Config.PopupMetrics.px(10)
                font.bold: true
                font.family: Config.BarConfig.fontFamily
                font.letterSpacing: 1.5
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pill.picked() }
        }

        component SectionLabel: Text {
            color: Config.ThemeConfig.colors.primary
            font.pixelSize: Config.PopupMetrics.px(10)
            font.bold: true
            font.family: Config.BarConfig.fontFamily
            font.letterSpacing: 1.8
        }

        // ---- style cards ----------------------------------------------------
        component StyleGlyph: Item {
            id: glyph
            property string styleName: ""
            property bool active: false
            readonly property color ink: active ? Config.BarConfig.colorAccent
                                                : Config.ThemeConfig.colors.textDim
            Layout.preferredWidth: Config.PopupMetrics.px(44)
            Layout.preferredHeight: Config.PopupMetrics.px(18)
            opacity: active ? 0.8 : 0.5
            // strip: every style except the island pill
            Rectangle {
                visible: glyph.styleName !== "island" && glyph.styleName !== "notch"
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Config.PopupMetrics.px(5)
                radius: 1
                color: glyph.ink
            }
            // notch: two strip halves + the lobe pill between them
            Rectangle {
                visible: glyph.styleName === "notch"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.38
                height: Config.PopupMetrics.px(5)
                radius: 1
                color: glyph.ink
            }
            Rectangle {
                visible: glyph.styleName === "notch"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.38
                height: Config.PopupMetrics.px(5)
                radius: 1
                color: glyph.ink
            }
            // island / notch lobe
            Rectangle {
                visible: glyph.styleName === "island" || glyph.styleName === "notch"
                anchors.centerIn: parent
                width: Config.PopupMetrics.px(14)
                height: Config.PopupMetrics.px(9)
                radius: Config.PopupMetrics.px(4.5)
                color: glyph.ink
            }
            // ryoku: ink dots under the strip
            Row {
                visible: glyph.styleName === "ryoku"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: Config.PopupMetrics.px(2)
                spacing: Config.PopupMetrics.px(4)
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        width: Config.PopupMetrics.px(3)
                        height: Config.PopupMetrics.px(3)
                        radius: Config.PopupMetrics.px(1.5)
                        color: glyph.ink
                    }
                }
            }
        }

        component StyleCard: Rectangle {
            id: sc
            property string styleName: ""
            property bool active: false
            signal picked()
            Layout.fillWidth: true
            Layout.preferredHeight: Config.PopupMetrics.px(52)
            radius: Config.PopupMetrics.px(8)
            color: Config.ThemeConfig.colors.surfaceVariant
            border.color: sc.active ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.border
            border.width: Config.PopupMetrics.hairline(sc)
            opacity: sc.active ? 1.0 : 0.8
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sc.picked() }
            RowLayout {
                anchors.fill: parent
                anchors.margins: Config.PopupMetrics.px(10)
                spacing: Config.PopupMetrics.px(10)
                StyleGlyph { styleName: sc.styleName; active: sc.active }
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: sc.styleName.toUpperCase()
                    color: sc.active ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.text
                    font.pixelSize: Config.PopupMetrics.px(11)
                    font.bold: sc.active
                    font.family: Config.BarConfig.fontFamily
                    font.letterSpacing: 1.2
                    elide: Text.ElideRight
                }
                Text {
                    visible: sc.active
                    text: "ACTIVE"
                    color: Config.BarConfig.colorAccent
                    font.pixelSize: Config.PopupMetrics.px(8)
                    font.family: Config.BarConfig.fontFamily
                    font.letterSpacing: 1.5
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.PopupMetrics.px(24)
            spacing: Config.PopupMetrics.px(12)

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.PopupMetrics.px(8)
                Text {
                    text: "\uF013"
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: Config.PopupMetrics.px(16)
                    color: Config.BarConfig.colorAccent
                }
                Text {
                    text: "BAR SETTINGS"
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
                    spacing: Config.PopupMetrics.px(14)

                    // ---- STYLE ----
                    SectionLabel { text: "STYLE — swaps the bar live" }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: Config.PopupMetrics.px(8)
                        columnSpacing: Config.PopupMetrics.px(8)
                        Repeater {
                            model: root._styles
                            delegate: StyleCard {
                                styleName: modelData
                                active: Config.BarConfig.barStyle === modelData
                                onPicked: root._pickStyle(modelData)
                            }
                        }
                    }

                    // ---- POSITION ----
                    SectionLabel { text: "BAR EDGE" }
                    RowLayout {
                        spacing: Config.PopupMetrics.px(8)
                        SegPill {
                            label: "TOP"
                            active: Config.BarConfig.barPosition === "top"
                            onPicked: root._pickPosition("top")
                        }
                        SegPill {
                            label: "BOTTOM"
                            active: Config.BarConfig.barPosition === "bottom"
                            onPicked: root._pickPosition("bottom")
                        }
                    }

                    // ---- OSD STYLE (J5) ----
                    SectionLabel { text: "OSD TRACK" }
                    RowLayout {
                        spacing: Config.PopupMetrics.px(8)
                        SegPill {
                            label: "BAR"
                            active: Config.BarConfig.osdStyle === "bar"
                            onPicked: root._pickOsdStyle("bar")
                        }
                        SegPill {
                            label: "SEGMENTS"
                            active: Config.BarConfig.osdStyle === "segments"
                            onPicked: root._pickOsdStyle("segments")
                        }
                    }

                    // ---- HEIGHT ----
                    SectionLabel { text: "HEIGHT" }
                    RowLayout {
                        spacing: Config.PopupMetrics.px(10)
                        Text {
                            text: root._heightDraft + "px"
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: Config.PopupMetrics.px(34)
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: Config.PopupMetrics.px(11)
                            font.bold: true
                            font.family: Config.BarConfig.fontFamily
                        }
                        Slider {
                            id: heightSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: Config.PopupMetrics.px(24)
                            from: 18; to: 64; stepSize: 1
                            value: root._heightDraft
                            onMoved: root._heightDraft = value
                            // AbstractSlider has no released() — commit when
                            // the press drops (drag end or click), but ONLY if
                            // the value actually moved (P1.5: every release
                            // was a settings fork).
                            onPressedChanged: if (!pressed && root._heightDraft !== root._heightCommitted) {
                                root._heightCommitted = root._heightDraft
                                root._pickHeight(root._heightDraft)
                            }
                            background: Rectangle {
                                x: heightSlider.leftPadding
                                y: heightSlider.topPadding + heightSlider.availableHeight / 2 - height / 2
                                width: heightSlider.availableWidth; implicitHeight: Config.PopupMetrics.px(6)
                                radius: height / 2
                                color: Config.ThemeConfig.hairlineSoft
                                Rectangle {
                                    width: heightSlider.visualPosition * parent.width; height: parent.height
                                    radius: parent.radius
                                    color: Config.BarConfig.colorAccent
                                }
                            }
                            handle: Rectangle {
                                x: heightSlider.leftPadding + heightSlider.visualPosition * (heightSlider.availableWidth - width)
                                y: heightSlider.topPadding + heightSlider.availableHeight / 2 - height / 2
                                width: Config.PopupMetrics.px(14); height: width; radius: width / 2
                                color: Config.ThemeConfig.colors.text
                                scale: heightSlider.pressed ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 90 } }
                            }
                        }
                    }

                    // ---- WORKSPACE DOTS ----
                    SectionLabel { text: "WORKSPACE DOTS" }
                    RowLayout {
                        spacing: Config.PopupMetrics.px(8)
                        Repeater {
                            model: [3, 5, 7, 9]
                            delegate: SegPill {
                                label: String(modelData)
                                active: Config.BarConfig.workspaceCount === modelData
                                onPicked: root._pickDots(modelData)
                            }
                        }
                    }

                    // ---- BAR BURN GUARD (H2 rename) ----
                    SectionLabel { text: "BAR BURN GUARD — sub-perceptual orbit" }
                    RowLayout {
                        spacing: Config.PopupMetrics.px(8)
                        Text {
                            text: "STRIPS"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: Config.PopupMetrics.px(9)
                            font.bold: true
                            font.family: Config.BarConfig.fontFamily
                            font.letterSpacing: 1.5
                        }
                        SegPill {
                            label: "ON"
                            active: Config.BarConfig.stripBurnGuard
                            onPicked: root._pickGuard("strip", true)
                        }
                        SegPill {
                            label: "OFF"
                            active: !Config.BarConfig.stripBurnGuard
                            onPicked: root._pickGuard("strip", false)
                        }
                        // The island's guard also drives its dim clock — a
                        // separate knob, shown only while it can apply.
                        Text {
                            visible: Config.BarConfig.barStyle === "island"
                            text: "ISLAND"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: Config.PopupMetrics.px(9)
                            font.bold: true
                            font.family: Config.BarConfig.fontFamily
                            font.letterSpacing: 1.5
                        }
                        SegPill {
                            visible: Config.BarConfig.barStyle === "island"
                            label: "ON"
                            active: Config.BarConfig.islandBurnGuard
                            onPicked: root._pickGuard("island", true)
                        }
                        SegPill {
                            visible: Config.BarConfig.barStyle === "island"
                            label: "OFF"
                            active: !Config.BarConfig.islandBurnGuard
                            onPicked: root._pickGuard("island", false)
                        }
                    }

                    // ---- MODULES ----
                    SectionLabel { text: "MODULES — enable · place (order: Settings ▸ Plugins)" }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Config.PopupMetrics.px(4)
                        Repeater {
                            model: root._rows
                            delegate: RowLayout {
                                id: row
                                property string pid: modelData.pid
                                property string pname: modelData.pname
                                property bool penabled: modelData.penabled
                                property string psection: modelData.psection
                                Layout.fillWidth: true
                                spacing: Config.PopupMetrics.px(8)
                                Text {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: row.pname
                                    color: row.penabled ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.textDim
                                    font.pixelSize: Config.PopupMetrics.px(11)
                                    font.family: Config.BarConfig.fontFamily
                                    elide: Text.ElideRight
                                }
                                Repeater {
                                    model: [{ k: "left", l: "L" }, { k: "center", l: "C" }, { k: "right", l: "R" }]
                                    delegate: Rectangle {
                                        property bool here: row.psection === modelData.k
                                        Layout.preferredWidth: Config.PopupMetrics.px(20)
                                        Layout.preferredHeight: Config.PopupMetrics.px(18)
                                        radius: Config.PopupMetrics.px(4)
                                        color: here ? Config.ThemeConfig.colors.surfaceVariant : "transparent"
                                        border.color: here ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.border
                                        border.width: Config.PopupMetrics.hairline(parent)
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.l
                                            color: parent.here ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.textDim
                                            font.pixelSize: Config.PopupMetrics.px(9)
                                            font.bold: parent.here
                                            font.family: Config.BarConfig.fontFamily
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root._placeModule(row.pid, modelData.k)
                                        }
                                    }
                                }
                                Rectangle {
                                    Layout.preferredWidth: Config.PopupMetrics.px(40)
                                    Layout.preferredHeight: Config.PopupMetrics.px(18)
                                    radius: Config.PopupMetrics.px(4)
                                    color: row.penabled ? Config.ThemeConfig.colors.surfaceVariant : "transparent"
                                    border.color: row.penabled ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.border
                                    border.width: Config.PopupMetrics.hairline(parent)
                                    Text {
                                        anchors.centerIn: parent
                                        text: row.penabled ? "ON" : "OFF"
                                        color: row.penabled ? Config.BarConfig.colorAccent : Config.ThemeConfig.colors.textDim
                                        font.pixelSize: Config.PopupMetrics.px(9)
                                        font.bold: row.penabled
                                        font.family: Config.BarConfig.fontFamily
                                        font.letterSpacing: 1
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root._toggleModule(row.pid, row.penabled)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: Config.ThemeConfig.colors.border }

            // ---- settings-process down (P1.4) ----
            // Accent border only, no fill (QD-OLED doctrine) — the card is
            // ephemeral, like the rest of the overlay.
            Rectangle {
                id: downRow
                Layout.fillWidth: true
                visible: root._settingsDown
                Layout.preferredHeight: visible ? Config.PopupMetrics.px(34) : 0
                radius: Config.PopupMetrics.px(6)
                color: "transparent"
                border.color: Config.BarConfig.colorAccent
                border.width: Config.PopupMetrics.hairline(downRow)
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.PopupMetrics.px(8)
                    spacing: Config.PopupMetrics.px(8)
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: "SETTINGS PROCESS DOWN — writes are failing"
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: Config.PopupMetrics.px(9)
                        font.family: Config.BarConfig.fontFamily
                        font.letterSpacing: 1
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        id: startBtn
                        Layout.preferredWidth: Config.PopupMetrics.px(52)
                        Layout.preferredHeight: Config.PopupMetrics.px(20)
                        radius: Config.PopupMetrics.px(4)
                        color: startMa.containsPress ? Config.ThemeConfig.colors.surfaceVariant : "transparent"
                        border.color: Config.BarConfig.colorAccent
                        border.width: Config.PopupMetrics.hairline(startBtn)
                        Text {
                            anchors.centerIn: parent
                            text: "START"
                            color: Config.BarConfig.colorAccent
                            font.pixelSize: Config.PopupMetrics.px(9)
                            font.bold: true
                            font.family: Config.BarConfig.fontFamily
                            font.letterSpacing: 1.5
                        }
                        MouseArea {
                            id: startMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._startSettingsProcess()
                        }
                    }
                }
            }

            // ---- footer ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.PopupMetrics.px(8)
                Text {
                    text: "PLUGINS ›"
                    color: Config.BarConfig.colorAccent
                    font.pixelSize: Config.PopupMetrics.px(10)
                    font.bold: true
                    font.family: Config.BarConfig.fontFamily
                    font.letterSpacing: 1.5
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._openPlugins()
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "opens Settings ▸ Plugins"
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: Config.PopupMetrics.px(9)
                    font.family: Config.BarConfig.fontFamily
                }
            }
        }
}
