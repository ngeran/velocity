// qs.Commons/Style.qml — spacing + typography mapped to the host bar scale.
pragma Singleton
import QtQuick

QtObject {
    id: root

    // Omarchy space unit ≈ 4px at the 26px bar baseline.
    function space(n) { return Math.round(n * 4) }

    readonly property string family: "monospace"
    readonly property string nerdFamily: "JetBrainsMono Nerd Font"
    readonly property int icon: 14
    readonly property int body: 12
    readonly property int bodySmall: 10
    readonly property int caption: 9

    readonly property QtObject font: QtObject {
        readonly property string family: root.family
        readonly property int title: 15
        readonly property int heading: 13
        readonly property int body: 12
        readonly property int bodySmall: 10
        readonly property int caption: 9
        readonly property int icon: 14
    }
}
