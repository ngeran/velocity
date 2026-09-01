// =============================================================================
// PanelSectionHeader.qml — Section header with label/value (omarchy pattern)
// =============================================================================
// Displays section labels in "LABEL · value" format (e.g., "MODE · eDP-1").
// Replaces simple Text labels with richer context.
//
// Interface:
//   property string label: ""           // Section label (e.g., "MODE")
//   property string value: ""           // Context value (e.g., "eDP-1")
//   property string text: ""            // Full text (overrides label+value)
//   property color color: Config.ThemeConfig.colors.textDim
//
// Theme mapping (from omarchy to our system):
//   foreground                → Config.ThemeConfig.colors.textDim
//   Qt.darker(foreground)     → Config.ThemeConfig.colors.border
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Text {
    id: root

    property string label: ""
    property string value: ""
    property string text: label !== "" && value !== "" ? label + " · " + value : (label || value)

    font.family: Config.ControlConfig.fontMono
    font.pixelSize: 10
    font.bold: true
    color: Config.ThemeConfig.colors.textDim
    elide: Text.ElideRight

    Behavior on color { ColorAnimation { duration: 100 } }
}
