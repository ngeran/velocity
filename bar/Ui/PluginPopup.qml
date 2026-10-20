// =============================================================================
// qs.Ui/PluginPopup.qml — the popup a plugin's bar widget opens (api 2)
// =============================================================================
//   import qs.Ui
//   PluginPopup {
//       id: panel
//       ctx: root.ctx                 // required: identity, screen, theme
//       anchorItem: root              // centre the card under the pill
//       title: "POWER"; icon: "󰁹"; contentWidth: 340
//       subKey: ""                  // set for a plugin's 2nd+ panel
//       Text { text: "body goes in the default slot" }
//   }
//   … and forward open()/close()/toggle() from the widget root to `panel`
//   so `plugins summon/hide <id>` reach it.
//
// The chrome (anchored positioning, edge clamp, motion, click-outside and
// hover-out dismiss) is Popover.qml. This adds the layer window, the
// one-panel-at-a-time slot (ctx.popup), closing on workspace change, the
// drag header and the body slot. Opens on the screen of the widget instance
// that owns it. Engine state goes through ctx only (see PluginContext.qml).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../components" as Components

PanelWindow {
    id: panelRoot

    property var ctx: null
    readonly property string pluginId: ctx ? ctx.pluginId : ""
    // Second+ panel of one plugin (clock: "wx") — its own exclusive slot.
    property string subKey: ""
    readonly property string slotKey: ctx ? ctx.popup.keyFor(subKey) : ""
    property string title: ""
    property string icon: ""
    property real contentWidth: 320
    // Horizontal dock when no anchorItem: "right" (default) or "center".
    property string anchorX: "right"
    // The bar pill to centre the card under (preferred over anchorX).
    property Item anchorItem: null
    // Cards that draw their own header (calendar/weather) hide this one.
    property bool showHeader: true
    // Called after open() — plugins refresh their data here.
    property var onOpen: null

    readonly property var _bar: ctx ? ctx.bar : null
    readonly property var _theme: ctx ? ctx.theme : null

    default property alias content: bodySlot.data

    Binding on screen {
        when: !!panelRoot.ctx && !!panelRoot.ctx.screen
        value: panelRoot.ctx ? panelRoot.ctx.screen : null
    }

    anchors { top: true; bottom: true; left: true; right: true }
    // B5: the content area excludes the bar strip on its desktop-facing
    // side — margins.top on a top bar, margins.bottom on a bottom one (the
    // Popover primitive reads barAtBottom and rises from the bottom edge).
    readonly property bool _atBottom: _bar ? _bar.barAtBottom === true : false
    margins.top: !_atBottom ? (_bar ? _bar.barHeight : 26) : 0
    margins.bottom: _atBottom ? (_bar ? _bar.barHeight : 26) : 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    WlrLayershell.namespace: "bar-plugin-" + slotKey
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // No `mask`: the panel must RECEIVE input (✕, hover-out, drag).

    visible: popover.opened || popover.cardOpacity > 0
    readonly property bool opened: popover.opened

    function open() {
        popover.open()
        if (onOpen) onOpen()
    }
    function close() { popover.close() }
    function toggle() { popover.toggle() }   // parity: toggle never fires onOpen

    // One-at-a-time: claiming the slot closes any other plugin panel (and,
    // via the host, the tray card / notification center / overlays); a
    // foreign claim closes us.
    Connections {
        target: popover
        function onPopOpened() {
            if (panelRoot.ctx) panelRoot.ctx.popup.request(panelRoot.subKey)
            panelRoot._publishConnected()
        }
        function onPopClosed() {
            if (panelRoot.ctx) panelRoot.ctx.popup.release(panelRoot.subKey)
            panelRoot._publishConnected()
        }
        // Drag and clamp shifts move the card — the notch carve tracks it.
        function onCardCenterXChanged() {
            if (popover.opened) panelRoot._publishConnected()
        }
    }
    Connections {
        target: panelRoot.ctx ? panelRoot.ctx.popup : null
        function onCurrentChanged() {
            if (popover.opened && panelRoot.ctx.popup.current !== panelRoot.slotKey) popover.close()
        }
    }

    // Notch-lobe plumbing: publish the caret geometry while open; owner-
    // checked clear so a successor's publish is never wiped.
    function _publishConnected() {
        if (!panelRoot.ctx) return
        panelRoot.ctx.popup.publish(popover.opened
            ? { screen: panelRoot.screen ? panelRoot.screen.name : "", caretX: popover.cardCenterX }
            : null, panelRoot.subKey)
    }

    // Leaving the workspace closes the panel (a layer surface would follow
    // you everywhere otherwise).
    Connections {
        target: panelRoot.ctx ? panelRoot.ctx.events : null
        ignoreUnknownSignals: true
        function onHyprEvent(line) {
            if (!popover.opened) return
            var ev = String(line)
            if (ev.indexOf("workspace>>") === 0 || ev.indexOf("workspacev2>>") === 0) popover.close()
        }
    }

    // Drag-to-move offsets for the card (against its anchored dock).
    property real offX: 0
    property real offY: 0
    readonly property int headerH: 34

    Components.Popover {
        id: popover
        cardWidth: panelRoot.contentWidth
        anchorFallback: panelRoot.anchorX
        anchorItem: panelRoot.anchorItem
        hoverClose: true
        offX: panelRoot.offX
        offY: panelRoot.offY
        // Under the notch style the lobe's caret wedge meets the card.
        gap: panelRoot._bar && panelRoot._bar.barStyle === "notch" ? 0 : 8

        // ── header (press-drag to move the card) ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: panelRoot.showHeader ? panelRoot.headerH : 0
            visible: panelRoot.showHeader

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                property point press
                onPressed: function(m) { press = Qt.point(m.x, m.y) }
                onPositionChanged: function(m) {
                    if (!pressed) return
                    panelRoot.offX -= (m.x - press.x)
                    panelRoot.offY += (m.y - press.y)
                    press = Qt.point(m.x, m.y)
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 10
                spacing: 8
                Text {
                    text: panelRoot.icon
                    font.family: panelRoot._bar ? panelRoot._bar.fontNerd : "monospace"; font.pixelSize: 14
                    color: panelRoot._bar ? panelRoot._bar.colorAccent : "#00dce5"
                }
                Text {
                    text: panelRoot.title.toUpperCase()
                    font.family: panelRoot._bar ? panelRoot._bar.fontFamily : "monospace"; font.pixelSize: 10
                    font.bold: true; font.letterSpacing: 2.5
                    color: panelRoot._bar ? panelRoot._bar.colorText : "#cccccc"
                    Layout.fillWidth: true
                }
                Text {
                    text: "✕"
                    font.pixelSize: 11
                    color: !panelRoot._bar ? "#888888" : closeArea.containsMouse ? panelRoot._bar.colorAccent : panelRoot._bar.colorTextDim
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent; anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: panelRoot.close()
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; height: 1
            visible: panelRoot.showHeader
            color: panelRoot._theme ? panelRoot._theme.hairline : "#22ffffff"
        }

        // ── body ──
        ColumnLayout {
            id: bodySlot
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 0
        }
    }
}
