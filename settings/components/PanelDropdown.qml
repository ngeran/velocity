// =============================================================================
// PanelDropdown.qml — Dropdown control (Shibumi pill pattern, our theme)
// =============================================================================
// Keyboard-accessible dropdown with hover states and auto-positioning.
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
// All colors resolve through ThemeConfig (surface / surfaceContainer /
// outlineVariant / accent) — no hardcoded rgb anywhere, so the control
// repaints correctly on theme switches.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config

Item {
    id: root
    width: parent ? parent.width : 140
    implicitHeight: showLabel && label !== "" ? 26 + Config.ControlConfig.space1 : 26

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
        var popupHeight = options.length * 30 + 8
        var belowY = trigger.height + 4
        if (belowY + popupHeight <= parent.height) return Qt.point(0, belowY)
        return Qt.point(0, -popupHeight - 4)
    }

    Column {
        anchors.fill: parent
        spacing: Config.ControlConfig.space1

        // Label (optional) — eyebrow style
        Text {
            visible: root.showLabel && root.label !== ""
            text: root.label
            font.family: Config.ControlConfig.fontSans
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.0
            font.capitalization: Font.AllUppercase
            color: Config.ThemeConfig.colors.textDim
            elide: Text.ElideRight
        }

        // Trigger button — themed surface pill
        Rectangle {
            id: trigger
            width: parent.width
            height: 26
            radius: Config.ControlConfig.radiusPill
            color: mouseArea.containsMouse || menu.opened
                   ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.14)
                   : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.55)
            border.color: mouseArea.containsMouse || menu.opened
                          ? Config.ControlConfig.accent
                          : Config.ThemeConfig.colors.outlineVariant
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }

            Text {
                anchors.left: parent.left; anchors.leftMargin: 10
                anchors.right: chevron.left; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentLabel()
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                color: Config.ThemeConfig.colors.text
                elide: Text.ElideRight
            }

            Text {
                id: chevron
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: menu.opened ? "󰅃" : "󰅀"
                font.family: Config.ControlConfig.fontNerd
                font.pixelSize: 9
                color: mouseArea.containsMouse ? Config.ControlConfig.accent
                                               : Config.ThemeConfig.colors.textDim
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

    // Popup menu — opaque themed surface
    Popup {
        id: menu
        parent: root
        x: 0
        y: root.menuPosition().y
        width: trigger.width
        padding: 4

        background: Rectangle {
            radius: Config.ControlConfig.radiusCard
            color: Config.ThemeConfig.colors.surfaceContainer
            border.color: Config.ThemeConfig.colors.outlineVariant
            border.width: 1
        }

        contentItem: Column {
            spacing: 0

            Repeater {
                model: root.options
                Rectangle {
                    width: trigger.width - 8
                    height: 30
                    radius: Config.ControlConfig.radiusSmall
                    color: optionMA.containsMouse
                           ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.12)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 10
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: optionLabel(modelData)
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 10
                        color: optionValue(modelData) === root.value
                               ? Config.ControlConfig.accent
                               : Config.ThemeConfig.colors.text
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

        onOpenedChanged: if (!opened) menu.close()
    }

    function toggle() {
        menu.opened ? menu.close() : menu.open()
    }

    function close() {
        menu.close()
    }
}
