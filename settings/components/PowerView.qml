// =============================================================================
// PowerView.qml — battery / AC power detail for the POWER section
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 10

    readonly property color _accent: {
        var p = Services.PowerControlService
        if (p.state === "charging") return Config.ControlConfig.accent
        if (p.hasSystemBattery && p.percent <= 15) return Config.ControlConfig.logError
        return Config.ControlConfig.accent
    }

    // --- Big status card ---
    Rectangle {
        width: parent.width
        height: 72
        radius: Config.ControlConfig.radius
        color: "#000000"
        border.color: view._accent
        border.width: 1

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 16
            spacing: 16

            Text {
                text: Services.PowerControlService.glyph
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 32
                color: view._accent
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    text: Services.PowerControlService.hasSystemBattery
                          ? (Services.PowerControlService.percent + "%")
                          : "AC POWER"
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 20
                    font.bold: true
                    color: view._accent
                }
                Text {
                    text: Services.PowerControlService.stateLabel
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    color: Config.ThemeConfig.colors.textDim
                }
            }
        }
    }

    // --- Battery level bar (system battery only) ---
    Rectangle {
        visible: Services.PowerControlService.hasSystemBattery
        width: parent.width
        height: 8
        radius: 2
        color: "#1a1a1a"
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, Services.PowerControlService.percent / 100))
            height: parent.height
            color: view._accent
            Behavior on width { NumberAnimation { duration: 250 } }
        }
    }

    // --- Detail rows ---
    Repeater {
        model: [
            ["SOURCE",   Services.PowerControlService.onAc ? "AC ADAPTER" : "BATTERY"],
            ["STATE",    Services.PowerControlService.stateLabel],
            ["DRAW",     Services.PowerControlService.wattage > 0 ? (Services.PowerControlService.wattage.toFixed(1) + " W") : "—"],
            ["ESTIMATE", Services.PowerControlService.hasSystemBattery ? Services.PowerControlService.timeRemaining : "—"]
        ]
        delegate: Row {
            spacing: 8
            Text {
                width: 90
                text: modelData[0]
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
                color: Config.ThemeConfig.colors.textDim
            }
            Text {
                text: modelData[1]
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 11
                color: Config.ThemeConfig.colors.text
            }
        }
    }

    // --- Peripherals (e.g. wireless mouse/keyboard batteries) ---
    Text {
        visible: Services.PowerControlService.peripherals.length > 0
        text: "[ PERIPHERALS ]"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1
        color: Config.ControlConfig.accent
    }

    Repeater {
        model: Services.PowerControlService.peripherals
        delegate: Row {
            spacing: 8
            Text {
                width: 90
                text: modelData.name
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
                elide: Text.ElideRight
            }
            Text {
                text: modelData.capacity + "%   " + modelData.status
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 11
                color: modelData.capacity <= 15 ? Config.ControlConfig.logError : Config.ThemeConfig.colors.text
            }
        }
    }
}
