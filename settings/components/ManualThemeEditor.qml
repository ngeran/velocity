// =============================================================================
// ManualThemeEditor.qml — Custom Theme Color Editor
// =============================================================================

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.platform
import "../config" as Config
import "../services" as Services

Item {
    id: root
    implicitWidth: 600
    implicitHeight: 400

    // List of editable color tokens with display names
    readonly property var colorTokens: [
        { key: "primary",   name: "Primary Accent",    value: Config.ThemeConfig.colors.primary },
        { key: "secondary", name: "Secondary Accent",  value: Config.ThemeConfig.colors.secondary },
        { key: "accent",    name: "Tertiary Accent",    value: Config.ThemeConfig.colors.accent },
        { key: "success",   name: "Success Color",      value: Config.ThemeConfig.colors.success },
        { key: "warning",   name: "Warning Color",      value: Config.ThemeConfig.colors.warning },
        { key: "error",     name: "Error Color",        value: Config.ThemeConfig.colors.error },
        { key: "info",      name: "Info Color",         value: Config.ThemeConfig.colors.info },
        { key: "background", name: "Background",        value: Config.ThemeConfig.colors.background },
        { key: "surface",    name: "Surface",           value: Config.ThemeConfig.colors.surface },
        { key: "text",       name: "Text Color",        value: Config.ThemeConfig.colors.text }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Header
        Text {
            text: "MANUAL THEME COLOR EDITOR"
            font.pixelSize: 14
            font.family: "monospace"
            font.bold: true
            color: Config.ThemeConfig.colors.text
            Layout.fillWidth: true
        }

        Text {
            text: "Click on any color swatch to customize. Changes are applied immediately."
            font.pixelSize: 10
            font.family: "monospace"
            color: Config.ThemeConfig.colors.textDim
            Layout.fillWidth: true
        }

        // Color grid
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 8

            Repeater {
                model: root.colorTokens

                delegate: RowLayout {
                    spacing: 10

                    // Color name
                    Text {
                        text: modelData.name
                        font.pixelSize: 10
                        font.family: "monospace"
                        color: Config.ThemeConfig.colors.text
                        Layout.preferredWidth: 120
                    }

                    // Color swatch button
                    Rectangle {
                        Layout.preferredWidth:  80
                        Layout.preferredHeight: 24
                        color: modelData.value
                        border.color: Config.ThemeConfig.colors.border
                        border.width: 1
                        radius: 4

                        Text {
                            anchors.centerIn: parent
                            text: modelData.value.toUpperCase()
                            font.pixelSize: 8
                            font.family: "monospace"
                            color: {
                                // Determine if we need light or dark text for contrast
                                var hex = modelData.value.replace("#", "")
                                if (hex.length === 6) {
                                    var r = parseInt(hex.substring(0, 2), 16)
                                    var g = parseInt(hex.substring(2, 4), 16)
                                    var b = parseInt(hex.substring(4, 6), 16)
                                    var brightness = (r * 299 + g * 587 + b * 114) / 1000
                                    return brightness > 128 ? "#000000" : "#ffffff"
                                }
                                return "#ffffff"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedToken = modelData.key
                                colorDialog.open()
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            Item { Layout.fillHeight: true }
        }

        Item { Layout.fillHeight: true }

        // Reset button
        Rectangle {
            Layout.alignment: Qt.AlignRight
            Layout.preferredWidth:  100
            Layout.preferredHeight: 28
            color: "transparent"
            border.color: Config.ThemeConfig.colors.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "RESET TO DEFAULT"
                font.pixelSize: 9
                font.family: "monospace"
                color: Config.ThemeConfig.colors.textDim
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Services.ThemeService.applyPreset("OLED Pure Black", Config.ThemeConfig.metadata.oledClamp)
                }
            }
        }
    }

    // Color picker dialog
    ColorDialog {
        id: colorDialog
        title: "Select Custom Color"

        onAccepted: {
            if (root.selectedToken) {
                // Convert QColor to hex string
                var color = colorDialog.selectedColor
                var hex = "#" +
                    ("0" + color.r.toString(16)).slice(-2) +
                    ("0" + color.g.toString(16)).slice(-2) +
                    ("0" + color.b.toString(16)).slice(-2)
                Services.ThemeService.applyManualOverride(root.selectedToken, hex)
            }
        }
    }

    property string selectedToken: ""
}
