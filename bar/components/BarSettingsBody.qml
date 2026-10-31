// =============================================================================
// BarSettingsBody.qml — the BAR settings sections (P4.7 extraction)
// =============================================================================
// The bar-settings sections (originally the P4.7 overlay's card body) so the
// same body hosts in every bar-settings surface — today the Control Center's
// BAR page, and since P4.9 the settings app's BAR pane (file://-loaded by
// settings/components/BarSettingsPane.qml across the import split; PLUGINS ›
// jumps to that dashboard's CONTROL › plugins via the pane's dash link):
//
//   STYLE     every scanned style (bar/styles/*/Scene.qml) as a card — a pick
//             swaps the bar live. The pick calls Config.BarConfigWriter.merge()
//             DIRECTLY (P2.5 — one process, one writer). Active state reads
//             the bar's own BarConfig — disk truth, never an optimistic guess.
//   POSITION  top/bottom edge pills, same direct merge.
//   OSD       bar/segments track pills.
//   HEIGHT    slider (drafts locally, commits on release — one fork per
//             drag, not per tick).
//   DOTS      workspace-count pills.
//   SCALE     uiScale 0.75–2.0 (NEW — PopupMetrics rescales every px() live).
//   MOTION    motionScale 0–2 + reduceMotion pills (NEW — MotionConfig).
//   GUARD     QD-OLED burn-guard pills — STRIPS (stripBurnGuard, the shared
//             BurnOrbit on vector/notch/ryoku) and ISLAND (its own dim+orbit
//             knob, shown only while the island style is active).
//   MODULES   the plugin engine is IN this process: enable/disable and section
//             placement call PluginRegistry directly (the bar is
//             plugins-state.json's only writer — no fork, no drift). Rows are
//             rebuilt imperatively after every action (array-identity law).
//
// Host wiring: PLUGINS › emits pluginsRequested() (the overlay deep-links and
// closes; the settings pane routes into its own Plugins page); showBack adds
// the in-card ‹ BACK row (Control Center page use); viewportHeight > 0 bounds
// the scroll area to a fixed height (in-card) instead of filling (overlay).
// Ephemeral surfaces only — no bright fills: accent as text and borders
// (QD-OLED doctrine).
// =============================================================================
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import bar.config as Config
import bar.engine as Engine
import bar.services as Services

ColumnLayout {
    id: root

    signal backRequested()
    signal pluginsRequested()
    property bool showBack: false
    property real viewportHeight: 0    // >0: fixed-height scroll area (in-card)

    spacing: Config.PopupMetrics.px(10)

    Component.onCompleted: {
        root._scanStyles()
        root._refresh()
        root._heightDraft = Config.BarConfig.barHeight
        root._heightCommitted = Config.BarConfig.barHeight
        root._scaleDraft = Config.BarConfig.uiScale
        root._scaleCommitted = Config.BarConfig.uiScale
        root._motionDraft = Config.MotionConfig.motionScale
        root._motionCommitted = Config.MotionConfig.motionScale
    }

    // Re-seed the drafts when BarConfig reloads under us while open (a
    // settings-side save, another host's pick) — never mid-drag (P1.5).
    Connections {
        target: Config.BarConfig
        function onBarHeightChanged() {
            if (heightRow.pressing) return
            root._heightDraft = Config.BarConfig.barHeight
            root._heightCommitted = Config.BarConfig.barHeight
        }
        function onUiScaleChanged() {
            if (scaleRow.pressing) return
            root._scaleDraft = Config.BarConfig.uiScale
            root._scaleCommitted = Config.BarConfig.uiScale
        }
    }
    Connections {
        target: Config.MotionConfig
        function onMotionScaleChanged() {
            if (motionRow.pressing) return
            root._motionDraft = Config.MotionConfig.motionScale
            root._motionCommitted = Config.MotionConfig.motionScale
        }
    }

    // ---- state (rebuilt imperatively — no cross-object bindings) ----
    // _styles seeds with the built-in set (P1.3): the directory scan needs the
    // repo on disk at the deployed path — under `qs -p` (or a moved checkout)
    // it finds nothing and the pre-P1 empty list left the STYLE section blank.
    property var _styles: ["vector", "notch", "ryoku", "island"]
    property var _rows: []
    // Sliders draft locally (disk truth on open) and commit once on release —
    // onMoved fires per tick and each commit is a config fork. The *Committed
    // twins make the release commit a no-op unless the value actually moved
    // (P1.5: every release was a settings fork).
    property int _heightDraft: Config.BarConfig.barHeight
    property int _heightCommitted: Config.BarConfig.barHeight
    property real _scaleDraft: Config.BarConfig.uiScale
    property real _scaleCommitted: Config.BarConfig.uiScale
    property real _motionDraft: Config.MotionConfig.motionScale
    property real _motionCommitted: Config.MotionConfig.motionScale

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

    // ---- bar-config writes (P2.5: the writer is IN this process) ----
    // Config.BarConfigWriter is bar-config.json's single writer: each pick
    // merges over the disk content (extras preserved) atomically and reloads
    // BarConfig in-process.
    function _pickStyle(name) { Config.BarConfigWriter.merge({ barStyle: String(name) }) }
    function _pickPosition(p) { Config.BarConfigWriter.merge({ barPosition: p === "bottom" ? "bottom" : "top" }) }
    function _pickOsdStyle(s) {
        // P6.6: "edge" joins the set (the glyph edge light). Anything unknown
        // falls back to the D5 default.
        const known = s === "segments" || s === "edge"
        Config.BarConfigWriter.merge({ osdStyle: known ? s : "segments" })
    }
    function _pickHeight(h) {
        var v = Math.round(Number(h))
        if (v >= 18 && v <= 64) Config.BarConfigWriter.merge({ barHeight: v })
    }
    function _pickDots(n) {
        var v = Math.round(Number(n))
        if ([3, 5, 7, 9].indexOf(v) !== -1) Config.BarConfigWriter.merge({ workspaceCount: v })
    }
    function _pickScale(s) {
        var v = Math.round(Number(s) * 20) / 20   // 0.05 steps
        if (v >= 0.75 && v <= 2.0) Config.BarConfigWriter.merge({ uiScale: v })
    }
    function _pickMotion(m) {
        var v = Math.round(Number(m) * 10) / 10
        if (v >= 0 && v <= 2) Config.BarConfigWriter.merge({ motionScale: v })
    }
    function _pickReduceMotion(on) { Config.BarConfigWriter.merge({ reduceMotion: on === true }) }
    function _pickGuard(scope, on) {
        var key = scope === "island" ? "islandBurnGuard" : "stripBurnGuard"
        var c = {}; c[key] = (on === true)
        Config.BarConfigWriter.merge(c)
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

    // draft/commit slider row (HEIGHT / SCALE / MOTION — one shape, P1.5 law)
    component DraftSlider: RowLayout {
        id: ds
        property real dValue: 0
        property real dFrom: 0
        property real dTo: 100
        property real dStep: 0
        property string readout: ""
        readonly property bool pressing: dslider.pressed
        signal moved(real v)
        signal released(real v)
        spacing: Config.PopupMetrics.px(10)
        Text {
            text: ds.readout
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: Config.PopupMetrics.px(48)
            color: Config.ThemeConfig.colors.text
            font.pixelSize: Config.PopupMetrics.px(11)
            font.bold: true
            font.family: Config.BarConfig.fontFamily
        }
        Slider {
            id: dslider
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: Config.PopupMetrics.px(24)
            from: ds.dFrom; to: ds.dTo; stepSize: ds.dStep
            value: ds.dValue
            onMoved: ds.moved(value)
            // AbstractSlider has no released() — commit when the press drops
            // (drag end or click), but ONLY if the value actually moved.
            onPressedChanged: if (!pressed) ds.released(value)
            background: Rectangle {
                x: dslider.leftPadding
                y: dslider.topPadding + dslider.availableHeight / 2 - height / 2
                width: dslider.availableWidth; implicitHeight: Config.PopupMetrics.px(6)
                radius: height / 2
                color: Config.ThemeConfig.hairlineSoft
                Rectangle {
                    width: dslider.visualPosition * parent.width; height: parent.height
                    radius: parent.radius
                    color: Config.BarConfig.colorAccent
                }
            }
            handle: Rectangle {
                x: dslider.leftPadding + dslider.visualPosition * (dslider.availableWidth - width)
                y: dslider.topPadding + dslider.availableHeight / 2 - height / 2
                width: Config.PopupMetrics.px(14); height: width; radius: width / 2
                color: Config.ThemeConfig.colors.text
                scale: dslider.pressed ? 1.15 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }
            }
        }
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
        // strip: every style except the island/notch pill
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

    // ── in-card back row (Control Center page use) ──────────────────────────
    RowLayout {
        visible: root.showBack
        Layout.fillWidth: true
        spacing: Config.PopupMetrics.px(8)
        Text {
            text: "‹"
            font.pixelSize: Config.PopupMetrics.px(16)
            color: backArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
            MouseArea {
                id: backArea
                anchors.fill: parent; anchors.margins: -Config.PopupMetrics.px(6)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backRequested()
            }
        }
        Text {
            text: "BACK"
            color: Config.BarConfig.colorTextDim
            font.pixelSize: Config.PopupMetrics.px(10)
            font.bold: true
            font.family: Config.BarConfig.fontFamily
            font.letterSpacing: 2.5
        }
    }

    // ── scrollable sections ──────────────────────────────────────────────────
    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: root.viewportHeight === 0
        Layout.preferredHeight: root.viewportHeight > 0 ? root.viewportHeight : 0
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
                SegPill {
                    label: "EDGE"
                    active: Config.BarConfig.osdStyle === "edge"
                    onPicked: root._pickOsdStyle("edge")
                }
            }

            // ---- HEIGHT ----
            SectionLabel { text: "HEIGHT" }
            DraftSlider {
                id: heightRow
                Layout.fillWidth: true
                dValue: root._heightDraft
                dFrom: 18; dTo: 64; dStep: 1
                readout: root._heightDraft + "px"
                onMoved: function(v) { root._heightDraft = v }
                onReleased: function(v) {
                    if (root._heightDraft !== root._heightCommitted) {
                        root._heightCommitted = root._heightDraft
                        root._pickHeight(root._heightDraft)
                    }
                }
            }

            // ---- INTERFACE SCALE (P4.7) ----
            SectionLabel { text: "INTERFACE SCALE — popups, cards, OSD" }
            DraftSlider {
                id: scaleRow
                Layout.fillWidth: true
                dValue: root._scaleDraft
                dFrom: 0.75; dTo: 2.0; dStep: 0.0
                readout: root._scaleDraft.toFixed(2) + "×"
                onMoved: function(v) { root._scaleDraft = v }
                onReleased: function(v) {
                    if (root._scaleDraft !== root._scaleCommitted) {
                        root._scaleCommitted = root._scaleDraft
                        root._pickScale(root._scaleDraft)
                    }
                }
            }

            // ---- MOTION (P4.7) ----
            SectionLabel { text: "MOTION" }
            DraftSlider {
                id: motionRow
                Layout.fillWidth: true
                dValue: root._motionDraft
                dFrom: 0; dTo: 2; dStep: 0.0
                readout: root._motionDraft.toFixed(1) + "×"
                onMoved: function(v) { root._motionDraft = v }
                onReleased: function(v) {
                    if (root._motionDraft !== root._motionCommitted) {
                        root._motionCommitted = root._motionDraft
                        root._pickMotion(root._motionDraft)
                    }
                }
            }
            RowLayout {
                spacing: Config.PopupMetrics.px(8)
                Text {
                    text: "REDUCE MOTION"
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: Config.PopupMetrics.px(9)
                    font.bold: true
                    font.family: Config.BarConfig.fontFamily
                    font.letterSpacing: 1.5
                }
                SegPill {
                    label: "ON"
                    active: Config.MotionConfig.reduceMotion
                    onPicked: root._pickReduceMotion(true)
                }
                SegPill {
                    label: "OFF"
                    active: !Config.MotionConfig.reduceMotion
                    onPicked: root._pickReduceMotion(false)
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

    // ---- footer deep link ----
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
                onClicked: root.pluginsRequested()
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
