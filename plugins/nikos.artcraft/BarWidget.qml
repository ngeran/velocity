// =============================================================================
// nikos.artcraft — bar widget (plugin api 2)
// =============================================================================
// Rest: palette glyph. Updates pending: up-arrow glyph + accent + count on
// hover. Upgrading: pulsing glyph. Failure: error colour.
// Click toggles the ArtCraft panel. The shared state lives in ServiceRoot.qml
// (ctx.service), so every output sees the same status/progress.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import qs.Ui

Item {
    id: root

    property var ctx: null

    readonly property var svc: ctx ? ctx.service : null
    readonly property int count: svc ? svc.count : 0
    readonly property bool upgrading: svc ? svc.upgrading : false
    readonly property bool failed: svc ? (svc.checkError !== "" || svc.progress.error !== "") : false
    readonly property bool hideWhenCurrent: ctx ? ctx.settings.get("hideWhenCurrent", false) : false

    visible: !hideWhenCurrent || count > 0 || upgrading || failed || panel.opened
    implicitWidth: visible ? pill.implicitWidth : 0
    implicitHeight: pill.height

    BarPill {
        id: pill
        ctx: root.ctx
        icon: root.upgrading ? "󰔟"
            : root.failed ? "󰅚"
            : root.count > 0 ? "󰇚"
            : "󰏘"
        label: root.upgrading ? "UPGRADING"
            : root.failed ? "FAILED"
            : root.count > 0 ? root.count + " UPDATE" + (root.count === 1 ? "" : "S")
            : ""
        active: panel.opened
        restColor: {
            if (!root.ctx) return "#888"
            if (root.failed) return root.ctx.theme.colors.error
            if (root.count > 0 || root.upgrading) return root.ctx.theme.colors.accent
            return root.ctx.bar.colorText
        }
        onClicked: function(button) {
            if (button === Qt.LeftButton) panel.toggle()
        }
    }

    SequentialAnimation on opacity {
        running: root.upgrading
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 650 }
        NumberAnimation { to: 1.0; duration: 650 }
        onRunningChanged: if (!running) root.opacity = 1.0
    }

    PluginPopup {
        id: panel
        ctx: root.ctx
        anchorItem: root
        title: "ARTCRAFT"
        icon: "󰏘"
        contentWidth: 680
        onOpen: function() {
            if (root.svc && root.svc.shouldCheck()) root.svc.check()
        }

        Loader {
            id: body
            Layout.fillWidth: true
            active: root.ctx !== null
            source: Qt.resolvedUrl("ArtcraftPanel.qml")
            onLoaded: item.ctx = root.ctx
            onStatusChanged: if (status === Loader.Error)
                console.log("[nikos.artcraft] panel failed to load")
        }
    }

    // Host IPC (plugins summon/hide/call) routes through these. `update`
    // must be declared here: Item has a built-in update() that would
    // otherwise swallow the manifest.ipc verb before the service sees it.
    function toggle() { panel.toggle() }
    function open()   { panel.open() }
    function close()  { panel.close() }
    function update(app) { return svc ? svc.update(app) : "no service" }
}
