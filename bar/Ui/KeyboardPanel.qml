// qs.Ui/KeyboardPanel.qml — compat visual card for converted panel bodies.
// Sized from contentWidth/contentHeight (set by the derived panel), docked
// top-right below the bar, themed from the live palette. Children (content
// rows, key catchers, overlays) are placed by the derived panel itself.
import QtQuick
import "../Commons"

Rectangle {
    id: kbdPanel

    property bool open: false
    property real contentWidth: 300
    property real contentHeight: 200
    property var anchorItem: null
    property var owner: null
    property var bar: null
    property bool centerOnBar: true
    property var focusTarget: null

    // Upstream API surface the converted panels call: content inset (12px
    // margins + 1px borders) and the fitted-size helpers. Identity functions
    // — THIS card adds its own +24 when sizing from contentWidth/Height, so
    // adding an inset here as well would double-pad.
    readonly property real verticalContentInset: 26
    function fittedContentWidth(w)  { return w }
    function fittedContentHeight(h) { return h }

    default property alias content: contentSlot.data

    anchors.top: parent.top
    anchors.topMargin: 38
    anchors.right: parent.right
    anchors.rightMargin: 12
    width: contentWidth + 24
    height: contentHeight + 24
    visible: open
    radius: 0
    color: Theme.colors.background
    border.color: Qt.rgba(Theme.colors.text.r, Theme.colors.text.g, Theme.colors.text.b, 0.15)
    border.width: 1

    // Content dock — derived panel children land inside this inset.
    Item {
        id: contentSlot
        anchors.fill: parent
        anchors.margins: 12
        clip: true
    }
}
