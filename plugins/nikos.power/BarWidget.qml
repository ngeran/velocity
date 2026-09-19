// =============================================================================
// nikos.power — battery glyph (plugin api 1)
// =============================================================================
// Port of the built-in BatteryIcon with the audit fix: tier colours ride
// api.theme tokens (the old hex literals disagreed with the popup on
// non-teal themes). Hover-reveal label shows charge %; click toggles the
// plugin's own power panel.
// =============================================================================
import QtQuick
import "file:///home/nikos/.config/quickshell/bar/components" as Host
import "." as PW

Item {
    id: root

    property string pluginId: ""
    property var api: null

    readonly property bool hot: mouseArea.containsMouse
    readonly property bool expanded: mouseArea.containsMouse

    // Hover-reveal pill idiom: implicitWidth grows, never a fixed width.
    implicitWidth: powerRow.implicitWidth
    height: api ? api.bar.barHeight : 30
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    function toggle() { panel.toggle() }
    function open()   { panel.open() }
    function close()  { panel.close() }

    Host.PluginPanel {
        anchorItem: root   // center the panel under this pill (Popover)
        id: panel
        pluginId: "nikos.power"
        title: "POWER"
        icon: PW.BatteryService.glyph
        contentWidth: 340

        Loader {
            id: bodyLoader
            active: root.api !== null
            source: Qt.resolvedUrl("Panel.qml")
            onActiveChanged: console.log("[nikos.power] bodyLoader active=" + active + " api=" + (root.api !== null))
            onLoaded: {
                console.log("[nikos.power] panel loaded w=" + item.width + " h=" + item.height)
                item.hostBar = root.api ? root.api.bar : null
                item.hostTheme = root.api ? root.api.theme : null
            }
            onStatusChanged: if (status === Loader.Error) console.log("[nikos.power] PANEL LOAD ERROR")
        }
    }

    onApiChanged: {
        if (!panel.item) return
        panel.item.hostBar = api ? api.bar : null
        panel.item.hostTheme = api ? api.theme : null
    }

    Row {
        id: powerRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.expanded ? 6 : 0

        Text {
            text: PW.BatteryService.glyph
            font.family: api ? api.bar.fontNerd : "monospace"
            font.pixelSize: api ? api.bar.fontSizeIcon : 13
            color: {
                if (root.hot) return api.theme.colors.accent
                if (!PW.BatteryService.hasBattery) return api.bar.colorText
                if (PW.BatteryService.charging) return api.theme.colors.success
                if (PW.BatteryService.percentage <= 20) return api.theme.colors.error
                if (PW.BatteryService.percentage <= 50) return api.theme.colors.warning
                return api.bar.colorText
            }
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            visible: root.expanded
            text: PW.BatteryService.hasBattery
                  ? "PWR " + PW.BatteryService.percentage + "%" : "PWR"
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
        onClicked: panel.toggle()
    }
}
