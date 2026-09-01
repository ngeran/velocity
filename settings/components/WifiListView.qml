// =============================================================================
// WifiListView.qml — NETWORK section view (viewport-fit, NO SCROLLING)
// =============================================================================
// Fixed composition per SKILL.md §6.1:
//   header row (badge · counts · RESCAN)
//   body = left summary column (ACTIVE LINK + filters) | right list card
//          whose rows clamp to the visible capacity (priority order:
//          in-use first, then signal desc; footer shows visible-of-total).
//
// Backed by Services.NetworkControlService (nmcli). All colours are live
// ThemeConfig tokens. Filtering, scanning, inline-password and freeze logic
// are unchanged from the scrolling version.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

ColumnLayout {
    id: view
    spacing: Config.ControlConfig.space3

    readonly property var cs: Services.NetworkControlService.connectionStatus
    readonly property bool linkUp: view.cs.connected === true
    // Lit signal segments for the connected card (same tiers as the row).
    readonly property int linkBars: view.cs.signal >= 75 ? 4 : view.cs.signal >= 50 ? 3 : view.cs.signal >= 25 ? 2 : view.cs.signal > 0 ? 1 : 0

    // Minimum signal a scan-row needs to be shown (0 = ALL). Default 50 hides
    // weak/noisy APs. The active link is force-included even below threshold.
    property int minSignal: 50
    property bool anyRowEditing: false  // Tracks if any row is in password-edit mode

    readonly property var filteredNets: {
        var all = Services.NetworkControlService.wifiNetworks
        if (view.minSignal <= 0) return all
        var out = []
        for (var i = 0; i < all.length; i++) {
            var n = all[i]
            if (n.signal >= view.minSignal || n.inUse) out.push(n)
        }
        return out
    }

    // Priority order for the visible capacity: in-use first, then signal desc.
    // Presentation-only — the service's array is never mutated.
    readonly property var sortedNets: {
        var arr = view.filteredNets.slice(0)
        arr.sort(function(a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
            return b.signal - a.signal
        })
        return arr
    }
    // Rows are 40px (66 while one expands for the inline password field —
    // reserve one slot so the editor is never clipped by the viewport).
    readonly property int listCapacity: Math.max(3, Math.floor(listViewport.height / 40) - (view.anyRowEditing ? 1 : 0))
    // Count only. Rows are clamped by VISIBILITY (index < listCapacity), never
    // by slicing the model: a sliced model is a fresh array on every capacity
    // change (height churn while the card slides up, the editing reserve),
    // which destroys + recreates the row delegates mid-interaction. A delegate
    // dying while editing=true strands `anyRowEditing` forever — every row
    // stays frozen/disabled ("cannot switch networks"). Visibility clamping
    // keeps delegates alive so click/password state survives.
    readonly property int visibleCount: Math.min(view.sortedNets.length, view.listCapacity)

    // Label/value stat pair (used by the connected card).
    component Stat: RowLayout {
        property string label: ""
        property string value: "—"
        spacing: 6
        Text {
            text: parent.label
            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8
            color: Config.ThemeConfig.colors.textDim
        }
        Text {
            text: parent.value
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
            color: Config.ThemeConfig.colors.text
            elide: Text.ElideRight
            Layout.maximumWidth: 140
        }
    }

    // Segmented MIN SIGNAL button (ALL / ≥50% / ≥70%) — sets minSignal.
    component FilterSeg: ControlSeg {
        property int value: 0
        onTarget: view
        targetProperty: "minSignal"
    }

    // =========================================================================
    // 1. HEADER ROW
    // =========================================================================
    SectionHeader {
        Layout.fillWidth: true
        title: "NETWORK"

        StatusBadge {
            Layout.alignment: Qt.AlignVCenter
            label: view.linkUp ? "STABLE" : "OFFLINE"
            kind: view.linkUp ? "ok" : "err"
        }

        Item { Layout.fillWidth: true }

        Text {
            visible: !Services.NetworkControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: Services.NetworkControlService.wifiNetworks.length + " nets"
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ThemeConfig.colors.textDim
        }

        Text {
            visible: Services.NetworkControlService.scanning
            Layout.alignment: Qt.AlignVCenter
            text: { var d = ["·", "··", "···", "····"]; return "scan" + d[Math.floor(dotTimer.tick % 4)] }
            font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
            color: Config.ControlConfig.accent
            Timer {
                id: dotTimer; property int tick: 0
                interval: 300; repeat: true
                running: Services.NetworkControlService.scanning
                onTriggered: tick++
                onRunningChanged: if (!running) tick = 0
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: rescanLbl.implicitWidth + 20; height: 24
            radius: Config.ControlConfig.radiusPill
            color: rescanMA.containsMouse && !Services.NetworkControlService.scanning
                   ? Config.ThemeConfig.tint(Config.ControlConfig.accent, 0.16) : "transparent"
            border.color: Services.NetworkControlService.scanning ? Config.ThemeConfig.colors.outlineVariant : Config.ControlConfig.accent
            border.width: 1
            opacity: Services.NetworkControlService.scanning ? 0.5 : 1.0
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
                id: rescanLbl; anchors.centerIn: parent
                text: "RESCAN"
                font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                color: Config.ControlConfig.accent
            }
            MouseArea {
                id: rescanMA; anchors.fill: parent; hoverEnabled: true
                cursorShape: Services.NetworkControlService.scanning ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: if (!Services.NetworkControlService.scanning) Services.NetworkControlService.scanWifi()
            }
        }
    }

    // Error surface
    Text {
        Layout.fillWidth: true
        visible: Services.NetworkControlService.lastConnectError !== ""
        text: "⚠ " + Services.NetworkControlService.lastConnectError
        font.family: Config.ControlConfig.fontSans
        font.pixelSize: 10
        color: Config.ThemeConfig.colors.error
        wrapMode: Text.NoWrap
        elide: Text.ElideMiddle
    }

    // =========================================================================
    // 2. BODY — summary column | list card (both fit the pane, no scrolling)
    // =========================================================================
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Config.ControlConfig.space3

        // ── Left: summary column ──────────────────────────────────────────────
        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.maximumWidth: 340
            Layout.fillHeight: true
            spacing: Config.ControlConfig.space3

            SettingsCard {
                Layout.fillWidth: true
                accent: Config.ThemeConfig.colors.secondary

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.ControlConfig.space2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "ACTIVE LINK"
                            font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                            color: Config.ThemeConfig.colors.textDim
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: view.linkUp
                            text: view.cs.signal + "%"
                            font.family: Config.ControlConfig.fontMono; font.pixelSize: 12; font.bold: true
                            color: Config.ControlConfig.accent
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: view.linkUp ? (view.cs.ssid || view.cs.iface || "CONNECTED") : "NO ACTIVE LINK"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 18; font.bold: true
                        color: view.linkUp ? Config.ThemeConfig.colors.primary : Config.ThemeConfig.colors.textDim
                        elide: Text.ElideRight
                    }

                    Row {
                        Layout.fillWidth: true
                        visible: view.linkUp && view.cs.signal > 0
                        spacing: 3
                        Repeater {
                            model: 4
                            Rectangle {
                                width: (view.cs.iface ? 268 : 268) / 4 - 3
                                height: 4; radius: 2
                                color: index < view.linkBars ? Config.ControlConfig.accent : Config.ThemeConfig.colors.border
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Stat { label: "IP";    value: view.cs.ip    || "—" }
                        Stat { label: "IFACE"; value: view.cs.iface || "—" }
                        Item { Layout.fillWidth: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Stat { label: "TYPE";  value: (view.cs.type || "—").toUpperCase() }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            SettingsCard {
                Layout.fillWidth: true
                accent: Config.ThemeConfig.colors.primary

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: "MIN SIGNAL"
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8
                        color: Config.ThemeConfig.colors.textDim
                        Layout.alignment: Qt.AlignVCenter
                    }
                    FilterSeg { text: "ALL";  value: 0;  active: view.minSignal === 0 }
                    FilterSeg { text: "≥50%"; value: 50; active: view.minSignal === 50 }
                    FilterSeg { text: "≥70%"; value: 70; active: view.minSignal === 70 }
                    Item { Layout.fillWidth: true }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // ── Right: networks table (viewport-fit) ─────────────────────────────
        SettingsCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            accent: Config.ThemeConfig.colors.primary
            contentSpacing: 0

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Card header + visible-of-total count
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.topMargin: 2
                    spacing: 6
                    Text {
                        text: "NETWORKS"
                        font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.0
                        color: Config.ThemeConfig.colors.text
                    }
                    Text {
                        text: view.visibleCount + " / " + view.filteredNets.length
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10; font.bold: true
                        color: view.visibleCount < view.filteredNets.length
                               ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.primary
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.tint(Config.ThemeConfig.colors.primary, 0.25) }
                }

                // Column header — mirrors the row geometry
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10; Layout.rightMargin: 6
                    spacing: 8
                    Item { Layout.preferredWidth: 14 }
                    Text { text: "SSID"; Layout.fillWidth: true; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                    Text { text: "SIGNAL"; Layout.preferredWidth: 76; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                    Text { text: "SECURITY"; Layout.preferredWidth: 72; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                    Text { text: "CHAN"; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignRight; font.family: Config.ControlConfig.fontSans; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8; color: Config.ThemeConfig.colors.textDim }
                    Item { Layout.preferredWidth: 16 }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                // Row viewport — rows clamp to what fits (no scrollbar)
                Item {
                    id: listViewport
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        Repeater {
                            model: view.sortedNets
                            delegate: WifiListRow {
                                width: parent.width
                                visible: index < view.listCapacity
                                net: modelData
                                listFrozen: view.anyRowEditing
                                onEditingChanged: {
                                    view.anyRowEditing = editing
                                }
                            }
                        }
                    }

                    // Empty state — nothing found at all
                    Text {
                        anchors.centerIn: parent
                        visible: Services.NetworkControlService.wifiNetworks.length === 0
                                 && !Services.NetworkControlService.scanning
                        text: "// no networks visible — press RESCAN to search"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.textDim
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Empty state — networks exist but all fall below the filter
                    Text {
                        anchors.centerIn: parent
                        visible: Services.NetworkControlService.wifiNetworks.length > 0
                                 && view.filteredNets.length === 0
                                 && !Services.NetworkControlService.scanning
                        text: "// " + Services.NetworkControlService.wifiNetworks.length
                              + " weak network" + (Services.NetworkControlService.wifiNetworks.length !== 1 ? "s" : "")
                              + " hidden — lower MIN SIGNAL to show"
                        font.family: Config.ControlConfig.fontMono; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.textDim
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // Footer — honest count of clamped-away rows
                Text {
                    Layout.fillWidth: true
                    visible: view.visibleCount < view.filteredNets.length
                    Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.bottomMargin: 2
                    text: "+ " + (view.filteredNets.length - view.visibleCount)
                          + " more hidden — raise MIN SIGNAL to narrow"
                    font.family: Config.ControlConfig.fontSans; font.pixelSize: 10
                    color: Config.ThemeConfig.colors.textDim
                    elide: Text.ElideRight
                }
            }
        }
    }

    // Wrong-password reprompt (Omarchy pattern) — unchanged.
    Connections {
        target: Services.NetworkControlService
        function onConnectFailed(ssid, reasonKey, reasonLabel) {
            if (reasonKey === "wrong-password" && ssid && ssid.length > 0) {
                for (var i = 0; i < view.filteredNets.length; i++) {
                    if (view.filteredNets[i].ssid === ssid) {
                        break
                    }
                }
            }
        }
    }
}
