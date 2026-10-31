// =============================================================================
// SettingsLink.qml — "OPEN IN SETTINGS >" footer link (tray popup bodies, I8)
// =============================================================================
// Right-aligned dim label that brightens on hover and emits activated(verb);
// the owning body forwards the verb to its card, which routes it to the
// settings app. Extracted from TrayCard's inline component — the bodies live
// in their own files now and share this one.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import bar.config as Config

Item {
    id: link
    property string verb: ""
    signal activated(string verb)
    Layout.fillWidth: true
    Layout.topMargin: Config.PopupMetrics.px(10)
    implicitHeight: Config.PopupMetrics.px(20)
    implicitWidth: linkTxt.implicitWidth
    Text {
        id: linkTxt
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        text: "OPEN IN SETTINGS ›"
        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
        font.bold: true; font.letterSpacing: 1.5
        color: linkArea.containsMouse ? Config.BarConfig.colorAccent : Config.BarConfig.colorTextDim
    }
    MouseArea { id: linkArea; anchors.fill: linkTxt; anchors.margins: -4; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor; onClicked: link.activated(link.verb) }
}
