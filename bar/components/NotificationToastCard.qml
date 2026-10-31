// =============================================================================
// NotificationToastCard.qml — one toast card (UX U3)
// =============================================================================
// Port of ryoku's NotificationCard anatomy (GPL-3 —
// github.com/ryoku-shell, modules/notifications/NotificationCard.qml), re-
// tokenised for this rice: pure #000 card, radius 0, hairline border, JetBrains
// Mono, MotionConfig durations, ornament alpha ≤ 0.45 (QD-OLED doctrine).
//
// Shared by the toast surface (compact: true — 2-line body clamp, actions
// behind the expand chevron, draining countdown border) and the notification
// center (compact: false — full body, no countdown). The delegate outlives its
// model entry (a dismissed toast animates out after the service dropped the
// row), so every read goes through n() — the ryoku safe-read idiom.
//
// Security posture matches components/NotificationCard.qml: appName/summary/
// action labels render PlainText; the body is the one StyledText surface with
// <img> stripped.
// =============================================================================

import QtQuick
import bar.config as Config
import bar.services as Services

Rectangle {
    id: card

    property var notif: null
    function n() { return card.notif || ({}) }   // ryoku safe-read idiom

    // Popups start compact and expand on demand; the center is always full.
    property bool compact: false
    property bool expanded: false
    // The center hosts the card inside its own framed list — suppress the
    // card's own border/countdown there (ryoku's unifiedFrame).
    property bool unifiedFrame: false

    // Countdown frame (popups only): traces the border and drains over the
    // toast's lifespan. 0 = draw nothing (the center, sticky criticals).
    property int lifespanMs: 0
    readonly property bool countingDown: card.lifespanMs > 0 && !card.unifiedFrame
    property real remaining: 1
    NumberAnimation on remaining {
        running: card.countingDown
        from: 1
        to: 0
        duration: Math.max(1, card.lifespanMs)
        easing.type: Easing.Linear
    }
    // Countdown ran out → retire the toast (the service marks the row read).
    onRemainingChanged: if (card.countingDown && card.remaining <= 0)
        Services.NotificationService.toastExpired(card.n().id)

    // Only real actions get a button: the freedesktop "default" action is
    // surfaced as the ↗ open button instead, and labelless actions are dropped.
    readonly property var visibleActions: {
        var all = card.n().actions || []
        var out = []
        for (var i = 0; i < all.length; i++)
            if (all[i] && all[i].id !== "default" && (all[i].text || "").length > 0)
                out.push(all[i])
        return out
    }
    readonly property var defaultAction: {
        var all = card.n().actions || []
        for (var i = 0; i < all.length; i++)
            if (all[i] && all[i].id === "default") return all[i]
        return null
    }

    // Compact clamps the body to two lines; the chevron shows only when
    // expanding reveals something (a longer body or any action). bodyOverflows
    // is measured off a hidden unclamped copy so it stays true once expanded.
    readonly property int compactLines: 2
    readonly property bool showFull: !card.compact || card.expanded
    readonly property bool bodyOverflows: bodyMeasure.lineCount > card.compactLines
    readonly property bool expandable: card.compact && (card.visibleActions.length > 0 || card.bodyOverflows)

    readonly property color urgencyColor: card.n().urgency === 2 ? Config.ThemeConfig.colors.error
                                         : card.n().urgency === 0 ? Config.ThemeConfig.colors.textDim
                                         : Config.ThemeConfig.colors.primary

    // Pure black (pixels off on QD-OLED), radius 0, hairline border; critical
    // tints the border error (transient highlight — allowed).
    color: "#000000"
    radius: 0
    border.width: Config.PopupMetrics.hairline(card)
    border.color: card.n().urgency === 2 ? Config.ThemeConfig.colors.error
                                         : Config.ThemeConfig.hairline
    implicitHeight: body.implicitHeight + Config.PopupMetrics.px(12) * 2
    // Ease only the user-driven expand/collapse — a fresh toast must not grow
    // tall as it arrives and churn the stack (ryoku's `ready` arm).
    property bool ready: false
    Component.onCompleted: card.ready = true
    Behavior on implicitHeight {
        enabled: card.ready
        NumberAnimation { duration: Config.MotionConfig.animDurationNormal; easing.type: Config.MotionConfig.ease }
    }

    // Hidden unclamped body copy — measures whether the real body would
    // overflow the compact clamp. Never painted.
    Text {
        id: bodyMeasure
        visible: false
        width: card.width - Config.PopupMetrics.px(12) * 2
        textFormat: Text.StyledText
        text: card.stripImages(card.n().body)
        font.family: Config.BarConfig.fontUi
        font.pixelSize: Config.PopupMetrics.px(11)
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    // One header affordance: a hover-tinted square button. Open, expand and
    // close share it so the cluster reads as one control set (ryoku idiom).
    component HeaderButton: Rectangle {
        id: hb
        property string glyph: ""
        property bool spin: false
        signal clicked()

        width: Config.PopupMetrics.px(22)
        height: width
        radius: 0
        color: hbHov.containsMouse
            ? Qt.tint("#000000", Qt.rgba(1, 1, 1, 0.08))
            : "transparent"

        Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: hb.glyph
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: Config.PopupMetrics.px(11)
            color: hbHov.containsMouse ? Config.BarConfig.colorAccent
                                       : Config.BarConfig.colorTextDim
            rotation: hb.spin ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: Config.MotionConfig.move; easing.type: Config.MotionConfig.ease } }
        }
        MouseArea {
            id: hbHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hb.clicked()
        }
    }

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Config.PopupMetrics.px(12)
        spacing: Config.PopupMetrics.px(8)

        // Header: glyph swatch · app name (fills) · arrival time · the
        // open/expand/close cluster.
        Item {
            width: parent.width
            height: Math.max(swatch.height, appName.implicitHeight, btnRow.height)

            Rectangle {
                id: swatch
                anchors.verticalCenter: parent.verticalCenter
                width: Config.PopupMetrics.px(20)
                height: width
                color: "transparent"
                border.width: Config.PopupMetrics.hairline(card)
                border.color: card.urgencyColor
                Text {
                    textFormat: Text.PlainText   // untrusted
                    anchors.centerIn: parent
                    text: (card.n().glyph || "") !== "" ? card.n().glyph : "󰂚"
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: Config.PopupMetrics.px(11)
                    color: card.urgencyColor
                }
            }

            Text {
                id: appName
                textFormat: Text.PlainText   // untrusted
                anchors.left: swatch.right
                anchors.leftMargin: Config.PopupMetrics.px(8)
                anchors.right: timeLabel.left
                anchors.rightMargin: Config.PopupMetrics.px(8)
                anchors.verticalCenter: parent.verticalCenter
                text: card.n().appName || ""
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(9)
                font.bold: true
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.6
                elide: Text.ElideRight
            }

            Text {
                id: timeLabel
                textFormat: Text.PlainText   // untrusted
                anchors.right: btnRow.left
                anchors.rightMargin: Config.PopupMetrics.px(4)
                anchors.verticalCenter: parent.verticalCenter
                text: card.relativeTime(card.n().timestamp || 0, Services.NotificationService.now)
                color: Config.ThemeConfig.colors.textDim
                font.family: Config.BarConfig.fontFamily
                font.pixelSize: Config.PopupMetrics.px(9)
                opacity: 0.75
            }

            Row {
                id: btnRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                // Open: the freedesktop default action; shown only when the
                // app sent one.
                HeaderButton {
                    glyph: "↗"
                    visible: card.defaultAction !== null
                    onClicked: Services.NotificationService.activate(card.n().id)
                }
                // Expand: reveal the full body + action buttons.
                HeaderButton {
                    glyph: "›"
                    visible: card.expandable
                    spin: card.expanded
                    onClicked: card.expanded = !card.expanded
                }
                // Close: intentional dismissal (DBus-fair, row deleted).
                HeaderButton {
                    glyph: "✕"
                    onClicked: Services.NotificationService.dismiss(card.n().id)
                }
            }
        }

        // Summary: bold, wraps.
        Text {
            width: parent.width
            textFormat: Text.PlainText   // untrusted
            text: card.n().summary || ""
            color: Config.BarConfig.colorText
            font.family: Config.BarConfig.fontUi
            font.pixelSize: Config.PopupMetrics.px(12)
            font.bold: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        // Body: present when non-empty; clamped to two lines while a popup is
        // compact and collapsed, full once expanded (or in the center).
        Text {
            width: parent.width
            textFormat: Text.StyledText
            visible: (card.n().body || "").length > 0
            text: card.stripImages(card.n().body)
            onLinkActivated: (link) => Qt.openUrlExternally(link)
            color: Config.ThemeConfig.colors.textDim
            font.family: Config.BarConfig.fontUi
            font.pixelSize: Config.PopupMetrics.px(11)
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: card.showFull ? 9999 : card.compactLines
            elide: card.showFull ? Text.ElideNone : Text.ElideRight
            opacity: 0.85
        }

        // Image preview (native image hint).
        Image {
            visible: (card.n().image || "") !== ""
            width: parent.width
            height: Config.PopupMetrics.px(64)
            fillMode: Image.PreserveAspectFit
            source: card.n().image || ""
            asynchronous: true
        }

        // Progress track (native hints.value).
        Rectangle {
            visible: card.n().progress !== undefined && card.n().progress >= 0
            width: parent.width
            height: 3
            radius: 0
            color: Config.ThemeConfig.colors.border
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, card.n().progress || 0)) / 100
                height: parent.height
                color: card.urgencyColor
            }
        }

        // Actions: one full-width button per action. Hidden while a popup is
        // compact and collapsed; the chevron brings them in.
        Column {
            id: actionCol
            width: parent.width
            spacing: Config.PopupMetrics.px(6)
            visible: card.visibleActions.length > 0 && card.showFull
            opacity: card.showFull ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.animDurationFast } }

            Repeater {
                model: card.visibleActions

                delegate: Rectangle {
                    id: actionBtn
                    // modelData is the Repeater's context property — a
                    // `required property var modelData` here breaks it
                    // (JS-array model; known Quickshell trap).
                    property var act: modelData

                    width: actionCol.width
                    height: actionLabel.implicitHeight + Config.PopupMetrics.px(8) * 2
                    radius: 0
                    color: actionHov.containsMouse
                           ? Config.ThemeConfig.colors.surfaceContainer
                           : Config.ThemeConfig.colors.background
                    border.width: Config.PopupMetrics.hairline(card)
                    border.color: card.urgencyColor

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        width: parent.width - Config.PopupMetrics.px(12) * 2
                        textFormat: Text.PlainText   // untrusted
                        horizontalAlignment: Text.AlignHCenter
                        text: actionBtn.act ? (actionBtn.act.text || "") : ""
                        color: Config.BarConfig.colorText
                        font.family: Config.BarConfig.fontFamily
                        font.pixelSize: Config.PopupMetrics.px(10)
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: actionHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Services.NotificationService.markRead(card.n().id)
                            Services.NotificationService.invokeActionKey(card.n().clickId,
                                                                         actionBtn.act.id)
                            Services.NotificationService._popupDrop(card.n().id)
                        }
                    }
                }
            }
        }
    }

    // The draining countdown, stroked over the card's own border: the accent
    // traces the whole rect at full life and recedes clockwise from the top as
    // the lifespan runs out (ryoku's Canvas, accent at the ornament cap).
    Canvas {
        id: timerFrame
        anchors.fill: parent
        visible: card.countingDown
        renderStrategy: Canvas.Cooperative
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (!card.countingDown) return
            var sw = Config.PopupMetrics.hairline(card) + 1
            var o = sw / 2
            var w = width - sw
            var h = height - sw
            var perim = 2 * w + 2 * h   // radius 0 — the rect perimeter
            var drawn = Math.max(0, Math.min(perim, card.remaining * perim))
            ctx.beginPath()
            ctx.moveTo(o + w / 2, o)
            ctx.lineTo(o + w, o)
            ctx.lineTo(o + w, o + h)
            ctx.lineTo(o, o + h)
            ctx.lineTo(o, o)
            ctx.lineTo(o + w / 2, o)
            ctx.lineWidth = sw
            ctx.strokeStyle = Config.BarConfig.colorAccent
            ctx.globalAlpha = 0.45      // QD-OLED ornament cap
            ctx.lineCap = "butt"
            ctx.setLineDash([drawn, perim + 1])
            ctx.stroke()
        }
        Connections {
            target: card
            function onRemainingChanged() { timerFrame.requestPaint() }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
    }

    // <img> strip for the styled body (see NotificationCard.qml — a styled
    // <img src="file:///…"> would render local-file pixels).
    function stripImages(t) {
        return String(t || "").replace(/<img\b[^>]*>/gi, "")
    }

    function relativeTime(ts, nowMs) {
        var diff = Math.max(0, Math.floor((nowMs - ts) / 1000))
        if (diff < 45)    return "now"
        if (diff < 90)    return "1m ago"
        if (diff < 3600)  return Math.floor(diff / 60) + "m ago"
        if (diff < 7200)  return "1h ago"
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
        return Math.floor(diff / 86400) + "d ago"
    }
}
