// =============================================================================
// LayoutSearch.qml — clipboard-free searchable picker (nikos.keyboard)
// =============================================================================
// Port of Keyboard-Layout-for-Omarchy's LayoutSearchDropdown.qml (itself a
// vendored omarchy SearchableDropdown) with one deliberate change kept: the
// search box is NOT a text field. Every editable Qt input hooks the clipboard
// at creation (paste / Shift+Insert / middle-click could pull other apps'
// text) and the panel stays loaded — so the query is built from key events
// (Logic.searchTyped / searchBackspace), with a fake caret. No paste, no IME.
//
// Expands INLINE below the trigger (no floating popup: this lives inside the
// host PluginPanel popover, where a nested layer window is wrong). Emits
// popupOpen so the panel can suspend its Esc/Enter handling while the list
// owns the keyboard.
// =============================================================================
import QtQuick
import "./lib/KeyboardLogic.mjs" as Logic

Rectangle {
    id: root

    property var options: []            // [{value, label, description}]
    property string value: ""
    property string placeholder: "Search…"
    property var theme: null            // api.theme (colors + derived fills)
    property int listHeight: 190

    signal changed(string value)
    signal popupOpenChanged(bool open)

    readonly property bool open: listBox.visible
    property string query: ""
    property var filtered: []
    property int cursorIndex: -1

    function _c(tok, fallback) {
        if (!theme) return fallback || "#888"
        // Derived fills (fillRest/fillHover/hairline/*Tint) live on the theme,
        // not inside .colors — check both before falling back.
        if (theme.colors[tok] !== undefined) return theme.colors[tok]
        if (theme[tok] !== undefined) return theme[tok]
        return fallback || "#888"
    }

    function recomputeFiltered() {
        var out = []
        var q = query.toLowerCase()
        for (var i = 0; i < options.length; i++) {
            var o = options[i]
            if (q === ""
                || String(o.label).toLowerCase().indexOf(q) !== -1
                || String(o.description).toLowerCase().indexOf(q) !== -1)
                out.push(o)
            if (out.length >= 200) break
        }
        // Content-identity check: reassigning an equal array resets the
        // ListView and scrambles hover mid-interaction (codebase trap).
        if (JSON.stringify(out) !== JSON.stringify(filtered)) filtered = out
        if (cursorIndex >= filtered.length) cursorIndex = filtered.length - 1
    }
    onQueryChanged: recomputeFiltered()
    onOptionsChanged: recomputeFiltered()

    function openPopup() {
        query = ""
        cursorIndex = -1
        recomputeFiltered()
        listBox.visible = true
        searchBox.forceActiveFocus()
        popupOpenChanged(true)
    }
    function closePopup() {
        if (!listBox.visible) return
        listBox.visible = false
        query = ""
        popupOpenChanged(false)
    }
    function togglePopup() { listBox.visible ? closePopup() : openPopup() }

    function labelFor(v) {
        for (var i = 0; i < options.length; i++)
            if (options[i].value === v) return options[i].label
        return v
    }

    function pick(index) {
        if (index < 0 || index >= filtered.length) return
        var v = filtered[index].value
        closePopup()
        // Emit only — value flows back through the owner's `value:` binding.
        // An imperative write here would destroy that binding and leave rows
        // stale after a draft reorder (array identity resets nothing then).
        if (v !== value) changed(v)
    }

    implicitWidth: parent ? parent.width : 180
    implicitHeight: listBox.visible ? (searchRow.height + Math.min(listHeight, list.contentHeight) + 8)
                                    : triggerRow.implicitHeight + 10
    radius: 4
    color: _c("surfaceVariant", "#111111")
    border.width: 1
    border.color: listBox.visible ? _c("secondary", "#00dce5") : _c("outline", "#2a2a2a")
    Behavior on border.color { ColorAnimation { duration: 100 } }

    // ── collapsed trigger ─────────────────────────────────────────────────────
    Row {
        id: triggerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: listBox.visible ? undefined : parent.verticalCenter
        anchors.top: listBox.visible ? parent.top : undefined
        anchors.margins: 8
        spacing: 6

        Text {
            width: triggerRow.width - chevron.width - triggerRow.spacing
            text: root.value !== "" ? root.labelFor(root.value) : root.placeholder
            font.family: "monospace"
            font.pixelSize: 11
            elide: Text.ElideRight
            color: root.value !== "" ? _c("text", "#e0e0e0") : _c("textDim", "#808080")
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: chevron
            text: listBox.visible ? "󰅂" : "󰅅"
            font.family: "monospace"
            font.pixelSize: 11
            color: _c("textDim", "#808080")
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // The trigger itself is clickable only while collapsed; while open the
    // surface below owns everything (click = close, keys = search).
    MouseArea {
        anchors.fill: parent
        enabled: !listBox.visible
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openPopup()
    }

    // ── expanded: search row + results ───────────────────────────────────────
    Column {
        id: listBox
        visible: false
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4
        spacing: 4

        // Search "box": plain Item + key events (clipboard-free by design).
        Item {
            id: searchBox
            width: listBox.width
            height: 22
            activeFocusOnTab: true

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: root._c("surface", "#0a0a0a")
                border.width: 1
                border.color: searchBox.activeFocus ? root._c("secondary", "#00dce5")
                                                    : root._c("outline", "#2a2a2a")
            }
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 8
                spacing: 0
                Text {
                    text: root.query === "" ? "Type to search…"
                                            : root.query
                    font.family: "monospace"
                    font.pixelSize: 11
                    color: root.query === "" ? root._c("textDim", "#808080")
                                             : root._c("text", "#e0e0e0")
                    elide: Text.ElideMiddle
                    width: Math.min(implicitWidth, parent.width - caret.width - 16)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    id: caret
                    width: query === "" && !searchBox.activeFocus ? 0 : 1
                    height: 13
                    color: root._c("secondary", "#00dce5")
                    anchors.verticalCenter: parent.verticalCenter
                    visible: width > 0
                    SequentialAnimation on opacity {
                        running: caret.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.closePopup(); event.accepted = true; return }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.pick(root.cursorIndex >= 0 ? root.cursorIndex : 0)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Down || event.text === "j") {
                    if (root.filtered.length) root.cursorIndex = Math.min(root.cursorIndex + 1, root.filtered.length - 1)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Up || event.text === "k") {
                    root.cursorIndex = Math.max(root.cursorIndex - 1, -1)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Backspace) {
                    root.query = Logic.searchBackspace(root.query)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_U && event.modifiers & Qt.ControlModifier) {
                    root.query = ""
                    event.accepted = true
                    return
                }
                // searchTyped returns the query unchanged for non-printable
                // text — so control keys keep their default meaning.
                var next = Logic.searchTyped(root.query, event.text, 64)
                if (next !== root.query) { root.query = next; event.accepted = true }
            }
        }

        ListView {
            id: list
            width: listBox.width
            height: Math.min(root.listHeight, contentHeight)
            clip: true
            model: root.filtered
            currentIndex: root.cursorIndex
            onCurrentIndexChanged: {
                if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            }

            delegate: Item {
                // Plain `property var` per delegate — `required property`
                // with a JS-array model breaks modelData (codebase trap).
                property var entry: modelData
                width: list.width
                height: 24

                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: index === root.cursorIndex ? root._c("fillHover", "#1c1c1c")
                                                      : "transparent"
                }
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 8
                    text: entry ? entry.label : ""
                    font.family: "monospace"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    color: entry && entry.value === root.value ? root._c("secondary", "#00dce5")
                                                               : _c("text", "#e0e0e0")
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: root.cursorIndex = index
                    onClicked: root.pick(index)
                }
            }
        }

        Text {
            visible: root.filtered.length === 0
            text: "No matches"
            font.family: "monospace"
            font.pixelSize: 10
            color: _c("textDim", "#808080")
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 8
            bottomPadding: 8
        }
    }

    // Losing focus (click elsewhere in the panel) closes — the popover never
    // traps the cursor.
    onActiveFocusChanged: if (!activeFocus && listBox.visible) closePopup()
}
