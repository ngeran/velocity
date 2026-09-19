// =============================================================================
// ControlRow.qml — reserved-footprint label/control row (ryoku Cell port)
// =============================================================================
// The structural fix for the 720×480 dashboard-floor overflow class: the
// control side's footprint is CLAIMED, and the text column is the only party
// allowed to shrink (fillWidth + minimumWidth 0 + elide at every level). A
// long label therefore ELIDES instead of pushing controls off the panel or
// overlapping them — overlap becomes impossible by construction rather than
// tuned away (ryoku docs: "the control's footprint is reserved by the text
// column, so overlap is impossible").
//
//   caption  eyebrow line above the label (optional; elides)
//   label    the title (elides; the squeeze absorber)
//   chips    [{text, color, dim}] status badges after the label (fixed width)
//   controls DEFAULT PROPERTY — the right-side control slot (fixed footprint)
//   dimmed   0.4 opacity — ryoku rule: "an inert control stops looking live"
//
// Chips ride a var array whose identity changes with state; they are passive
// badges (no per-chip click state), so Repeater resets on reassign are safe
// here — do NOT copy this pattern onto interactive rows (see memory:
// array-identity resets Repeater).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

RowLayout {
    id: root

    default property alias controls: controlsRow.data
    property string caption: ""
    property string label: ""
    property var chips: []
    property bool dimmed: false
    property int labelPixelSize: 20

    // Zero-radius terminal language stays: sans for the label, mono for the
    // eyebrow, matching Header/SectionHeader conventions.
    property string labelFont: Config.ControlConfig.fontSans
    property string captionFont: Config.ControlConfig.fontMono

    spacing: Config.ControlConfig.space2

    // ── LEFT: the shrinking column ──────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 1
        opacity: root.dimmed ? 0.4 : 1.0
        Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.flap } }

        Text {
            visible: root.caption !== ""
            text: root.caption
            font.family: root.captionFont
            font.pixelSize: 9
            font.letterSpacing: 1.2
            color: Config.ThemeConfig.colors.textDim
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        RowLayout {
            spacing: 6
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            clip: true   // a squeezed chip clips, never pushes the controls

            Text {
                text: root.label
                font.family: root.labelFont
                font.pixelSize: root.labelPixelSize
                font.bold: true
                color: Config.ThemeConfig.colors.text
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            Repeater {
                model: root.chips

                Rectangle {
                    readonly property var chip: modelData
                    Layout.alignment: Qt.AlignVCenter
                    width: chipText.implicitWidth + 14
                    height: 16
                    radius: Config.ControlConfig.radiusSmall
                    color: Config.ThemeConfig.tint(chip.color, 0.16)
                    border.color: Config.ThemeConfig.tint(chip.color, 0.5)
                    border.width: 1

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.text
                        font.family: Config.ControlConfig.fontMono
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 0.6
                        color: chip.dim === true ? Config.ThemeConfig.colors.textDim
                                                 : Config.ThemeConfig.colors.text
                    }
                }
            }
        }
    }

    // ── RIGHT: the reserved footprint ───────────────────────────────────────
    RowLayout {
        id: controlsRow
        spacing: Config.ControlConfig.space2
        Layout.alignment: Qt.AlignVCenter
    }
}
