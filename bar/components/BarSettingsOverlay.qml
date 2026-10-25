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
//   MODULES   the plugin engine is IN this process: enable/disable and section
//             placement call PluginRegistry directly (the bar is
//             plugins-state.json's only writer — no fork, no drift). Rows are
//             rebuilt imperatively after every action (array-identity law).
//   PLUGINS › deep link to Settings ▸ Plugins for ordering, per-plugin
//             settings forms and everything beyond quick toggles.
//
// Window chrome is the KeybindsOverlay pattern: dim backdrop, centered black
// card, Esc/outside-click close, focusable while mapped. Ephemeral — still no
// bright fills: the accent appears as text and borders only (QD-OLED doctrine).
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Qt.labs.platform
import "../config" as Config
import "../engine" as Engine
import "../services" as Services

PanelWindow {
    id: root

    property bool shown: false
    visible: false
    function open() {
        _scanStyles()
        _refresh()
        visible = true
        shown = true
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

    // ---- state (rebuilt imperatively — no cross-object bindings) ----
    property var _styles: []
    property var _rows: []

    readonly property string _stylesDir: StandardPaths.writableLocation(
        StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell/bar/styles"

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
    Services.BoundedProcess {
        id: settingsCall
        property bool expectOk: true
        onDone: function (out, err, code) {
            // `qs ipc call` exits 0 even on rejected calls — output is the truth.
            var t = String(out).trim()
            if (expectOk && (code !== 0 || t.indexOf("ok") !== 0))
                console.log("[BarSettingsOverlay] settings write failed:", t || "(no output)", String(err).trim())
        }
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
            if (code === 0 && found.length > 0) root._styles = found
        }
    }
    function _scanStyles() { scanProc.run() }

    // ---- dim backdrop (click-outside = close) ----
    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        opacity: root.shown ? 0.45 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ---- centered card ----
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Config.PopupMetrics.px(560), parent.width - Config.PopupMetrics.px(48))
        height: Math.min(Config.PopupMetrics.px(640), parent.height - Config.PopupMetrics.px(48))
        color: "#000000"
        radius: Config.PopupMetrics.px(18)
        clip: true
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
        Behavior on scale { NumberAnimation { duration: Config.MotionConfig.swap; easing.type: Config.MotionConfig.ease } }

        Keys.onEscapePressed: root.close()
        MouseArea { anchors.fill: parent }   // stop click-through to the backdrop

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
                    text: ""
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
}
