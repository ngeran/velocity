// =============================================================================
// WeatherWidget.qml — Vertical Strip Weather Widget
// =============================================================================
//
// Compact vertical weather display for 1-column grid strip.
//
// PUBLIC API
//   property string city — City name (default: "ATHENS")
//   property real tempNow — Current temperature
//   property string condition — Weather condition text
//   property string icon — Weather icon/glyph
//
// LAYOUT (vertical strip)
//   - Weather icon (centered, large)
//   - Temperature (bold, centered)
//   - City name (small, dim)
//   - Condition (small, dim)
//
// CONSTRAINTS
//   radius: 0 everywhere
//   monospace font on all Text
//   ThemeConfig colors
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Item {
    id: root

    // =========================================================================
    // PUBLIC PROPERTIES (replace with real data bindings)
    // =========================================================================

    property string city: "ATHENS"
    property real tempNow: 18
    property string condition: "PARTLY CLOUDY"
    property string icon: "☀"

    // =========================================================================
    // BACKGROUND
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        radius: 0
    }

    // =========================================================================
    // MAIN LAYOUT (vertical strip)
    // =========================================================================

    ColumnLayout {
        anchors {
            fill: parent
            topMargin: 16
            bottomMargin: 16
        }
        spacing: 8

        // ── Weather icon ─────────────────────────────────────────────────────

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            font.pixelSize: 32
            font.family: "monospace"
            color: Config.ThemeConfig.colors.text
        }

        // ── Temperature ────────────────────────────────────────────────────────

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Math.round(root.tempNow) + "°"
            font.pixelSize: 20
            font.family: "monospace"
            font.weight: Font.Bold
            color: Config.ThemeConfig.colors.text
        }

        // ── Divider ─────────────────────────────────────────────────────────────

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 20
            Layout.preferredHeight: 1
            color: Config.ThemeConfig.colors.border
        }

        // ── City name ─────────────────────────────────────────────────────────

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.city
            font.pixelSize: 9
            font.family: "monospace"
            font.letterSpacing: 1.0
            color: Config.ThemeConfig.colors.textDim
            horizontalAlignment: Text.AlignHCenter
        }

        // ── Condition ───────────────────────────────────────────────────────────

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.condition
            font.pixelSize: 7
            font.family: "monospace"
            font.letterSpacing: 0.5
            color: Config.ThemeConfig.colors.textDim
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.2
        }

        Item { Layout.fillHeight: true }
    }
}
