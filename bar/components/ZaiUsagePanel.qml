// =============================================================================
// ZaiUsagePanel.qml — Z.ai usage popup BODY (anchored under the bar)
// =============================================================================
// Lives inside qs.Ui.PluginPopup (the bar widget): intrinsic-height ColumnLayout,
// no window chrome / backdrop of its own — PluginPopup provides the anchored
// card, header and dismiss.
//
// Layout:
//   headline  — the 5h and weekly quotas as big Doto numbers side by side,
//               with the peak/off-peak multiplier on the right
//   windows   — one row per token window: status chip, usage bar, reset
//               countdown + absolute reset time, burn rate + ETA
//   search    — the TIME_LIMIT quota card: used/limit, remaining, and the
//               per-tool usageDetails breakdown
//   advice    — peak/off-peak model hint
//   key       — PASTE & SAVE: install a new API key from the clipboard
//   footer    — plan-level badge, data source, sync time, KEY pill, refresh
//
// Data + polling come from ZaiUsageService. `active` (bound to the popup's
// open state) gates the polling and the multiplier clock.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: root

    // Bound to qs.Ui.PluginPopup.opened by the widget: open = poll + tick.
    property bool active: false

    // The KEY card also shows on its own while the error is about the key;
    // this pins it open from the footer when the key still works.
    property bool showKeyInstall: false
    readonly property string keyPathLabel: Services.ZaiUsageService.keyFile.replace(/^\/home\/[^/]+\//, "~/")

    Layout.fillWidth: true
    spacing: Config.PopupMetrics.px(12)

    readonly property color cText:   Config.ThemeConfig.colors.text
    readonly property color cDim:    Config.ThemeConfig.colors.textDim
    readonly property color cBorder: Config.ThemeConfig.colors.border
    readonly property color cSurface:Config.ThemeConfig.colors.surfaceVariant
    readonly property color cAccent: Config.ThemeConfig.colors.secondary
    readonly property color cWarn:   Config.ThemeConfig.colors.warning
    readonly property color cCrit:   Config.ThemeConfig.colors.error
    readonly property string fontM:  Config.BarConfig.fontFamily
    readonly property string fontN:  Config.BarConfig.fontNerd

    function tierColor(tier) {
        if (tier >= 2) return root.cCrit
        if (tier === 1) return root.cWarn
        return root.cAccent
    }
    function formatTokens(n) {
        var v = Math.max(0, Math.round(n || 0))
        return v.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }
    function windowFor(role) {
        var ws = Services.ZaiUsageService.windows
        for (var i = 0; i < ws.length; i++)
            if (ws[i].role === role) return ws[i]
        return null
    }
    function burnLabel(win) {
        var r = win ? win.burnPerHour : null
        if (r === null || r === undefined) return "—"
        return (r < 0.1 ? r.toFixed(2) : r.toFixed(1)) + "%/H"
    }
    function usageLine(win) {
        if (!win || win.usage === null || win.usage === undefined) return "—"
        var used = (win.currentValue === null || win.currentValue === undefined) ? 0 : win.currentValue
        return root.formatTokens(used) + " / " + root.formatTokens(win.usage)
    }
    function toolLabel(code) {
        return String(code || "").replace(/-/g, " ").toUpperCase()
    }

    readonly property var sessionWin: root.windowFor("session")
    readonly property var weeklyWin:  root.windowFor("weekly")
    readonly property var searchWin:  root.windowFor("search")
    // Every non-search window stays in the generic rows; the search quota gets
    // its own card so its usageDetails breakdown has room.
    readonly property var quotaWindows: {
        var out = []
        var ws = Services.ZaiUsageService.windows
        for (var i = 0; i < ws.length; i++)
            if (ws[i].role !== "search") out.push(ws[i])
        return out
    }

    // ---- peak/off-peak multiplier window (Mon–Fri 14:00–18:00 UTC+8) ----
    readonly property int zaiPeakStartSgtMin: 14 * 60
    readonly property int zaiPeakEndSgtMin:   18 * 60
    readonly property int zaiPeakMultiplier:    3
    readonly property int zaiOffPeakMultiplier: 1

    property bool zaiIsPeak: false
    property bool zaiIsWeekend: false
    property int zaiMultiplier: 1
    property string zaiNextChangeLabel: ""
    property string zaiPeakLocalLabel: ""

    readonly property var zaiModelAdvice: root.zaiIsPeak
        ? { model: "GLM-4.7", note: "PEAK WINDOW — route routine / boilerplate work here; reserve GLM-5.3 for tasks that need it." }
        : { model: "GLM-5.3", note: "OFF-PEAK — full headroom, best time for heavy tasks on the flagship model." }

    function updateZaiMultiplier() {
        var now = new Date()
        var sgt = new Date(now.getTime() + 8 * 60 * 60 * 1000)
        var sgtDow = sgt.getUTCDay()
        var sgtMin = sgt.getUTCHours() * 60 + sgt.getUTCMinutes()
        root.zaiIsWeekend = sgtDow === 0 || sgtDow === 6
        var inPeak = !root.zaiIsWeekend
            && sgtMin >= root.zaiPeakStartSgtMin && sgtMin < root.zaiPeakEndSgtMin
        root.zaiIsPeak = inPeak
        root.zaiMultiplier = inPeak ? root.zaiPeakMultiplier : root.zaiOffPeakMultiplier

        var boundary = null
        for (var d = 0; d < 8 && boundary === null; d++) {
            var y = sgt.getUTCFullYear(), m = sgt.getUTCMonth(), dom = sgt.getUTCDate() + d
            var dow = new Date(Date.UTC(y, m, dom)).getUTCDay()
            if (dow === 0 || dow === 6) continue
            var mins = [root.zaiPeakStartSgtMin, root.zaiPeakEndSgtMin]
            for (var c = 0; c < mins.length && boundary === null; c++) {
                var t = Date.UTC(y, m, dom, Math.floor(mins[c] / 60), mins[c] % 60, 0) - 8 * 60 * 60 * 1000
                if (t > now.getTime()) boundary = new Date(t)
            }
        }
        if (boundary !== null) {
            var hh = boundary.getHours().toString().padStart(2, "0")
            var mm = boundary.getMinutes().toString().padStart(2, "0")
            var dayTag = boundary.toDateString() === now.toDateString()
                ? ""
                : ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][boundary.getDay()] + " "
            root.zaiNextChangeLabel = "→ " + (inPeak ? root.zaiOffPeakMultiplier : root.zaiPeakMultiplier)
                + "× " + dayTag + hh + ":" + mm
        }

        var pStart = new Date(Date.UTC(sgt.getUTCFullYear(), sgt.getUTCMonth(), sgt.getUTCDate(),
                                        Math.floor(root.zaiPeakStartSgtMin / 60), root.zaiPeakStartSgtMin % 60, 0)
                              - 8 * 60 * 60 * 1000)
        var pEnd = new Date(Date.UTC(sgt.getUTCFullYear(), sgt.getUTCMonth(), sgt.getUTCDate(),
                                      Math.floor(root.zaiPeakEndSgtMin / 60), root.zaiPeakEndSgtMin % 60, 0)
                            - 8 * 60 * 60 * 1000)
        root.zaiPeakLocalLabel =
            "PEAK (" + root.zaiPeakMultiplier + "×) " + pStart.getHours().toString().padStart(2, "0") + ":"
            + pStart.getMinutes().toString().padStart(2, "0") + "–"
            + pEnd.getHours().toString().padStart(2, "0") + ":"
            + pEnd.getMinutes().toString().padStart(2, "0")
            + " LOCAL  //  " + root.zaiOffPeakMultiplier + "× ELSEWHERE"
    }

    onActiveChanged: {
        Services.ZaiUsageService.active = root.active
        if (root.active) {
            root.updateZaiMultiplier()
            if (!Services.ZaiUsageService.loading) Services.ZaiUsageService.refresh()
        }
    }

    Timer {
        interval: 30000
        running: root.active
        repeat: true
        onTriggered: root.updateZaiMultiplier()
    }
    Component.onCompleted: root.updateZaiMultiplier()

    // ---- headline: 5h + weekly big numbers, multiplier on the right ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.PopupMetrics.px(14)

        ColumnLayout {
            Layout.alignment: Qt.AlignBottom
            spacing: 0
            Text {
                text: root.sessionWin ? Math.round(root.sessionWin.pct) + "%" : "—"
                color: root.tierColor(root.sessionWin ? root.sessionWin.tier : 0)
                font.family: "Doto"
                font.variableAxes: ({ "ROND": 100, "wght": 600 })
                font.weight: Font.DemiBold
                font.pixelSize: Config.PopupMetrics.px(46)
            }
            Text {
                text: "5HR QUOTA"
                color: root.cDim
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.letterSpacing: 1
            }
        }

        Rectangle {
            Layout.preferredWidth: Config.PopupMetrics.hairline(parent)
            Layout.preferredHeight: Config.PopupMetrics.px(48)
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: Config.PopupMetrics.px(8)
            color: root.cBorder
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignBottom
            spacing: 0
            Text {
                text: root.weeklyWin ? Math.round(root.weeklyWin.pct) + "%" : "—"
                color: root.tierColor(root.weeklyWin ? root.weeklyWin.tier : 0)
                font.family: "Doto"
                font.variableAxes: ({ "ROND": 100, "wght": 600 })
                font.weight: Font.DemiBold
                font.pixelSize: Config.PopupMetrics.px(46)
            }
            Text {
                text: "WEEKLY"
                color: root.cDim
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.letterSpacing: 1
            }
        }

        Item { Layout.fillWidth: true }

        ColumnLayout {
            Layout.alignment: Qt.AlignBottom
            spacing: Config.PopupMetrics.px(1)
            Text {
                Layout.alignment: Qt.AlignRight
                text: root.zaiMultiplier + "× " + (root.zaiIsPeak ? "PEAK" : "OFF-PEAK")
                color: root.zaiIsPeak ? root.cWarn : root.cAccent
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(13); font.bold: true
            }
            Text {
                Layout.alignment: Qt.AlignRight
                text: root.zaiNextChangeLabel
                color: root.cDim
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8)
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: root.cBorder }

    // ---- loading / error ----
    Text {
        visible: Services.ZaiUsageService.loading && Services.ZaiUsageService.windows.length === 0
        Layout.fillWidth: true
        Layout.topMargin: Config.PopupMetrics.px(18)
        text: "SYNCING…"
        color: root.cDim
        font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.letterSpacing: 2
        horizontalAlignment: Text.AlignHCenter
    }
    Rectangle {
        visible: Services.ZaiUsageService.hasError
        Layout.fillWidth: true
        Layout.preferredHeight: errCol.implicitHeight + Config.PopupMetrics.px(20)
        radius: Config.PopupMetrics.px(8)
        color: Qt.rgba(root.cCrit.r, root.cCrit.g, root.cCrit.b, 0.10)
        border.color: Qt.rgba(root.cCrit.r, root.cCrit.g, root.cCrit.b, 0.55)
        border.width: Config.PopupMetrics.hairline(parent)
        ColumnLayout {
            id: errCol
            anchors.fill: parent
            anchors.margins: Config.PopupMetrics.px(10)
            spacing: Config.PopupMetrics.px(3)
            Text {
                text: Services.ZaiUsageService.errorTitle
                color: root.cCrit
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(10); font.bold: true; font.letterSpacing: 1
            }
            Text {
                Layout.fillWidth: true
                text: Services.ZaiUsageService.errorMessage || "Unknown error"
                color: root.cDim
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(10)
                wrapMode: Text.WordWrap
            }
        }
    }

    // ---- API key install: PASTE & SAVE ----
    // Shown on its own while the error is about the key, or pinned by the
    // footer's KEY pill. The popup is keyboard-inert (PluginPopup keeps
    // keyboardFocus None), so the key arrives from the clipboard: the service
    // checks it with Z.ai before anything is written, and the key itself
    // never reaches QML — only the outcome line does.
    Rectangle {
        visible: Services.ZaiUsageService.hasKeyError || root.showKeyInstall
        Layout.fillWidth: true
        implicitHeight: keyCol.implicitHeight + Config.PopupMetrics.px(18)
        radius: Config.PopupMetrics.px(8)
        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
        border.color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.7)
        border.width: Config.PopupMetrics.hairline(parent)
        ColumnLayout {
            id: keyCol
            anchors.fill: parent
            anchors.margins: Config.PopupMetrics.px(9)
            spacing: Config.PopupMetrics.px(6)

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "API KEY"
                    color: root.cAccent
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(10); font.bold: true; font.letterSpacing: 1
                }
                Item { Layout.fillWidth: true }
                // Same pill as the footer's REFRESH
                Rectangle {
                    enabled: !Services.ZaiUsageService.isInstallingKey
                    opacity: enabled ? 1 : 0.5
                    implicitWidth: pasteLabel.implicitWidth + Config.PopupMetrics.px(16)
                    implicitHeight: Config.PopupMetrics.px(24)
                    radius: Config.PopupMetrics.px(5)
                    color: pasteMa.containsMouse
                        ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.16)
                        : Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.06)
                    border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.45)
                    border.width: Config.PopupMetrics.hairline(parent)
                    Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
                    Text {
                        id: pasteLabel
                        anchors.centerIn: parent
                        text: Services.ZaiUsageService.isInstallingKey ? "CHECKING…" : "PASTE & SAVE"
                        color: root.cAccent
                        font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.bold: true; font.letterSpacing: 1
                    }
                    MouseArea {
                        id: pasteMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.ZaiUsageService.installKeyFromClipboard()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Copy the key from z.ai, then PASTE & SAVE. It is checked with Z.ai before anything is written."
                color: root.cDim
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9)
                wrapMode: Text.WordWrap
            }
            Text {
                visible: Services.ZaiUsageService.keyInstallMessage !== ""
                Layout.fillWidth: true
                text: Services.ZaiUsageService.keyInstallMessage
                color: root.cAccent
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: "SAVES TO " + root.keyPathLabel + "  ·  MODE 600"
                color: root.cDim
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8)
                elide: Text.ElideRight
            }
        }
    }

    // ---- per-window rows (5h + weekly) with telemetry ----
    Repeater {
        model: root.quotaWindows

        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: Config.PopupMetrics.px(5)

            RowLayout {
                Layout.fillWidth: true
                spacing: Config.PopupMetrics.px(6)
                Text {
                    text: modelData.label
                    color: root.cText
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true; font.letterSpacing: 1
                }
                Rectangle {
                    implicitWidth: statusText.implicitWidth + Config.PopupMetrics.px(10)
                    implicitHeight: Config.PopupMetrics.px(14)
                    radius: Config.PopupMetrics.px(3)
                    color: Qt.rgba(root.tierColor(modelData.tier).r, root.tierColor(modelData.tier).g,
                                   root.tierColor(modelData.tier).b, 0.10)
                    border.width: Config.PopupMetrics.hairline(parent)
                    border.color: Qt.rgba(root.tierColor(modelData.tier).r, root.tierColor(modelData.tier).g,
                                          root.tierColor(modelData.tier).b, 0.45)
                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: modelData.statusWord
                        color: root.tierColor(modelData.tier)
                        font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(7); font.bold: true; font.letterSpacing: 0.5
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: Math.round(modelData.pct) + "%"
                    color: root.tierColor(modelData.tier)
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(12); font.bold: true
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Config.PopupMetrics.px(8)
                Rectangle {
                    anchors.fill: parent
                    radius: Config.PopupMetrics.px(2)
                    color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.06)
                    border.color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.7)
                    border.width: Config.PopupMetrics.hairline(parent)
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: parent.width * Math.min(modelData.pct, 100) / 100
                    radius: Config.PopupMetrics.px(2)
                    color: root.tierColor(modelData.tier)
                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Config.MotionConfig.flap } }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "RESET " + modelData.resetLabel
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8)
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "AT " + modelData.resetAbsLabel
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "BURN " + root.burnLabel(modelData)
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8)
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "ETA " + modelData.etaLabel
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8)
                }
                Text {
                    visible: modelData.remaining !== null && modelData.remaining !== undefined
                    text: visible ? ("· " + root.formatTokens(modelData.remaining) + " LEFT") : ""
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8)
                }
            }
        }
    }

    // ---- search/time quota card (usage + per-tool breakdown) ----
    Rectangle {
        visible: root.searchWin !== null && !Services.ZaiUsageService.hasError
        Layout.fillWidth: true
        implicitHeight: searchCol.implicitHeight + Config.PopupMetrics.px(18)
        radius: Config.PopupMetrics.px(8)
        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
        border.color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.7)
        border.width: Config.PopupMetrics.hairline(parent)

        ColumnLayout {
            id: searchCol
            anchors.fill: parent
            anchors.margins: Config.PopupMetrics.px(9)
            spacing: Config.PopupMetrics.px(3)

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "SEARCH QUOTA"
                    color: root.cAccent
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(10); font.bold: true; font.letterSpacing: 1
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.usageLine(root.searchWin) + " USED"
                    color: root.cText
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.searchWin && root.searchWin.remaining !== null
                          && root.searchWin.remaining !== undefined
                          ? (root.formatTokens(root.searchWin.remaining) + " LEFT")
                          : "—"
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8)
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.searchWin
                          ? ("RESET " + root.searchWin.resetLabel + " · " + root.searchWin.resetAbsLabel)
                          : ""
                    color: root.cDim
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Config.PopupMetrics.px(3)
                Layout.bottomMargin: Config.PopupMetrics.px(2)
                height: Config.PopupMetrics.hairline(parent)
                color: root.cBorder
            }

            Repeater {
                model: root.searchWin ? root.searchWin.usageDetails : []

                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Config.PopupMetrics.px(6)
                    Rectangle {
                        width: Config.PopupMetrics.px(5); height: Config.PopupMetrics.px(5)
                        color: root.cAccent
                        opacity: 0.7
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: root.toolLabel(modelData.modelCode || "unknown")
                        color: root.cDim
                        font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.letterSpacing: 0.5
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.formatTokens(Number(modelData.usage) || 0)
                        color: root.cText
                        font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8); font.bold: true
                    }
                }
            }
        }
    }

    // ---- model advice ----
    Rectangle {
        visible: Services.ZaiUsageService.windows.length > 0 && !Services.ZaiUsageService.hasError
        Layout.fillWidth: true
        implicitHeight: advCol.implicitHeight + Config.PopupMetrics.px(18)
        radius: Config.PopupMetrics.px(8)
        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.35)
        border.color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 0.7)
        border.width: Config.PopupMetrics.hairline(parent)
        ColumnLayout {
            id: advCol
            anchors.fill: parent
            anchors.margins: Config.PopupMetrics.px(9)
            spacing: Config.PopupMetrics.px(3)
            RowLayout {
                spacing: Config.PopupMetrics.px(6)
                Rectangle {
                    width: Config.PopupMetrics.px(7); height: Config.PopupMetrics.px(7)
                    color: root.zaiIsPeak ? root.cWarn : root.cAccent
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "USE  ·  " + root.zaiModelAdvice.model
                    color: root.zaiIsPeak ? root.cWarn : root.cAccent
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(11); font.bold: true; font.letterSpacing: 1
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.zaiModelAdvice.note
                color: root.cDim
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9)
                wrapMode: Text.WordWrap
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: Config.PopupMetrics.hairline(parent); color: root.cBorder }

    // ---- footer ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.PopupMetrics.px(6)

        Rectangle {
            visible: Services.ZaiUsageService.level !== "—"
            implicitWidth: levelText.implicitWidth + Config.PopupMetrics.px(10)
            implicitHeight: Config.PopupMetrics.px(15)
            radius: Config.PopupMetrics.px(3)
            color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.10)
            border.width: Config.PopupMetrics.hairline(parent)
            border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.45)
            Text {
                id: levelText
                anchors.centerIn: parent
                text: "PLAN " + Services.ZaiUsageService.level
                color: root.cAccent
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(7); font.bold: true; font.letterSpacing: 0.5
            }
        }

        Text {
            text: "api.z.ai  //  SYNC " + (Services.ZaiUsageService.lastUpdated || "—")
            color: root.cAccent
            font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8)
            opacity: 0.7
        }
        Item { Layout.fillWidth: true }
        // KEY — toggles the PASTE & SAVE card (same pill shape as REFRESH)
        Rectangle {
            implicitWidth: keyLabel.implicitWidth + Config.PopupMetrics.px(16)
            implicitHeight: Config.PopupMetrics.px(24)
            radius: Config.PopupMetrics.px(5)
            color: root.showKeyInstall || keyMa.containsMouse
                ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.16)
                : Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.06)
            border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.45)
            border.width: Config.PopupMetrics.hairline(parent)
            Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
            Text {
                id: keyLabel
                anchors.centerIn: parent
                text: "KEY"
                color: root.cAccent
                font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.bold: true; font.letterSpacing: 1
            }
            MouseArea {
                id: keyMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showKeyInstall = !root.showKeyInstall
            }
        }
        Rectangle {
            implicitWidth: refreshRow.implicitWidth + Config.PopupMetrics.px(16)
            implicitHeight: Config.PopupMetrics.px(24)
            radius: Config.PopupMetrics.px(5)
            color: refreshMa.containsMouse
                ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.16)
                : Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.06)
            border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.45)
            border.width: Config.PopupMetrics.hairline(parent)
            Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
            RowLayout {
                id: refreshRow
                anchors.centerIn: parent
                spacing: Config.PopupMetrics.px(5)
                Text {
                    text: "󰑓"
                    color: root.cAccent
                    font.family: root.fontN; font.pixelSize: Config.PopupMetrics.px(11)
                    RotationAnimation on rotation {
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        running: Services.ZaiUsageService.loading
                    }
                }
                Text {
                    text: "REFRESH"
                    color: root.cAccent
                    font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(9); font.bold: true; font.letterSpacing: 1
                }
            }
            MouseArea {
                id: refreshMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (!Services.ZaiUsageService.loading) Services.ZaiUsageService.refresh()
            }
        }
    }

    // ---- peak window footnote ----
    Text {
        Layout.fillWidth: true
        text: root.zaiPeakLocalLabel
        color: root.cDim
        font.family: root.fontM; font.pixelSize: Config.PopupMetrics.px(8)
        elide: Text.ElideRight
    }
}
