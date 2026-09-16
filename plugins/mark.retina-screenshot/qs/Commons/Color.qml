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
}
