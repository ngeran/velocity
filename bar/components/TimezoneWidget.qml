// =============================================================================
// TimezoneWidget.qml — world-clock pill for the bar (omarchy-inspired)
// =============================================================================
// Globe/clock glyph that expands on hover to the client zones' times
// ("NY 07:12 · CA 04:12"); left click opens the shared TrayCard's timezone
// body (same tray contract as Network/Bluetooth/Volume/Battery icons).
// Data lives in Services.TimezoneService (system tzdata via Intl — offline,
// DST-correct). Middle click refreshes; right click opens worldtimebuddy.
// =============================================================================

import QtQuick
import "../services" as Services
import "../config" as Config

Item {
    id: root
    // Grow through implicitWidth (NOT width) — RowLayout sizes children from
    // their implicit/preferred size; an explicit width binding is overridden,
    // so the hover pill used to overflow the fixed box and paint over the
    // neighbouring icons. The row is LEFT-anchored: the glyph stays under the
    // cursor and the label extends rightward only (omarchy pill idiom).
    implicitWidth: tzRow.implicitWidth + 12
    height: Config.BarConfig.barHeight
    // Hard guarantee: even mid-animation the pill can never paint over
    // adjacent widgets.
    clip: true

    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    property bool isActive: false
    signal trayRequested()

    readonly property bool expanded: tzMA.containsMouse
                                     && Services.TimezoneService.compactLabel !== ""

    Row {
        id: tzRow
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.expanded ? 8 : 0

        Text {
            text: "󰅐"
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.BarConfig.fontSizeIcon
            color: (root.isActive || tzMA.containsMouse)
                   ? Config.BarConfig.colorAccent
                   : Config.ThemeConfig.colors.textDim
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            visible: root.expanded
            text: Services.TimezoneService.compactLabel
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: 11
            color: Config.ThemeConfig.colors.text
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: tzMA
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton)      Services.TimezoneService.refresh()
            else if (mouse.button === Qt.RightButton)  Qt.openUrlExternally("https://www.worldtimebuddy.com/")
            else                                       root.trayRequested()
        }
    }
}
