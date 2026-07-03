// =============================================================================
// SourceListView.qml — audio sources (microphones) for the AUDIO section
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 2

    Text {
        text: "[ INPUT_SOURCES ]"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        font.bold: true
        color: Config.ControlConfig.accent
    }

    Repeater {
        model: Services.AudioControlService.sources
        delegate: SourceRow {
            width: view.width
            source: modelData
        }
    }

    Text {
        visible: Services.AudioControlService.sources.length === 0
        text: "// no sources detected"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
    }

    Item { width: 1; height: 12 }
}
