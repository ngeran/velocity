// {{ID}} — bar widget (plugin api 2).
// The engine injects `ctx` (see bar/engine/PluginContext.qml); UI parts come
// from qs.Ui. Check it: velocity-plugin validate {{ID}}
import QtQuick
import qs.Ui

Item {
    id: root
    property var ctx: null

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.height

    BarPill {
        id: pill
        ctx: root.ctx
        icon: "󰜗"
        label: root.ctx ? root.ctx.settings.get("label", "HELLO") : ""
        onClicked: function(button) { if (root.ctx) root.ctx.log("clicked " + button) }
    }

    // manifest.ipc verb: velocity-plugin call {{ID}} ping hi
    function ping(arg) { return "pong " + arg }
}
