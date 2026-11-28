// =============================================================================
// settings/components/ThemePresetCard.qml
// One row of the Theme page's presets column: a theme, how legible it is, and
// what can be done with it. Curated, custom and Omarchy folder themes all use
// this card; the caller decides which actions to offer.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../lib/theme-core.mjs" as ThemeCore

Rectangle {
    id: root

    // ── PUBLIC API ───────────────────────────────────────────────────────────
    property string themeName: ""
    property bool isActive: false
    // The palette the card shows. Curated presets leave it null and are looked
    // up by name; custom and folder themes pass their colors.
    property var paletteOverride: null
    // Custom palettes only: adds EDIT and DEL beside CLONE.
    property bool showActions: false
    // A neutral chip naming where the theme comes from ("OMARCHY").
    property string sourceTag: ""
    // The list sets these; the defaults are one row of the presets column.
    property real cardWidth: 264
    property real cardHeight: 60

    signal clicked()
    signal editClicked()
    signal deleteClicked()
    signal cloneClicked()
    // HOVER PREVIEW (P5.4): the caller fades the live palette to this card's
    // theme on enter and back on leave.
    signal previewEntered()
    signal previewExited()

    readonly property string fUi: Config.SettingsConfig.fontFamily
    readonly property string fMono: Config.ControlConfig.fontNerd

    // The palette AS SAVED — the contrast is judged before any clamp.
    readonly property var sourcePalette:
        root.paletteOverride || Config.ThemePresets.getPalette(root.themeName)
        || Config.ThemePresets.getPalette("OLED Pure Black")

    // WCAG contrast of the palette's text on its own background.
    readonly property real textContrast:
        ThemeCore.contrastRatio(root.sourcePalette.text, root.sourcePalette.background)

    // Right of the name, in this order: ACTIVE, the contrast level, the source.
    readonly property var chips: {
        var c = Config.ThemeConfig.colors
        var list = []
        if (root.isActive) list.push({ label: "ACTIVE", fg: c.accent, edge: c.accent })
        var level = ThemeCore.contrastLabel(root.textContrast)
        list.push({ label: level, fg: level === "LOW" ? c.warning : c.textDim,
                    edge: level === "LOW" ? c.warning : c.outline })
        if (root.sourceTag !== "")
            list.push({ label: root.sourceTag, fg: c.textDim, edge: c.outline })
        return list
    }

    // The 12 tokens a reader recognises a theme by, neutrals first.
    readonly property var swatches: [
        root.sourcePalette.background, root.sourcePalette.surface,
        root.sourcePalette.surfaceVariant, root.sourcePalette.surfaceContainer,
        root.sourcePalette.text, root.sourcePalette.textDim,
        root.sourcePalette.border, root.sourcePalette.outline,
        root.sourcePalette.outlineVariant,
        root.sourcePalette.primary, root.sourcePalette.secondary, root.sourcePalette.accent
    ]

    // ── CARD ──────────────────────────────────────────────────────────────────
    implicitWidth: cardWidth
    implicitHeight: cardHeight
    // The chrome follows the ACTIVE theme; only the strip shows the preset.
    color: press.containsMouse ? Config.ThemeConfig.colors.surfaceVariant
                              : Config.ThemeConfig.colors.background
    border.color: root.isActive ? Config.ThemeConfig.colors.accent
                                : Config.ThemeConfig.colors.border
    border.width: 1
    radius: 0

    // ── INTERACTION ───────────────────────────────────────────────────────────
    // No focus/Keys handling: cards once took focus and the last one drew a
    // second active border. The shell does no keyboard navigation here. The
    // action links above sit on top of this area.
    MouseArea {
        id: press

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.clicked()
        onEntered: root.previewEntered()
        onExited: root.previewExited()
    }

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Config.ThemeConfig.colors.primary
        opacity: press.pressed ? 0.04 : (press.containsMouse ? 0.02 : 0.0)

        Behavior on opacity {
            NumberAnimation { duration: Config.MotionConfig.animDurationFast; easing.type: Easing.OutQuad }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
            topMargin: 8
            bottomMargin: 8
        }
        spacing: 5

        // Name and chips.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.themeName
                font.family: root.fUi
                font.pixelSize: 10
                font.bold: root.isActive
                color: Config.ThemeConfig.colors.text
                elide: Text.ElideRight
            }

            Row {
                spacing: 4

                Repeater {
                    model: root.chips

                    delegate: Rectangle {
                        readonly property var chip: modelData

                        width: chipText.implicitWidth + 8
                        height: 12
                        radius: 0
                        color: "transparent"
                        border.width: 1
                        border.color: chip.edge

                        Text {
                            id: chipText

                            anchors.centerIn: parent
                            text: chip.label
                            font.family: root.fUi
                            font.pixelSize: 7
                            font.bold: true
                            font.letterSpacing: 1
                            color: chip.fg
                        }
                    }
                }
            }
        }

        // Swatch strip.
        Row {
            id: strip

            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: root.swatches

                delegate: Rectangle {
                    width: (strip.width - 11 * strip.spacing) / 12
                    height: 8
                    radius: 0
                    color: modelData
                    border.width: 1
                    border.color: Config.ThemeConfig.colors.outline
                }
            }
        }

        // Actions, and the measured contrast at the right.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "CLONE"
                font.family: root.fUi
                font.pixelSize: 7
                font.bold: true
                font.letterSpacing: 1
                color: cloneMA.containsMouse ? Config.ThemeConfig.colors.info
                                             : Config.ThemeConfig.colors.textDim
                Behavior on color { ColorAnimation { duration: Config.MotionConfig.animDurationFast } }

                MouseArea {
                    id: cloneMA

                    anchors.fill: parent
                    anchors.margins: -4   // slack around 7px type
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cloneClicked()
                }
            }

            Text {
                visible: root.showActions
                text: "EDIT"
                font.family: root.fUi
                font.pixelSize: 7
                font.bold: true
                font.letterSpacing: 1
                color: editMA.containsMouse ? Config.ThemeConfig.colors.primary
                                            : Config.ThemeConfig.colors.textDim
                Behavior on color { ColorAnimation { duration: Config.MotionConfig.animDurationFast } }

                MouseArea {
                    id: editMA

                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editClicked()
                }
            }

            Text {
                visible: root.showActions
                text: "DEL"
                font.family: root.fUi
                font.pixelSize: 7
                font.bold: true
                font.letterSpacing: 1
                color: delMA.containsMouse ? Config.ThemeConfig.colors.error
                                           : Config.ThemeConfig.colors.textDim
                Behavior on color { ColorAnimation { duration: Config.MotionConfig.animDurationFast } }

                MouseArea {
                    id: delMA

                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.deleteClicked()
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.textContrast.toFixed(1) + ":1"
                font.family: root.fMono
                font.pixelSize: 7
                color: Config.ThemeConfig.colors.textDim
            }
        }
    }
}
