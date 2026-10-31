// =============================================================================
// HoverGlyph.qml — hover-reveal bar icon BASE (DU10)
// =============================================================================
// One implementation of the bar's hover-pill idiom: a nerd glyph that tints
// accent on hover/active and a label that slides in from the collapse, plus
// the click MouseArea. Subclasses (VolumeIcon, BluetoothIcon, NetworkIcon,
// LogsIcon, SettingsIcon) bind `glyph`/`label` — both reactive, so state
// glyphs (BT off, offline, muted) and live labels (the IP) stay bindings —
// and re-emit `triggered` under their historical signal names so the
// builtins/velocity.* wrappers are untouched.
//
// DELIBERATELY NOT this base: PrivacyIcon (dots cluster between glyph and
// label, demand-gated pollers, primary-tinted idle glyph, zero-width idle)
// and NotificationButton (count badge, pulse ring, right-pinned icon). They
// share only the color-hover idiom; folding them in would need more hooks
// than the duplication it saves.
//
// Motion tokens only (LogsIcon/SettingsIcon used to hardcode 120/150ms — the
// exact drift a shared base prevents).
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property bool isActive: false
    // SettingsIcon: accept right-clicks and emit rightTriggered instead of
    // hijacking left (left stays `triggered`; the subclass keeps its policy).
    property bool rightClickEnabled: false

    signal triggered()
    signal rightTriggered()

    readonly property bool expanded: ma.containsMouse

    implicitWidth: iconRow.implicitWidth
    height: Config.BarConfig.barHeight
    clip: true
    Behavior on implicitWidth {
        NumberAnimation { duration: Config.MotionConfig.move; easing.type: Config.MotionConfig.ease }
    }

    Row {
        id: iconRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.expanded ? 6 : 0

        Text {
            text: root.glyph
            font.family: Config.BarConfig.fontNerd
            font.pixelSize: Config.BarConfig.fontSizeIcon
            color: (ma.containsMouse || root.isActive)
                   ? Config.ThemeConfig.colors.accent : Config.BarConfig.colorText
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
        }
        Text {
            visible: root.expanded
            text: root.label
            font.family: Config.BarConfig.fontFamily
            font.pixelSize: Config.BarConfig.fontSizeLabel
            color: Config.ThemeConfig.colors.text
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: root.rightClickEnabled ? (Qt.LeftButton | Qt.RightButton) : Qt.LeftButton
        onClicked: function(mouse) {
            if (root.rightClickEnabled && mouse.button === Qt.RightButton) root.rightTriggered()
            else root.triggered()
        }
    }
}
