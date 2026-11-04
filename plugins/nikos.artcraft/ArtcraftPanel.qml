// =============================================================================
// nikos.artcraft — panel body (plugin api 2)
// =============================================================================
// Table-style rows, one per app in versions.json:
//   APP                 CURRENT     NEW         STATUS
//   PhotoCraft 1.0.0    1.0.0       1.1.0       [UPDATE]
//   VectorCraft ...     ...         ...         ▓▓▓▓░░ 42% DOWNLOADING
//
// Per-row UPDATE calls ServiceRoot.update(app); UPDATE ALL calls
// ServiceRoot.updateAll(). Progress comes from progress.json (real download
// percent, phase-based hash/rebuild), so the rows stay truthful even when the
// bar restarts during the rebuild.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "lib/artcraft.mjs" as A

ColumnLayout {
    id: panel

    property var ctx: null
    readonly property var svc: ctx ? ctx.service : null
    readonly property var progress: svc ? svc.progress : A.normalizeProgress({})
    readonly property var apps: svc ? svc.apps : []
    readonly property var outdated: svc ? svc.outdated : []
    readonly property bool upgrading: progress.running === true
    readonly property bool checking: svc ? svc.checking : false
    readonly property int count: svc ? svc.count : 0
    readonly property string errorText:
        svc ? (svc.checkError || progress.error || "") : ""
    readonly property double checkedAt: svc ? svc.status.checked : 0
    readonly property var colors: ctx && ctx.theme ? ctx.theme.colors : ({})
    readonly property var bar: ctx ? ctx.bar : null

    property double now: Math.floor(new Date().getTime() / 1000)

    spacing: 10

    function col(name, fallback) {
        return colors && colors[name] ? colors[name] : fallback
    }
    function alpha(color, a) {
        return ctx && ctx.theme ? ctx.theme.withAlpha(color, a) : color
    }
    function px(n) {
        return bar ? Math.round(bar.uiScale * n) : n
    }
    function fontFamily() {
        return bar ? bar.fontFamily : "monospace"
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: panel.now = Math.floor(new Date().getTime() / 1000)
    }

    component Label: Text {
        font.family: panel.fontFamily()
        font.pixelSize: panel.px(10)
        color: panel.col("textDim", "#888")
    }

    component ActionButton: Rectangle {
        id: btn
        property string text: ""
        signal clicked()

        implicitWidth: Math.max(88, btnText.implicitWidth + 24)
        implicitHeight: 28
        radius: 6
        color: "transparent"
        border.width: 1
        border.color: btn.enabled
            ? (btnArea.containsMouse ? panel.col("accent", "#00dce5")
                                     : panel.alpha(panel.col("accent", "#00dce5"), 0.55))
            : panel.alpha(panel.col("text", "#ddd"), 0.15)

        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.text
            font.family: panel.fontFamily()
            font.pixelSize: panel.px(9)
            font.bold: true
            font.letterSpacing: 1.5
            color: btn.enabled ? panel.col("accent", "#00dce5")
                               : panel.alpha(panel.col("textDim", "#888"), 0.55)
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            enabled: btn.enabled
            hoverEnabled: true
            cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: btn.clicked()
        }
    }

    // ── summary ──────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Label {
            text: panel.upgrading ? "UPGRADING"
                : panel.count > 0 ? panel.count + (panel.count === 1 ? " UPDATE AVAILABLE" : " UPDATES AVAILABLE")
                : "ALL APPS CURRENT"
            color: panel.upgrading ? panel.col("accent", "#00dce5")
                : panel.count > 0 ? panel.col("warning", "#ffcc66")
                : panel.col("success", "#77dd99")
            font.bold: true
            font.letterSpacing: 2
        }

        Item { Layout.fillWidth: true }

        Label {
            text: panel.checking ? "CHECKING GITHUB…"
                : "CHECKED " + A.relativeTime(panel.checkedAt, panel.now).toUpperCase()
            color: panel.checking ? panel.col("accent", "#00dce5")
                                  : panel.col("textDim", "#888")
        }
    }

    // ── error banner ─────────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: errText.implicitHeight + 16
        visible: panel.errorText !== ""
        radius: 6
        color: "transparent"
        border.width: 1
        border.color: panel.alpha(panel.col("error", "#ff4d4d"), 0.55)

        Text {
            id: errText
            anchors.fill: parent
            anchors.margins: 8
            text: panel.errorText
            wrapMode: Text.WrapAnywhere
            font.family: panel.fontFamily()
            font.pixelSize: panel.px(9)
            color: panel.col("error", "#ff4d4d")
        }
    }

    // ── table header ─────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Label { text: "APP"; Layout.preferredWidth: 210; font.letterSpacing: 1.5 }
        Label { text: "CURRENT"; Layout.preferredWidth: 92; font.letterSpacing: 1.5 }
        Label { text: "NEW"; Layout.preferredWidth: 92; font.letterSpacing: 1.5 }
        Label { text: "STATUS"; Layout.fillWidth: true; font.letterSpacing: 1.5 }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: panel.alpha(panel.col("text", "#ddd"), 0.16)
    }

    // ── rows ─────────────────────────────────────────────────────────────────
    Repeater {
        model: panel.apps

        delegate: Column {
            id: row
            property var app: modelData
            readonly property var pa: A.appProgress(panel.progress, row.app.app)
            readonly property string st: A.rowState(row.app, panel.progress)

            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                width: parent.width
                spacing: 10

                Column {
                    Layout.preferredWidth: 210
                    spacing: 2

                    Text {
                        width: parent.width
                        text: row.app.displayName || row.app.app
                        elide: Text.ElideRight
                        font.family: panel.fontFamily()
                        font.pixelSize: panel.px(11)
                        font.bold: true
                        color: panel.col("text", "#ddd")
                    }
                    Text {
                        width: parent.width
                        text: row.app.repo || ""
                        elide: Text.ElideRight
                        font.family: panel.fontFamily()
                        font.pixelSize: panel.px(8)
                        color: panel.col("textDim", "#888")
                    }
                }

                Text {
                    Layout.preferredWidth: 92
                    text: A.versionLabel(row.app.installed)
                    elide: Text.ElideRight
                    font.family: panel.fontFamily()
                    font.pixelSize: panel.px(10)
                    color: panel.col("textDim", "#aaa")
                }

                Text {
                    Layout.preferredWidth: 92
                    text: A.versionLabel(row.app.latest)
                    elide: Text.ElideRight
                    font.family: panel.fontFamily()
                    font.pixelSize: panel.px(10)
                    color: row.st === "update" || row.st === "download"
                        ? panel.col("accent", "#00dce5")
                        : panel.col("text", "#ddd")
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 30

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        Label {
                            visible: row.st === "current"
                            text: "CURRENT"
                            color: panel.col("success", "#77dd99")
                            font.letterSpacing: 1.5
                        }
                        Label {
                            visible: row.st === "waiting"
                            text: "WAITING FOR ASSET"
                            color: panel.col("warning", "#ffcc66")
                            font.letterSpacing: 1.5
                        }
                        Label {
                            visible: row.st === "unknown"
                            text: "—"
                            color: panel.col("textDim", "#888")
                        }
                        Label {
                            visible: row.st === "done"
                            text: "DONE"
                            color: panel.col("success", "#77dd99")
                            font.bold: true
                            font.letterSpacing: 1.5
                        }

                        ActionButton {
                            visible: row.st === "update"
                            text: "UPDATE"
                            enabled: !panel.upgrading
                            onClicked: if (panel.svc) panel.svc.update(row.app.app)
                        }

                        ActionButton {
                            visible: row.st === "retry" || row.st === "error"
                            text: "RETRY"
                            enabled: !panel.upgrading
                            onClicked: if (panel.svc) panel.svc.update(row.app.app)
                        }

                        RowLayout {
                            visible: row.st === "download" || row.st === "hash"
                                || row.st === "pin" || row.st === "switch"
                                || row.st === "check"
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: panel.alpha(panel.col("text", "#ddd"), 0.12)

                                Rectangle {
                                    width: parent.width * (row.pa ? row.pa.percent : 0) / 100
                                    height: parent.height
                                    radius: 3
                                    color: panel.col("accent", "#00dce5")
                                    Behavior on width {
                                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                                    }
                                }
                            }

                            Label {
                                text: row.pa ? A.formatPercent(row.pa.percent) : "0%"
                                color: panel.col("accent", "#00dce5")
                            }
                            Label {
                                text: A.phaseLabel(row.pa ? row.pa.phase : "")
                                color: panel.col("textDim", "#888")
                                font.letterSpacing: 1
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: panel.alpha(panel.col("text", "#ddd"), 0.08)
            }
        }
    }

    // ── footer ───────────────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: panel.alpha(panel.col("text", "#ddd"), 0.16)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Label {
            Layout.fillWidth: true
            text: panel.upgrading ? (panel.progress.message || "UPGRADING…")
                : panel.errorText !== "" ? "LAST CHECK FAILED"
                : panel.outdated.length > 0 ? "VERSIONS.JSON WILL BE BUMPED, THEN THE SYSTEM REBUILDS"
                : "NOTHING TO DO"
            color: panel.errorText !== "" ? panel.col("error", "#ff4d4d")
                                          : panel.col("textDim", "#888")
            elide: Text.ElideRight
        }

        ActionButton {
            text: "CHECK NOW"
            enabled: !panel.checking && !panel.upgrading
            onClicked: if (panel.svc) panel.svc.check()
        }

        ActionButton {
            text: "UPDATE ALL"
            enabled: panel.outdated.length > 0 && !panel.upgrading
            onClicked: if (panel.svc) panel.svc.updateAll()
        }
    }
}
