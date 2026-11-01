// =============================================================================
// NotificationRow.qml — one notification card (omarchy-notification-center port)
// =============================================================================
// The card anatomy from jankeesvw's omarchy-notification-center
// (components/NotificationRow.qml, MIT), re-tokenised for this rice: PopupMetrics
// scaling, JetBrains Mono, MotionConfig durations, theme colors.
//
// Deliberate departures from the rice's old toast language (pure #000, radius 0,
// hairline borders): the omarchy card is a soft raised surface — fill = text
// color at 6 % (11 % hovered), rounded corners, NO border — and the same shape
// serves BOTH surfaces (toast + center), omarchy's "finding the toast you missed
// still sitting where it landed" doctrine. Fill opacity stays ≤ 0.11 (QD-OLED:
// dim transient surfaces, no static bright fills); the countdown border canvas
// became a thin draining accent line at the card's foot.
//
// One row, two modes:
//   toast:  true  → countdown line, inline action buttons (compact, 2-line body)
//   toast:  false → center row (no countdown, no actions; click opens)
//
// The root IS the card (Rectangle with a live implicitHeight binding, exactly
// the old NotificationToastCard shape): hosts read .implicitHeight for row
// height, and a plain-Item root + child-card indirection froze that chain at
// first evaluation on this build (proven 2026-11-01: delegate stuck at 32 px
// while the card inside measured 65).
//
// Untrusted text (appName/summary/body come off the bus): rendered PlainText
// after stripping ALL markup — Qt reads markup-looking strings as rich text and
// would fetch `<img src="http://…">` out of the shell process (omarchy's
// posture; stricter than the old StyledText+stripImages body).
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Rectangle {
    id: root

    property var notif: null
    function n() { return root.notif || ({}) }   // ryoku safe-read idiom

    property bool toast: false
    // Sticky criticals pass -1 → no countdown line.
    property int lifespanMs: 0
    property bool unread: false
    // Expired-history rows: dimmed, non-interactive (no dismiss affordance).
    property bool dead: false

    signal clicked()
    signal removeRequested()
    signal actionRequested(var act)

    readonly property bool hovered: hov.hovered
    readonly property color fg: Config.BarConfig.colorText
    readonly property bool isCritical: root.n().urgency === 2

    // Countdown frame (toasts only): the accent line drains over the toast's
    // lifespan; ran out → retire the toast (the service marks the row read).
    readonly property bool countingDown: root.toast && root.lifespanMs > 0
    property real remaining: 1
    NumberAnimation on remaining {
        running: root.countingDown
        from: 1
        to: 0
        duration: Math.max(1, root.lifespanMs)
        easing.type: Easing.Linear
    }
    onRemainingChanged: if (root.countingDown && root.remaining <= 0)
        Services.NotificationService.toastExpired(root.n().id)

    // Only real actions get a button (toast mode, capped at 2 — a card is not
    // a dialog): the freedesktop "default" action is the card click instead,
    // and labelless actions are dropped.
    readonly property var visibleActions: {
        if (!root.toast) return []
        var all = root.n().actions || []
        var out = []
        for (var i = 0; i < all.length && out.length < 2; i++)
            if (all[i] && all[i].id !== "default" && (all[i].text || "").length > 0)
                out.push(all[i])
        return out
    }

    // Icon resolution chain — per-notification media first (an avatar, album
    // art), then the desktop entry, then the app-icon/theme name the arrival
    // carried; glyph (nerd font) and initial cover the rest. All of it lives
    // in the service so both surfaces resolve identically.
    readonly property string iconSource: (root.n().image || "") !== ""
        ? root.n().image
        : Services.NotificationService.iconUrlFor(root.n().appIcon, root.n().appName)
    readonly property bool hasIcon: root.iconSource !== ""
    readonly property string initial: {
        var a = String(root.n().appName || "")
        return a === "" ? "?" : a.charAt(0).toUpperCase()
    }

    // Markup strip: images first (one <img> would also set the card's height),
    // then every tag, then collapse whitespace.
    function cleanMarkup(t) {
        return String(t || "")
            .replace(/<img[^>]*>/gi, "")
            .replace(/<[^>]+>/g, " ")
            .replace(/\s+/g, " ")
            .trim()
    }
    readonly property string cleanSummary: root.cleanMarkup(root.n().summary)
    readonly property string cleanBody: root.cleanMarkup(root.n().body)

    // Recent things get a duration, older things a clock. "4m ago" is how you
    // think about something that just happened; "16:04" is how you think about
    // something from this morning — the day is already written above the card.
    readonly property string when: {
        var age = Math.max(0, Services.NotificationService.now - (root.n().timestamp || 0))
        if (age < 60000) return "now"
        if (age < 3600000) return Math.round(age / 60000) + "m ago"
        return Qt.formatDateTime(new Date(root.n().timestamp || 0), "HH:mm")
    }

    // The card is made of the foreground at low opacity — always whatever
    // contrasts with the panel it sits on, light theme included.
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b,
                   root.hovered ? 0.11 : 0.06)
    radius: Config.PopupMetrics.px(10)
    Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }

    implicitHeight: texts.implicitHeight + Config.PopupMetrics.px(20)

    // Expired rows read as memory, not as mail: the whole card quieted.
    opacity: root.dead ? 0.45 : 1.0

    HoverHandler { id: hov }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) root.removeRequested()
            else root.clicked()
        }
    }

    // Critical keeps the one piece of color on the card: a bar down the
    // leading edge, readable from across the room an hour later.
    Rectangle {
        visible: root.isCritical
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Config.PopupMetrics.px(6)
        width: Config.PopupMetrics.px(3)
        radius: width / 2
        color: Config.ThemeConfig.colors.error
    }

    // The icon slot is always the same size, filled or not — a list whose
    // left edge moves depending on whether an app shipped an icon is a
    // list you cannot scan down.
    Item {
        id: avatar
        anchors.left: parent.left
        anchors.leftMargin: Config.PopupMetrics.px(12)
        anchors.top: parent.top
        anchors.topMargin: Config.PopupMetrics.px(10)
        width: Config.PopupMetrics.px(32)
        height: Config.PopupMetrics.px(32)

        Rectangle {
            anchors.fill: parent
            radius: Config.PopupMetrics.px(9)
            visible: !root.hasIcon
            color: root.fg
            opacity: 0.12
        }

        // The sender's nerd glyph, for apps that arrive without an icon.
        Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: !root.hasIcon && (root.n().glyph || "") !== ""
            text: root.n().glyph || ""
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.PopupMetrics.px(16)
            color: root.fg
            opacity: 0.8
        }

        // The initial, for apps that never say what they are.
        Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: !root.hasIcon && (root.n().glyph || "") === ""
            text: root.initial
            font.family: Config.BarConfig.fontUi
            font.pixelSize: Config.PopupMetrics.px(13)
            font.bold: true
            color: root.fg
            opacity: 0.7
        }

        Image {
            anchors.fill: parent
            visible: root.hasIcon
            source: root.iconSource
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }
    }

    Column {
        id: texts
        anchors.left: avatar.right
        anchors.leftMargin: Config.PopupMetrics.px(10)
        anchors.right: parent.right
        anchors.rightMargin: Config.PopupMetrics.px(12)
        anchors.top: parent.top
        anchors.topMargin: Config.PopupMetrics.px(10)
        spacing: Config.PopupMetrics.px(2)

        // App and time on one line above the message, the way every chat
        // client arranges the same three facts. The app name is the quiet
        // one; what you came to read is underneath.
        Item {
            width: parent.width
            height: appLabel.implicitHeight

            Text {
                textFormat: Text.PlainText
                id: appLabel
                anchors.left: parent.left
                width: parent.width - whenLabel.implicitWidth - Config.PopupMetrics.px(20)
                text: root.n().appName || ""
                elide: Text.ElideRight
                font.family: Config.BarConfig.fontUi
                font.pixelSize: Config.PopupMetrics.px(9)
                color: root.fg
                opacity: 0.5
            }

            // Swapped for the dismiss button while the pointer is over the
            // card — they never coexist, so neither makes room for the
            // other and the corner stays quiet until you reach for it.
            Text {
                textFormat: Text.PlainText
                id: whenLabel
                anchors.right: parent.right
                visible: !root.hovered || root.dead
                text: root.when
                font.family: Config.BarConfig.fontUi
                font.pixelSize: Config.PopupMetrics.px(9)
                color: root.fg
                opacity: 0.45
            }

            Rectangle {
                id: dismiss
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hovered && !root.dead
                width: Config.PopupMetrics.px(16)
                height: width
                radius: width / 2
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b,
                               dismissMa.containsMouse ? 0.25 : 0.15)

                Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    // A multiplication sign, not the letter x: it is in
                    // every font, at every size, and reads as "close".
                    text: "×"
                    font.family: Config.BarConfig.fontUi
                    font.pixelSize: Config.PopupMetrics.px(10)
                    color: root.fg
                    opacity: 0.8
                }

                MouseArea {
                    id: dismissMa
                    anchors.fill: parent
                    anchors.margins: -Config.PopupMetrics.px(3)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.removeRequested()
                }
            }
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.cleanSummary !== ""
            text: root.cleanSummary
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Config.BarConfig.fontUi
            font.pixelSize: Config.PopupMetrics.px(12)
            font.bold: true
            color: root.fg
        }

        // Two lines of message and no more: long enough to tell whether
        // you need to open the thing, short enough that one chatty app
        // cannot push the rest of the list off the screen.
        Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.cleanBody !== ""
            text: root.cleanBody
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            elide: Text.ElideRight
            maximumLineCount: 2
            font.family: Config.BarConfig.fontUi
            font.pixelSize: Config.PopupMetrics.px(10)
            color: root.fg
            opacity: 0.75
        }

        // The picture, when the notification came with one — the frame a
        // camera caught, the screenshot that was just taken. Contained
        // rather than edge-to-edge: a run of them keeps the list scannable
        // however tall the originals were.
        Image {
            width: parent.width
            visible: (root.n().image || "") !== ""
            height: visible ? Config.PopupMetrics.px(72) : 0
            source: root.n().image || ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }

        // Progress track (native hints.value).
        Rectangle {
            width: parent.width
            visible: root.n().progress !== undefined && root.n().progress >= 0
            height: Config.PopupMetrics.px(3)
            radius: height / 2
            color: root.fg
            opacity: 0.08
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, root.n().progress || 0)) / 100
                height: parent.height
                radius: parent.radius
                color: root.isCritical ? Config.ThemeConfig.colors.error
                                       : Config.BarConfig.colorAccent
            }
        }

        // Toast actions: quiet text buttons, one hover-tinted pill each.
        Row {
            width: parent.width
            spacing: Config.PopupMetrics.px(6)
            visible: root.visibleActions.length > 0

            Repeater {
                model: root.visibleActions

                delegate: Rectangle {
                    // modelData is the Repeater's context property — a
                    // `required property` here breaks it (JS-array model;
                    // known Quickshell trap).
                    property var act: modelData

                    width: actLabel.implicitWidth + Config.PopupMetrics.px(12)
                    height: actLabel.implicitHeight + Config.PopupMetrics.px(5)
                    radius: Config.PopupMetrics.px(4)
                    color: actMa.containsMouse
                           ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.10)
                           : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)

                    Text {
                        id: actLabel
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: act ? (act.text || "") : ""
                        font.family: Config.BarConfig.fontUi
                        font.pixelSize: Config.PopupMetrics.px(10)
                        font.bold: true
                        color: actMa.containsMouse ? root.fg
                                                   : Config.BarConfig.colorTextDim
                    }
                    MouseArea {
                        id: actMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.actionRequested(act)
                    }
                }
            }
        }
    }

    // Unread marker: an accent dot on the leading edge, where an unread
    // mail sits in every mail client.
    Rectangle {
        visible: root.unread && !root.isCritical
        anchors.left: parent.left
        anchors.leftMargin: Config.PopupMetrics.px(4)
        anchors.verticalCenter: parent.verticalCenter
        width: Config.PopupMetrics.px(5)
        height: width
        radius: width / 2
        color: Config.BarConfig.colorAccent
    }

    // The draining countdown, along the card's foot: accent at the
    // ornament cap (0.45), receding as the lifespan runs out.
    Rectangle {
        visible: root.countingDown
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.PopupMetrics.px(5)
        anchors.left: parent.left
        anchors.leftMargin: Config.PopupMetrics.px(12)
        height: Config.PopupMetrics.px(2)
        radius: height / 2
        color: Config.BarConfig.colorAccent
        opacity: 0.45
        width: Math.max(0, (parent.width - Config.PopupMetrics.px(24)) * root.remaining)
    }
}
