// ManualThemeEditor.qml — Theme page editor column.
// =============================================================================
// Everything here edits the LIVE palette:
//   • a tile's hex field commits on Enter or focus loss;
//   • the picker drafts one token and commits on APPLY;
//   • every commit is one undo step (ThemeService undo / redo).
// Nothing is saved until the dock's SAVE names it.
//
// The terminal preview shows the palette exactly as Ghostty receives it: it is
// read back from the block ThemeSync writes (`palette = N=#rrggbb`), so the
// preview cannot drift from the real mapping.
// =============================================================================
import QtQuick
import QtQuick.Layouts

import "../config" as Config
import "../services" as Services
import "../lib/theme-core.mjs" as ThemeCore
import "../lib/theme-sync.mjs" as ThemeSync

Item {
    id: root
    // Size for the page: the editor is as tall as its column, and a window
    // shorter than that scrolls the column instead of squeezing it.
    implicitWidth: mainColumn.implicitWidth + 24
    implicitHeight: mainColumn.implicitHeight + 12

    // Outlined action button of the editor bar and the picker. `available` is the
    // disabled state: dimmed and not clickable.
    component BarButton: Rectangle {
        id: barButton

        property string label: ""
        property color tint: Config.ThemeConfig.colors.secondary
        property bool available: true
        property bool filled: false

        signal activated()

        Layout.preferredHeight: 22
        Layout.preferredWidth: Math.max(52, buttonText.implicitWidth + 20)
        color: (filled || barHover.containsMouse) ? barButton.tint : "transparent"
        border.width: 1
        border.color: barButton.available ? barButton.tint : Config.ThemeConfig.colors.outline
        enabled: barButton.available
        opacity: barButton.available ? 1 : 0.45

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: buttonText

            anchors.centerIn: parent
            text: barButton.label
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1
            font.family: Config.SettingsConfig.fontFamily
            color: (barButton.filled || barHover.containsMouse) ? Config.ThemeConfig.colors.background
                                                                 : barButton.tint
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: barHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: barButton.activated()
        }
    }


    // True while a saved custom theme is open for editing (the page sets it):
    // card hover previews are held off so they cannot cover the edits.
    property bool editing: false

    // Token the picker is drafting. "" closes it (clicking the selected tile
    // again does that); the terminal preview then takes the whole bottom row.
    property string selectedToken: ""

    // The picker's draft. It becomes part of the theme only on APPLY.
    property real pickerHue: 0
    property real pickerSat: 0
    property real pickerVal: 0

    readonly property string currentHex: root.hsvToHex(root.pickerHue, root.pickerSat, root.pickerVal).toUpperCase()
    readonly property color pureHueColor: root.hsvToHex(root.pickerHue, 1, 1)

    // One tile per engine token, in ThemeSchema's order.
    readonly property var colorTokens: [
        { key: "background",       symbol: "Bg", name: "Background" },
        { key: "surface",          symbol: "Sf", name: "Surface" },
        { key: "surfaceVariant",   symbol: "Sv", name: "Surface variant" },
        { key: "surfaceContainer", symbol: "Sc", name: "Surface container" },
        { key: "text",             symbol: "Tx", name: "Text" },
        { key: "textDim",          symbol: "Td", name: "Text dim" },
        { key: "border",           symbol: "Bd", name: "Border" },
        { key: "outline",          symbol: "Ol", name: "Outline" },
        { key: "outlineVariant",   symbol: "Ov", name: "Outline variant" },
        { key: "primary",          symbol: "Pr", name: "Primary" },
        { key: "secondary",        symbol: "Sd", name: "Secondary" },
        { key: "accent",           symbol: "Ac", name: "Accent" },
        { key: "success",          symbol: "Su", name: "Success" },
        { key: "warning",          symbol: "Wn", name: "Warning" },
        { key: "error",            symbol: "Er", name: "Error" },
        { key: "info",             symbol: "In", name: "Info" }
    ]

    function tokenName(key) {
        for (var i = 0; i < root.colorTokens.length; i++)
            if (root.colorTokens[i].key === key) return root.colorTokens[i].name
        return key
    }

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

    function rgbText(hex) {
        var h = (hex || "#000000").replace("#", "")
        return "RGB(" + parseInt(h.substring(0, 2), 16) + ", "
                         + parseInt(h.substring(2, 4), 16) + ", "
                         + parseInt(h.substring(4, 6), 16) + ")"
    }

    function hsvText() {
        var deg = Math.round(root.pickerHue * 360)
        if (deg >= 360) deg = 0
        return "HSV(" + deg + "deg, " + Math.round(root.pickerSat * 100) + "%, "
                        + Math.round(root.pickerVal * 100) + "%)"
    }

    // ── commits ───────────────────────────────────────────────────────────────

    function selectToken(key) {
        // Clicking the selected tile again closes the picker.
        if (root.selectedToken === key) {
            root.selectedToken = ""
            return
        }
        root.selectedToken = key
        root.syncPicker()
    }

    // Re-seed the picker from the committed token: on selection and on every
    // theme switch, so the picker never carries a draft over to another theme.
    function syncPicker() {
        if (root.selectedToken === "") return
        Services.ThemeService.endPreview()
        var hsv = root.hexToHsv((Config.ThemeConfig.colors[root.selectedToken] || "#000000").toUpperCase())
        root.pickerHue = hsv.h
        root.pickerSat = hsv.s
        root.pickerVal = hsv.v
    }

    function applyFromPicker() {
        Services.ThemeService.applyManualOverride(root.selectedToken, root.currentHex)
        root.syncPicker()
    }

    // A tile's hex field. Invalid text is dropped and the field springs back.
    function applyHex(key, value) {
        var hex = String(value || "").trim().toUpperCase()
        if (root.isValidHex(hex))
            Services.ThemeService.applyManualOverride(key, hex)
        if (key === root.selectedToken) root.syncPicker()
    }

    Connections {
        target: Services.ThemeService
        function onCurrentThemeNameChanged() { root.syncPicker() }
    }

    // ── editor column ─────────────────────────────────────────────────────────

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 12
        anchors.bottomMargin: 0
        spacing: 10

        // Action bar: what is live, how to edit, and the ways to load a palette.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: Config.ThemeConfig.colors.surfaceContainer
            border.width: 1
            border.color: Config.ThemeConfig.colors.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 5
                spacing: 8

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: Services.ThemeService.isRegenerating
                           ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.success
                }

                Text {
                    readonly property string source: Config.ThemeConfig.metadata.source
                    text: Services.ThemeService.isRegenerating ? "GENERATING..."
                         : source === "matugen" ? "WALLPAPER PALETTE"
                         : source === "stylix" ? "STYLIX SEED" : "EDITOR READY"
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1
                    font.family: Config.SettingsConfig.fontFamily
                    color: Config.ThemeConfig.colors.text
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "Type a hex or click a swatch to pick. Changes apply live to QuickShell and Ghostty."
                    font.pixelSize: 8
                    font.family: Config.SettingsConfig.fontFamily
                    color: Config.ThemeConfig.colors.textDim
                    elide: Text.ElideRight
                }

                BarButton {
                    label: "FROM WALLPAPER"
                    tint: Config.ThemeConfig.colors.info
                    available: !Services.ThemeService.isRegenerating
                    onActivated: Services.ThemeService.applyDynamicTheme(
                                     Services.WallpaperService.currentWallpaper,
                                     Services.WallpaperService.previewSourceFor(Services.WallpaperService.currentWallpaper))
                }

                BarButton {
                    label: "LOAD STYLIX"
                    tint: Config.ThemeConfig.colors.warning
                    onActivated: Services.ThemeService.applyStylixSeedNow()
                }

                BarButton {
                    label: "UNDO"
                    tint: Config.ThemeConfig.colors.text
                    available: Services.ThemeService.canUndo
                    onActivated: { Services.ThemeService.undoManualEdit(); root.syncPicker() }
                }

                BarButton {
                    label: "REDO"
                    tint: Config.ThemeConfig.colors.text
                    available: Services.ThemeService.canRedo
                    onActivated: { Services.ThemeService.redoManualEdit(); root.syncPicker() }
                }
            }
        }

        Text {
            visible: Services.ThemeService.regenFailed && Services.ThemeService.regenError !== ""
            text: "REBUILD FAILED: " + Services.ThemeService.regenError
            Layout.fillWidth: true
            font.pixelSize: 8
            font.family: Config.SettingsConfig.fontFamily
            color: Config.ThemeConfig.colors.error
            elide: Text.ElideRight
        }

        // ── the colour matrix ──────────────────────────────────────────────────
        // Four by four, one tile per token: number, symbol, swatch, hex. The hex
        // is typed in place; clicking elsewhere on the tile opens the picker.

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "COLOR MATRIX"
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1
                font.family: Config.SettingsConfig.fontFamily
                color: Config.ThemeConfig.colors.text
            }
            Text {
                text: "16 TOKENS"
                font.pixelSize: 7
                font.letterSpacing: 1
                font.family: Config.SettingsConfig.fontFamily
                color: Config.ThemeConfig.colors.textDim
            }
            Item { Layout.fillWidth: true }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: root.colorTokens

                delegate: Rectangle {
                    id: tile

                    readonly property var token: modelData
                    readonly property int number: index + 1
                    readonly property string hex: (Config.ThemeConfig.colors[tile.token.key] || "#000000").toUpperCase()
                    readonly property bool selected: root.selectedToken === tile.token.key

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.preferredHeight: 70
                    color: Config.ThemeConfig.colors.background
                    border.width: 1
                    border.color: tile.selected ? Config.ThemeConfig.colors.accent : Config.ThemeConfig.colors.border

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectToken(tile.token.key)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: ("0" + tile.number).slice(-2)
                                font.pixelSize: 10
                                font.family: Config.HudConfig.fontDoto
                                color: Config.ThemeConfig.colors.textDim
                            }
                            Text {
                                text: tile.token.symbol
                                font.pixelSize: 9
                                font.bold: true
                                font.family: Config.ControlConfig.fontNerd
                                color: Config.ThemeConfig.colors.text
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: tile.token.name
                                font.pixelSize: 7
                                font.family: Config.SettingsConfig.fontFamily
                                color: Config.ThemeConfig.colors.textDim
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            // Takes the tile's spare height; never smaller than this.
                            Layout.fillHeight: true
                            Layout.preferredHeight: 24
                            Layout.minimumHeight: 24
                            color: tile.hex
                            border.width: 1
                            border.color: Config.ThemeConfig.colors.outline
                        }

                        TextInput {
                            id: hexField

                            Layout.fillWidth: true
                            font.pixelSize: 10
                            font.family: Config.ControlConfig.fontNerd
                            color: Config.ThemeConfig.colors.text
                            selectByMouse: true
                            text: tile.hex
                            // While the field has focus the typed text is the
                            // user's; once it loses focus the committed value wins.
                            Binding on text { value: tile.hex; when: !hexField.activeFocus; restoreMode: Binding.RestoreBinding }
                            onEditingFinished: root.applyHex(tile.token.key, text)
                        }
                    }
                }
            }
        }

        // ── picker + terminal preview ──────────────────────────────────────────
        // The picker is hidden until a tile is selected, so the first view is the
        // matrix over a full-width terminal preview.

        RowLayout {
            Layout.fillWidth: true
            // A nested layout grows by default; the tile grid takes the spare
            // height instead. Never smaller than this.
            Layout.fillHeight: false
            Layout.minimumHeight: 220
            Layout.preferredHeight: 220
            spacing: 10

            Rectangle {
                visible: root.selectedToken !== ""
                Layout.fillWidth: true
                Layout.preferredWidth: 380
                Layout.maximumWidth: 470
                // A child of a layout: only Layout.* sizes are heard.
                Layout.fillHeight: true
                color: Config.ThemeConfig.colors.background
                border.width: 1
                border.color: Config.ThemeConfig.colors.accent

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    ColumnLayout {
                        spacing: 8

                        Text {
                            text: "PICK COLOR  -  " + root.tokenName(root.selectedToken).toUpperCase()
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1
                            font.family: Config.SettingsConfig.fontFamily
                            color: Config.ThemeConfig.colors.text
                        }

                        RowLayout {
                            spacing: 8

                            // Saturation / value square
                            Item {
                                id: svArea

                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 120

                                // Saturation axis: white -> pure hue
                                Rectangle {
                                    anchors.fill: parent
                                    gradient: Gradient {
                                        orientation: Qt.Horizontal
                                        GradientStop { position: 0.0; color: "#ffffff" }
                                        GradientStop { position: 1.0; color: root.pureHueColor }
                                    }
                                }
                                // Value axis: transparent -> black
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
                                    width: 12
                                    height: 12
                                    radius: 6
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

                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 120
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

                                // Cursor
                                Rectangle {
                                    width: parent.width
                                    height: 4
                                    y: hueStrip.height * root.pickerHue - 2
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
                    }

                    // The draft: large hex, its other notations, how it reads
                    // on the page, and the two ways out.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 30
                                height: 30
                                color: root.currentHex
                                border.width: 1
                                border.color: Config.ThemeConfig.colors.outline
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                color: Config.ThemeConfig.colors.surface
                                border.width: 1
                                border.color: Config.ThemeConfig.colors.outline

                                TextInput {
                                    id: pickerHex

                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 20
                                    font.family: Config.HudConfig.fontDoto
                                    color: Config.ThemeConfig.colors.text
                                    selectByMouse: true
                                    text: root.currentHex
                                    Binding on text { value: root.currentHex; when: !pickerHex.activeFocus; restoreMode: Binding.RestoreBinding }
                                    onEditingFinished: {
                                        var typed = String(text).trim()
                                        if (!root.isValidHex(typed)) return
                                        var hsv = root.hexToHsv(typed)
                                        root.pickerHue = hsv.h
                                        root.pickerSat = hsv.s
                                        root.pickerVal = hsv.v
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root.rgbText(root.currentHex) + "   " + root.hsvText()
                            font.pixelSize: 8
                            font.family: Config.ControlConfig.fontNerd
                            color: Config.ThemeConfig.colors.textDim
                            elide: Text.ElideRight
                        }

                        Text {
                            // The background is judged by the text it carries;
                            // every other token by how it reads on the background.
                            readonly property bool isBackground: root.selectedToken === "background"
                            readonly property real ratio: ThemeCore.contrastRatio(
                                root.currentHex,
                                isBackground ? Config.ThemeConfig.colors.text : Config.ThemeConfig.colors.background)

                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: ratio.toFixed(1) + ":1 " + (isBackground ? "for text on it" : "on the background")
                                  + "   " + ThemeCore.contrastLabel(ratio)
                            font.pixelSize: 8
                            font.family: Config.SettingsConfig.fontFamily
                            color: Config.ThemeConfig.colors.text
                            elide: Text.ElideRight
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            spacing: 6

                            BarButton {
                                label: "APPLY"
                                filled: true
                                tint: Config.ThemeConfig.colors.primary
                                onActivated: root.applyFromPicker()
                            }
                            BarButton {
                                label: "COPY HEX"
                                onActivated: Services.ThemeService.copyText(root.currentHex)
                            }
                        }
                    }
                }
            }

            // Live Ghostty preview. Real prompt, real ANSI roles - no made-up log
            // lines.
            Rectangle {
                id: preview

                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Config.ThemeConfig.colors.background
                border.width: 1
                border.color: Config.ThemeConfig.colors.border

                // ANSI 0-15, read back from the block Ghostty is given.
                readonly property var palette: {
                    var out = []
                    var lines = ThemeSync.ghosttyBlock(Config.ThemeConfig.colors).split("\n")
                    for (var i = 0; i < lines.length; i++) {
                        var hit = /^palette = (\d+)=(#[0-9A-Fa-f]{6})$/.exec(lines[i])
                        if (hit) out[parseInt(hit[1], 10)] = hit[2].toUpperCase()
                    }
                    return out
                }

                // The last sync result for Ghostty; absent until the first sync.
                readonly property var ghosttyState: Services.ThemeService.syncerHealth
                                                   ? Services.ThemeService.syncerHealth["ghostty"] : null

                readonly property string prompt: {
                    var m = Services.HostBridge.metrics
                    var user = m && m.userName ? String(m.userName).toLowerCase() : ""
                    var home = String(Services.ThemeService.homeDir || "")
                    if (user === "" && home !== "") user = home.split("/").pop()
                    var host = m && m.hostname && m.hostname !== "unknown" ? m.hostname : "host"
                    return (user === "" ? "user" : user) + "@" + host
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    // Title row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Row {
                            spacing: 4

                            Repeater {
                                model: ["error", "warning", "success"]

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Config.ThemeConfig.colors[modelData]
                                }
                            }
                        }

                        Text {
                            text: "GHOSTTY PREVIEW"
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 1
                            font.family: Config.SettingsConfig.fontFamily
                            color: Config.ThemeConfig.colors.text
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            readonly property bool synced: !!preview.ghosttyState && preview.ghosttyState.ok === true
                            text: !preview.ghosttyState ? "NOT SYNCED YET"
                                  : synced ? "SYNCED" : "SYNC FAILED"
                            color: !preview.ghosttyState ? Config.ThemeConfig.colors.textDim
                                   : synced ? Config.ThemeConfig.colors.success
                                            : Config.ThemeConfig.colors.warning
                            font.pixelSize: 7
                            font.bold: true
                            font.letterSpacing: 1
                            font.family: Config.SettingsConfig.fontFamily
                        }
                    }

                    // Prompt line: one prompt, no gaps between its parts.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: preview.prompt
                            font.pixelSize: 9
                            font.family: Config.ControlConfig.fontNerd
                            color: Config.ThemeConfig.colors.success
                        }
                        Text {
                            text: ":~ "
                            font.pixelSize: 9
                            font.family: Config.ControlConfig.fontNerd
                            color: Config.ThemeConfig.colors.info
                        }
                        Text {
                            text: " $"
                            font.pixelSize: 9
                            font.family: Config.ControlConfig.fontNerd
                            color: Config.ThemeConfig.colors.text
                        }
                        // Blinking cursor
                        Rectangle {
                            width: 7
                            height: 12
                            color: Config.ThemeConfig.colors.text
                            opacity: cursorBlink.on ? 1 : 0
                        }

                        Timer {
                            id: cursorBlink

                            property bool on: false

                            interval: 530
                            repeat: true
                            running: preview.visible
                            onTriggered: cursorBlink.on = !cursorBlink.on
                        }
                    }

                    // ANSI 0-15 as Ghostty will render them
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "ANSI 0-15"
                            font.pixelSize: 7
                            font.letterSpacing: 1
                            font.family: Config.SettingsConfig.fontFamily
                            color: Config.ThemeConfig.colors.textDim
                            Layout.rightMargin: 6
                        }
                        Repeater {
                            model: 16

                            Rectangle {
                                width: 18
                                height: 16
                                color: preview.palette[index] || "#000000"
                                border.width: 1
                                border.color: Config.ThemeConfig.colors.outline

                                Text {
                                    anchors.centerIn: parent
                                    text: "0123456789ABCDEF".charAt(index)
                                    font.pixelSize: 6
                                    font.family: Config.ControlConfig.fontNerd
                                    color: root.contrastColor(parent.color.toString())
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // The accent roles by name
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Repeater {
                            model: ["error", "warning", "success", "accent", "textDim"]

                            Text {
                                readonly property string label: modelData === "textDim" ? "TEXT DIM" : modelData.toUpperCase()
                                text: label
                                font.pixelSize: 8
                                font.family: Config.ControlConfig.fontNerd
                                color: Config.ThemeConfig.colors[modelData]
                            }
                        }
                    }
                }
            }
        }
    }
}
