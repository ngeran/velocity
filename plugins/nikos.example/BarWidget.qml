// =============================================================================
// nikos.example — minimal bar-widget plugin (plugin api 1)
// =============================================================================
// The host injects two properties after loading:
//   pluginId : string   — this plugin's manifest id
//   api      : object   — { version, theme, bar, osd } — OBJECT REFERENCES to
//                        the shell's process-wide singletons. Never import
//                        shell dirs from a plugin: same-dir relative imports
//                        would construct a SECOND set of singletons.
// Root must be an Item sized to the bar (height: api.bar.barHeight); the bar
// RowLayout sizes the slot from implicitWidth.
//
// Interaction copies the TimezoneWidget pill idiom: glyph only at rest, the
// label expands rightward on hover. Click deep-links to the plugin manager
// (Control ▸ Plugins) in the settings dashboard — cross-process, so it rides
// the settings shell's IPC instead of any host coupling.
// =============================================================================
import QtQuick
import Quickshell.Io

Item {
    id: root

    property string pluginId: ""
    property var api: null

    readonly property bool expanded: mouseArea.containsMouse

    // Grow through implicitWidth (NOT width) — see file header.
    implicitWidth: row.implicitWidth
    height: api ? api.bar.barHeight : 30
    clip: true

    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.expanded ? 6 : 0

        Text {
            text: "󰜗"
            font.family: api ? api.bar.fontNerd : "monospace"
            font.pixelSize: api ? api.bar.fontSizeIcon : 13
            color: root.expanded ? api.theme.colors.accent
                                 : (api ? api.theme.colors.success : "#888")
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            visible: root.expanded
            text: "PLUGIN"
            font.family: api ? api.bar.fontFamily : "monospace"
            font.pixelSize: 11
            color: api ? api.theme.colors.text : "#aaa"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Cross-process deep-link: the settings dashboard owns the manager UI.
    Process {
        id: openManagerProc
        command: ["quickshell", "-c", "settings", "ipc", "call", "SettingsWindow", "openControlPlugins"]
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: openManagerProc.running = true
    }
}
