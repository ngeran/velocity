// =============================================================================
// SinkListView.qml — output sinks + active streams for the AUDIO section
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 2

    Text {
        text: "[ OUTPUT_SINKS ]"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        font.bold: true
        color: Config.ControlConfig.accent
    }

    Repeater {
        model: Services.AudioControlService.sinks
        delegate: SinkRow {
            width: view.width
            sink: modelData
        }
    }

    Text {
        visible: Services.AudioControlService.sinks.length === 0
        text: "// no sinks detected"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
    }

    Item { width: 1; height: 8 }

    Text {
        text: "[ ACTIVE_STREAMS ]"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        font.bold: true
        color: Config.ControlConfig.accent
    }

    Repeater {
        model: Services.AudioControlService.sinkInputs
        delegate: SinkInputRow {
            width: view.width
            stream: modelData
        }
    }

    Text {
        visible: Services.AudioControlService.sinkInputs.length === 0
        text: "// no active streams"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
    }
}
