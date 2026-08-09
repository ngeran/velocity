// =============================================================================
// ArchLogo.qml — Arch Linux icon with fastfetch action
// =============================================================================

import QtQuick
import "../config" as Config

Item {
    id: icon
    width: Config.BarConfig.iconSize
    height: Config.BarConfig.iconSize

    // Emitted on click → shell.qml wires it to FastfetchOverlay.toggle().
    // (Replaces the old inline kitty fastfetch launcher — see FastfetchOverlay.qml.)
    signal triggered()

    // Two pre-encoded Arch SVGs (text-colour + accent). Baking both up front
    // means a hover only flips opacity between two already-decoded textures —
    // no per-hover string concat / base64 encode / texture re-upload (the old
    // binding rebuilt the data URL on every mouse enter/leave). They rebuild
    // only when the theme colours they embed change.
    function _svgBody(fill) {
        return '<svg width="24" height="25" viewBox="0 0 24 25" fill="none" xmlns="http://www.w3.org/2000/svg">'
            + '<path d="M15.7733 10.2843L23.998 2.05957L22.1477 0.20926L13.923 8.43396L15.7733 10.2843Z" fill="' + fill + '"/>'
            + '<path d="M0.00772348 2.06143L8.23242 10.2861L10.0827 8.43582L1.85803 0.211124L0.00772348 2.06143Z" fill="' + fill + '"/>'
            + '<path d="M24.0001 22.3468L15.7754 14.1221L13.9251 15.9724L22.1498 24.1971L24.0001 22.3468Z" fill="' + fill + '"/>'
            + '<path d="M8.2247 14.1249L0 22.3496L1.85031 24.1999L10.075 15.9752L8.2247 14.1249Z" fill="' + fill + '"/>'
            + '</svg>'
    }
    readonly property string _normalSrc: "data:image/svg+xml;base64," + Qt.btoa(_svgBody(Config.ThemeConfig.colors.text))
    readonly property string _hoverSrc: "data:image/svg+xml;base64," + Qt.btoa(_svgBody(Config.BarConfig.colorAccent))

    // Normal (text-colour) logo
    Image {
        anchors.centerIn: parent
        width: Config.BarConfig.archLogoSize
        height: Config.BarConfig.archLogoSize
        source: icon._normalSrc
        smooth: true
        mipmap: true
        opacity: mouseArea.containsMouse ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    // Hover (accent-colour) logo, stacked on top
    Image {
        anchors.centerIn: parent
        width: Config.BarConfig.archLogoSize
        height: Config.BarConfig.archLogoSize
        source: icon._hoverSrc
        smooth: true
        mipmap: true
        opacity: mouseArea.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: icon.triggered()
    }

    // Tooltip on hover
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 4
        text: "System Info"
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: 10
        color: Config.ThemeConfig.colors.textDim
        visible: mouseArea.containsMouse
        opacity: mouseArea.containsMouse ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
