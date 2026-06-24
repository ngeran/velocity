// =============================================================================
// TerminalLogLine.qml — one console line, colored by kind
// =============================================================================

import QtQuick
import "../config" as Config

Text {
    id: line
    property string kind: "output"

    wrapMode: Text.Wrap
    font.family: Config.ControlConfig.fontMono
    font.pixelSize: 11
    color: {
        if (kind === "input")   return Config.ControlConfig.logInput
        if (kind === "success") return Config.ControlConfig.logSuccess
        if (kind === "warning") return Config.ControlConfig.logWarning
        if (kind === "error")   return Config.ControlConfig.logError
        return Config.ThemeConfig.colors.text
    }
}
