// =============================================================================
// BtDeviceListView.qml — BLUETOOTH section view (tactical HUD)
// =============================================================================
// Mirrors WifiListView.qml's structure (Column shell, HUD header, HudCard
// sections, column-header geometry pinned to the row, empty states).
// Stack (scrolls with the parent Flickable, ~440px wide):
//   1. Header         — title + power-state pill + count/scan countdown + RESCAN
//   2. Status card    — HudCard: adapter alias + STATE/ADAPTER/VERSION/DEVICES
//                       grid + power pill toggle + (connected) battery bar
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
    spacing: Config.ControlConfig.space4

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
    // 1. HEADER
    // =========================================================================
    SectionHeader {
        title: "BLUETOOTH"

        // Power-state badge
        StatusBadge {
            Layout.alignment: Qt.AlignVCenter
            label: Services.BluetoothControlService.powered ? "POWERED" : "OFFLINE"
            kind: Services.BluetoothControlService.powered ? "ok" : "err"
        }

        Item { Layout.fillWidth: true }

        // Paired/beacon count (idle)
        Text {
            visible: !Services.BluetoothControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: view.pairedDevs.length + " paired · " + view.beaconDevs.length + " beacons"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }

        // Scan countdown (accent)
        Text {
            visible: Services.BluetoothControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: "scan " + Services.BluetoothControlService.scanSecondsLeft + "s"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
            color: Config.ControlConfig.accent
        }

        // RESCAN button — disabled+dimmed when adapter is off or scan is running
        // (mirrors WifiListView's RESCAN pill).
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

    // Hero-row status caption
    Text {
        Layout.fillWidth: true
        Layout.topMargin: -6
        text: "BLUETOOTH · " + (Services.BluetoothControlService.powered ? "POWERED" : "OFFLINE") + " · " + view.pairedDevs.length + " PAIRED · " + view.beaconDevs.length + " BEACONS"
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 10
        font.letterSpacing: 0.3
        color: Config.ThemeConfig.colors.textDim
        opacity: 0.75
    }

    // Error surface (pairing/scan failures)
    Text {
        Layout.fillWidth: true
        visible: false  // TODO: Bind to service error property when available
        text: "⚠ Bluetooth operation failed"
        font.family: Config.ControlConfig.fontMono
        font.pixelSize: 9
        color: Config.ThemeConfig.colors.error
        wrapMode: Text.Wrap
        Layout.topMargin: 4
    }

    // =========================================================================
    // 2. STATUS CARD
    // =========================================================================
    SettingsCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.primary

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.ControlConfig.space2

            // Top row: ADAPTER label + power chip
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "ADAPTER"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                    color: Config.ThemeConfig.colors.textDim
                }
                Item { Layout.fillWidth: true }
                // Power pill
                PowerPill {
                    Layout.alignment: Qt.AlignVCenter
                    on: Services.BluetoothControlService.powered
                    onClicked: Services.BluetoothControlService.togglePower()
                }
            }

            // Big line: adapter alias (or address, or "READY"); NO ACTIVE ADAPTER when off.
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

    // =========================================================================
    // 3. PAIRED_NODES
    // =========================================================================
    SettingsCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.primary
        contentSpacing: 0

        // Header label row: title + [ count ] + thin accent line on the right
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "PAIRED DEVICES"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                color: Config.ThemeConfig.colors.text
            }
            Text {
                text: "[ " + view.pairedDevs.length + " ]"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: Config.ThemeConfig.colors.primary
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.25) }
        }

        // Column header — mirrors BtDeviceRow geometry (margins, spacing, icon
        // slot, NAME fill, SIGNAL 60, STATE 70, ACTION 80, × 16) so every
        // column lines up between the header and the rows beneath it.
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
    SettingsCard {
        width: parent.width
        accent: Config.ThemeConfig.colors.secondary
        contentSpacing: 0

        // Header: title + accent scan dot (while scanning)
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "AVAILABLE DEVICES"
                font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
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

        // Column header — SAME pinned geometry as the paired card.
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
