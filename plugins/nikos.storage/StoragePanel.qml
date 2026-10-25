// =============================================================================
// nikos.storage — storage popup body ("STORAGE", upstream-Ryoku adaptation)
// =============================================================================
// Adaptation of Ryoku's qsbar StoragePanel (user-provided photo) to this
// bar's design language (theme tokens, hairline cards):
//   ┌─ ROOT ──────────────────────── 43% ─┐
//   │  ▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░  │
//   │  USED 400.0GiB  FREE 530.5GiB  …    │
//   ├─ DRIVES ─────────────────── 3 DEVICES┤
//   │ 󰢮 Samsung SSD 990 PRO 1TB     1.0 TB │
//   │  NVME SSD · BTRFS · /                │
//   │  USAGE  ▓▓▓▓░░░░░░░░░░░░░  43%       │
//   │  USED 400.0GiB  FREE 530.5GiB  …     │
//   └──────────────────────────────────────┘
// Card chrome is transparent + 1px hairline (QD-OLED: no bright static
// fills); the usage bars are ephemeral-popup content — the sanctioned
// filled-shape place — with a near-invisible track and an accent fill.
// Data: the plugin's StorageService singleton (one lsblk probe, open-gated);
// pure parsing lives in lib/storage.mjs (node-tested).
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "lib/storage.mjs" as St
import "." as Storage

ColumnLayout {
    id: stRoot

    property var ctx: null

    spacing: 12

    readonly property var _drives: Storage.StorageService.drives
    readonly property var _root: Storage.StorageService.rootDrive

    component Card: Rectangle {
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: stRoot.ctx ? stRoot.ctx.theme.withAlpha(stRoot.ctx.theme.colors.text, 0.14) : "#222"
    }

    // Track + fill usage bar (ephemeral popup: filled shapes allowed here;
    // the track stays near-invisible and the fill rides the accent token).
    component UsageBar: Rectangle {
        id: ub
        property real pct: 0
        height: 8
        radius: 4
        color: stRoot.ctx ? stRoot.ctx.theme.withAlpha(stRoot.ctx.theme.colors.text, 0.10) : "#111"

        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, ub.pct)) / 100
            height: parent.height
            radius: 4
            color: stRoot.ctx ? stRoot.ctx.theme.colors.accent : "#0ff"
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }

    // USED / FREE / TOTAL — three label-over-value columns.
    component MetricRow: Row {
        id: mr
        property string used: ""
        property string free: ""
        property string total: ""
        width: parent ? parent.width : 0

        Repeater {
            model: [
                { l: "USED",  v: mr.used },
                { l: "FREE",  v: mr.free },
                { l: "TOTAL", v: mr.total }
            ]
            delegate: Column {
                width: mr.width / 3
                spacing: 2
                Text {
                    text: modelData.l
                    color: stRoot.ctx ? stRoot.ctx.theme.colors.textDim : "#666"
                    font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
                    font.pixelSize: 8; font.letterSpacing: 1
                }
                Text {
                    text: modelData.v
                    color: stRoot.ctx ? stRoot.ctx.theme.colors.text : "#ddd"
                    font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
                    font.pixelSize: 10
                }
            }
        }
    }

    // ── ROOT filesystem card ─────────────────────────────────────────────────
    Card {
        Layout.fillWidth: true
        Layout.preferredHeight: 84
        visible: stRoot._root !== null

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 14
            anchors.bottomMargin: 14
            spacing: 10

            Item {
                Layout.fillWidth: true
                height: 16

                Text {
                    id: rootLbl
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ROOT"
                    color: stRoot.ctx ? stRoot.ctx.theme.colors.textDim : "#666"
                    font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
                    font.pixelSize: 10; font.letterSpacing: 1.5
                }
                Text {
                    id: rootPct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Storage.StorageService.percent >= 0 ? Storage.StorageService.percent + "%" : ""
                    color: stRoot.ctx ? stRoot.ctx.theme.colors.text : "#ddd"
                    font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
                    font.pixelSize: 11; font.weight: Font.DemiBold
                }
                UsageBar {
                    anchors.left: rootLbl.right
                    anchors.leftMargin: 10
                    anchors.right: rootPct.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    pct: Storage.StorageService.percent
                }
            }

            MetricRow {
                Layout.fillWidth: true
                used: St.formatGiB(Storage.StorageService.usedBytes)
                free: St.formatGiB(Storage.StorageService.freeBytes)
                total: St.formatGiB(Storage.StorageService.totalBytes)
            }
        }
    }

    // ── DRIVES header ────────────────────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        height: 16
        visible: stRoot._drives.length > 0

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "DRIVES"
            color: stRoot.ctx ? stRoot.ctx.theme.colors.textDim : "#666"
            font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
            font.pixelSize: 10; font.letterSpacing: 1.5
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: stRoot._drives.length + (stRoot._drives.length === 1 ? " DEVICE" : " DEVICES")
            color: stRoot.ctx ? stRoot.ctx.theme.colors.textDim : "#666"
            font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
            font.pixelSize: 8; font.letterSpacing: 1
        }
    }

    // ── per-drive rows ───────────────────────────────────────────────────────
    Repeater {
        model: stRoot._drives

        delegate: Card {
            property var drive: modelData

            Layout.fillWidth: true
            Layout.preferredHeight: driveCol.height + 24

            Column {
                id: driveCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 5

                // 󰢮 model …… 1.0 TB
                Item {
                    width: parent.width
                    height: 20

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: St.nerdFor(drive.driveType)
                        color: stRoot.ctx ? stRoot.ctx.theme.colors.accent : "#0ff"
                        font.family: stRoot.ctx ? stRoot.ctx.bar.fontNerd : "monospace"
                        font.pixelSize: 14
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.right: capText.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: drive.model
                        color: stRoot.ctx ? stRoot.ctx.theme.colors.text : "#ddd"
                        font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    Text {
                        id: capText
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: St.formatBytes(drive.size)
                        color: stRoot.ctx ? stRoot.ctx.theme.colors.text : "#ddd"
                        font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 11; font.weight: Font.DemiBold
                    }
                }

                // NVME SSD · BTRFS · /  (or  NO FILESYSTEM)
                Text {
                    width: parent.width
                    text: drive.media
                          + (drive.fileSystems !== "" ? " · " + drive.fileSystems : "")
                          + " · " + drive.state
                    color: stRoot.ctx ? stRoot.ctx.theme.colors.textDim : "#666"
                    font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
                    font.pixelSize: 9
                    elide: Text.ElideMiddle
                }

                // USAGE ▓▓▓▓░░░░ 43% — only for mounted-with-usage drives
                Item {
                    width: parent.width
                    height: 16
                    visible: drive.percent >= 0

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "USAGE"
                        color: stRoot.ctx ? stRoot.ctx.theme.colors.textDim : "#666"
                        font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 8; font.letterSpacing: 1
                    }
                    Text {
                        id: drivePct
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: drive.percent + "%"
                        color: stRoot.ctx ? stRoot.ctx.theme.colors.text : "#ddd"
                        font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
                        font.pixelSize: 9; font.weight: Font.DemiBold
                    }
                    UsageBar {
                        anchors.left: parent.left
                        anchors.leftMargin: 52
                        anchors.right: drivePct.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        pct: drive.percent
                    }
                }

                MetricRow {
                    width: parent.width
                    visible: drive.totalBytes > 0
                    used: St.formatGiB(drive.usedBytes)
                    free: St.formatGiB(drive.freeBytes)
                    total: St.formatGiB(drive.totalBytes)
                }
            }
        }
    }

    // ── loading / empty states ───────────────────────────────────────────────
    Text {
        Layout.fillWidth: true
        visible: !Storage.StorageService.available
        horizontalAlignment: Text.AlignHCenter
        text: "READING DRIVE INFORMATION …"
        color: stRoot.ctx ? stRoot.ctx.theme.colors.textDim : "#666"
        font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
        font.pixelSize: 10; font.letterSpacing: 1.5
    }
    Text {
        Layout.fillWidth: true
        visible: Storage.StorageService.available && stRoot._drives.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: "NO PHYSICAL DRIVES FOUND"
        color: stRoot.ctx ? stRoot.ctx.theme.colors.textDim : "#666"
        font.family: stRoot.ctx ? stRoot.ctx.bar.fontFamily : "monospace"
        font.pixelSize: 10; font.letterSpacing: 1.5
    }
}
