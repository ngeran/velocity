// =============================================================================
// nikos.timezones — bar pill (plugin api 1)
// =============================================================================
// Clock glyph that expands on hover to "ATHENS 03:31 · LON 01:31 · TYO 09:31";
// click toggles the plugin's own working-hours panel. Contract: host injects
// pluginId + api after loading; the host `plugins` IPC can summon/hide via
// open()/close().
// =============================================================================
import QtQuick
import "file:///home/nikos/.config/quickshell/bar/components" as Host
import "." as TZ

Item {
    id: root

    property string pluginId: ""
    property var api: null

    readonly property bool expanded: mouseArea.containsMouse && TZ.TimezoneService.compactLabel !== ""

    implicitWidth: tzRow.implicitWidth
    height: api ? api.bar.barHeight : 30
    clip: true

    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    function toggle() { panel.toggle() }
    function open()   { panel.open() }
    function close()  { panel.close() }

    Host.PluginPanel {
        anchorItem: root   // center the panel under this pill (Popover)
        id: panel
        pluginId: "nikos.timezones"
        title: "TIME ZONES"
        icon: "󰅐"
        contentWidth: 800
        onOpen: TZ.TimezoneService.refresh()

        Loader {
            // Defer until api lands — the panel body binds hostBar/hostTheme
            // at creation and must never see null.
            active: root.api !== null
            source: Qt.resolvedUrl("Panel.qml")
            onLoaded: {
                item.hostBar = root.api ? root.api.bar : null
                item.hostTheme = root.api ? root.api.theme : null
            }
        }
    }

    onApiChanged: {
        if (!panel.item) return
        panel.item.hostBar = api ? api.bar : null
        panel.item.hostTheme = api ? api.theme : null
    }

    Row {
        id: tzRow
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.expanded ? 8 : 0

        Text {
            text: "󰅐"
            font.family: api ? api.bar.fontNerd : "monospace"
            font.pixelSize: api ? api.bar.fontSizeIcon : 13
            color: (root.expanded || mouseArea.containsMouse)
                   ? api.theme.colors.accent
                   : (api ? api.bar.colorText : "#888")
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            visible: root.expanded
            text: TZ.TimezoneService.compactLabel
            font.family: api ? api.bar.fontFamily : "monospace"
            font.pixelSize: 11
            color: api ? api.theme.colors.text : "#aaa"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) TZ.TimezoneService.refresh()
            else panel.toggle()
        }
    }
}
