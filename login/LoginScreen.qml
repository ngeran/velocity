// =============================================================================
// FILE: LoginScreen.qml
// PROJECT: Obsidian Core — Quickshell Desktop Environment
// PURPOSE: SDDM/greetd replacement login screen with PAM authentication
// DESIGN: Full-screen, bottom-left command cluster, large clock, password field,
//         grid background, user avatar, footer power actions
// LAYER: WlrLayerShell.Overlay (greetd session) — run as greeter compositor
// AUTHOR: ngeran
// VERSION: 0.1.0
// UPDATED: 2025-06
// =============================================================================
//
// DEPENDENCIES:
//   - Quickshell (PanelWindow, WlrLayerShell)
//   - Quickshell.Io (Process)
//   - QtQuick, QtQuick.Layouts
//
// GREETD INTEGRATION:
//   This file is designed to run under greetd with a Quickshell greeter.
//   Authentication is performed by calling `greetd-ipc` via Process, or by
//   invoking `greet` helper scripts. See INTEGRATION NOTE below.
//
//   Minimal greetd config (/etc/greetd/config.toml):
//     [terminal]
//     vt = 1
//     [default_session]
//     command = "quickshell -c /path/to/LoginShell.qml"
//     user = "greeter"
//
//   For PAM via script:
//     command: ["bash", "-c", "echo PASSWORD | greetd-pam-helper USER SESSION"]
//
// SECTIONS:
//   [1]  Imports
//   [2]  PanelWindow / Layer-shell Setup
//   [3]  Auth State Machine
//   [4]  Background: Black + Grid Canvas
//   [5]  Header: Branding
//   [6]  Bottom-left Cluster
//   [7]  User Identity Card
//   [8]  Password Input Field
//   [9]  Large Clock + Date
//   [10] Status Pill
//   [11] Footer: Power Actions
//   [12] Clock Timer
//   [13] Auth Process (greetd IPC / PAM helper)
//   [14] Input Handling
// =============================================================================

// -- [1] Imports --------------------------------------------------------------
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// -- [2] PanelWindow / Layer-shell Setup --------------------------------------
PanelWindow {
    id: root

    // -- [3] Auth State Machine -----------------------------------------------
    // "idle"          → waiting for user interaction
    // "input"         → password field focused, user typing
    // "authenticating" → PAM/greetd call in flight
    // "error"         → auth failed, show error feedback
    // "success"       → auth passed, session starting
    property string authState: "idle"

    // Configurable — set from your shell config or read from /etc/passwd
    property string userName:    "ngeran"
    property string sessionCmd:  "Hyprland"   // passed to greetd on success
    property string userAvatar:  ""            // path; empty = initials

    WlrLayerShell.layer:         WlrLayerShell.Layer.Overlay
    WlrLayerShell.keyboardFocus: WlrLayerShell.KeyboardFocus.Exclusive
    WlrLayerShell.namespace:     "obsidian-login-screen"

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: true

    // -- [4] Background: Black + Grid Canvas ----------------------------------
    Rectangle {
        anchors.fill: parent
        color: "#000000"

        // Fine grid texture
        Canvas {
            anchors.fill: parent
            opacity: 0.022
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = "#FFFFFF"
                ctx.lineWidth   = 1
                var step = 40
                for (var x = 0; x <= width;  x += step) {
                    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
                }
                for (var y = 0; y <= height; y += step) {
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                }
            }
        }

        // Bottom vignette
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.7; color: "transparent" }
                GradientStop { position: 1.0; color: "#000000" }
            }
            opacity: 0.8
        }
    }

    // -- [5] Header: Branding -------------------------------------------------
    Item {
        anchors {
            top:   parent.top
            left:  parent.left
            right: parent.right
            topMargin:   24
            leftMargin:  24
            rightMargin: 24
        }
        height: 48

        ColumnLayout {
            anchors.left: parent.left
            spacing: 2
            Text {
                text: "Obsidian Core System"
                font.family:    "JetBrains Mono"
                font.pixelSize: 12
                font.weight:    Font.Medium
                font.letterSpacing: 2.4
                color: "#8E9192"
                font.capitalization: Font.AllUppercase
            }
            Text {
                text: "Terminal Docked v0.4.1"
                font.family:    "JetBrains Mono"
                font.pixelSize: 11
                font.letterSpacing: 1.5
                color: Qt.rgba(0.651, 0.784, 1.0, 0.6)
                font.capitalization: Font.AllUppercase
            }
        }

        Row {
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16
            Repeater {
                model: ["⊞", "◎", ">_"]
                Text {
                    text: modelData
                    font.family:   "JetBrains Mono"
                    font.pixelSize: 15
                    color: "#8E9192"
                }
            }
        }
    }

    // -- [6] Bottom-left Cluster ----------------------------------------------
    Item {
        anchors {
            left:   parent.left
            bottom: loginFooter.top
            bottomMargin: 24
            leftMargin:   24
        }
        // Limit width so it doesn't run full screen
        width: Math.min(560, parent.width * 0.5)

        ColumnLayout {
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: 0

            // -- [7] User Identity Card ---------------------------------------
            RowLayout {
                spacing: 16
                Layout.bottomMargin: 32

                // Avatar
                Rectangle {
                    width:  64; height: 64
                    color:  "#1B1B1B"
                    border.color: "#444748"
                    border.width: 1

                    Image {
                        anchors.fill: parent
                        anchors.margins: 4
                        source:   root.userAvatar
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: root.userAvatar !== ""
                        // Grayscale + dim to match mockup
                        layer.effect: null   // attach ColorOverlay or Colorize if available
                        visible: root.userAvatar !== ""
                        opacity: 0.8
                    }

                    Text {
                        anchors.centerIn: parent
                        text:  root.userName.substring(0, 2).toUpperCase()
                        font.family:    "JetBrains Mono"
                        font.pixelSize: 20
                        font.weight:    Font.Bold
                        color: "#A6C8FF"
                        visible: root.userAvatar === ""
                    }

                    // Online dot
                    Rectangle {
                        anchors { bottom: parent.bottom; right: parent.right }
                        anchors.margins: -2
                        width: 12; height: 12
                        color:  "#3192FC"
                        border.color: "#000000"
                        border.width: 2
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: root.userName
                        font.family:    "JetBrains Mono"
                        font.pixelSize: 18
                        font.weight:    Font.SemiBold
                        font.letterSpacing: -0.18
                        color: "#FFFFFF"
                    }
                    Text {
                        text: root.authState === "error"
                              ? "AUTH FAILED — RETRY"
                              : "AWAITING COMMAND"
                        font.family:    "JetBrains Mono"
                        font.pixelSize: 11
                        font.weight:    Font.SemiBold
                        font.letterSpacing: 5.5
                        color: root.authState === "error" ? "#FFB4AB" : "#8E9192"
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            // -- [8] Password Input Field -------------------------------------
            ColumnLayout {
                spacing: 6
                Layout.fillWidth: true
                Layout.bottomMargin: 32

                // Terminal-style input row
                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 400
                    height: 44
                    color: Qt.rgba(0.027, 0.027, 0.027, 0.4)
                    // Bottom border only — mimic CSS border-b
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 1
                        color: passwordField.activeFocus ? "#A6C8FF" : "#444748"
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Prompt glyph
                        Text {
                            text: ">"
                            font.family:    "JetBrains Mono"
                            font.pixelSize: 14
                            font.weight:    Font.Medium
                            color: "#A6C8FF"
                            Layout.leftMargin: 8
                        }

                        // Password text input
                        Controls.TextField {
                            id: passwordField
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            echoMode:        TextInput.Password
                            passwordCharacter: "●"
                            placeholderText: "ENTER AUTH CODE"
                            font.family:     "JetBrains Mono"
                            font.pixelSize:  12
                            font.letterSpacing: 2
                            color: "#FFFFFF"
                            placeholderTextColor: Qt.rgba(0.557, 0.569, 0.573, 0.4)

                            background: null   // we draw our own background above
                            leftPadding:  4
                            rightPadding: 0

                            enabled: root.authState !== "authenticating" &&
                                     root.authState !== "success"

                            Component.onCompleted: forceActiveFocus()

                            onAccepted: root.attemptAuth(text)

                            // Clear error state on new input
                            onTextChanged: {
                                if (root.authState === "error") root.authState = "input"
                            }
                        }

                        // Submit arrow button
                        Rectangle {
                            width:  40
                            height: parent.height
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "→"
                                font.family:   "JetBrains Mono"
                                font.pixelSize: 16
                                color: submitHover.containsMouse ? "#A6C8FF" : "#8E9192"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: submitHover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.attemptAuth(passwordField.text)
                            }
                        }
                    }
                }

                // Sub-row: encryption label + switch user
                RowLayout {
                    Layout.maximumWidth: 400

                    Text {
                        text: "Encryption: SHA-256"
                        font.family:    "JetBrains Mono"
                        font.pixelSize: 10
                        font.letterSpacing: 2
                        color: Qt.rgba(0.557, 0.569, 0.573, 0.4)
                        Layout.leftMargin: 4
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Switch User"
                        font.family:    "JetBrains Mono"
                        font.pixelSize: 10
                        font.letterSpacing: 2
                        color: switchHover.containsMouse
                               ? "#A6C8FF"
                               : Qt.rgba(0.651, 0.784, 1.0, 0.4)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: switchHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                // Cycle through sessions / users
                                // Implement user enumeration from /etc/passwd if needed
                            }
                        }
                    }
                }

                // Auth spinner / feedback text
                Text {
                    visible: root.authState === "authenticating"
                    text: "Authenticating..."
                    font.family:    "JetBrains Mono"
                    font.pixelSize: 11
                    font.letterSpacing: 2
                    color: "#A6C8FF"
                    Layout.leftMargin: 4
                    SequentialAnimation on opacity {
                        running: root.authState === "authenticating"
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }
            }

            // -- [9] Large Clock + Date ---------------------------------------
            ColumnLayout {
                spacing: 4
                Layout.bottomMargin: 24

                RowLayout {
                    spacing: 8

                    Text {
                        id: clockTime
                        text: "00:00"
                        font.family:    "JetBrains Mono"
                        font.pixelSize: 120
                        font.weight:    Font.Black
                        font.letterSpacing: -2.4
                        color: "#FFFFFF"
                    }
                    Text {
                        text: "UTC"
                        font.family:    "JetBrains Mono"
                        font.pixelSize: 18
                        font.weight:    Font.SemiBold
                        color: "#A6C8FF"
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 12
                    }
                }

                Text {
                    id: clockDate
                    text: "WEDNESDAY, OCT 25"
                    font.family:    "JetBrains Mono"
                    font.pixelSize: 18
                    font.weight:    Font.SemiBold
                    font.letterSpacing: 3.6
                    color: "#8E9192"
                    Layout.leftMargin: 8
                }
            }

            // -- [10] Status Pill ---------------------------------------------
            Rectangle {
                height: 36
                width:  pillRow.implicitWidth + 32
                color:  Qt.rgba(0.027, 0.027, 0.027, 0.5)
                border.color: Qt.rgba(0.267, 0.278, 0.282, 0.3)
                border.width: 1

                Row {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: root.authState === "error" ? "#FFB4AB" : "#3192FC"
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 700 }
                            NumberAnimation { to: 1.0; duration: 700 }
                        }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: root.authState === "error"
                                  ? "Auth Failed"
                                  : "Docked Command"
                            font.family:    "JetBrains Mono"
                            font.pixelSize: 12
                            font.weight:    Font.Medium
                            font.letterSpacing: 3.6
                            color: root.authState === "error" ? "#FFB4AB" : "#A6C8FF"
                            font.capitalization: Font.AllUppercase
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        // Blinking cursor
                        Rectangle {
                            width: 10; height: 14
                            color: "#3192FC"
                            anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0; duration: 500 }
                                NumberAnimation { to: 1; duration: 500 }
                            }
                        }
                    }
                }
            }
        }
    }

    // -- [11] Footer: Power Actions -------------------------------------------
    Item {
        id: loginFooter
        anchors {
            bottom: parent.bottom
            left:   parent.left
            right:  parent.right
            bottomMargin: 16
            leftMargin:   24
            rightMargin:  24
        }
        height: 36

        opacity: footerHoverArea.containsMouse ? 1.0 : 0.6
        Behavior on opacity { NumberAnimation { duration: 300 } }

        MouseArea {
            id: footerHoverArea
            anchors.fill: parent
            hoverEnabled: true
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 32

            Repeater {
                model: [
                    { label: "RESTART",   cmd: "systemctl reboot",  accent: false },
                    { label: "SUSPEND",   cmd: "systemctl suspend", accent: false },
                    { label: "POWER OFF", cmd: "systemctl poweroff", accent: true }
                ]
                delegate: Item {
                    property bool hov: false
                    implicitWidth:  fl.implicitWidth
                    implicitHeight: 24

                    Text {
                        id: fl
                        text: modelData.label
                        font.family:    "JetBrains Mono"
                        font.pixelSize: 11
                        font.weight:    Font.SemiBold
                        font.letterSpacing: 2
                        color: modelData.accent
                               ? (parent.hov ? "#FFFFFF" : "#A6C8FF")
                               : (parent.hov ? "#A6C8FF" : "#8E9192")
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.hov = true
                        onExited:  parent.hov = false
                        onClicked: {
                            powerCmd.command = ["bash", "-c", modelData.cmd]
                            powerCmd.running = true
                        }
                    }
                }
            }
        }
    }

    // -- [12] Clock Timer -----------------------------------------------------
    Timer {
        interval: 1000
        running:  true
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            clockTime.text = String(now.getHours()).padStart(2, '0') + ":" +
                             String(now.getMinutes()).padStart(2, '0')
            var days   = ["SUNDAY","MONDAY","TUESDAY","WEDNESDAY","THURSDAY","FRIDAY","SATURDAY"]
            var months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
            clockDate.text = days[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate()
        }
    }

    // -- [13] Auth Process (greetd IPC / PAM helper) --------------------------
    //
    // INTEGRATION NOTE:
    //   Replace the command below with your actual greetd IPC call.
    //   Option A — greetd-ipc JSON over unix socket (recommended):
    //     Use a small Python/bash helper that speaks greetd IPC protocol.
    //     See: https://man.sr.ht/~kennylevinsen/greetd/ipc.md
    //
    //   Option B — regreet / tuigreet style: exec tuigreet in a child process.
    //
    //   Option C — PAM via su/unix helper for testing:
    //     command: ["bash", "-c", "echo '" + pw + "' | su -c exit " + user + " 2>&1; echo $?"]
    //
    //   The example below uses a placeholder greet-helper script you create at:
    //     /usr/local/bin/obsidian-greet
    //   It should return exit code 0 on success, 1 on failure.
    // -------------------------------------------------------------------------

    Process {
        id: authProcess

        // Stdout/stderr captured for debug; not displayed
        stdout: SplitParser {
            onRead: data => console.log("[auth]", data)
        }

        onRunningChanged: {
            if (!running) {
                // exitCode 0 = success
                if (exitCode === 0) {
                    root.authState = "success"
                    startSession()
                } else {
                    root.authState = "error"
                    passwordField.text = ""
                    passwordField.forceActiveFocus()
                    errorShake.start()
                }
            }
        }
    }

    // Session start after successful auth
    Process {
        id: sessionProcess
    }

    Process {
        id: powerCmd
    }

    // -- [14] Auth trigger & helpers ------------------------------------------
    function attemptAuth(password) {
        if (password.length === 0) return
        if (root.authState === "authenticating") return

        root.authState = "authenticating"

        // Replace this command with your greetd helper
        // The helper receives USER, SESSION, PASSWORD via env vars for safety
        authProcess.environment = {
            "GREET_USER":     root.userName,
            "GREET_SESSION":  root.sessionCmd,
            "GREET_PASSWORD": password
        }
        authProcess.command = ["/usr/local/bin/obsidian-greet"]
        authProcess.running = true
    }

    function startSession() {
        // After greetd auth succeeds, greetd itself starts the session.
        // If using PAM directly, exec the session here:
        sessionProcess.command = [root.sessionCmd]
        sessionProcess.running = true
    }

    // Shake animation on auth error
    SequentialAnimation {
        id: errorShake
        NumberAnimation { target: passwordField.parent; property: "x"; to: -8;  duration: 50 }
        NumberAnimation { target: passwordField.parent; property: "x"; to:  8;  duration: 50 }
        NumberAnimation { target: passwordField.parent; property: "x"; to: -6;  duration: 50 }
        NumberAnimation { target: passwordField.parent; property: "x"; to:  6;  duration: 50 }
        NumberAnimation { target: passwordField.parent; property: "x"; to:  0;  duration: 50 }
    }
}
