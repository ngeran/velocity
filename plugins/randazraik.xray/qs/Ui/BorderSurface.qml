import QtQuick
Rectangle {
    property var borderSpec: null
    property int padding: 0
    border.color: borderSpec ? borderSpec.color : "transparent"
    border.width: borderSpec ? (borderSpec.width || 0) : 0
    color: "transparent"
}
