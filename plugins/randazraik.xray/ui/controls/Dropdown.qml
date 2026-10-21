import QtQuick
import QtQuick.Controls as Controls
Controls.ComboBox {
    id: root
    property var options: []
    property bool showLabel: true
    property string value: ""
    signal changed(string value)
    model: root.options
    textRole: "label"
    valueRole: "value"
    displayText: currentText || "…"
    font.family: "JetBrains Mono"
    font.pixelSize: 11
    onActivated: function(index) { root.changed(root.options[index] ? root.options[index].value : "") }
}
