// =============================================================================
// PluginPanel.qml — HOST-PROVIDED popup base for bar-widget plugins (api 1)
// =============================================================================
// Full-screen transparent overlay + top-right card, TrayCard styling: same
// background/hairline/accent tokens, 140ms fade, click-outside dismissal,
// hover-out dismissal (450ms, entered-guard), ✕ button.
//
// Plugins import this by ABSOLUTE PATH (component import — safe; only
// singleton imports can fork instances):
//   import "file:///home/nikos/.config/quickshell/bar/components" as Host
//   Host.PluginPanel { pluginId: "nikos.x"; title: "X"; icon: ""; contentWidth: 320
//                      content.children: [ ...body... ] }
//
// The host shell calls toggle()/open()/close() through the `plugins` IPC
// (summon/hide) when the plugin root exposes them and forwards to panel.
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

    visible: opened || card.opacity > 0
    property bool opened: false

    // One-at-a-time: registering our open with the host closes any other
    // plugin panel; a foreign panel registering closes us.
    onOpenedChanged: {
        if (opened) Services.PluginHostService.openPanel = pluginId
        else if (Services.PluginHostService.openPanel === pluginId)
            Services.PluginHostService.openPanel = ""
    }
    Connections {
        target: Services.PluginHostService
        function onOpenPanelChanged() {
            if (opened && Services.PluginHostService.openPanel !== pluginId) close()
        }
    }

    // Contextual dismissal: leaving the workspace closes the panel (the
    // layer-shell surface would otherwise follow you everywhere).
    Connections {
        target: Services.HyprlandService
        function onSocketEvent(line) {
            var ev = "" + line
            if (!opened) return
            if (ev.indexOf("workspace>>") === 0 || ev.indexOf("workspacev2>>") === 0) {
                console.log("[PluginPanel] " + pluginId + " closing on workspace change")
                close()
            }
        }
    }

    function open() {
        opened = true
        if (onOpen) onOpen()
    }
    function close() {
        opened = false
        if (Services.PluginHostService.openPanel === pluginId)
            Services.PluginHostService.openPanel = ""
    }
    function toggle() { opened = !opened }

    // Hook plugins use to refresh data on open (assigned by the plugin).
    property var onOpen: null

    // Drag-to-move offsets for the card (applied against its top-right dock).
    property real offX: 0
    property real offY: 0

    readonly property string lastTitle: title
    readonly property int headerH: 34
    // Mockup-faithful cards (calendar/weather) draw their own headers — hide
    // the title row and let the body start at the card's top margin.
    property bool showHeader: true

    // Click-catcher — only misses reach it (card is stacked above) → close.
    MouseArea { anchors.fill: parent; onClicked: panelRoot.close() }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: panelRoot.offY + 8
        x: panelRoot.anchorX === "center"
           ? (parent.width - width) / 2 + panelRoot.offX
           : parent.width - width - 12 - panelRoot.offX
        width: panelRoot.contentWidth
        implicitHeight: bodyCol.implicitHeight + 20
        color: Config.BarConfig.colorBackground
        radius: 10
        border.width: 1
        border.color: Config.ThemeConfig.colors.border
        opacity: panelRoot.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }   // swallow in-card clicks

        HoverHandler {
            onHoveredChanged: {
                if (hovered) hoverCloseTimer.stop()
                else if (panelRoot.opened) hoverCloseTimer.restart()
            }
        }
        Timer {
            id: hoverCloseTimer
            interval: 450
            onTriggered: if (panelRoot.opened) panelRoot.close()
        }

        ColumnLayout {
            id: bodyCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 0

            // ── HEADER ──
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
}
