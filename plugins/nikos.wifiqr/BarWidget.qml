// =============================================================================
// nikos.wifiqr — share the active Wi-Fi as a scannable QR (plugin api 1)
// =============================================================================
// Pill hidden until an active Wi-Fi connection exists. Click toggles a panel
// rendering the QR matrix (white card, dark modules) built by qrencode from
// NetworkManager's connection secrets. Security chip + SSID shown.
// Requires: qrencode + nmcli (see manifest.commands).
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "file:///home/nikos/.config/quickshell/bar/components" as Host
import qs.Commons
import qs.Ui

Item {
    id: root

    property string pluginId: ""
    property var api: null

    readonly property bool hot: mouseArea.containsMouse
    readonly property bool expanded: mouseArea.containsMouse

    // ── state ────────────────────────────────────────────────────────────────
    property bool hasQr: false
    property string errorText: ""
    property string ssid: ""
    property string security: ""
    property string password: ""
    property var matrix: []            // array of "10100…" strings
    readonly property int modulePx: 5
    readonly property int quiet: 3

    function toggle() { panel.toggle() }
    function open()   { panel.open() }
    function close()  { panel.close() }

    Host.PluginPanel {
        id: panel
        pluginId: "nikos.wifiqr"
        title: "WI-FI QR"
        icon: "󰀄"
        contentWidth: 280

        // ── body ──
        Column {
            Layout.fillWidth: true
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.ssid !== "" ? root.ssid : "—"
                font.family: "monospace"; font.pixelSize: 14; font.bold: true
                color: Theme.colors.text
            }

            // QR matrix card — white ground, dark modules (scanner contract)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.matrix.length > 0 ? root.matrix[0].length * root.modulePx + root.quiet * 2 * root.modulePx : 0
                height: root.matrix.length > 0 ? root.matrix.length * root.modulePx + root.quiet * 2 * root.modulePx : 0
                color: "#ffffff"
                radius: 4

                Grid {
                    anchors.centerIn: parent
                    columns: root.matrix.length > 0 ? root.matrix[0].length : 0
                    spacing: 0
                    visible: root.matrix.length > 0

                    Repeater {
                        model: root.matrix.length > 0 ? root.matrix[0].length * root.matrix.length : 0

                        Rectangle {
                            readonly property int row: Math.floor(index / (root.matrix.length > 0 ? root.matrix[0].length : 1))
                            readonly property int col: index % (root.matrix.length > 0 ? root.matrix[0].length : 1)
                            readonly property bool dark: {
                                if (root.matrix.length === 0 || row >= root.matrix.length) return false
                                var line = root.matrix[row] || ""
                                return col < line.length && line.charAt(col) === "1"
                            }
                            width: root.modulePx; height: root.modulePx
                            color: dark ? "#1a1a1a" : "#ffffff"
                        }
                    }
                }
            }

            // Error / status
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.errorText !== ""
                text: root.errorText
                font.family: "monospace"; font.pixelSize: 9
                color: Theme.colors.error
                wrapMode: Text.Wrap
                width: parent.width
            }

            // Security chip
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Rectangle {
                    width: secLbl.implicitWidth + 12; height: 18; radius: 3
                    color: Qt.rgba(Theme.colors.primary.r, Theme.colors.primary.g, Theme.colors.primary.b, 0.15)
                    border.color: Theme.colors.primary; border.width: 1
                    Text { id: secLbl; anchors.centerIn: parent
                        text: root.security !== "" ? root.security : "OPEN"
                        font.family: "monospace"; font.pixelSize: 8; font.bold: true
                        color: Theme.colors.primary }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.password !== "" ? "P:" + root.password : ""
                    font.family: "monospace"; font.pixelSize: 9
                    color: Theme.colors.textDim
                }
            }
        }

        // ── service: nmcli → payload → qrencode matrix ──
        Process {
            id: qrProc
            command: []
            property string buffer: ""
            stdout: SplitParser { onRead: function(d) { qrProc.buffer += d + "\n" } }
            onRunningChanged: {
                if (running) return
                var raw = qrProc.buffer
                qrProc.buffer = ""
                root.matrix = []
                root.ssid = ""; root.security = ""; root.password = ""
                if (raw.indexOf("No active Wi-Fi") !== -1 || raw.trim() === "") {
                    root.errorText = raw.trim() !== "" ? raw.trim().split("\n")[0] : "no active wi-fi"
                    return
                }
                var meta = ""
                var rows = []
                raw.split("\n").forEach(function(line) {
                    if (line.indexOf("meta\t") === 0) {
                        var f = line.split("\t")
                        root.ssid = f[2] || ""; root.security = f[1] || ""
                    } else if (line !== "") rows.push(line)
                })
                root.matrix = rows
                if (rows.length === 0) root.errorText = "could not generate QR"
            }
        }

        function refreshQr() {
            qrProc.command = ["bash", "-c",
                "iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"dev\"){print $(i+1);exit}}'); " +
                "[ -z \"$iface\" ] && iface=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2==\"wifi\" && $3 ~ /^connected/{print $1;exit}'); " +
                "[ -z \"$iface\" ] && echo 'No active Wi-Fi connection' && exit 0; " +
                "uuid=$(nmcli --get-values GENERAL.CON-UUID device show \"$iface\" | head -n1); " +
                "mapfile -t fl < <(nmcli --show-secrets --escape no --get-values " +
                "802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,802-11-wireless.hidden connection show uuid \"$uuid\"); " +
                "ssid=${fl[0]}; km=${fl[1]}; pw=${fl[2]}; hidden=${fl[3]}; " +
                "[ -z \"$ssid\" ] && echo 'Could not read the Wi-Fi name' && exit 0; " +
                "sec=nopass; [ -n \"$km\" ] && [ \"$km\" != none ] && sec=WPA; " +
                "payload=\"WIFI:T:$sec;S:$ssid;P:$pw;\"; " +
                "qrencode --type ASCII --margin 4 --output - <<< \"$payload\" | " +
                "awk '{r=\"\";for(c=1;c<=length($0);c+=2) r =r (substr($0,c,2) ~ /#/ ? 1 : 0); print r}'"]
            qrProc.running = true
        }

        onOpenedChanged: if (opened) refreshQr()
    }

    // ── bar pill ──────────────────────────────────────────────────────────────
    implicitWidth: iconText.implicitWidth + 8
    height: api ? api.bar.barHeight : 30
    visible: true
    clip: true

    Text {
        id: iconText
        anchors.centerIn: parent
        text: "󰀄"
        font.family: api ? api.bar.fontNerd : "monospace"
        font.pixelSize: api ? api.bar.fontSizeIcon : 13
        color: root.hot ? "#7DCFFF" : (api ? api.theme.colors.success : "#888")
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: panel.toggle()
    }
}
