// =============================================================================
// ConfirmDialog.qml — inline destructive-action confirm chip.
// =============================================================================
// Click once → arms ("CONFIRM?" in error color, 4s). Click again → executes.
// Timeout or moving on disarms. Emits confirmed() only on the armed click.
// =============================================================================
import QtQuick
import "../config" as Config

Rectangle {
    id: root

    property string label: ""
    property string confirmLabel: "CONFIRM?"
    property int resetMs: 4000

    signal confirmed()

    property bool armed: false

    width: confirmLbl.implicitWidth + 18
    height: 22
    radius: height / 2
    color: armed ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.18)
                 : (confirmMa.containsMouse ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.text, 0.08)
                                            : Config.ThemeConfig.tint(Config.ThemeConfig.colors.surface, 0.5))
    border.color: armed ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.outlineVariant
    border.width: 1
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        id: confirmLbl
        anchors.centerIn: parent
        text: root.armed ? root.confirmLabel : root.label
        font.family: Config.BarConfig.fontFamily
        font.pixelSize: 9
        font.bold: true
        color: root.armed ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.text
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    MouseArea {
        id: confirmMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.armed) {
                root.armed = false
                armTimer.stop()
                root.confirmed()
            } else {
                root.armed = true
                armTimer.restart()
            }
        }
    }

    Timer {
        id: armTimer
        interval: root.resetMs
        onTriggered: root.armed = false
    }
}
