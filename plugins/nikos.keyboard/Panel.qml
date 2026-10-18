// =============================================================================
// nikos.keyboard — panel body (placed inside the host PluginPanel)
// =============================================================================
// Port of Keyboard-Layout-for-Omarchy's Panel.qml (3 columns: LAYOUTS /
// SWITCH KEY & DISPLAY / BACKUPS) onto house styling (api.theme tokens).
// Edits are a DRAFT: seeded from the service's derived settings, only re-seeded
// while clean (never clobber mid-edit — the wifi-list regression pattern),
// applied by the service's write → git add → hyprctl eval pipeline.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "." as KB
import "./lib/KeyboardLogic.mjs" as Logic

ColumnLayout {
    id: panelRoot

    property var service: null     // the BarWidget root (state + verbs)
    property var api: null

    width: parent.width
    spacing: 0

    function _c(tok, fallback) {
        if (!api) return fallback || "#888"
        var t = api.theme
        // Derived fills (fillRest/fillHover/hairline/*Tint) live on the theme,
        // not inside .colors — check both before falling back.
        if (t.colors[tok] !== undefined) return t.colors[tok]
        if (t[tok] !== undefined) return t[tok]
        return fallback || "#888"
    }
    function _font() { return api ? api.bar.fontFamily : "monospace" }

    // ── draft state ─────────────────────────────────────────────────────────
    property var draft: []              // [{layout, variant}] — up to 4
    property string draftHotkey: "none"
    property bool draftLed: false
    property string pendingConfirm: ""  // "" | "apply" (non-us main) | "restore:<id>"

    function specOf(entry) { return Logic.layoutSpec(entry) }

    function seed() {
        var s = service ? service.derivedSettings : null
        if (!s) return
        draft = s.layouts.slice(0, Logic.MAX_LAYOUTS).map(function(e) {
            return { layout: e.layout, variant: e.variant }
        })
        draftHotkey = s.hotkey
        draftLed = s.led
        pendingConfirm = ""
    }

    readonly property bool isDirty: {
        var s = service ? service.derivedSettings : null
        if (!s) return false
        if (draft.length !== s.layouts.length) return true
        for (var i = 0; i < draft.length; i++)
            if (Logic.layoutSpec(draft[i]) !== Logic.layoutSpec(s.layouts[i])) return true
        return draftHotkey !== s.hotkey || draftLed !== s.led
    }

    readonly property bool hasDuplicates: {
        var seen = {}
        for (var i = 0; i < draft.length; i++) {
            var k = "$" + Logic.layoutSpec(draft[i])
            if (seen[k]) return true
            seen[k] = true
        }
        return false
    }

    // Re-seed only when clean (input.lua is the source of truth), and only on
    // real content change — equal reassignments reset every row dropdown.
    readonly property string seedFingerprint: service && service.derivedSettings
        ? JSON.stringify(service.derivedSettings.layouts) + "|" + service.derivedSettings.hotkey
          + "|" + service.derivedSettings.led : ""
    onSeedFingerprintChanged: if (!isDirty) seed()
    Component.onCompleted: seed()
    onServiceChanged: seed()

    // Catalog options for layout pickers: {value: "gr(polytonic)", label, description}.
    readonly property var catalogOptions: {
        var s = service
        if (!s || !s.catalog) return []
        return s.catalog.entries.map(function(e) {
            var spec = Logic.layoutSpec(e)
            return { value: spec, label: e.description, description: spec }
        })
    }
    // Degrade path (catalog unavailable): the currently configured layouts,
    // so the panel stays usable for reorder/remove/switch-key without search.
    readonly property var fallbackOptions: {
        var s = service
        if (!s) return []
        var out = []
        var seen = {}
        var src = (s.derivedSettings ? s.derivedSettings.layouts : []).slice()
        for (var i = 0; i < src.length; i++) {
            var spec = Logic.layoutSpec(src[i])
            if (!seen["$" + spec]) { seen["$" + spec] = true; out.push({ value: spec, label: spec, description: spec }) }
        }
        return out
    }
    readonly property var layoutOptions: catalogOptions.length > 0 ? catalogOptions : fallbackOptions

    // Switch-key options: the 16 choices, plus a keep-entry for a custom
    // unlisted grp: option already live in the file.
    readonly property var hotkeyOptions: {
        var out = []
        for (var i = 0; i < Logic.HOTKEYS.length; i++)
            out.push({ value: Logic.HOTKEYS[i].value, label: Logic.HOTKEYS[i].label,
                       description: Logic.HOTKEYS[i].value })
        var current = draftHotkey
        if (current !== "none" && !Logic.isKnownHotkey(current))
            out.unshift({ value: current, label: "Custom (" + current + ") — keep", description: current })
        return out
    }

    // What Apply would change in kb_options, before it does (planNotes).
    readonly property var optionNotes: {
        var s = service ? service.derivedSettings : null
        if (!s) return []
        var base = (service.fileLua && service.fileLua.hasOptions)
            ? service.fileLua.options : (service.effective ? service.effective.options : [])
        return Logic.planOptions(base, draftHotkey, draftLed).notes
    }

    readonly property var mainRisk: Logic.mainLayoutRisksPasswords(draft)
    readonly property var bindingsRisk: Logic.mainLayoutBreaksBindings(draft)

    function requestApply() {
        if (!service || hasDuplicates || draft.length === 0) return
        if (Logic.needsPasswordConfirm(service.layouts, draft)) { pendingConfirm = "apply"; return }
        applyNow()
    }
    function applyNow() {
        pendingConfirm = ""
        service.applySettings(draft, draftHotkey, draftLed)
    }

    // ── header strip: ACTIVE + prev/next ────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "ACTIVE"
            font.family: _font(); font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
            color: _c("textDim", "#666")
        }
        Rectangle { width: 4; height: 4; radius: 2; color: _c("secondary", "#00dce5") }
        Text {
            text: service && service.ready
                  ? service.currentKeymap + "  (" + service.abbr + " · " + (service.currentIndex + 1)
                    + "/" + service.layoutCount + ")"
                  : "no layout information"
            font.family: _font(); font.pixelSize: 11; font.bold: true
            color: _c("text", "#e0e0e0")
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Repeater {
            model: [
                { glyph: "󰼨", fn: function() { if (service) service.prev() }, label: "previous" },
                { glyph: "󰼧", fn: function() { if (service) service.next() }, label: "next" }
            ]
            delegate: Rectangle {
                // plain property var per delegate (modelData trap)
                property var act: modelData
                width: 26; height: 22; radius: 4
                color: ma.containsMouse ? _c("fillHover", "#1c1c1c") : _c("fillRest", "#141414")
                enabled: service && service.layoutCount > 1
                opacity: enabled ? 1 : 0.4
                Text {
                    anchors.centerIn: parent
                    text: parent.act.glyph
                    font.family: "monospace"; font.pixelSize: 13
                    color: _c("text", "#e0e0e0")
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.act.fn()
                }
            }
        }
    }
    Item { height: 12 }

    // ── the three columns ────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        // ═══ Column 1 — LAYOUTS ═══
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 8

            Text {
                text: "LAYOUTS (" + draft.length + " OF " + Logic.MAX_LAYOUTS + ")"
                font.family: _font(); font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                color: _c("textDim", "#666")
            }

            Repeater {
                model: draft.length

                delegate: RowLayout {
                    property int rowIndex: index
                    property var entry: draft[index] ? draft[index] : { layout: "", variant: "" }
                    spacing: 6

                    Text {
                        text: (rowIndex + 1) + ""
                        font.family: _font(); font.pixelSize: 10; font.bold: rowIndex === 0
                        color: rowIndex === 0 ? _c("secondary", "#00dce5") : _c("textDim", "#666")
                    }
                    KB.LayoutSearch {
                        Layout.fillWidth: true
                        theme: api ? api.theme : null
                        placeholder: "layout…"
                        options: layoutOptions
                        value: specOf(entry)
                        onChanged: function(v) {
                            var parsed = Logic.parseLayoutSpec(v)
                            if (!parsed) return
                            var next = draft.slice()
                            next[rowIndex] = parsed
                            draft = next
                        }
                    }
                    Column {
                        Layout.preferredWidth: 30
                        spacing: 2
                        Rectangle {
                            width: 14; height: 12; radius: 2
                            color: upMa.containsMouse ? _c("fillHover", "#1c1c1c") : "transparent"
                            visible: rowIndex > 0
                            Text { anchors.centerIn: parent; text: "󰼵"; font.pixelSize: 9; font.family: "monospace"; color: _c("textDim", "#666") }
                            MouseArea { id: upMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { var n = draft.slice(); var t = n[rowIndex]; n[rowIndex] = n[rowIndex-1]; n[rowIndex-1] = t; draft = n } }
                        }
                        Rectangle {
                            width: 14; height: 12; radius: 2
                            color: downMa.containsMouse ? _c("fillHover", "#1c1c1c") : "transparent"
                            visible: rowIndex < draft.length - 1
                            Text { anchors.centerIn: parent; text: "󰼹"; font.pixelSize: 9; font.family: "monospace"; color: _c("textDim", "#666") }
                            MouseArea { id: downMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { var n = draft.slice(); var t = n[rowIndex]; n[rowIndex] = n[rowIndex+1]; n[rowIndex+1] = t; draft = n } }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 16; Layout.preferredHeight: 22; radius: 3
                        color: delMa.containsMouse ? _c("errorTint", "#3a2020") : "transparent"
                        visible: draft.length > 1
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: _c("error", "#f87171") }
                        MouseArea { id: delMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { var n = draft.slice(); n.splice(rowIndex, 1); draft = n } }
                    }
                }
            }

            // Add-a-layout picker (while under the cap)
            KB.LayoutSearch {
                Layout.fillWidth: true
                visible: draft.length < Logic.MAX_LAYOUTS
                theme: api ? api.theme : null
                placeholder: "+ Add a layout…"
                options: layoutOptions
                value: ""
                onChanged: function(v) {
                    var parsed = Logic.parseLayoutSpec(v)
                    if (!parsed) return
                    var next = draft.slice()
                    next.push(parsed)
                    draft = next
                }
            }

            // notes
            ColumnLayout {
                id: notesCol
                Layout.fillWidth: true
                spacing: 3
                visible: notes.length > 0
                property var notes: {
                    var out = []
                    var s = service
                    if (s && s.fileLua && !s.fileLua.hasLayout)
                        out.push("look-and-feel.lua sets no layouts yet: these are the values Hyprland has in effect.")
                    if (hasDuplicates) out.push("The same layout is listed twice.")
                    if (s && s.fileLua && s.fileLua.layouts.length > Logic.MAX_LAYOUTS)
                        out.push("The file lists more than 4 layouts; xkb only uses the first 4.")
                    if (mainRisk) {
                        var why = "Layout 1 is not English (US): lock screens and fresh prompts will start in it."
                        if (bindingsRisk) why += " SUPER keybindings resolve against layout 1 and may stop firing."
                        out.push("⚠ " + why)
                    }
                    return out
                }
                Repeater {
                    model: notesCol.notes
                    delegate: Text {
                        property var noteText: modelData
                        Layout.fillWidth: true
                        text: noteText
                        wrapMode: Text.WordWrap
                        font.family: _font(); font.pixelSize: 9
                        color: noteText.indexOf("⚠") === 0 ? _c("warning", "#fbbf24") : _c("textDim", "#808080")
                    }
                }
            }
        }

        // column separators
        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: _c("hairline", "#1a1a1a") }

        // ═══ Column 2 — SWITCH KEY & DISPLAY ═══
        // Fixed widths on columns 2/3: with all three on fillWidth each column
        // shrank below its text and labels overlapped the neighbours.
        ColumnLayout {
            Layout.preferredWidth: 190
            Layout.alignment: Qt.AlignTop
            spacing: 8

            Text {
                text: "SWITCH KEY"
                font.family: _font(); font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                color: _c("textDim", "#666")
            }
            KB.LayoutSearch {
                Layout.fillWidth: true
                theme: api ? api.theme : null
                placeholder: "switch key…"
                options: hotkeyOptions
                value: draftHotkey
                onChanged: function(v) { draftHotkey = v }
            }
            PanelToggle {
                Layout.fillWidth: true
                label: "Caps LED off main"
                theme: api ? api.theme : null
                font: _font()
                checked: draftLed
                enabled: draftHotkey === Logic.LED_HOTKEY
                onToggled: function(v) { draftLed = v }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                visible: optionNotes.length > 0
                Text {
                    text: "APPLY WILL"
                    font.family: _font(); font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                    color: _c("textDim", "#666")
                }
                Repeater {
                    model: optionNotes
                    delegate: Text {
                        property var noteText: modelData
                        Layout.fillWidth: true
                        text: "· " + noteText
                        wrapMode: Text.WordWrap
                        font.family: _font(); font.pixelSize: 9
                        color: _c("textDim", "#808080")
                    }
                }
            }

            // Apply / confirm
            Rectangle {
                id: applyBtn
                Layout.fillWidth: true
                height: 26
                radius: 4
                color: {
                    if (pendingConfirm !== "") return _c("warningTint", "#3a3320")
                    if (applyMa.containsMouse && canApply) return _c("accentTintSoft", "#16202a")
                    return _c("fillRest", "#141414")
                }
                border.width: 1
                border.color: pendingConfirm !== "" ? _c("warning", "#fbbf24")
                            : (canApply ? _c("outline", "#2a2a2a") : _c("border", "#1a1a1a"))
                opacity: canApply || pendingConfirm !== "" ? 1 : 0.45
                readonly property bool canApply: !hasDuplicates && draft.length > 0 && isDirty && service && !service.applying
                Text {
                    width: parent.width - 12
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: {
                        if (pendingConfirm === "apply")
                            return "Apply anyway — non-US main"   // detail in the warning line below
                        if (hasDuplicates) return "Duplicate layout listed"
                        if (!isDirty) return "Apply (no changes)"
                        return "Apply & apply live"
                    }
                    font.family: _font(); font.pixelSize: 10; font.bold: true
                    color: pendingConfirm !== "" ? _c("warning", "#fbbf24") : _c("text", "#e0e0e0")
                }
                MouseArea {
                    id: applyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: applyBtn.canApply || pendingConfirm !== ""
                    onClicked: pendingConfirm === "apply" ? applyNow() : requestApply()
                }
            }
            Text {
                Layout.fillWidth: true
                text: pendingConfirm === "apply"
                      ? "This newly puts a non-US layout first — passwords may come out wrong. Apply anyway?"
                      : ""
                visible: pendingConfirm === "apply"
                wrapMode: Text.WordWrap
                font.family: _font(); font.pixelSize: 9
                color: _c("warning", "#fbbf24")
            }
            Text {
                Layout.fillWidth: true
                text: (service && service.lastError !== "") ? service.lastError
                    : (service && service.lastAction !== "") ? service.lastAction : ""
                visible: text !== ""
                wrapMode: Text.WordWrap
                font.family: _font(); font.pixelSize: 9
                color: service && service.lastError !== "" ? _c("error", "#f87171") : _c("success", "#34d399")
            }

            Item { height: 4 }
            Text {
                text: "DISPLAY"
                font.family: _font(); font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                color: _c("textDim", "#666")
            }
            PanelToggle {
                Layout.fillWidth: true
                label: "OSD flash on switch"
                theme: api ? api.theme : null
                font: _font()
                checked: service ? service.prefOsd : false
                onToggled: function(v) { if (service) { service.prefOsd = v; service.savePrefs() } }
            }
            PanelToggle {
                Layout.fillWidth: true
                label: "Accent while off main"
                theme: api ? api.theme : null
                font: _font()
                checked: service ? service.prefHighlight : false
                onToggled: function(v) { if (service) { service.prefHighlight = v; service.savePrefs() } }
            }
        }

        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: _c("hairline", "#1a1a1a") }

        // ═══ Column 3 — BACKUPS ═══
        ColumnLayout {
            Layout.preferredWidth: 235
            Layout.alignment: Qt.AlignTop
            spacing: 8

            Text {
                text: "BACKUPS"
                font.family: _font(); font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.5
                color: _c("textDim", "#666")
            }
            Text {
                Layout.fillWidth: true
                text: "Taken before every Apply or Restore. Newest 10 kept. A restore applies live."
                wrapMode: Text.WordWrap
                font.family: _font(); font.pixelSize: 9
                color: _c("textDim", "#808080")
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 92   // label (~78px) must never outgrow the button
                    height: 22; radius: 4
                    color: bakMa.containsMouse ? _c("fillHover", "#1c1c1c") : _c("fillRest", "#141414")
                    border.width: 1; border.color: _c("outline", "#2a2a2a")
                    Text { anchors.centerIn: parent; text: "Back up now"; font.family: _font(); font.pixelSize: 10; color: _c("text", "#e0e0e0") }
                    MouseArea { id: bakMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (service) service.backupNow() }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 92
                    height: 22; radius: 4
                    color: foldMa.containsMouse ? _c("fillHover", "#1c1c1c") : _c("fillRest", "#141414")
                    border.width: 1; border.color: _c("outline", "#2a2a2a")
                    Text { anchors.centerIn: parent; text: "Open folder"; font.family: _font(); font.pixelSize: 10; color: _c("text", "#e0e0e0") }
                    MouseArea { id: foldMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (service) service.openBackupFolder() }
                }
            }

            Repeater {
                model: service ? service.backups : []

                delegate: RowLayout {
                    id: backupRow
                    property var row: modelData
                    spacing: 4
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!row) return ""
                                var d = new Date(row.time * 1000)
                                function p(n) { return (n < 10 ? "0" : "") + n }
                                var stamp = d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
                                          + " " + p(d.getHours()) + ":" + p(d.getMinutes())
                                return stamp + "  ·  " + (row.layouts !== "" ? row.layouts : "(defaults)")
                            }
                            elide: Text.ElideMiddle
                            font.family: _font(); font.pixelSize: 9
                            color: row && row.valid ? _c("text", "#e0e0e0") : _c("error", "#f87171")
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 44; Layout.preferredHeight: 18; radius: 3
                        color: resMa.containsMouse ? _c("accentTintSoft", "#16202a") : "transparent"
                        border.width: 1; border.color: _c("outline", "#2a2a2a")
                        Text { anchors.centerIn: parent; text: "Restore"; font.family: _font(); font.pixelSize: 8; color: _c("text", "#e0e0e0") }
                        MouseArea {
                            id: resMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (backupRow.row && service) service.restoreBackup(backupRow.row.id)
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: service && service.lastBackupAction !== "" ? service.lastBackupAction : ""
                visible: text !== ""
                wrapMode: Text.WordWrap
                font.family: _font(); font.pixelSize: 9
                color: service && service.lastBackupAction.indexOf("failed") !== -1
                       ? _c("error", "#f87171") : _c("success", "#34d399")
            }
        }
    }
    Item { height: 4 }

    // ── inline toggle component ─────────────────────────────────────────────
    component PanelToggle: Rectangle {
        id: toggleRoot
        property string label: ""
        property bool checked: false
        // `enabled` is Item's own — never redeclare it (duplicate property).
        property var theme: null
        property string font: "monospace"
        signal toggled(bool value)

        implicitHeight: 22
        radius: 4
        color: "transparent"
        opacity: enabled ? 1 : 0.4
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Rectangle {
                width: 26; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                color: toggleRoot.checked ? (toggleRoot.theme ? toggleRoot.theme.colors.secondary : "#00dce5")
                                          : (toggleRoot.theme ? toggleRoot.theme.colors.surfaceVariant : "#222")
                border.width: 1
                border.color: toggleRoot.checked ? "transparent" : (toggleRoot.theme ? toggleRoot.theme.colors.outline : "#2a2a2a")
                Rectangle {
                    x: toggleRoot.checked ? parent.width - width - 2 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10; height: 10; radius: 5
                    color: toggleRoot.checked ? "#000000" : (toggleRoot.theme ? toggleRoot.theme.colors.textDim : "#555")
                    Behavior on x { NumberAnimation { duration: 100 } }
                }
            }
            Text {
                text: toggleRoot.label
                font.family: toggleRoot.font; font.pixelSize: 10
                color: toggleRoot.theme ? toggleRoot.theme.colors.text : "#e0e0e0"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: toggleRoot.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleRoot.toggled(!toggleRoot.checked)
        }
    }
}
