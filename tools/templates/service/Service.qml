// {{ID}} — headless service (plugin api 2). Lives as long as it is enabled;
// survives bar style swaps. `ctx` is injected.
import QtQuick

Item {
    id: root
    property var ctx: null
    property int ticks: 0

    Timer {
        interval: 1000 * (root.ctx ? root.ctx.settings.get("interval", 60) : 60)
        running: root.ctx !== null
        repeat: true
        onTriggered: root.ticks++
    }

    // manifest.ipc verb
    function status(arg) { return JSON.stringify({ ticks: root.ticks }) }
}
