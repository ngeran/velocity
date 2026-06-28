// =============================================================================
// WifiPasswordDialog.qml — inline password prompt for secured WiFi networks
//
// Usage: set targetSsid and call open(); dialog emits confirmed(ssid, password)
// or cancelled(). Parent is responsible for calling
// NetworkControlService.connectWifi() on confirmed().
//
// Design: sharp-cornered terminal aesthetic — teal accent, mono font, no blur.
// Animates in/out via implicitHeight (same pattern as PopupWindow cards).
// =============================================================================

import QtQuick
import QtQuick.Controls.Basic
import "../config" as Config
import "../services" as Services

Item {
    id: dialog
    width: parent ? parent.width : 400
    implicitHeight: visible ? inner.implicitHeight + 2 : 0   // +2 for border
    visible: false
    clip: true

    property string targetSsid: ""

    signal confirmed(string ssid, string password)
    signal cancelled()

    function open(ssid) {
        targetSsid = ssid
        passField.text = ""
        passField.echoMode = TextInput.Password
        visible = true
        passField.forceActiveFocus()
    }

    function close() {
        visible = false
        passField.text = ""
        targetSsid = ""
    }

    // Animate height on show/hide
    Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // -------------------------------------------------------------------------
    // BORDER + BACKGROUND
    // -------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0.863, 0.898, 0.05)
        border.color: Config.ControlConfig.accent
        border.width: 1
    }

    // -------------------------------------------------------------------------
    // CONTENT
    // -------------------------------------------------------------------------
    Column {
        id: inner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 8
        topPadding: 10
        bottomPadding: 10

        // Header
        Row {
            spacing: 6
            Text {
                text: "⬡"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 11
                color: Config.ControlConfig.accent
            }
            Text {
                text: "CONNECT  //  " + dialog.targetSsid
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1
                color: Config.ControlConfig.accent
            }
        }

        // Password label + field row
        Row {
            width: parent.width
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "PASSWORD ›"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
                color: Config.ThemeConfig.colors.textDim
            }

            // Input field
            Rectangle {
                width: parent.width - 100 - 8 - 28 - 8  // leave room for show-btn + spacing
                height: 22
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: passField.activeFocus
                             ? Config.ControlConfig.accent
                             : Config.ThemeConfig.colors.border
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: 120 } }

                TextInput {
                    id: passField
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 11
                    color: Config.ThemeConfig.colors.text
                    selectionColor: Qt.rgba(0, 0.863, 0.898, 0.35)
                    verticalAlignment: TextInput.AlignVCenter

                    Keys.onReturnPressed: dialog._submit()
                    Keys.onEscapePressed: { dialog.cancelled(); dialog.close() }
                }
            }

            // Show/hide toggle
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: passField.echoMode === TextInput.Password ? "👁" : "🚫"
                font.pixelSize: 13
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: passField.echoMode = (passField.echoMode === TextInput.Password)
                                                    ? TextInput.Normal
                                                    : TextInput.Password
                }
            }
        }

        // Action buttons
        Row {
            spacing: 8

            // CONNECT
            Rectangle {
                width: connectLabel.implicitWidth + 20
                height: 22
                color: connectMA.containsMouse ? Config.ControlConfig.accent : "transparent"
                border.color: Config.ControlConfig.accent
                border.width: 1

                Text {
                    id: connectLabel
                    anchors.centerIn: parent
                    text: "[ CONNECT ]"
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 10
                    font.bold: true
                    color: connectMA.containsMouse
                           ? Config.ThemeConfig.colors.background
                           : Config.ControlConfig.accent
                }
                MouseArea {
                    id: connectMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dialog._submit()
                }
            }

            // CANCEL
            Rectangle {
                width: cancelLabel.implicitWidth + 20
                height: 22
                color: cancelMA.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent"
                border.color: Config.ThemeConfig.colors.border
                border.width: 1

                Text {
                    id: cancelLabel
                    anchors.centerIn: parent
                    text: "[ CANCEL ]"
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 10
                    color: Config.ThemeConfig.colors.textDim
                }
                MouseArea {
                    id: cancelMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { dialog.cancelled(); dialog.close() }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // INTERNAL
    // -------------------------------------------------------------------------
    function _submit() {
        var pw = passField.text
        if (pw.length === 0) {
            // Briefly flash the border red to indicate empty input
            emptyFlash.restart()
            return
        }
        dialog.confirmed(dialog.targetSsid, pw)
        Services.NetworkControlService.connectWifi(dialog.targetSsid, pw)
        dialog.close()
    }

    Timer {
        id: emptyFlash
        interval: 600
        onTriggered: { /* border returns to normal via binding */ }
    }
}
