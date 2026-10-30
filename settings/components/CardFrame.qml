// GENERATED from shared/components/CardFrame.qml by tools/sync-shared — do not edit
// =============================================================================
// CardFrame.qml — the ONE sectioned frame for quick-access card bodies
// =============================================================================
// CANONICAL FILE — lives in shared/, synced byte-identical into
//   bar/components/CardFrame.qml        (tray-card bodies)
//   settings/components/CardFrame.qml   (hosted pages that embed card bodies)
// by tools/sync-shared; drift fails tools/check-shared. Edit here only.
//
// This file is synced into roots with different singleton import URIs, so it
// imports NOTHING from either config tree: every color/scale arrives as a
// property. Bar callers bind themed colors + `uiScale: Config.PopupMetrics.scale`.
//
// A frame is an optional eyebrow TITLE above a content column, optionally
// boxed (bordered: true) for grouped sub-sections. Boxed hairlines stay ≤3 %
// luminance and only ever appear inside TRANSIENT popups (QD-OLED doctrine —
// never use this as an always-on container).
// =============================================================================

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    default property alias content: slot.data

    property string title: ""
    property bool bordered: false
    property real uiScale: 1.0
    property int pad: 10
    property int contentSpacing: 6

    // Theme hooks (defaults are the bar's dark tokens; bind over them).
    property color titleColor: "#6a7a82"
    property color hairlineColor: "#141414"
    property color surfaceColor: "transparent"

    color: root.surfaceColor
    radius: 0
    border.color: root.hairlineColor
    border.width: root.bordered ? Math.max(1, Math.round(root.uiScale)) : 0
    implicitHeight: col.implicitHeight + 2 * root.pad * root.uiScale

    ColumnLayout {
        id: col
        x: root.pad * root.uiScale
        y: root.pad * root.uiScale
        width: parent.width - 2 * x
        spacing: root.contentSpacing * root.uiScale

        Text {
            visible: root.title !== ""
            text: root.title
            font.family: "Space Mono"
            font.pixelSize: Math.round(9 * root.uiScale)
            font.letterSpacing: 1.2 * root.uiScale
            color: root.titleColor
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            elide: Text.ElideRight
        }

        // The content column: children land here via the default alias.
        ColumnLayout {
            id: slot
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: root.contentSpacing * root.uiScale
        }
    }
}
