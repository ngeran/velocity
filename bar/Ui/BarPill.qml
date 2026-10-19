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

    readonly property bool hot: mouse.containsMouse
    readonly property bool expanded: (hot || alwaysShowLabel) && label !== ""
    readonly property color accent: ctx && ctx.theme ? ctx.theme.colors.accent : "#00dce5"

    signal clicked(int button)
    signal scrolled(int delta)

    implicitWidth: row.implicitWidth
    height: ctx && ctx.bar ? ctx.bar.barHeight : 30
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: pill.expanded ? 6 : 0

        Text {
            text: pill.icon
            font.family: pill.ctx && pill.ctx.bar ? pill.ctx.bar.fontNerd : "monospace"
            font.pixelSize: pill.ctx && pill.ctx.bar ? pill.ctx.bar.fontSizeIcon : 13
            color: pill.hot || pill.active ? pill.accent : pill.restColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            visible: pill.expanded
            text: pill.label
            font.family: pill.ctx && pill.ctx.bar ? pill.ctx.bar.fontFamily : "monospace"
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
