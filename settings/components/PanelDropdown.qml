// =============================================================================
// PanelDropdown.qml — Dropdown control (omarchy pattern, our theme)
// =============================================================================
// Provides keyboard-accessible dropdown with hover states and auto-positioning.
// Replaces inline Seg controls for cleaner UI.
//
// Interface:
//   property string label: ""           // Label text (optional)
//   property string value: ""           // Current selected value
//   property var options: []            // Array of {value, label} objects
//   property bool showLabel: true       // Show label above trigger
//
// Signals:
//   signal changed(string value)       // Emitted when selection changes
//
// Theme mapping (from omarchy Color.* to Config.ThemeConfig.*):
//   Color.foreground        → Config.ThemeConfig.colors.text
//   Color.accent           → Config.ControlConfig.accent
//   Color.popups.background → Config.ThemeConfig.colors.surface
//   Color.popups.border     → Config.ThemeConfig.colors.border
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config

Item {
    id: root
    width: parent ? parent.width : 140
    implicitHeight: showLabel && label !== "" ? 24 + 4 : 24

    property string label: ""
    property string value: ""
    property var options: []
    property bool showLabel: true

    signal changed(string value)

    readonly property bool popupOpen: menu.opened

    function optionValue(option) {
        return option && typeof option === "object" ? String(option.value) : String(option)
    }
    function optionLabel(option) {
        return option && typeof option === "object" ? String(option.label) : String(option)
    }
    function currentLabel() {
        for (var i = 0; i < options.length; i++) {
            if (optionValue(options[i]) === value) return optionLabel(options[i])
        }
        return value
    }
    function menuPosition() {
        var popupHeight = options.length * 26 + 8
        var belowY = trigger.height + 4
        if (belowY + popupHeight <= parent.height) return Qt.point(0, belowY)
        return Qt.point(0, -popupHeight - 4)
    }

    Column {
        anchors.fill: parent
        spacing: 4

        // Label (optional)
        Text {
            visible: root.showLabel && root.label !== ""
            text: root.label
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 8
            font.bold: true
            color: Config.ThemeConfig.colors.textDim
            elide: Text.ElideRight
        }

        // Trigger button
        Rectangle {
            id: trigger
            width: parent.width
            height: 24
            color: mouseArea.containsMouse ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.15) : Config.ThemeConfig.colors.surface
            border.color: mouseArea.containsMouse ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
            border.width: 1
            radius: 4
            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }

            Text {
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.right: chevron.left; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentLabel()
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 9
                color: Config.ThemeConfig.colors.text
                elide: Text.ElideRight
            }

            Text {
                id: chevron
                anchors.right: parent.right; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: menu.opened ? "󰅃" : "󰅀"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 8
                color: Config.ThemeConfig.colors.textDim
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggle()
            }
        }
    }

    // Popup menu
    Popup {
        id: menu
        parent: root
        x: 0
        y: root.menuPosition().y
        width: trigger.width

        Rectangle {
            width: parent.width
            height: parent.height
            color: Config.ThemeConfig.colors.surface
            border.color: Config.ThemeConfig.colors.border
            border.width: 1
            radius: 4

            Column {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: root.options
                    Rectangle {
                        width: parent.width
                        height: 28
                        color: optionMA.containsMouse ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.15) : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 8
                            anchors.right: parent.right; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: optionLabel(modelData)
                            font.family: Config.ControlConfig.fontMono
                            font.pixelSize: 9
                            color: optionValue(modelData) === root.value ? Config.ControlConfig.accent : Config.ThemeConfig.colors.text
                            font.bold: optionValue(modelData) === root.value
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: optionMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.value = optionValue(modelData)
                                root.changed(root.value)
                                menu.close()
                            }
                        }
                    }
                }
            }
        }

        onOpenedChanged: if (!opened) menu.close()
    }

    function toggle() {
        menu.opened ? menu.close() : menu.open()
    }

    function close() {
        menu.close()
    }
}
