// =============================================================================
// qs.Ui/BarPill.qml — the standard bar-widget pill (api 2)
// =============================================================================
// Glyph at rest; the label slides out on hover. Grows through implicitWidth
// (never width) so the rail's PluginSlot passes the size through.
//
//   import qs.Ui
//   BarPill {
//       ctx: root.ctx
//       icon: "󰁹"; label: "PWR 82%"
//       restColor: ctx ? ctx.theme.colors.success : "#888"
//       active: panel.opened                     // accent while the panel is open
//       onClicked: function(button) { panel.toggle() }
//       onScrolled: function(delta) { … }        // wheel, +/- angleDelta.y
//   }
// =============================================================================

import QtQuick

Item {
    id: pill

    property var ctx: null
    property string icon: ""
    property string label: ""
    // Glyph colour at rest; hover and `active` switch it to the accent.
    property color restColor: ctx && ctx.bar ? ctx.bar.colorText : "#aaaaaa"
    property bool active: false
    // Show the label without hovering.
    property bool alwaysShowLabel: false

    // Hover intent: the hover state lands after a short entry delay so
    // sweeping the bar doesn't shimmer; exit is instant. The 70/90ms
    // literals mirror the MotionConfig snap scale (Ui imports no config
    // singletons — D13).
    readonly property bool hoverLive: mouse.containsMouse
    property bool hot: false
    onHoverLiveChanged: {
        if (hoverLive) hotDelay.restart()
        else { hotDelay.stop(); hot = false }
    }
    Timer {
        id: hotDelay
        interval: 70
        onTriggered: pill.hot = true
    }
    readonly property bool expanded: (hot || alwaysShowLabel) && label !== ""
    readonly property color accent: ctx && ctx.theme ? ctx.theme.colors.accent : "#00dce5"
    // Press grammar: transient 16% ink plate + 1px settle while held, snap
    // release. Transient only, so QD-OLED-safe; press deliberately does NOT
    // set `hot` so a click never jiggles the label expansion.
    readonly property bool pressed: mouse.pressed
    readonly property color ink: pill.ctx && pill.ctx.theme ? pill.ctx.theme.colors.text : "#aaaaaa"

    signal clicked(int button)
    signal scrolled(int delta)

    implicitWidth: row.implicitWidth
    height: ctx && ctx.bar ? ctx.bar.barHeight : 30
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        color: pill.pressed ? Qt.rgba(pill.ink.r, pill.ink.g, pill.ink.b, 0.16) : "transparent"
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    Row {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        transform: Translate {
            y: pill.pressed ? 1 : 0
            Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        }
        spacing: pill.expanded ? 6 : 0

        Text {
            text: pill.icon
            font.family: pill.ctx && pill.ctx.bar ? pill.ctx.bar.fontNerd : "Space Mono"
            font.pixelSize: pill.ctx && pill.ctx.bar ? pill.ctx.bar.fontSizeIcon : 13
            color: pill.hot || pill.active ? pill.accent : pill.restColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            visible: pill.expanded
            text: pill.label
            font.family: pill.ctx && pill.ctx.bar ? pill.ctx.bar.fontFamily : "Space Mono"
            font.pixelSize: pill.ctx && pill.ctx.bar ? pill.ctx.bar.fontSizeLabel : 11
            color: pill.ctx && pill.ctx.theme ? pill.ctx.theme.colors.text : "#aaaaaa"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function(m) { pill.clicked(m.button) }
        onWheel: function(w) { pill.scrolled(w.angleDelta.y) }
    }
}
