// =============================================================================
// BarButton.qml — the Theme page's outlined action button
// =============================================================================
// One action style for the editor bar, the colour picker and the page's dock
// (the dock was bare text links; the editor had boxed buttons). `tint` is the
// button's colour: its border, its label, and its fill while hovered or when
// `filled`. `available` is the disabled state: dimmed and not clickable.
//
// On a fill the label takes white or black, whichever reads better on the
// tint. The theme's background colour is not used for it: a fill can be the
// same colour as the page behind it.
//
//   Components.BarButton { label: "SAVE"; onActivated: save() }
// =============================================================================

import QtQuick
import QtQuick.Layouts

import "../config" as Config
import "../lib/theme-core.mjs" as ThemeCore

Rectangle {
    id: root

    property string label: ""
    property color tint: Config.ThemeConfig.colors.secondary
    property bool available: true
    property bool filled: false

    signal activated()

    // True while the fill shows: a filled button, or a hovered one.
    readonly property bool showFill: root.filled || hover.containsMouse
    // Label colour for the fill. contrastRatio() reads "#rrggbb" strings and
    // a QML colour has no .replace, so the tint is converted first.
    readonly property string fillLabel: ThemeCore.contrastRatio("#ffffff", root.tint.toString())
                                         >= ThemeCore.contrastRatio("#000000", root.tint.toString())
                                         ? "#ffffff" : "#000000"

    // A layout hears Layout.*; a plain positioner hears the implicit size.
    implicitWidth: Math.max(52, labelText.implicitWidth + 20)
    implicitHeight: 22
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: 22
    color: root.showFill ? root.tint : "transparent"
    border.width: 1
    border.color: root.available ? root.tint : Config.ThemeConfig.colors.outline
    enabled: root.available
    opacity: root.available ? 1 : 0.45

    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: labelText

        anchors.centerIn: parent
        text: root.label
        font.pixelSize: 9
        font.bold: true
        font.letterSpacing: 1
        font.family: Config.SettingsConfig.fontFamily
        color: root.showFill ? root.fillLabel : root.tint
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
