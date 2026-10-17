import QtQuick
import QtQuick.Controls as Controls
Controls.TextField {
    id: root
    property color foreground: "#c0caf5"
    property color accent: "#BB9AF7"
    property color selectionTint: "#1a1c26"
    color: root.foreground
    selectionColor: root.selectionTint
    selectedTextColor: "#000000"
    selectByMouse: true
}
