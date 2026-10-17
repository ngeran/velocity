// qs.Commons/Color.qml — semantic color roles mapped to the live palette.
pragma Singleton
import QtQuick

QtObject {
    readonly property color foreground: Theme.colors.text
    readonly property color background: Theme.colors.background
    readonly property color accent: Theme.colors.primary
    readonly property color success: Theme.colors.success
    readonly property color warning: Theme.colors.warning
    readonly property color error: Theme.colors.error
    readonly property color muted: Theme.colors.textDim
    readonly property color urgent: Theme.colors.error
    readonly property QtObject menu: QtObject {
        readonly property color background: Theme.colors.surface
        readonly property color text: Theme.colors.text
        readonly property color selectedBackground: Theme.colors.surfaceVariant
    }
}
