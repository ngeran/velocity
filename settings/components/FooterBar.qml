// =============================================================================
// FooterBar.qml — Dashboard Footer Bar
// =============================================================================
//
// Footer bar with sync status indicator and session token.
//
// PUBLIC API
//   — No public properties
//
// LAYOUT
//   - Height: 36px
//   - Border top: 1px outlineVariant
//   - Background: Qt.rgba(1,1,1,0.03)
//   - Left: "SYSTEM SYNC ACTIVE" 9px textDim, letterSpacing 2.0
//   - Right: hex session token (generated once on load)
//
// CONSTRAINTS
//   radius: 0 everywhere
//   monospace font on all Text
//   ThemeConfig colors
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root

    // =========================================================================
    // APPEARANCE
    // =========================================================================

    height: 36
    color: Qt.rgba(1, 1, 1, 0.03)
    radius: 0

    // Top border
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: Config.ThemeConfig.colors.border
    }

    // =========================================================================
    // SESSION TOKEN (generated once on load)
    // =========================================================================

    property string _token: "0x" + Math.floor(Math.random() * 65535)
                                        .toString(16).toUpperCase().padStart(4, "0")

    // =========================================================================
    // MAIN LAYOUT
    // =========================================================================

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 16
            rightMargin: 16
        }
        spacing: 0

        // Left: "SYSTEM SYNC ACTIVE"
        Text {
            text: "SYSTEM SYNC ACTIVE"
            font.pixelSize: 9
            font.family: "monospace"
            font.letterSpacing: 2.0
            color: Config.ThemeConfig.colors.textDim
        }

        Item { Layout.fillWidth: true }

        // Right: session token
        Text {
            text: root._token
            font.pixelSize: 9
            font.family: "monospace"
            font.letterSpacing: 1.0
            color: Config.ThemeConfig.colors.secondary
        }
    }
}
