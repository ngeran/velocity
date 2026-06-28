// =============================================================================
// WifiListView.qml — visible-networks list for the NETWORK section
// WifiPasswordDialog is inlined as a local Component to avoid import issues.
// =============================================================================

import QtQuick
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 6

    // -------------------------------------------------------------------------
    // SCAN TOOLBAR
    // -------------------------------------------------------------------------
    Row {
        width: parent.width
        height: 26
        spacing: 10

        // [ SCAN ] button
        Rectangle {
            id: scanBtn
            width: scanLabel.implicitWidth + 18
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            color: scanMA.containsMouse && !Services.NetworkControlService.scanning
                   ? Config.ControlConfig.accent : "transparent"
            border.color: Services.NetworkControlService.scanning
                          ? Config.ThemeConfig.colors.border
                          : Config.ControlConfig.accent
            border.width: 1

            Text {
                id: scanLabel
                anchors.centerIn: parent
                text: "[ SCAN ]"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                font.bold: true
                color: scanMA.containsMouse && !Services.NetworkControlService.scanning
                       ? Config.ThemeConfig.colors.background
                       : Services.NetworkControlService.scanning
                         ? Config.ThemeConfig.colors.textDim
                         : Config.ControlConfig.accent
            }
            MouseArea {
                id: scanMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Services.NetworkControlService.scanning
                             ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: {
                    if (!Services.NetworkControlService.scanning)
                        Services.NetworkControlService.scanWifi()
                }
            }
        }

        // Animated dots while scanning
        Text {
            visible: Services.NetworkControlService.scanning
            anchors.verticalCenter: parent.verticalCenter
            text: {
                var dots = ["·", "··", "···", "····"]
                return "scanning" + dots[Math.floor(dotTimer.tick % 4)]
            }
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim

            Timer {
                id: dotTimer
                property int tick: 0
                interval: 300
                repeat: true
                running: Services.NetworkControlService.scanning
                onTriggered: tick++
                onRunningChanged: if (!running) tick = 0
            }
        }

        // Network count when idle
        Text {
            visible: !Services.NetworkControlService.scanning
            anchors.verticalCenter: parent.verticalCenter
            text: Services.NetworkControlService.wifiNetworks.length > 0
                  ? Services.NetworkControlService.wifiNetworks.length + " networks"
                  : ""
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }
    }

    // -------------------------------------------------------------------------
    // PASSWORD DIALOG — compact single-row inline form
    // -------------------------------------------------------------------------
    Item {
        id: pwDialog
        width: view.width
        height: visible ? 36 : 0
        visible: false
        clip: true

        property string targetSsid: ""

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

        function submit() {
            if (passField.text.length === 0) return
            Services.NetworkControlService.connectWifi(pwDialog.targetSsid, passField.text)
            pwDialog.close()
        }

        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: 4
            color: Qt.rgba(0, 0.863, 0.898, 0.04)
            border.color: Config.ControlConfig.accent
            border.width: 1
        }

        // Single row: SSID label · password field · 👁 · [OK] · [×]
        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            // Network name
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pwDialog.targetSsid
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                font.bold: true
                color: Config.ControlConfig.accent
                elide: Text.ElideRight
                width: 130
            }

            // Separator
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: 10
                color: Config.ThemeConfig.colors.textDim
            }

            // Password input
            Rectangle {
                width: 180
                height: 22
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: passField.activeFocus
                             ? Config.ControlConfig.accent
                             : Config.ThemeConfig.colors.border
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 100 } }

                TextInput {
                    id: passField
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 11
                    color: Config.ThemeConfig.colors.text
                    selectionColor: Qt.rgba(0, 0.863, 0.898, 0.35)
                    Keys.onReturnPressed: pwDialog.submit()
                    Keys.onEscapePressed: pwDialog.close()
                }
            }

            // Show/hide toggle
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: passField.echoMode === TextInput.Password ? "👁" : "○"
                font.pixelSize: 12
                color: Config.ThemeConfig.colors.textDim
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: passField.echoMode = (passField.echoMode === TextInput.Password)
                                                    ? TextInput.Normal : TextInput.Password
                }
            }

            // [ OK ]
            Rectangle {
                width: 40; height: 22
                anchors.verticalCenter: parent.verticalCenter
                color: okMA.containsMouse ? Config.ControlConfig.accent : "transparent"
                border.color: Config.ControlConfig.accent
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "OK"
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 9
                    font.bold: true
                    color: okMA.containsMouse
                           ? Config.ThemeConfig.colors.background
                           : Config.ControlConfig.accent
                }
                MouseArea {
                    id: okMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pwDialog.submit()
                }
            }

            // [ × ]
            Rectangle {
                width: 28; height: 22
                anchors.verticalCenter: parent.verticalCenter
                color: xMA.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent"
                border.color: Config.ThemeConfig.colors.border
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    font.family: Config.ControlConfig.fontMono
                    font.pixelSize: 11
                    color: Config.ThemeConfig.colors.textDim
                }
                MouseArea {
                    id: xMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pwDialog.close()
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // COLUMN HEADER
    // -------------------------------------------------------------------------
    Row {
        x: 4
        spacing: 8
        Text { width: 14;  text: "";         font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; color: Config.ThemeConfig.colors.textDim }
        Text { width: 180; text: "SSID";     font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
        Text { width: 90;  text: "SIGNAL";   font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
        Text {             text: "SECURITY"; font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
    }

    // -------------------------------------------------------------------------
    // NETWORK LIST
    // -------------------------------------------------------------------------
    Repeater {
        model: Services.NetworkControlService.wifiNetworks
        delegate: WifiListRow {
            width: view.width
            net: modelData
            onRequestPassword: function(ssid) {
                if (pwDialog.visible && pwDialog.targetSsid !== ssid) pwDialog.close()
                pwDialog.open(ssid)
            }
        }
    }

    // Empty state
    Text {
        visible: Services.NetworkControlService.wifiNetworks.length === 0
                 && !Services.NetworkControlService.scanning
        text: "// no networks visible — press [ SCAN ] to search"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 11
        color: Config.ThemeConfig.colors.textDim
    }
}
