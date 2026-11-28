// ThemeModule.qml - Themes tab: pick a palette, edit it token by token, move it
// in and out. One screen at the usual window size; a shorter window scrolls the
// editor column.
//
//   +----------------------------------------------------------------------+
//   | OLED SAFE  FOLLOW WALLPAPER  HOVER PREVIEW  | MASTER SWATCHES (strip) |
//   +-------------------------+--------------------------------------------+
//   | [CURATED (7)] [CUSTOM]  | action bar: status, wallpaper / stylix, undo |
//   | one wide card per row   | COLOR MATRIX: 4 x 4 tiles, hex typed inline  |
//   | name, chips, swatches   | picker for the selected tile | Ghostty view   |
//   | CLONE / EDIT / DEL      |--------------------------------------------|
//   | + CREATE PRESET         | DOCK: formats, export, name + SAVE, imports  |
//   +-------------------------+--------------------------------------------+
//
// Cards are ThemePresetCard, the editor is ManualThemeEditor. Every colour here
// follows the active theme (Config.ThemeConfig.colors).
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services
import "." as Components

Item {
    id: root

    // A destroyed card never emits previewExited - end any armed hover preview.
    Component.onDestruction: Services.ThemeService.endPreview()
    // The themes folder is read when the page first opens.
    Component.onCompleted: Services.ThemeService.scanOmarchyThemes()

    // ---- state ---------------------------------------------------------------
    property string currentTheme: Config.ThemeConfig.metadata.name || "OLED Pure Black"
    // The clamp is ON unless the theme says otherwise (never `|| false`).
    property bool oledClampEnabled: Config.ThemeConfig.metadata.oledClamp !== false
    property bool followWallpaper: Services.SettingsConfigService.matugenOnWallpaperChange
    property bool hoverPreviewEnabled: Services.SettingsConfigService.themeHoverPreview
    readonly property var extendedThemes: Config.ThemePresets.paletteNames

    // "curated" | "custom" - which list the presets column shows.
    property string presetTab: "curated"

    // The custom list = saved palettes, then folder themes not saved yet. A saved
    // palette and a folder theme with the same name are ONE card: a click on a
    // folder card imports it, and from then on it is saved and tagged OMARCHY.
    readonly property var customCards: {
        var saved = Services.ThemeService.customThemes || []
        var folder = Services.ThemeService.omarchyThemes || []
        var byName = {}, done = {}, out = []
        var i, j
        for (j = 0; j < folder.length; j++) byName[folder[j].name] = folder[j]
        for (i = 0; i < saved.length; i++) {
            var f = byName[saved[i].name]
            done[saved[i].name] = true
            out.push({ name: saved[i].name, colors: saved[i].colors,
                       folderOnly: false, omarchy: !!f, path: f ? f.path : "" })
        }
        for (j = 0; j < folder.length; j++) {
            if (!done[folder[j].name])
                out.push({ name: folder[j].name, colors: folder[j].colors,
                           folderOnly: true, omarchy: true, path: folder[j].path })
        }
        return out
    }
    readonly property int folderOnlyCount: {
        var n = 0
        for (var i = 0; i < root.customCards.length; i++)
            if (root.customCards[i].folderOnly) n++
        return n
    }

    readonly property var spectrumTokens: [
        { key: "background", tier: "structural" },
        { key: "surface", tier: "structural" },
        { key: "surfaceVariant", tier: "structural" },
        { key: "surfaceContainer", tier: "structural" },
        { key: "text", tier: "structural" },
        { key: "textDim", tier: "structural" },
        { key: "border", tier: "structural" },
        { key: "outline", tier: "structural" },
        { key: "outlineVariant", tier: "structural" },
        { key: "primary", tier: "accent" },
        { key: "secondary", tier: "accent" },
        { key: "accent", tier: "accent" },
        { key: "success", tier: "semantic" },
        { key: "warning", tier: "semantic" },
        { key: "error", tier: "semantic" },
        { key: "info", tier: "semantic" }
    ]
    // One bar per DISTINCT colour of the palette, tallest for the accents.
    readonly property var uniqueSpectrumColors: {
        var seen = {}, out = []
        var cols = Config.ThemeConfig.colors
        for (var i = 0; i < root.spectrumTokens.length; i++) {
            var t = root.spectrumTokens[i], c = cols[t.key]
            if (c && !seen[c]) { seen[c] = true; out.push({ key: t.key, color: c, tier: t.tier }) }
        }
        return out
    }

    // ---- actions that span the lists and the editor --------------------------

    // CLONE: a saved copy under "<name> copy", applied and opened in the editor
    // under its own name.
    function cloneCard(name, palette) {
        var copy = Services.ThemeService.cloneTheme(name, palette)
        manualEditor.editing = true
        nameField.text = copy
    }

    // CREATE: the live palette in the editor, under a name still to be typed.
    // Nothing is saved until SAVE.
    function startCreate() {
        manualEditor.editing = true
        manualEditor.selectToken("background")
        nameField.text = ""
        nameField.focusInput()
    }

    // ---- small building blocks of this page ----------------------------------

    // One-line text field with a placeholder. Enter submits; leaving the field
    // does not (a name must not be saved just because focus moved on).
    component Field: Rectangle {
        id: field
        property string placeholder: ""
        property alias text: input.text
        signal submitted()
        // Focus the text, not the frame (CREATE and a nameless SAVE land here).
        function focusInput() { input.forceActiveFocus() }
        // The height of a BarButton, so a dock row shares one baseline.
        implicitHeight: 22
        color: Config.ThemeConfig.colors.background
        border.width: 1
        border.color: input.activeFocus ? Config.ThemeConfig.colors.accent
                                        : Config.ThemeConfig.colors.outline
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            color: Config.ThemeConfig.colors.text
            font.pixelSize: 9
            font.family: Config.SettingsConfig.fontFamily
            selectByMouse: true
            clip: true
            Keys.onReturnPressed: field.submitted()
            Keys.onEnterPressed: field.submitted()
        }
        Text {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: Text.AlignVCenter
            visible: input.text === "" && !input.activeFocus
            text: field.placeholder
            font.pixelSize: 9
            font.family: Config.SettingsConfig.fontFamily
            color: Config.ThemeConfig.colors.textDim
            elide: Text.ElideRight
        }
    }

    // One segment of a segmented control (CURATED | CUSTOM, JSON | BASE16 | ...).
    component SegTab: Rectangle {
        id: tab
        property string label: ""
        property bool selected: false
        signal activated()
        implicitWidth: tabText.implicitWidth + 16
        implicitHeight: 20
        color: tab.selected ? Qt.alpha(Config.ThemeConfig.colors.accent, 0.12) : "transparent"
        border.width: 1
        border.color: tab.selected ? Config.ThemeConfig.colors.accent
                                   : Config.ThemeConfig.colors.outline
        Text {
            id: tabText
            anchors.centerIn: parent
            text: tab.label
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 1
            font.family: Config.SettingsConfig.fontFamily
            color: tab.selected ? Config.ThemeConfig.colors.text
                                : Config.ThemeConfig.colors.textDim
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tab.activated()
        }
    }

    // The dashed "+ CREATE PRESET" row that ends the custom list.
    component CreateCard: Rectangle {
        id: create
        signal activated()
        // Repainted when the theme changes colour under it.
        property color dash: Config.ThemeConfig.colors.outlineVariant
        implicitHeight: 40
        color: "transparent"
        Canvas {
            id: canvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = create.dash
                ctx.lineWidth = 1
                ctx.setLineDash([4, 3])
                ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
        onDashChanged: canvas.requestPaint()
        Text {
            anchors.centerIn: parent
            text: "+ CREATE PRESET"
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 1
            font.family: Config.SettingsConfig.fontFamily
            color: createMouse.containsMouse ? Config.ThemeConfig.colors.text
                                             : Config.ThemeConfig.colors.textDim
        }
        MouseArea {
            id: createMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: create.activated()
        }
    }

    // ---- layout ---------------------------------------------------------------

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ---- header strip: the three switches, then the palette itself ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: "#000000"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 14

                RowLayout {
                    spacing: 6
                    Text {
                        text: "OLED SAFE"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1
                        font.family: Config.SettingsConfig.fontFamily
                        color: root.oledClampEnabled ? Config.ThemeConfig.colors.text
                                                     : Config.ThemeConfig.colors.textDim
                    }
                    ToggleSwitch {
                        checked: root.oledClampEnabled
                        onToggled: Services.ThemeService.setOledClamp(!root.oledClampEnabled)
                    }
                }
                RowLayout {
                    spacing: 6
                    Text {
                        text: "FOLLOW WALLPAPER"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1
                        font.family: Config.SettingsConfig.fontFamily
                        color: root.followWallpaper ? Config.ThemeConfig.colors.text
                                                    : Config.ThemeConfig.colors.textDim
                    }
                    ToggleSwitch {
                        checked: root.followWallpaper
                        onToggled: Services.SettingsConfigService.setMatugenOnWallpaperChange(
                                       !Services.SettingsConfigService.matugenOnWallpaperChange)
                    }
                }
                RowLayout {
                    spacing: 6
                    Text {
                        text: "HOVER PREVIEW"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1
                        font.family: Config.SettingsConfig.fontFamily
                        color: root.hoverPreviewEnabled ? Config.ThemeConfig.colors.text
                                                        : Config.ThemeConfig.colors.textDim
                    }
                    ToggleSwitch {
                        checked: root.hoverPreviewEnabled
                        onToggled: {
                            Services.SettingsConfigService.setThemeHoverPreview(checked)
                            if (!checked) Services.ThemeService.endPreview()
                        }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: Config.ThemeConfig.colors.outlineVariant
                }

                Text {
                    text: "MASTER SWATCHES"
                    font.pixelSize: 7
                    font.bold: true
                    font.letterSpacing: 1
                    font.family: Config.SettingsConfig.fontFamily
                    color: Config.ThemeConfig.colors.textDim
                }

                // A plain Item, not a nested layout: bars are placed by hand.
                Rectangle {
                    id: spectrumArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    clip: true

                    Repeater {
                        model: root.uniqueSpectrumColors
                        Rectangle {
                            x: index * (parent.width / root.uniqueSpectrumColors.length)
                            width: Math.max(6, parent.width / root.uniqueSpectrumColors.length - 8)
                            height: modelData.tier === "accent" ? parent.height - 2
                                  : modelData.tier === "semantic" ? parent.height - 6
                                                                  : parent.height - 10
                            anchors.bottom: parent.bottom
                            color: modelData.color
                            // A 1 px outline: the background token's bar is black,
                            // and so is the strip behind it.
                            border.width: 1
                            border.color: Config.ThemeConfig.colors.outline
                        }
                    }
                }
            }
        }

        // ---- external apps that refused the last sync ----
        Text {
            Layout.fillWidth: true
            visible: Services.ThemeService.syncerFailureSummary.length > 0
            text: "APP SYNC FAILED: " + Services.ThemeService.syncerFailureSummary
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 0.5
            font.family: Config.SettingsConfig.fontFamily
            color: Config.ThemeConfig.colors.error
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.ThemeConfig.colors.outlineVariant
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // ---- presets column ----
            ColumnLayout {
                // The column keeps its width; the editor takes the rest.
                Layout.preferredWidth: 300
                Layout.fillWidth: false
                Layout.minimumWidth: 260
                Layout.maximumWidth: 300
                Layout.fillHeight: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    SegTab {
                        label: "CURATED (" + root.extendedThemes.length + ")"
                        selected: root.presetTab === "curated"
                        onActivated: {
                            root.presetTab = "curated"
                            Services.ThemeService.endPreview()
                        }
                    }
                    SegTab {
                        label: "CUSTOM (" + root.customCards.length + ")"
                        selected: root.presetTab === "custom"
                        onActivated: {
                            root.presetTab = "custom"
                            Services.ThemeService.endPreview()
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.presetTab === "curated"
                              ? root.extendedThemes.length + " PRESETS"
                              : (Services.ThemeService.customThemes || []).length + " SAVED"
                                + (root.folderOnlyCount > 0
                                   ? " + " + root.folderOnlyCount + " IN FOLDER" : "")
                        font.pixelSize: 8
                        font.letterSpacing: 1
                        font.family: Config.SettingsConfig.fontFamily
                        color: Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight
                    }
                }

                // Both lists fill this one slot; only the selected tab is visible.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: curatedList
                        anchors.fill: parent
                        visible: root.presetTab === "curated"
                        clip: true
                        spacing: 6
                        cacheBuffer: 320
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.extendedThemes

                        delegate: Components.ThemePresetCard {
                            width: curatedList.width - 6
                            themeName: modelData
                            isActive: root.currentTheme === modelData
                            onClicked: {
                                Services.ThemeService.applyPreset(modelData, root.oledClampEnabled)
                                manualEditor.editing = false
                            }
                            onCloneClicked: root.cloneCard(
                                modelData, Config.ThemePresets.getPalette(modelData))
                            onPreviewEntered: if (root.hoverPreviewEnabled && !manualEditor.editing)
                                Services.ThemeService.previewTheme(Config.ThemePresets.getPalette(modelData))
                            onPreviewExited: Services.ThemeService.endPreview()
                        }
                    }

                    ListView {
                        id: customList
                        anchors.fill: parent
                        visible: root.presetTab === "custom"
                        clip: true
                        spacing: 6
                        cacheBuffer: 320
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.customCards

                        delegate: Components.ThemePresetCard {
                            width: customList.width - 6
                            themeName: modelData.name
                            paletteOverride: modelData.colors
                            sourceTag: modelData.omarchy ? "OMARCHY" : ""
                            isActive: root.currentTheme === modelData.name
                            // A folder-only card has nothing to edit or delete yet.
                            showActions: !modelData.folderOnly
                            onClicked: {
                                if (modelData.folderOnly)
                                    Services.ThemeService.importFromPath(modelData.path)
                                else
                                    Services.ThemeService.applyCustomTheme(modelData.name)
                                manualEditor.editing = false
                            }
                            onEditClicked: {
                                Services.ThemeService.applyCustomTheme(modelData.name)
                                manualEditor.editing = true
                                nameField.text = modelData.name
                            }
                            onDeleteClicked: Services.ThemeService.deleteCustomTheme(modelData.name)
                            onCloneClicked: root.cloneCard(modelData.name, modelData.colors)
                            onPreviewEntered: if (root.hoverPreviewEnabled && !manualEditor.editing)
                                Services.ThemeService.previewTheme(modelData.colors)
                            onPreviewExited: Services.ThemeService.endPreview()
                        }

                        footer: CreateCard {
                            width: customList.width - 6
                            onActivated: root.startCreate()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.presetTab === "custom" && root.customCards.length === 0
                        text: "// none saved yet - edit the matrix, then SAVE"
                        font.pixelSize: 8
                        font.family: Config.SettingsConfig.fontFamily
                        color: Config.ThemeConfig.colors.textDim
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Config.ThemeConfig.colors.outlineVariant
            }

            // ---- editor column: the editor, then the dock. Taller than the
            // window allows? The whole column scrolls. ----
            // A plain Item takes the width from the row; the view fills it.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: editorScroll
                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: rightColumn.height

                    ColumnLayout {
                        id: rightColumn
                        // As tall as the viewport, or taller when the editor needs it.
                        width: editorScroll.width
                        height: Math.max(editorScroll.height, implicitHeight)
                        spacing: 0

                        Components.ManualThemeEditor {
                            id: manualEditor
                            Layout.fillWidth: true
                            // Its content height is the floor; spare height goes here.
                            Layout.fillHeight: true
                            Layout.minimumHeight: implicitHeight
                            Layout.preferredHeight: implicitHeight
                        }

                        // ---- dock: formats and files, saving, importing, the folder ----
                        ColumnLayout {
                            id: dock
                            property string exportFmt: "json"

                            Layout.fillWidth: true
                            // Lines up with the editor's 12 px insets.
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Config.ThemeConfig.colors.outlineVariant
                            }

                            // The export format, then the two ways to export.
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: "THEME DOCK"
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 1
                                    font.family: Config.SettingsConfig.fontFamily
                                    color: Config.ThemeConfig.colors.text
                                }
                                Repeater {
                                    model: [{ k: "json", label: "JSON" },
                                            { k: "base16", label: "BASE16" },
                                            { k: "toml", label: "TOML" },
                                            { k: "ghostty", label: "GHOSTTY" }]
                                    SegTab {
                                        label: modelData.label
                                        selected: dock.exportFmt === modelData.k
                                        onActivated: dock.exportFmt = modelData.k
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Components.BarButton {
                                    label: "EXPORT FILE"
                                    onActivated: Services.ThemeService.exportToFile(
                                                     dock.exportFmt, pathField.text)
                                }
                                Components.BarButton {
                                    label: "EXPORT CLIP"
                                    onActivated: Services.ThemeService.exportToClipboard(dock.exportFmt)
                                }
                            }

                            // Save the live palette under a name, or go back to
                            // the default theme.
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Field {
                                    id: nameField
                                    // A name is short; the buttons stay beside it.
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 260
                                    placeholder: "name your palette, then SAVE"
                                    onSubmitted: saveButton.activated()
                                }
                                Components.BarButton {
                                    id: saveButton
                                    label: "SAVE"
                                    onActivated: {
                                        var n = nameField.text.trim()
                                        if (n === "") {
                                            Services.ThemeService.portError =
                                                "SAVE needs a name - type one in the name field"
                                            nameField.focusInput()
                                        } else {
                                            Services.ThemeService.saveCustomTheme(n)
                                            Services.ThemeService.portStatus = "saved " + n
                                            manualEditor.editing = false
                                        }
                                    }
                                }
                                Components.BarButton {
                                    label: "RESET TO DEFAULT"
                                    onActivated: {
                                        Services.ThemeService.applyPreset(
                                            "OLED Pure Black", Config.ThemeConfig.metadata.oledClamp)
                                        manualEditor.editing = false
                                    }
                                }
                            }

                            // Import a palette from a file or the clipboard;
                            // rescan the Omarchy themes folder.
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Field {
                                    id: pathField
                                    // A path is long: it takes the room the buttons leave.
                                    Layout.fillWidth: true
                                    placeholder: "/path/to/theme.json|yaml|toml (empty = default)"
                                    onSubmitted: Services.ThemeService.importFromPath(pathField.text)
                                }
                                Components.BarButton {
                                    label: "IMPORT FILE"
                                    onActivated: Services.ThemeService.importFromPath(pathField.text)
                                }
                                Components.BarButton {
                                    label: "IMPORT CLIP"
                                    onActivated: Services.ThemeService.importFromClipboard()
                                }
                                Components.BarButton {
                                    label: "RESCAN OMARCHY THEMES"
                                    onActivated: Services.ThemeService.scanOmarchyThemes()
                                }
                            }

                            // What the last folder scan found.
                            Text {
                                Layout.fillWidth: true
                                text: Services.ThemeService.omarchyHint
                                font.pixelSize: 8
                                font.family: Config.SettingsConfig.fontFamily
                                color: Config.ThemeConfig.colors.textDim
                                elide: Text.ElideRight
                            }

                            // What the last dock action did. An error wins over a status.
                            Text {
                                Layout.fillWidth: true
                                visible: Services.ThemeService.portError !== ""
                                         || Services.ThemeService.portStatus !== ""
                                text: Services.ThemeService.portError !== ""
                                      ? Services.ThemeService.portError
                                      : Services.ThemeService.portStatus
                                font.pixelSize: 8
                                font.family: Config.SettingsConfig.fontFamily
                                color: Services.ThemeService.portError !== ""
                                       ? Config.ThemeConfig.colors.error
                                       : Config.ThemeConfig.colors.textDim
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
