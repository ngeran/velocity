// =============================================================================
// components/BentoCard.qml
// Reusable Bento Grid Card Container
//
// USAGE:
//   UI.BentoCard {
//       Layout.row: 0; Layout.column: 0
//       Layout.rowSpan: 2; Layout.columnSpan: 6
//       Layout.fillWidth: true; Layout.fillHeight: true
//
//       Text { text: "content goes here" }
//   }
//
// NOTES:
//   - `default property alias` means any child items placed inside BentoCard
//     are automatically parented into the inner `container` Item, not cardRoot.
//     This prevents children from escaping the 1px border inset margin.
//   - radius: 0 enforces flat 90-degree corners — do not change for this theme.
//   - border.width is intentionally 1px. Thicker borders conflict with the
//     tight grid spacing and OLED contrast ratio at dark values.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "." as UI     // Resolves Colors singleton from the same components/ dir

Rectangle {
    id: cardRoot

    // -------------------------------------------------------------------------
    // VISUAL SURFACE
    // -------------------------------------------------------------------------
    color:         UI.Colors.surface
    border.color:  UI.Colors.outline
    border.width:  1
    radius:        0   // Hard flat corners — no softening

    // -------------------------------------------------------------------------
    // CONTENT SLOT
    // `default property alias` re-routes declarative children into `container`.
    // This means: BentoCard { Text {} } places Text inside container, not root.
    // The 1px anchors.margins insets content away from the border line.
    // -------------------------------------------------------------------------
    default property alias cardContent: container.data

    Item {
        id: container
        anchors.fill:    parent
        anchors.margins: 1  // Keeps content clear of the 1px border
    }
}
