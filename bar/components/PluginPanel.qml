// =============================================================================
// PluginPanel.qml — plugin popover HOST (window + plugin semantics)
// =============================================================================
// The popover chrome (trigger-anchored positioning, edge clamp, open/close
// motion, click-outside dismiss, hover-out close) lives in Popover.qml — the
// Tier-3 primitive. This file keeps what is plugin-specific: the layer
// window, the one-at-a-time registry (PluginHostService.openPanel), the
// workspace-change contextual close, the drag header, and the body slot.
//
// API (unchanged for plugin call sites) + NEW optional `anchorItem`:
//   pluginId / title / icon / contentWidth / anchorX ("right"|"center") /
//   showHeader / onOpen / open() / close() / toggle() / offX / offY /
//   default slot → body content. anchorItem: pass the bar pill to center the
//   card under it (falls back to anchorX when null).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services" as Services
import "../config" as Config

PanelWindow {
    id: panelRoot

    required property string pluginId
    property string title: ""
    property string icon: ""
    property real contentWidth: 320
    // Horizontal dock: "right" (default) or "center" (under the clock anchor)
    property string anchorX: "right"
    // NEW: the bar pill to center under (preferred over anchorX)
    property Item anchorItem: null

    // Body content goes here: content.children: [ ... ]
    default property alias content: bodySlot.data
    // Optional: called by the host on summon; plugins override open()/close()
    // on their BarWidget root and forward here.

    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Config.BarConfig.barHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    WlrLayershell.namespace: "bar-plugin-" + pluginId
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // NOTE: no `mask` here — the panel must RECEIVE input (✕, hover-out, drag).
    // (Osd.qml uses an empty mask for the opposite, click-through behavior.)

    visible: popover.opened || popover.cardOpacity > 0

    // State lives in the Popover primitive; `opened` stays readable.
    readonly property bool opened: popover.opened

    // One-at-a-time: registering our open with the host closes any other
    // plugin panel; a foreign panel registering closes us.
    Connections {
        target: popover
        function onPopOpened() { Services.PluginHostService.openPanel = pluginId }
        function onPopClosed() {
            if (Services.PluginHostService.openPanel === pluginId)
                Services.PluginHostService.openPanel = ""
        }
    }
    Connections {
        target: Services.PluginHostService
        function onOpenPanelChanged() {
            if (popover.opened && Services.PluginHostService.openPanel !== pluginId)
                popover.close()
        }
    }

    // Contextual dismissal: leaving the workspace closes the panel (the
    // layer-shell surface would otherwise follow you everywhere).
    Connections {
        target: Services.HyprlandService
        function onSocketEvent(line) {
            var ev = "" + line
            if (!popover.opened) return
            if (ev.indexOf("workspace>>") === 0 || ev.indexOf("workspacev2>>") === 0) {
                console.log("[PluginPanel] " + pluginId + " closing on workspace change")
                popover.close()
            }
        }
    }

    function open() {
        popover.open()
        if (onOpen) onOpen()
    }
    function close() { popover.close() }
    function toggle() { popover.toggle() }   // parity: toggle never fires onOpen

    // Hook plugins use to refresh data on open (assigned by the plugin).
    property var onOpen: null

    // Drag-to-move offsets for the card (applied against its anchored dock).
    property real offX: 0
    property real offY: 0

    readonly property string lastTitle: title
    readonly property int headerH: 34
    // Mockup-faithful cards (calendar/weather) draw their own headers — hide
    // the title row and let the body start at the card's top margin.
    property bool showHeader: true

    Popover {
        id: popover
        cardWidth: panelRoot.contentWidth
        anchorFallback: panelRoot.anchorX
        anchorItem: panelRoot.anchorItem
        hoverClose: true
        offX: panelRoot.offX
        offY: panelRoot.offY

        // ── HEADER (press-drag to move the card) ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: panelRoot.showHeader ? panelRoot.headerH : 0
            visible: panelRoot.showHeader

            // Drag-to-move: press anywhere in the header and drag the card
            MouseArea {
                id: dragMa
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
                    font.family: Config.BarConfig.fontNerd; font.pixelSize: 14
                    color: Config.BarConfig.colorAccent
                }
                Text {
                    text: panelRoot.title.toUpperCase()
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: 10
                    font.bold: true; font.letterSpacing: 2.5
                    color: Config.BarConfig.colorText
                    Layout.fillWidth: true
                }
                Text {
                    text: "✕"
                    font.pixelSize: 11
                    color: closeArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
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
            color: Config.ThemeConfig.hairline
        }

        // ── BODY ──
        ColumnLayout {
            id: bodySlot
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 0
        }
    }
}
