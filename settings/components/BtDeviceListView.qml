// =============================================================================
// BtDeviceListView.qml — BLUETOOTH section view (viewport-fit, NO SCROLLING)
// =============================================================================
// Fixed composition per SKILL.md §6.1:
//   header row (badge · counts · RESCAN)
//   body = left summary column (ADAPTER card) | right column:
//          PAIRED DEVICES (fixed, clamped) over AVAILABLE DEVICES (fills,
//          clamped). Rows show visible-of-total; priority = connected first.
//
// Backed by Services.BluetoothControlService (native BlueZ). All colours are
// live ThemeConfig tokens. Scan/pair/connect/disconnect logic unchanged.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: view
    spacing: Config.ControlConfig.space3

    // Paired nodes feed the right-top card; everything else (scan beacons)
    // feeds the right-bottom card. Re-evaluate when `devices` changes.
    readonly property var pairedDevs: Services.BluetoothControlService.devices.filter(function(d){ return d.paired })
    readonly property var beaconDevs: Services.BluetoothControlService.devices.filter(function(d){ return !d.paired })

    // Priority order for the visible capacity: connected first, then rssi desc.
    readonly property var sortedPaired: {
        var arr = view.pairedDevs.slice(0)
        arr.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            return (b.rssi || 0) - (a.rssi || 0)
        })
        return arr
    }
    readonly property var sortedBeacons: {
        var arr = view.beaconDevs.slice(0)
        arr.sort(function(a, b) { return (b.rssi || 0) - (a.rssi || 0) })
        return arr
    }

    // First connected device that reports a battery (drives the status card bar).
    readonly property var connBatDev: {
        var ds = Services.BluetoothControlService.devices
        for (var i = 0; i < ds.length; i++) {
            if (ds[i].connected && ds[i].battery >= 0) return ds[i]
        }
        return null
    }

    // Label/value stat cell — used by the adapter info grid.
    component Stat: ColumnLayout {
        property string label: ""
        property string value: "—"
        spacing: 2
        Text {
            text: parent.label
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8
            color: Config.ThemeConfig.colors.textDim
        }
        Text {
            Layout.fillWidth: true
            text: parent.value
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
            color: Config.ThemeConfig.colors.text
            elide: Text.ElideRight
        }
    }

    // =========================================================================
    // 1. HEADER ROW
    // =========================================================================
    SectionHeader {
        Layout.fillWidth: true
        title: "BLUETOOTH"

        StatusBadge {
            Layout.alignment: Qt.AlignVCenter
            label: Services.BluetoothControlService.powered ? "POWERED" : "OFFLINE"
            kind: Services.BluetoothControlService.powered ? "ok" : "err"
        }

        Item { Layout.fillWidth: true }

        Text {
            visible: !Services.BluetoothControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: view.pairedDevs.length + " paired · " + view.beaconDevs.length + " beacons"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }

        Text {
            visible: Services.BluetoothControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: "scan " + Services.BluetoothControlService.scanSecondsLeft + "s"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
            color: Config.ControlConfig.accent
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: rescanLbl.implicitWidth + 20; height: 24
            radius: Config.ControlConfig.radiusPill
            color: rescanMA.containsMouse && Services.BluetoothControlService.powered && !Services.BluetoothControlService.scanning
                   ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16) : "transparent"
            border.color: (!Services.BluetoothControlService.powered || Services.BluetoothControlService.scanning)
                          ? Config.ThemeConfig.colors.outlineVariant : Config.ControlConfig.accent
            border.width: 1
            opacity: (!Services.BluetoothControlService.powered || Services.BluetoothControlService.scanning) ? 0.5 : 1.0
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
                id: rescanLbl; anchors.centerIn: parent
                text: "RESCAN"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: Config.ControlConfig.accent
            }
            MouseArea {
                id: rescanMA; anchors.fill: parent; hoverEnabled: true
                cursorShape: (!Services.BluetoothControlService.powered || Services.BluetoothControlService.scanning)
                             ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: if (Services.BluetoothControlService.powered && !Services.BluetoothControlService.scanning)
                               Services.BluetoothControlService.scanDevices()
            }
        }
    }

    // =========================================================================
    // 2. BODY — summary column | paired/available lists (viewport-fit)
    // =========================================================================
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Config.ControlConfig.space3

        // ── Left: adapter summary ─────────────────────────────────────────────
        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.maximumWidth: 340
            Layout.fillHeight: true
            spacing: Config.ControlConfig.space3

            SettingsCard {
                Layout.fillWidth: true
                accent: Config.ThemeConfig.colors.primary

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.ControlConfig.space2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "ADAPTER"
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                            color: Config.ThemeConfig.colors.textDim
                        }
                        Item { Layout.fillWidth: true }
                        PowerPill {
                            Layout.alignment: Qt.AlignVCenter
                            on: Services.BluetoothControlService.powered
                            onClicked: Services.BluetoothControlService.togglePower()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Services.BluetoothControlService.powered
                              ? (Services.BluetoothControlService.adapterAlias
                                 || Services.BluetoothControlService.adapterAddress
                                 || "READY")
                              : "NO ACTIVE ADAPTER"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 18; font.bold: true
                        color: Services.BluetoothControlService.powered
                               ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    // 4-cell info grid: STATE · ADAPTER · VERSION · DEVICES
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "STATE";   value: Services.BluetoothControlService.powered ? "POWERED" : "DOWN" }
                        Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "VERSION"; value: Services.BluetoothControlService.adapterVersion || "—" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "ADAPTER"; value: Services.BluetoothControlService.adapterAddress || "—" }
                        Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "DEVICES";  value: Services.BluetoothControlService.devices.length }
                    }

                    // Connected-device battery bar (first connected dev with a battery)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: view.connBatDev !== null
                        spacing: 8
                        Text {
                            text: "BAT"
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8
                            color: Config.ThemeConfig.colors.textDim
                        }
                        Text {
                            text: view.connBatDev ? (view.connBatDev.battery + "%") : ""
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                            color: view.connBatDev && view.connBatDev.battery < 20
                                   ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.text
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 4; radius: 2
                            color: Config.ThemeConfig.colors.border
                            Rectangle {
                                height: 4; radius: 2
                                width: parent.width * (view.connBatDev ? view.connBatDev.battery : 0) / 100
                                color: (view.connBatDev && view.connBatDev.battery < 20)
                                       ? Config.ThemeConfig.colors.error : Config.ControlConfig.accent
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // ── Right: paired (fixed, clamped) + available (fills, clamped) ──────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Config.ControlConfig.space3

            // PAIRED DEVICES — up to 4 rows, then a hidden-count footer
            SettingsCard {
                Layout.fillWidth: true
                accent: Config.ThemeConfig.colors.primary
                contentSpacing: 0

                readonly property int cap: Math.max(1, Math.floor(pairedViewport.height / 40))
                readonly property var shown: view.sortedPaired.slice(0, cap)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.topMargin: 2
                        spacing: 6
                        Text {
                            text: "PAIRED DEVICES"
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                            color: Config.ThemeConfig.colors.text
                        }
                        Text {
                            text: view.pairedDevs.length > 0
                                  ? (shown.length + " / " + view.pairedDevs.length) : "0"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                            color: shown.length < view.pairedDevs.length
                                   ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.primary
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.25) }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10; Layout.rightMargin: 6
                        spacing: 8
                        Item { Layout.preferredWidth: 26 }
                        Text { text: "NAME";   Layout.fillWidth: true;  font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                        Text { text: "SIGNAL"; Layout.preferredWidth: 66; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                        Text { text: "STATE";  Layout.preferredWidth: 70; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                        Text { text: "ACTION"; Layout.preferredWidth: 80; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                        Item { Layout.preferredWidth: 16 }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    Item {
                        id: pairedViewport
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(view.sortedPaired.length, 4) * 40
                        clip: true

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            Repeater {
                                model: shown
                                delegate: BtDeviceRow { width: parent.width; dev: modelData; beacon: false }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: view.pairedDevs.length === 0 && !Services.BluetoothControlService.scanning
                            text: "// no paired devices — pair from AVAILABLE below"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                            color: Config.ThemeConfig.colors.textDim
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: shown.length < view.pairedDevs.length
                        Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.bottomMargin: 2
                        text: "+ " + (view.pairedDevs.length - shown.length) + " more paired hidden"
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight
                    }
                }
            }

            // AVAILABLE DEVICES — fills the remaining height, rows clamped
            SettingsCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                accent: Config.ThemeConfig.colors.secondary
                contentSpacing: 0

                readonly property int cap: Math.max(1, Math.floor(beaconViewport.height / 40))
                readonly property var shown: view.sortedBeacons.slice(0, cap)

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.topMargin: 2
                        spacing: 6
                        Text {
                            text: "AVAILABLE DEVICES"
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                            color: Config.ThemeConfig.colors.text
                        }
                        Text {
                            text: view.beaconDevs.length > 0
                                  ? (shown.length + " / " + view.beaconDevs.length) : "0"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                            color: shown.length < view.beaconDevs.length
                                   ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.secondary
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.25) }
                        Text {
                            visible: Services.BluetoothControlService.scanning
                            text: "●"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                            color: Config.ControlConfig.accent
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10; Layout.rightMargin: 6
                        spacing: 8
                        Item { Layout.preferredWidth: 26 }
                        Text { text: "NAME";   Layout.fillWidth: true;  font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                        Text { text: "SIGNAL"; Layout.preferredWidth: 66; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                        Text { text: "STATE";  Layout.preferredWidth: 70; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                        Text { text: "ACTION"; Layout.preferredWidth: 80; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                        Item { Layout.preferredWidth: 16 }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    Item {
                        id: beaconViewport
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            Repeater {
                                model: shown
                                delegate: BtDeviceRow { width: parent.width; dev: modelData; beacon: true }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: view.beaconDevs.length === 0 && Services.BluetoothControlService.scanning
                            text: "// scanning for nearby devices…"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                            color: Config.ControlConfig.accent
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: view.beaconDevs.length === 0 && !Services.BluetoothControlService.scanning
                            text: "// no devices found — press RESCAN to scan nearby devices"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                            color: Config.ThemeConfig.colors.textDim
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: shown.length < view.beaconDevs.length
                        Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.bottomMargin: 2
                        text: "+ " + (view.beaconDevs.length - shown.length) + " more nearby hidden"
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
