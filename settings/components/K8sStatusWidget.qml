// =============================================================================
// K8sStatusWidget.qml — k3s cluster status card (display-only)
// =============================================================================
//
// Polls `systemctl is-active k3s` every 10s. When active, also polls node
// and pod counts via kubectl. No start/stop control here on purpose —
// start/stop the cluster manually: `sudo systemctl start|stop k3s`.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config
import "." as Components

Item {
    id: k8sRoot

    property string serviceState: "unknown"   // active | inactive | unknown
    property int    nodesReady:   0
    property int    nodesTotal:   0
    property int    podsRunning:  0

    readonly property bool isActive: serviceState === "active"

    function refresh() {
        systemctlStatus.running = true
        if (isActive) {
            nodesProc.running = true
            podsProc.running = true
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: k8sRoot.refresh()
    }

    // -------------------------------------------------------------------
    // systemctl is-active k3s
    // -------------------------------------------------------------------
    Process {
        id: systemctlStatus
        command: ["systemctl", "is-active", "k3s"]
        stdout: SplitParser {
            onRead: function(line) {
                stateParseTimer.pending = line.trim()
                stateParseTimer.restart()
            }
        }
        // is-active exits non-zero for "inactive" — still need the stdout line,
        // Process keeps delivering stdout regardless of exit code.
    }
    Timer {
        id: stateParseTimer
        interval: 50
        property string pending: ""
        onTriggered: k8sRoot.serviceState = pending.length ? pending : "inactive"
    }

    // -------------------------------------------------------------------
    // kubectl get nodes — collect "Ready"/"NotReady" tokens, count on timer
    // -------------------------------------------------------------------
    Process {
        id: nodesProc
        command: ["bash", "-c", "kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}'"]
        stdout: SplitParser {
            onRead: function(line) {
                nodesParseTimer.lines.push(line.trim())
                nodesParseTimer.restart()
            }
        }
    }
    Timer {
        id: nodesParseTimer
        interval: 50
        property var lines: []
        onTriggered: {
            k8sRoot.nodesTotal = lines.length
            k8sRoot.nodesReady = lines.filter(function(l) { return l.indexOf("Ready") === 0 }).length
            lines = []
        }
    }

    // -------------------------------------------------------------------
    // kubectl get pods -A — running count
    // -------------------------------------------------------------------
    Process {
        id: podsProc
        command: ["bash", "-c", "kubectl get pods -A --no-headers 2>/dev/null | grep -c Running"]
        stdout: SplitParser {
            onRead: function(line) {
                k8sRoot.podsRunning = parseInt(line.trim()) || 0
            }
        }
    }

    // -------------------------------------------------------------------
    // Start / stop was removed — sudo from a non-interactive Process is
    // fragile (TTY/sudoers issues). Start/stop the cluster manually with
    // `sudo systemctl start|stop k3s`; this card just reflects status.
    // -------------------------------------------------------------------

    // =====================================================================
    // LAYOUT
    // =====================================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 0

        Components.WidgetHeader {
            icon: "󱃾"
            label: "KUBERNETES"
            Layout.bottomMargin: 15
        }

        // Status row
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 18
            spacing: 8

            Rectangle {
                width: 6; height: 6; radius: 0
                color: k8sRoot.isActive ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
            }
            Text {
                text: k8sRoot.isActive ? "RUNNING" : "STOPPED"
                color: k8sRoot.isActive ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
                font.pixelSize: 11
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.0
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "k3s"
                color: Config.ThemeConfig.colors.textDim
                opacity: 0.5
                font.pixelSize: 10
                font.family: Config.SettingsConfig.fontFamily
            }
        }

        // Node / pod counts — only meaningful once the cluster is up
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            visible: k8sRoot.isActive
            Text {
                text: "NODES"
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 9
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.2
                Layout.preferredWidth: 70
            }
            Text {
                text: k8sRoot.nodesReady + "/" + k8sRoot.nodesTotal + " READY"
                color: Config.ThemeConfig.colors.primary
                font.pixelSize: 11
                font.family: Config.SettingsConfig.fontFamily
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 18
            visible: k8sRoot.isActive
            Text {
                text: "PODS"
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 9
                font.bold: true
                font.family: Config.SettingsConfig.fontFamily
                font.letterSpacing: 1.2
                Layout.preferredWidth: 70
            }
            Text {
                text: k8sRoot.podsRunning + " RUNNING"
                color: Config.ThemeConfig.colors.primary
                font.pixelSize: 11
                font.family: Config.SettingsConfig.fontFamily
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            text: "manual control: sudo systemctl start|stop k3s"
            color: Config.ThemeConfig.colors.textDim
            opacity: 0.4
            font.pixelSize: 9
            font.family: Config.SettingsConfig.fontFamily
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
