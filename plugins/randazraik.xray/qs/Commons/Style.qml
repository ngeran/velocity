pragma Singleton
import QtQuick
QtObject {
    function space(n) { return n }
    readonly property int cornerRadius: 6
    readonly property int gapsOut: 8
    readonly property int normalBorderWidth: 1
    readonly property QtObject font: QtObject {
        readonly property string family: "JetBrains Mono"
        readonly property int display: 20
        readonly property int heading: 16
        readonly property int subtitle: 14
        readonly property int body: 12
        readonly property int bodySmall: 11
        readonly property int caption: 10
    }
}
