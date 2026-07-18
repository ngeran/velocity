import QtQuick
import QtQuick.Layouts

// Single usage row: label + reset info + horizontal bar gauge.
// Bar color shifts teal -> amber -> red as percentage climbs, since a
// filled OLED highlight bar risks burn-in over long uptimes at fixed
// percentages — kept as a thin outlined bar rather than a solid block.

ColumnLayout {
    id: row
    Layout.fillWidth: true
    spacing: 6

    property string label: ""
    property string sublabel: ""
    property real percentage: 0
    property color accent: "#00dce5"
    property color warnColor: "#e5b800"
    property color critColor: "#e53e3e"
    property color textPrimary: "#e8e8e8"
    property color textDim: "#6b6b6b"
    property string fontFamily: "JetBrainsMono Nerd Font"

    readonly property color barColor: percentage >= 90 ? critColor
                                       : percentage >= 75 ? warnColor
                                       : accent

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: row.label
            color: row.textPrimary
            font.family: row.fontFamily
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
        }

        Item { Layout.fillWidth: true }

        Text {
            text: row.percentage.toFixed(0) + "%"
            color: row.barColor
            font.family: row.fontFamily
            font.pixelSize: 14
            font.bold: true

            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    // outline track with animated fill — no solid static block
    Rectangle {
        Layout.fillWidth: true
        height: 6
        radius: 0
        color: "transparent"
        border.color: row.textDim
        border.width: 1

        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.min(row.percentage, 100) / 100
            color: row.barColor
            radius: 0

            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    Text {
        text: row.sublabel
        color: row.textDim
        font.family: row.fontFamily
        font.pixelSize: 9
    }
}
