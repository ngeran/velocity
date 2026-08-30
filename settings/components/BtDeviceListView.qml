// =============================================================================
// BtDeviceListView.qml — BLUETOOTH section view (tactical HUD)
// =============================================================================
// Mirrors WifiListView.qml's structure (Column shell, HUD header, HudCard
// sections, column-header geometry pinned to the row, empty states).
// Stack (scrolls with the parent Flickable, ~440px wide):
//   1. Header         — title + power-state pill + count/scan countdown + RESCAN
//   2. Status card    — HudCard: adapter alias + STATE/ADAPTER/VERSION/DEVICES
//                       grid + (offline) POWER ON + (connected) battery bar
//   3. PAIRED_NODES   — HudCard: NAME | SIGNAL | STATE | ACTION + rows
//   4. AVAIL_BEACONS  — HudCard: same geometry, scan-discovered beacons
//
// Backed by Services.BluetoothControlService (bluetoothctl). All colours are
// live ThemeConfig tokens (no hardcoded rgba).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Column {
    id: view
    width: parent ? parent.width : 400
    spacing: 10

    // -------------------------------------------------------------------------
    // DERIVED ARRAYS — re-evaluate when `devices` changes (the service reassigns
    // a fresh array, so the binding re-runs). Paired nodes feed section 3;
    // everything else (scan beacons) feeds section 4.
    // -------------------------------------------------------------------------
    readonly property var pairedDevs: Services.BluetoothControlService.devices.filter(function(d){ return d.paired })
    readonly property var beaconDevs: Services.BluetoothControlService.devices.filter(function(d){ return !d.paired })

    // First connected device that reports a battery (drives the status card bar).
    readonly property var connBatDev: {
        var ds = Services.BluetoothControlService.devices
        for (var i = 0; i < ds.length; i++) {
            if (ds[i].connected && ds[i].battery >= 0) return ds[i]
        }
        return null
    }

    // Label/value stat cell — used by the 4-cell info grid. Declared at the TOP
    // of the Column (before first use — QML requires inline components to be
    // declared before they're referenced), same pattern as WifiListView.Stat.
    component Stat: ColumnLayout {
        property string label: ""
        property string value: "—"
        spacing: 2
        Text {
            text: parent.label
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
            color: Config.ThemeConfig.colors.textDim
        }
        Text {
            Layout.fillWidth: true
            text: parent.value
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
            color: Config.ThemeConfig.colors.text
            elide: Text.ElideRight
        }
    }

    // =========================================================================
    // 1. HEADER
    // =========================================================================
    RowLayout {
        width: parent.width
        spacing: 8

        Rectangle { width: 3; height: 16; color: Config.ControlConfig.accent; Layout.alignment: Qt.AlignVCenter }

        Text {
            text: "BLUETOOTH"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 13; font.bold: true
            color: Config.ThemeConfig.colors.text
            Layout.alignment: Qt.AlignVCenter
        }

        // Power-state pill
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: stateLbl.implicitWidth + 14; height: 16
            color: Services.BluetoothControlService.powered
                   ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.12)
                   : Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.10)
            border.color: Services.BluetoothControlService.powered ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
            border.width: 1
            Text {
                id: stateLbl; anchors.centerIn: parent
                text: Services.BluetoothControlService.powered ? "● POWERED" : "○ OFFLINE"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                color: Services.BluetoothControlService.powered ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
            }
        }

        Item { Layout.fillWidth: true }

        // Paired/beacon count (idle)
        Text {
            visible: !Services.BluetoothControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: view.pairedDevs.length + " paired · " + view.beaconDevs.length + " beacons"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9
            color: Config.ThemeConfig.colors.textDim
        }

        // Scan countdown (accent)
        Text {
            visible: Services.BluetoothControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: "scan " + Services.BluetoothControlService.scanSecondsLeft + "s"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
            color: Config.ControlConfig.accent
        }

        // RESCAN button — disabled+dimmed when adapter is off or scan is running.
        // Border = accent, hover fill = accent, label inverts to background on
        // hover, opacity 0.5 while disabled (mirrors WifiListView's RESCAN).
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: rescanLbl.implicitWidth + 16; height: 20
            color: rescanMA.containsMouse && Services.BluetoothControlService.powered && !Services.BluetoothControlService.scanning
                   ? Config.ControlConfig.accent : "transparent"
            border.color: (!Services.BluetoothControlService.powered || Services.BluetoothControlService.scanning)
                          ? Config.ThemeConfig.colors.border : Config.ControlConfig.accent
            border.width: 1
            opacity: (!Services.BluetoothControlService.powered || Services.BluetoothControlService.scanning) ? 0.5 : 1.0
            Text {
                id: rescanLbl; anchors.centerIn: parent
                text: "RESCAN"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                color: rescanMA.containsMouse && Services.BluetoothControlService.powered && !Services.BluetoothControlService.scanning
                       ? Config.ThemeConfig.colors.background : Config.ControlConfig.accent
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
    // 2. STATUS CARD
    // =========================================================================
    HudCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.primary

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            // Top row: ADAPTER label + power chip
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "ADAPTER"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                    color: Config.ThemeConfig.colors.textDim
                }
                Item { Layout.fillWidth: true }
                // Power chip
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: pwrChipLbl.implicitWidth + 12; height: 14
                    color: Services.BluetoothControlService.powered
                           ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.12)
                           : Config.ThemeConfig.tint(Config.ThemeConfig.colors.error, 0.10)
                    border.color: Services.BluetoothControlService.powered ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
                    border.width: 1
                    Text {
                        id: pwrChipLbl; anchors.centerIn: parent
                        text: Services.BluetoothControlService.powered ? "ON" : "OFF"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true
                        color: Services.BluetoothControlService.powered ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.error
                    }
                }
            }

            // Big line: adapter alias (or address, or "READY"); NO_ACTIVE_ADAPTER when off.
            Text {
                Layout.fillWidth: true
                text: Services.BluetoothControlService.powered
                      ? (Services.BluetoothControlService.adapterAlias
                         || Services.BluetoothControlService.adapterAddress
                         || "READY")
                      : "NO_ACTIVE_ADAPTER"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 16; font.bold: true
                color: Services.BluetoothControlService.powered
                       ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.textDim
                elide: Text.ElideRight
            }

            // Separator before the info grid
            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

            // 4-cell info grid: STATE · ADAPTER · VERSION · DEVICES
            // (preferredWidth:0 + fillWidth spreads the four cells equally)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "STATE";   value: Services.BluetoothControlService.powered ? "POWERED" : "DOWN" }
                Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "ADAPTER"; value: Services.BluetoothControlService.adapterAddress || "—" }
                Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "VERSION"; value: Services.BluetoothControlService.adapterVersion || "—" }
                Stat { Layout.fillWidth: true; Layout.preferredWidth: 0; label: "DEVICES"; value: Services.BluetoothControlService.devices.length }
            }

            // POWER ON button (only when the adapter is off)
            Rectangle {
                Layout.alignment: Qt.AlignLeft
                width: pwrOnLbl.implicitWidth + 16; height: 20
                visible: !Services.BluetoothControlService.powered
                color: pwrOnMA.containsMouse ? Config.ControlConfig.accent : "transparent"
                border.color: Config.ControlConfig.accent; border.width: 1
                Text {
                    id: pwrOnLbl; anchors.centerIn: parent
                    text: "POWER ON"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                    color: pwrOnMA.containsMouse ? Config.ThemeConfig.colors.background : Config.ControlConfig.accent
                }
                MouseArea {
                    id: pwrOnMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Services.BluetoothControlService.togglePower()
                }
            }

            // Connected-device battery bar (first connected dev with a battery)
            RowLayout {
                Layout.fillWidth: true
                visible: view.connBatDev !== null
                spacing: 6
                Text {
                    text: "BAT"
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
                    color: Config.ThemeConfig.colors.textDim
                }
                Text {
                    text: view.connBatDev ? (view.connBatDev.battery + "%") : ""
                    font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                    color: view.connBatDev && view.connBatDev.battery < 20
                           ? Config.ThemeConfig.colors.error : Config.ThemeConfig.colors.text
                }
                Rectangle {
                    Layout.fillWidth: true; height: 3
                    color: Config.ThemeConfig.colors.border
                    Rectangle {
                        height: 3
                        width: parent.width * (view.connBatDev ? view.connBatDev.battery : 0) / 100
                        color: (view.connBatDev && view.connBatDev.battery < 20)
                               ? Config.ThemeConfig.colors.error : Config.ControlConfig.accent
                    }
                }
            }
        }
    }

    // =========================================================================
    // 3. PAIRED_NODES
    // =========================================================================
    HudCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.primary
        contentSpacing: 0

        // Header label row: title + [ count ] + thin accent line on the right
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "PAIRED_NODES"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                color: Config.ThemeConfig.colors.text
            }
            Text {
                text: "[ " + view.pairedDevs.length + " ]"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true
                color: Config.ThemeConfig.colors.primary
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.25) }
        }

        // Column header — mirrors BtDeviceRow geometry EXACTLY (margins 8/6,
        // spacing 8, icon 22, NAME fill, SIGNAL 60, STATE 70, ACTION 80, × 16)
        // so every column lines up between the header and the rows beneath it.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8; Layout.rightMargin: 6
            spacing: 8
            Item { Layout.preferredWidth: 22 }
            Text { text: "NAME";   Layout.fillWidth: true;  font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Text { text: "SIGNAL"; Layout.preferredWidth: 60; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Text { text: "STATE";  Layout.preferredWidth: 70; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Text { text: "ACTION"; Layout.preferredWidth: 80; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Item { Layout.preferredWidth: 16 }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        // Paired device rows
        Repeater {
            model: view.pairedDevs
            delegate: BtDeviceRow { width: parent.width; dev: modelData; beacon: false }
        }

        // Empty state
        Text {
            Layout.fillWidth: true
            visible: view.pairedDevs.length === 0 && !Services.BluetoothControlService.scanning
            text: "// no paired devices — press RESCAN to scan"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            Layout.topMargin: 8; Layout.bottomMargin: 6
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // =========================================================================
    // 4. AVAIL_BEACONS
    // =========================================================================
    HudCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.secondary
        contentSpacing: 0

        // Header: title + accent scan dot (while scanning)
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "AVAIL_BEACONS"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                color: Config.ThemeConfig.colors.text
            }
            Text {
                visible: Services.BluetoothControlService.scanning
                text: "●"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: Config.ControlConfig.accent
            }
            Item { Layout.fillWidth: true }
        }

        // Column header — SAME pinned geometry as section 3.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8; Layout.rightMargin: 6
            spacing: 8
            Item { Layout.preferredWidth: 22 }
            Text { text: "NAME";   Layout.fillWidth: true;  font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Text { text: "SIGNAL"; Layout.preferredWidth: 60; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Text { text: "STATE";  Layout.preferredWidth: 70; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Text { text: "ACTION"; Layout.preferredWidth: 80; font.family: Config.ControlConfig.fontMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; color: Config.ThemeConfig.colors.textDim }
            Item { Layout.preferredWidth: 16 }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

        // Beacon rows (scan-discovered, unpaired)
        Repeater {
            model: view.beaconDevs
            delegate: BtDeviceRow { width: parent.width; dev: modelData; beacon: true }
        }

        // Empty state — scanning
        Text {
            Layout.fillWidth: true
            visible: view.beaconDevs.length === 0 && Services.BluetoothControlService.scanning
            text: "// scanning for nearby devices…"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ControlConfig.accent
            Layout.topMargin: 8; Layout.bottomMargin: 6
            horizontalAlignment: Text.AlignHCenter
        }

        // Empty state — idle, no beacons
        Text {
            Layout.fillWidth: true
            visible: view.beaconDevs.length === 0 && !Services.BluetoothControlService.scanning
            text: "// no devices found — press RESCAN to scan nearby devices"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
            Layout.topMargin: 8; Layout.bottomMargin: 6
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // -------------------------------------------------------------------------
    // Inline label/value stat cell (used by the status card info grid)
    // -------------------------------------------------------------------------
}
