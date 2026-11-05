// =============================================================================
// NotificationRow.qml — one notification card (omarchy-notification-center port)
// =============================================================================
// The card anatomy from jankeesvw's omarchy-notification-center
// (components/NotificationRow.qml, MIT), re-tokenised for this rice: PopupMetrics
// scaling, JetBrains Mono, MotionConfig durations, theme colors.
//
// The card is a quiet raised surface: a low-alpha fill, a hairline edge, and
// one small status dot — no full-height urgency rail. Criticality shows as a
// faint error wash plus the dot; unread shares the same dot in the accent.
// That keeps the card readable at a glance without a saturated bar shouting
// across the screen, which is what the old leading rail did.
//
// Media is never shown twice: the avatar prefers the resolved app icon, then
// falls back to the notification's own image; the inline image renders only
// when it is NOT already the avatar. A drive notification that carried a
// thumbnail used to repeat that thumbnail at 72px below its own 32px copy.
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
    readonly property color errorColor: Config.ThemeConfig.colors.error
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

    // Media resolution: app identity first, content second. The desktop entry
    // (or an explicit app icon) makes the avatar; only when the app has no
    // icon does the notification's own image stand in for it. The inline image
    // is then suppressed if it already became the avatar, so one picture is
    // never stacked twice on the same card.
    readonly property string appIconSource: Services.NotificationService.iconUrlFor(
        root.n().appIcon, root.n().appName)
    readonly property string mediaImage: String(root.n().image || "")
    readonly property string iconSource: root.appIconSource !== ""
        ? root.appIconSource : root.mediaImage
    readonly property bool hasIcon: root.iconSource !== ""
    readonly property bool showInlineImage: root.mediaImage !== ""
        && root.mediaImage !== root.iconSource
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

    // A low-alpha wash over the desktop, edged by a hairline so the card holds
    // its shape on any wallpaper. Critical cards take the same wash in the
    // error hue — a tint you notice, not a rail that interrupts.
    color: {
        var c = root.isCritical ? root.errorColor : root.fg
        return Qt.rgba(c.r, c.g, c.b, root.hovered ? 0.09 : 0.06)
    }
    radius: Config.PopupMetrics.px(12)
    border.width: Config.PopupMetrics.hairline(root)
    border.color: {
        var c = root.isCritical ? root.errorColor : root.fg
        if (root.isCritical)
            return Qt.rgba(c.r, c.g, c.b, root.hovered ? 0.36 : 0.22)
        return Qt.rgba(c.r, c.g, c.b, root.hovered ? 0.16 : 0.09)
    }
    Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }

    implicitHeight: Math.max(texts.implicitHeight, avatar.height)
                    + Config.PopupMetrics.px(24)

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

    // The icon slot is always the same size, filled or not — a list whose
    // left edge moves depending on whether an app shipped an icon is a
    // list you cannot scan down.
    Item {
        id: avatar
        anchors.left: parent.left
        anchors.leftMargin: Config.PopupMetrics.px(12)
        anchors.top: parent.top
        anchors.topMargin: Config.PopupMetrics.px(12)
        width: Config.PopupMetrics.px(32)
        height: Config.PopupMetrics.px(32)

        // A soft plate behind the glyph/initial; icons sit on it too, so a
        // transparent app icon still has an edge to hold.
        Rectangle {
            anchors.fill: parent
            radius: Config.PopupMetrics.px(9)
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
            border.width: Config.PopupMetrics.hairline(root)
            border.color: root.isCritical
                ? Qt.rgba(root.errorColor.r, root.errorColor.g,
                          root.errorColor.b, 0.22)
                : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
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

        // Inset one pixel so the plate reads as a frame around the artwork.
        Image {
            anchors.fill: parent
            anchors.margins: root.hasIcon ? Config.PopupMetrics.px(1) : 0
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
        anchors.leftMargin: Config.PopupMetrics.px(11)
        anchors.right: parent.right
        anchors.rightMargin: Config.PopupMetrics.px(14)
        anchors.top: parent.top
        anchors.topMargin: Config.PopupMetrics.px(12)
        spacing: Config.PopupMetrics.px(3)

        // App and time on one line above the message. The one status dot
        // lives here, at the start of the quiet label — urgency and unread
        // share the slot instead of painting the card's whole edge.
        Item {
            width: parent.width
            height: Math.max(appLabel.implicitHeight, Config.PopupMetrics.px(10))

            Rectangle {
                id: indicator
                visible: root.isCritical || root.unread
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Config.PopupMetrics.px(5)
                height: width
                radius: width / 2
                color: root.isCritical ? root.errorColor : Config.BarConfig.colorAccent
                opacity: 0.9
            }

            Text {
                textFormat: Text.PlainText
                id: appLabel
                anchors.left: indicator.visible ? indicator.right : parent.left
                anchors.leftMargin: indicator.visible ? Config.PopupMetrics.px(7) : 0
                anchors.right: trailing.left
                anchors.rightMargin: Config.PopupMetrics.px(10)
                anchors.verticalCenter: parent.verticalCenter
                text: root.n().appName || ""
                elide: Text.ElideRight
                font.family: Config.BarConfig.fontUi
                font.pixelSize: Config.PopupMetrics.px(9)
                font.letterSpacing: 0.6
                font.capitalization: Font.AllUppercase
                color: root.fg
                opacity: 0.55
            }

            // Right corner: the clock, or a bare dismiss when reached for.
            // They never coexist, so neither makes room for the other. The
            // slot is as wide as whichever holds it — "59m ago" must never
            // overdraw the app label that anchors to its left edge.
            Item {
                id: trailing
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(Config.PopupMetrics.px(18), whenLabel.implicitWidth)
                height: parent.height

                Text {
                    textFormat: Text.PlainText
                    id: whenLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.hovered || root.dead
                    text: root.when
                    font.family: Config.BarConfig.fontUi
                    font.pixelSize: Config.PopupMetrics.px(9)
                    color: root.fg
                    opacity: 0.4
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hovered && !root.dead
                    // A multiplication sign, not the letter x: it is in
                    // every font, at every size, and reads as "close".
                    text: "×"
                    font.family: Config.BarConfig.fontUi
                    font.pixelSize: Config.PopupMetrics.px(13)
                    color: root.fg
                    opacity: dismissMa.containsMouse ? 0.9 : 0.45

                    MouseArea {
                        id: dismissMa
                        anchors.fill: parent
                        anchors.margins: -Config.PopupMetrics.px(4)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.removeRequested()
                    }
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
            opacity: 0.65
        }

        // The picture, when the notification came with one that is not
        // already the avatar — the frame a camera caught, the screenshot
        // that was just taken. Short and contained so a run of them keeps
        // the list scannable however tall the originals were.
        Image {
            width: parent.width
            visible: root.showInlineImage
            height: visible ? Config.PopupMetrics.px(60) : 0
            source: root.mediaImage
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            opacity: 0.92
        }

        // Progress track (native hints.value).
        Rectangle {
            width: parent.width
            visible: root.n().progress !== undefined && root.n().progress >= 0
            height: Config.PopupMetrics.px(2)
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

        // Toast actions: quiet text that lights in the accent on hover. No
        // resting fill means a card with actions still reads as one message,
        // not as a little toolbar.
        Row {
            width: parent.width
            spacing: Config.PopupMetrics.px(4)
            visible: root.visibleActions.length > 0

            Repeater {
                model: root.visibleActions

                delegate: Rectangle {
                    // modelData is the Repeater's context property — a
                    // `required property` here breaks it (JS-array model;
                    // known Quickshell trap).
                    property var act: modelData

                    width: actLabel.implicitWidth + Config.PopupMetrics.px(16)
                    height: Config.PopupMetrics.px(20)
                    radius: Config.PopupMetrics.px(5)
                    color: actMa.containsMouse
                           ? Config.ThemeConfig.accentTint : "transparent"

                    Text {
                        id: actLabel
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: act ? (act.text || "") : ""
                        font.family: Config.BarConfig.fontUi
                        font.pixelSize: Config.PopupMetrics.px(9)
                        font.bold: true
                        font.letterSpacing: 0.4
                        font.capitalization: Font.AllUppercase
                        color: actMa.containsMouse ? Config.BarConfig.colorAccent
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

    // The draining countdown, along the card's foot: accent at the
    // ornament cap (0.5), receding as the lifespan runs out.
    Rectangle {
        visible: root.countingDown
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.PopupMetrics.px(7)
        anchors.left: parent.left
        anchors.leftMargin: Config.PopupMetrics.px(14)
        height: Config.PopupMetrics.px(2)
        radius: height / 2
        color: Config.BarConfig.colorAccent
        opacity: 0.5
        width: Math.max(0, (parent.width - Config.PopupMetrics.px(28)) * root.remaining)
    }
}
