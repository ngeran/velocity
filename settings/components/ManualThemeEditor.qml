// =============================================================================
// ManualThemeEditor.qml — Custom Theme Color Editor
// =============================================================================
//
// Build a color scheme by typing a hex value OR picking from an in-app HSV
// color picker. Every change is applied LIVE to:
//   • the settings shell (ThemeConfig.updateColorToken)
//   • the bar (via ~/.cache/theme/colors.json, written by applyManualOverride)
//   • ghostty (via syncToExternalApps → ~/.config/ngeran/theme/ghostty.conf)
//
// The picker is implemented fully in QML (no Qt.labs.platform ColorDialog),
// because native platform dialogs are unreliable under Quickshell/Wayland.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Item {
    id: root
    implicitWidth: 600
    implicitHeight: 400

    // -------------------------------------------------------------------------
    // STATE
    // -------------------------------------------------------------------------
    property string selectedToken: ""   // token the picker is editing
    property bool   pickerOpen:   false
    property real   pickerHue:    0.0
    property real   pickerSat:    1.0
    property real   pickerVal:    1.0

    // Derived from the current HSV selection.
    readonly property string currentHex:   root.hsvToHex(root.pickerHue, root.pickerSat, root.pickerVal)
    readonly property string pureHueColor: root.hsvToHex(root.pickerHue, 1.0, 1.0)

    // Editable tokens (key into ThemeConfig.colors). value is read live in the
    // delegate so swatches + hex fields track the canonical theme reactively.
    readonly property var colorTokens: [
        { key: "primary",    name: "Primary" },
        { key: "secondary",  name: "Secondary" },
        { key: "accent",     name: "Accent" },
        { key: "success",    name: "Success" },
        { key: "warning",    name: "Warning" },
        { key: "error",      name: "Error" },
        { key: "info",       name: "Info" },
        { key: "background", name: "Background" },
        { key: "surface",    name: "Surface" },
        { key: "text",       name: "Text" },
        { key: "textDim",    name: "Text Dim" },
        { key: "border",     name: "Border" }
    ]

    // -------------------------------------------------------------------------
    // COLOR MATH HELPERS
    // -------------------------------------------------------------------------
    function isValidHex(v) {
        return typeof v === "string" && /^#[0-9A-Fa-f]{6}$/.test(v)
    }

    // HSV (h,s,v in 0..1) -> "#rrggbb"
    function hsvToHex(h, s, v) {
        h = ((h % 1) + 1) % 1
        var c = v * s
        var hp = h * 6
        var x = c * (1 - Math.abs((hp % 2) - 1))
        var r = 0, g = 0, b = 0
        if      (hp < 1) { r = c; g = x; b = 0 }
        else if (hp < 2) { r = x; g = c; b = 0 }
        else if (hp < 3) { r = 0; g = c; b = x }
        else if (hp < 4) { r = 0; g = x; b = c }
        else if (hp < 5) { r = x; g = 0; b = c }
        else             { r = c; g = 0; b = x }
        var m = v - c
        var rr = Math.round((r + m) * 255)
        var gg = Math.round((g + m) * 255)
        var bb = Math.round((b + m) * 255)
        return "#" + ("0" + rr.toString(16)).slice(-2)
                   + ("0" + gg.toString(16)).slice(-2)
                   + ("0" + bb.toString(16)).slice(-2)
    }

    // "#rrggbb" -> { h, s, v } (each in 0..1)
    function hexToHsv(hex) {
        var h = (hex || "#000000").replace("#", "")
        if (h.length !== 6) return { h: 0, s: 0, v: 0 }
        var r = parseInt(h.substring(0, 2), 16) / 255
        var g = parseInt(h.substring(2, 4), 16) / 255
        var b = parseInt(h.substring(4, 6), 16) / 255
        var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min
        var hh = 0
        if (d > 0) {
            if      (max === r) hh = ((g - b) / d) % 6
            else if (max === g) hh = (b - r) / d + 2
            else                hh = (r - g) / d + 4
            hh *= 60
            if (hh < 0) hh += 360
        }
        return { h: hh / 360, s: max === 0 ? 0 : d / max, v: max }
    }

    // Pick black or white text for contrast against a background hex.
    function contrastColor(bg) {
        var h = (bg || "#000000").replace("#", "")
        if (h.length !== 6) return "#ffffff"
        var r = parseInt(h.substring(0, 2), 16)
        var g = parseInt(h.substring(2, 4), 16)
        var b = parseInt(h.substring(4, 6), 16)
        return ((r * 299 + g * 587 + b * 114) / 1000) > 128 ? "#000000" : "#ffffff"
    }

    // -------------------------------------------------------------------------
    // PICKER ACTIONS
    // -------------------------------------------------------------------------
    function openPicker(key) {
        root.selectedToken = key
        var hsv = root.hexToHsv(Config.ThemeConfig.colors[key] || "#000000")
        root.pickerHue = hsv.h
        root.pickerSat = hsv.s
        root.pickerVal = hsv.v
        root.pickerOpen = true
    }

    function applyFromPicker() {
        if (root.selectedToken.length > 0)
            Services.ThemeService.applyManualOverride(root.selectedToken, root.currentHex)
        root.pickerOpen = false
    }

    function applyHex(key, value) {
        var v = (value || "").trim()
        if (root.isValidHex(v))
            Services.ThemeService.applyManualOverride(key, v)
    }

    // -------------------------------------------------------------------------
    // MAIN LAYOUT
    // -------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "MANUAL THEME COLOR EDITOR"
            font.pixelSize: 13
            font.family: "monospace"
            font.bold: true
            color: Config.ThemeConfig.colors.text
            Layout.fillWidth: true
        }

        Text {
            text: "Click a swatch to pick, or type a hex value. Changes apply live to QuickShell + ghostty."
            font.pixelSize: 9
            font.family: "monospace"
            color: Config.ThemeConfig.colors.textDim
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        // Token grid — scrollable + 2 columns so it fits the window without
        // overflowing. Swatch (click → picker) + hex field (type → apply).
        Flickable {
            id: tokenFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: tokenFlick.width
            contentHeight: tokenGrid.height

            GridLayout {
                id: tokenGrid
                width: tokenFlick.width
                columns: 2
                columnSpacing: 10
                rowSpacing: 6

                Repeater {
                    model: root.colorTokens

                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: modelData.name
                            font.pixelSize: 9
                            font.family: "monospace"
                            color: Config.ThemeConfig.colors.text
                            Layout.preferredWidth: 52
                        }

                        // Swatch (click → open picker). Reactive to ThemeConfig.colors.
                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 20
                            color: Config.ThemeConfig.colors[modelData.key] || "#000000"
                            border.color: Config.ThemeConfig.colors.border
                            border.width: 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openPicker(modelData.key)
                            }
                        }

                        // Hex text entry (type → apply on commit)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            color: Config.ThemeConfig.colors.background
                            border.color: Config.ThemeConfig.colors.border
                            border.width: 1

                            TextInput {
                                id: hexField
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: 9
                                font.family: "monospace"
                                color: Config.ThemeConfig.colors.text
                                selectByMouse: true
                                text: (Config.ThemeConfig.colors[modelData.key] || "#000000").toUpperCase()

                                // Re-sync from the live token color when not actively editing.
                                Binding on text {
                                    value: (Config.ThemeConfig.colors[modelData.key] || "#000000").toUpperCase()
                                    when: !hexField.activeFocus
                                    restoreMode: Binding.RestoreBinding
                                }

                                onEditingFinished: root.applyHex(modelData.key, hexField.text)
                            }
                        }
                    }
                }
            }
        }

        // Reset
        Rectangle {
            Layout.alignment: Qt.AlignRight
            Layout.preferredWidth: 140
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
                onClicked: Services.ThemeService.applyPreset("OLED Pure Black", Config.ThemeConfig.metadata.oledClamp)
            }
        }
    }

    // -------------------------------------------------------------------------
    // COLOR PICKER OVERLAY (self-contained, in-QML)
    // -------------------------------------------------------------------------
    Item {
        id: pickerOverlay
        anchors.fill: parent
        visible: root.pickerOpen
        z: 100

        // Backdrop — click outside to cancel.
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.6
            MouseArea {
                anchors.fill: parent
                onClicked: root.pickerOpen = false
            }
        }

        // Panel
        Rectangle {
            id: pickerPanel
            anchors.centerIn: parent
            width: 300
            height: 340
            color: Config.ThemeConfig.colors.surface
            border.color: Config.ThemeConfig.colors.secondary
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: "PICK COLOR  ·  " + (root.selectedToken || "").toUpperCase()
                    font.pixelSize: 10
                    font.family: "monospace"
                    color: Config.ThemeConfig.colors.text
                    Layout.fillWidth: true
                }

                // SV square + hue strip
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Saturation/Value square
                    Item {
                        id: svArea
                        Layout.preferredWidth: 180
                        Layout.preferredHeight: 180

                        // Saturation axis: white → pure hue
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Qt.Horizontal
                                GradientStop { position: 0.0; color: "#ffffff" }
                                GradientStop { position: 1.0; color: root.pureHueColor }
                            }
                        }
                        // Value axis: transparent → black
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Qt.Vertical
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                                GradientStop { position: 1.0; color: "#000000" }
                            }
                        }
                        // Cursor
                        Rectangle {
                            width: 12; height: 12; radius: 6
                            x: svArea.width * root.pickerSat - 6
                            y: svArea.height * (1 - root.pickerVal) - 6
                            color: "transparent"
                            border.color: "#ffffff"
                            border.width: 2
                        }
                        MouseArea {
                            anchors.fill: parent
                            preventStealing: true
                            function upd(mx, my) {
                                root.pickerSat = Math.max(0, Math.min(1, mx / svArea.width))
                                root.pickerVal = Math.max(0, Math.min(1, 1 - (my / svArea.height)))
                            }
                            onPressed: mouse => upd(mouse.x, mouse.y)
                            onPositionChanged: mouse => upd(mouse.x, mouse.y)
                        }
                    }

                    // Hue strip
                    Rectangle {
                        id: hueStrip
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 180
                        gradient: Gradient {
                            orientation: Qt.Vertical
                            GradientStop { position: 0.0;   color: "#ff0000" }
                            GradientStop { position: 0.166; color: "#ffff00" }
                            GradientStop { position: 0.333; color: "#00ff00" }
                            GradientStop { position: 0.5;   color: "#00ffff" }
                            GradientStop { position: 0.666; color: "#0000ff" }
                            GradientStop { position: 0.833; color: "#ff00ff" }
                            GradientStop { position: 1.0;   color: "#ff0000" }
                        }
                        Rectangle {
                            width: parent.width; height: 4
                            y: parent.height * root.pickerHue - 2
                            color: "transparent"
                            border.color: "#ffffff"
                            border.width: 2
                        }
                        MouseArea {
                            anchors.fill: parent
                            preventStealing: true
                            function upd(my) {
                                root.pickerHue = Math.max(0, Math.min(1, my / hueStrip.height))
                            }
                            onPressed: mouse => upd(mouse.y)
                            onPositionChanged: mouse => upd(mouse.y)
                        }
                    }
                }

                // Preview + hex entry
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 28
                        color: root.currentHex
                        border.color: Config.ThemeConfig.colors.border
                        border.width: 1
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        color: Config.ThemeConfig.colors.background
                        border.color: Config.ThemeConfig.colors.border
                        border.width: 1

                        TextInput {
                            id: pickerHex
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 11
                            font.family: "monospace"
                            color: Config.ThemeConfig.colors.text
                            selectByMouse: true
                            text: root.currentHex.toUpperCase()

                            Binding on text {
                                value: root.currentHex.toUpperCase()
                                when: !pickerHex.activeFocus
                                restoreMode: Binding.RestoreBinding
                            }

                            onEditingFinished: {
                                var hsv = root.hexToHsv(pickerHex.text.trim())
                                root.pickerHue = hsv.h
                                root.pickerSat = hsv.s
                                root.pickerVal = hsv.v
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Apply / Cancel
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 28
                        color: "transparent"
                        border.color: Config.ThemeConfig.colors.border
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "CANCEL"
                            font.pixelSize: 9
                            font.family: "monospace"
                            color: Config.ThemeConfig.colors.textDim
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pickerOpen = false
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 28
                        color: Config.ThemeConfig.colors.secondary
                        border.color: Config.ThemeConfig.colors.secondary
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "APPLY"
                            font.pixelSize: 9
                            font.family: "monospace"
                            font.bold: true
                            color: "#000000"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applyFromPicker()
                        }
                    }
                }
            }
        }
    }
}
