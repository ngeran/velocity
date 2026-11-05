// velocity.ai-bot — bar widget: AI glyph whose click opens the Z.ai usage
// panel anchored under the bar (qs.Ui.PluginPopup, like the network/storage
// cards). Data/polling come from ZaiUsageService.
import QtQuick
import qs.Ui
import "../../components" as Components

Components.AiBotIcon {
    id: root
    property var ctx: null

    onTriggered: panel.toggle()

    PluginPopup {
        id: panel
        ctx: root.ctx
        anchorItem: root
        title: "Z.AI USAGE"
        icon: "󰚩"
        contentWidth: 420

        Components.ZaiUsagePanel {
            active: panel.opened
        }
    }

    // Host IPC (plugins summon/hide/call) routes through these.
    function toggle() { panel.toggle() }
    function open()   { panel.open() }
    function close()  { panel.close() }
}
