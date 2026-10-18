// qs.Ui/BarIconButton.qml — compat icon button for Quattro bar-widgets.
// House bar-icon idiom (NetworkIcon/VolumeIcon/nikos.keyboard pill):
//   • rest      — glyph only, theme text color
//   • hover     — glyph flips to theme accent (90ms snap) and the optional
//                 `label` reveals to the right; the pill grows via implicitWidth
//                 (150ms OutCubic — the slot passes implicit size through, so
//                 the rail shifts the glyph LEFT as the label unfolds)
//   • no wash, no tooltip, no fixed widths — PluginSlot's T6 regression note.
// Theme comes from the canonical bar/Commons reader (theme-reactive,
// self-reads ~/.cache/theme/colors.json; vendored qs/Commons has no palette).
import QtQuick
import "file:///home/nikos/.config/quickshell/bar/Commons" as CT

Item {
    id: root

    property var bar: null              // accepted for source compat; theme is CT.Theme
    property string text: ""
    property string label: ""           // hover-reveal text (e.g. "X-RAY"); "" = icon-only
    property string fontFamily: "monospace"
    property string labelFontFamily: "JetBrains Mono"   // = BarConfig.fontFamily (house label face)
    property int fontPixelSize: 13
    property string tooltipText: ""     // accepted for source compat; house icons show no tooltips
    signal pressed(var button)

    readonly property bool hot: ma.containsMouse

    clip: true
    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(glyph.implicitHeight, revealLabel.implicitHeight) + 8
    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.hot ? 6 : 0

        Text {
            id: glyph
            text: root.text
            font.family: root.fontFamily
            font.pixelSize: root.fontPixelSize
            color: root.hot ? CT.Theme.colors.accent : CT.Theme.colors.text
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        Text {
            id: revealLabel
            visible: root.label !== "" && root.hot
            text: root.label
            font.family: root.labelFontFamily
            font.pixelSize: 11
            color: CT.Theme.colors.text
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.pressed(root)
    }
}
