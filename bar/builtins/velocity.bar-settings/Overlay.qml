// velocity.bar-settings — built-in overlay, a lazy wrapper over
// components/BarSettingsOverlay.qml. The window is built on first open and
// kept warm (overlay contract: shown / open / close / toggle — the plugin
// host claims the popup slot). Reached from the logo's left click:
//   qs -c bar ipc call plugins call velocity.bar-settings toggle ""
import QtQuick
import "../../components" as Components

Item {
    id: root
    property var ctx: null

    readonly property bool shown: loader.item ? loader.item.shown : false
    property bool _wanted: false

    function open()   { if (loader.item) loader.item.open(); else root._wanted = true }
    function close()  { if (loader.item) loader.item.close() }
    function toggle() { if (loader.item) loader.item.toggle(); else root._wanted = true }

    Loader {
        id: loader
        active: root._wanted
        sourceComponent: Component { Components.BarSettingsOverlay { } }
        onLoaded: item.open()
    }
}
