// GENERATED from shared/components/CardRow.qml by tools/sync-shared — do not edit
// =============================================================================
// CardRow.qml — the ONE label/value readout row for quick-access cards
// =============================================================================
// CANONICAL FILE — lives in shared/, synced byte-identical into
//   bar/components/CardRow.qml          (tray-card bodies)
//   settings/components/CardRow.qml     (hosted pages that embed card readouts)
// by tools/sync-shared; drift fails tools/check-shared. Edit here only.
//
// Synced into roots with different singleton import URIs → imports nothing
// from either config tree; colors/scale arrive as properties (bar callers:
// `uiScale: Config.PopupMetrics.scale` + themed colors).
//
// Label left (dim, letter-spaced), value right (bold, elide-middle for long
// IPs/hostnames). `muted: true` renders the placeholder state ("—") dim so a
// missing readout never reads as live data. Optional trailing slot for a
// small action (Pill-style) via the `trailing` alias.
// =============================================================================

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    default property alias trailing: trailRow.data

    property string label: ""
    property string value: "—"
    property bool valueBold: true
    property bool muted: false
    property real uiScale: 1.0

    // Theme hooks (defaults = the bar's dark tokens; bind over them).
    property color textColor: "#e8edf0"
    property color labelColor: "#8a969c"
    property color valueColor: textColor

    implicitWidth: lbl.implicitWidth + val.implicitWidth + 16 * root.uiScale
    Layout.fillWidth: true
    Layout.preferredHeight: Math.round(28 * root.uiScale)

    Text {
        id: lbl
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.family: "Space Mono"
        font.pixelSize: Math.round(10 * root.uiScale)
        font.letterSpacing: 1 * root.uiScale
        color: root.labelColor
    }

    RowLayout {
        id: trailRow
        anchors.right: val.left
        anchors.rightMargin: 8 * root.uiScale
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.uiScale
    }

    Text {
        id: val
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        font.family: "Space Mono"
        font.pixelSize: Math.round(13 * root.uiScale)
        font.bold: root.valueBold
        color: root.muted ? root.labelColor : root.valueColor
        elide: Text.ElideMiddle
        width: Math.min(implicitWidth, parent.width * 0.7)
        horizontalAlignment: Text.AlignRight
    }
}
