// =============================================================================
// nikos.weather — bar pill (plugin api 1)
// =============================================================================
// Condition glyph + temperature. Hidden until the first valid sample. Click
// toggles the plugin's own weather panel; the panel refreshes on open.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "file:///home/nikos/.config/quickshell/bar/components" as Host
import "." as WX

Item {
    id: root

    property string pluginId: ""
    property var api: null

    readonly property bool hot: mouseArea.containsMouse

    implicitWidth: weatherRow.implicitWidth
    height: api ? api.bar.barHeight : 30
    visible: WX.WeatherService.hasData

    function toggle() { panel.toggle() }
    function open()   { panel.open() }
    function close()  { panel.close() }

    Host.PluginPanel {
        id: panel
        pluginId: "nikos.weather"
        title: "ATMOSPHERE"
        icon: WX.WeatherService.glyph
        contentWidth: 380
        anchorX: "center"
        showHeader: false
        onOpen: WX.WeatherService.refresh()

        Loader {
            // Defer until api lands — the panel body binds hostBar/hostTheme
            // at creation and must never see null. The LOADER is the layout
            // child: stretch it here, inside-the-file fillWidth is invisible.
            Layout.fillWidth: true
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
        id: weatherRow
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            text: WX.WeatherService.glyph
            font.family: api ? api.bar.fontNerd : "monospace"
            font.pixelSize: api ? api.bar.fontSizeIcon : 13
            color: root.hot ? api.theme.colors.accent
                            : (api ? api.theme.colors.success : "#888")
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            text: WX.WeatherService.temp
            font.family: api ? api.bar.fontFamily : "monospace"
            font.pixelSize: 11
            color: root.hot ? api.theme.colors.accent
                            : (api ? api.theme.colors.textDim : "#666")
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
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
