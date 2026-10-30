// GENERATED from shared/components/ListRow.qml by tools/sync-shared — do not edit
// =============================================================================
// ListRow.qml — the ONE row primitive for quick-access card lists
// =============================================================================
// CANONICAL FILE — lives in shared/, synced byte-identical into
//   bar/components/ListRow.qml          (tray-card bodies)
//   settings/components/ListRow.qml     (hosted pages that embed card lists)
// by tools/sync-shared; drift fails tools/check-shared. Edit here only.
//
// Synced into roots with different singleton import URIs → imports nothing
// from either config tree; colors/scale arrive as properties (bar callers:
// `uiScale: Config.PopupMetrics.scale` + themed colors).
//
// Layout law (the reserved-footprint row): the leading glyph and the trailing
// control slot have FIXED footprints; only the title/detail column shrinks
// (fillWidth + minimumWidth 0 + elide). A long title elides — it can never
// push controls off the card or overlap them.
//
// The row-wide MouseArea sits UNDER the controls (sibling order), so toggles
// and buttons in the control slot win the pointer; clicks anywhere else fire
// clicked(). Interactive children must never rebind `dimmed` mid-click
// (array-identity law applies to the caller's model, not here).
// =============================================================================

import QtQuick
import QtQuick.Layouts

// Layout.fillWidth on the root: a card-frame column child must take the full
// row width, or the eliding title column collapses to zero (implicitWidth
// alone is only the fallback for non-layout parents).

Rectangle {
    id: root

    default property alias controls: controlsRow.data

    property string glyph: ""
    property string title: ""
    property string detail: ""
    property bool dimmed: false
    property real uiScale: 1.0
    property int rowPad: 8
    property bool hoverable: true

    // Theme hooks (defaults = the bar's dark tokens; bind over them).
    property color textColor: "#e8edf0"
    property color detailColor: "#8a969c"
    property color glyphColor: textColor
    property color accentColor: "#00dce5"
    property color hoverColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.05)

    signal clicked()

    readonly property bool isHovered: hover.containsMouse && root.hoverable
    color: root.isHovered ? root.hoverColor : "transparent"
    radius: 0
    implicitWidth: row.implicitWidth + 2 * root.rowPad * root.uiScale
    implicitHeight: row.implicitHeight + 2 * root.rowPad * root.uiScale
    Layout.fillWidth: true
    opacity: root.dimmed ? 0.4 : 1.0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.hoverable ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.hoverable
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * root.uiScale

        Text {
            visible: root.glyph !== ""
            text: root.glyph
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(14 * root.uiScale)
            color: root.isHovered ? root.accentColor : root.glyphColor
            Behavior on color { ColorAnimation { duration: 120 } }
            Layout.preferredWidth: visible ? Math.round(18 * root.uiScale) : 0
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 1

            Text {
                visible: root.title !== ""
                text: root.title
                font.family: "Space Mono"
                font.pixelSize: Math.round(11 * root.uiScale)
                font.bold: true
                color: root.textColor
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            Text {
                visible: root.detail !== ""
                text: root.detail
                font.family: "Space Mono"
                font.pixelSize: Math.round(9 * root.uiScale)
                color: root.detailColor
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
        }

        RowLayout {
            id: controlsRow
            spacing: 8 * root.uiScale
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
