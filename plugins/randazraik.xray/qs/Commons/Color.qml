pragma Singleton
import QtQuick
QtObject {
    readonly property color accent: "#BB9AF7"
    readonly property color background: "#000000"
    readonly property color muted: "#a9b1d6"
    readonly property color urgent: "#4A6B80"
    readonly property QtObject menu: QtObject {
        readonly property color background: "#0d0d12"
        readonly property color text: "#c0caf5"
        readonly property color selectedBackground: "#1a1c26"
    }
}
