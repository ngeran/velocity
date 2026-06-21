// =============================================================================
// settings/components/ThemeModule.qml
// Final Unified Theme Control Panel Layout
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services
import "." as Components

Item {
    id: root

    // =========================================================================
    // STATE SYNCHRONIZATION (HYGIENE CONSOLIDATION & TYPO FIXES)
    // =========================================================================
    property string themeMode:        "curated"
    property string currentTheme:     Config.ThemeConfig.metadata.name || "OLED Pure Black"
    property bool   oledClampEnabled: Config.ThemeConfig.metadata.oledClamp || false

    // Array map defining the 6 canonical corporate preset targets for the matrix repeater
    readonly property var extendedThemes: [
        "OLED Pure Black", "Nord", "Catppuccin Mocha",
        "Tokyo Night", "Gruvbox Dark", "Dracula"
    ]

    // DEPRECATED — intentional no-op. SharedState.theme* now bind reactively
    // to Config.ThemeConfig, so the manual mirror push is redundant (and
    // would fight the bindings). Retained so the existing call sites — preset
    // click, override chip, OLED toggle, and the 1s Timer below — stay valid
    // without per-site edits. The 1s Timer still syncs the LOCAL
    // root.currentTheme / root.oledClampEnabled used for preset highlighting.
    function updateSharedState() { }

    // =========================================================================
    // HOUSING GRID STRUCTURE LAYOUT
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ---------------------------------------------------------------------
        // SECTION 1: ACTIVE STATUS ROW WITH LIVE METADATA CARD
        // ---------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Components.ThemeInfoCard {
                id: activeThemeInfoCard
                Layout.preferredWidth:  240
                Layout.preferredHeight: 110
            }

            // Live Swatch Mockup Dashboard Container Box
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: 110
                color:                  "#000000"
                border.color:           Config.ThemeConfig.colors.border
                border.width:           1
                radius:                 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        text:           "LIVE SPECTRUM MONITOR"
                        font.pixelSize: 8
                        font.family:    "monospace"
                        color:          Config.ThemeConfig.colors.textDim
                    }

                    Row {
                        spacing: 4
                        Layout.fillWidth: true

                        Repeater {
                            model: [
                                Config.ThemeConfig.colors.background,
                                Config.ThemeConfig.colors.surface,
                                Config.ThemeConfig.colors.surfaceContainer,
                                Config.ThemeConfig.colors.primary,
                                Config.ThemeConfig.colors.secondary,
                                Config.ThemeConfig.colors.outline,
                                Config.ThemeConfig.colors.border
                            ]
                            delegate: Rectangle {
                                width:  22
                                height: 40
                                color:  modelData
                                border.color: "#1a1a1a"
                                border.width: 1
                                radius: 0
                            }
                        }
                    }

                    Text {
                        text:           "Active Canvas: " + Config.ThemeConfig.colors.background + " // Accent: " + Config.ThemeConfig.colors.secondary
                        font.pixelSize: 8
                        font.family:    "monospace"
                        color:          Config.ThemeConfig.colors.textDim
                    }
                }
            }
        }

        // Pill-style section header navigation tier row
        RowLayout {
            Layout.fillWidth: true

            Text {
                text:            "INTERFACE CHANNELS"
                font.pixelSize:  9
                font.family:     "monospace"
                font.bold:       true
                color:           "#ffffff"
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: 2

                Repeater {
                    model: ["curated", "matugen", "manual"]
                    delegate: Rectangle {
                        width:  74
                        height: 20
                        color:  root.themeMode === modelData ? Config.ThemeConfig.colors.surface : "transparent"
                        border.color: root.themeMode === modelData ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border
                        border.width: 1
                        radius: 0

                        Text {
                            anchors.centerIn: parent
                            text:            modelData.toUpperCase()
                            font.pixelSize:  8
                            font.family:    "monospace"
                            color:           root.themeMode === modelData ? "#ffffff" : Config.ThemeConfig.colors.textDim
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    root.themeMode = modelData
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // MULTI-PANEL VIEW STACK CONTROLLER LAYOUT
        // ---------------------------------------------------------------------
        StackLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            currentIndex:      root.themeMode === "curated" ? 0 : (root.themeMode === "matugen" ? 1 : 2)

            // -----------------------------------------------------------------
            // SECTION 2: CURATED THEME ARCHIVE LIBRARY GRID (6 PRESETS)
            // -----------------------------------------------------------------
            Grid {
                columns: 3
                spacing: 10

                Repeater {
                    model: root.extendedThemes
                    delegate: Components.ThemePresetCard {
                        themeName: modelData
                        isActive:  root.currentTheme === modelData
                        onClicked: {
                            Services.ThemeService.applyPreset(modelData, root.oledClampEnabled)
                            // Note: root.currentTheme is bound to Config.ThemeConfig.metadata.name,
                            // so it updates automatically when applyPreset() updates the metadata.
                            // No manual assignment needed - that would break the binding!
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // SECTION 3: AUTOMATED MATUGEN WALLPAPER EXTRACTION ENGINE
            // -----------------------------------------------------------------
            ColumnLayout {
                spacing: 8

                Text {
                    text:           "DYNAMIC MATUGEN COLOR HARVESTER"
                    font.pixelSize: 11
                    font.family:    "monospace"
                    color:          "#ffffff"
                }

                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    Rectangle {
                        Layout.preferredWidth:  12
                        Layout.preferredHeight: 12
                        color:        Services.ThemeService.matugenAvailable ? "#00ff66" : "#ff3333"
                        radius:       0
                    }

                    Text {
                        text:           Services.ThemeService.matugenAvailable ? "MATUGEN PROTOCOL: OPERATIONAL" : "MATUGEN PROTOCOL: ABSENT"
                        font.pixelSize: 10
                        font.family:    "monospace"
                        color:          "#ffffff"
                    }
                }

                Text {
                    text:           Services.ThemeService.matugenAvailable ?
                                    "System binary maps wallpaper palettes dynamically onto active configuration arrays automatically." :
                                    "Dependency error detected. To initialize extraction routines, install the binary locally via host package engine using: \n$ paru -S matugen"
                    font.pixelSize: 9
                    font.family:    "monospace"
                    color:          Config.ThemeConfig.colors.textDim
                    Layout.fillWidth: true
                }

                Item { height: 4 }

                Rectangle {
                    Layout.preferredWidth:  160
                    Layout.preferredHeight: 28
                    color:        "transparent"
                    border.color: (!Services.ThemeService.matugenAvailable || Services.ThemeService.isRegenerating) ? Config.ThemeConfig.colors.border : Config.ThemeConfig.colors.secondary
                    border.width: 1
                    radius:       0

                    Text {
                        anchors.centerIn: parent
                        text:            Services.ThemeService.isRegenerating ? "GENERATING..." : "RUN EXTRACTION"
                        font.pixelSize:  10
                        font.family:    "monospace"
                        font.bold:       true
                        color:           (!Services.ThemeService.matugenAvailable || Services.ThemeService.isRegenerating) ? Config.ThemeConfig.colors.textDim : "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled:      Services.ThemeService.matugenAvailable && !Services.ThemeService.isRegenerating
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            Services.ThemeService.applyDynamicTheme(Config.SharedState.wallpaperPath, root.oledClampEnabled)
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }

            // -----------------------------------------------------------------
            // -----------------------------------------------------------------
            // SECTION 4: MANUAL THEME EDITOR
            // -----------------------------------------------------------------
            Components.ManualThemeEditor {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        // ---------------------------------------------------------------------
        // FOOTER TENTACLE: QD-OLED PURE BLACK PROTECTIVE TOGGLE PANEL
        // ---------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: 32
            color:                  Config.ThemeConfig.colors.surface
            border.color:           Config.ThemeConfig.colors.border
            border.width:           1
            radius:                 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                Text {
                    text:           "QD-OLED SAFE SCREEN LUMINANCE SHIELD"
                    font.pixelSize: 9
                    font.family:    "monospace"
                    color:          root.oledClampEnabled ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width:        38
                    height:       16
                    color:        root.oledClampEnabled ? Config.ThemeConfig.colors.secondary : "transparent"
                    border.color: root.oledClampEnabled ? "transparent" : Config.ThemeConfig.colors.border
                    border.width: 1
                    radius:       0

                    Text {
                        anchors.centerIn: parent
                        text:            root.oledClampEnabled ? "ON" : "OFF"
                        font.pixelSize:  9
                        font.family:    "monospace"
                        font.bold:       true
                        color:           root.oledClampEnabled ? "#000000" : Config.ThemeConfig.colors.textDim
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            console.log("=== QD-OLED TOGGLE CLICKED ===")

                            // Show current state BEFORE toggle
                            console.log("[TOGGLE] Current oledClampEnabled:", root.oledClampEnabled)
                            console.log("[TOGGLE] Current Config.ThemeConfig.metadata.oledClamp:", Config.ThemeConfig.metadata.oledClamp)
                            console.log("[TOGGLE] Current themeMode:", root.themeMode)
                            console.log("[TOGGLE] Current currentTheme:", root.currentTheme)

                            // Toggle the OLED clamp state
                            var newClampValue = !root.oledClampEnabled
                            console.log("[TOGGLE] New clamp value will be:", newClampValue)

                            // Apply the current theme with the new clamp value
                            // This will update Config.ThemeConfig.metadata.oledClamp
                            if (root.themeMode === "curated" && root.currentTheme) {
                                console.log("[TOGGLE] Calling applyPreset with theme:", root.currentTheme, "and clamp:", newClampValue)
                                Services.ThemeService.applyPreset(root.currentTheme, newClampValue)

                                // Check state after applyPreset
                                console.log("[TOGGLE] After applyPreset - oledClampEnabled:", root.oledClampEnabled)
                                console.log("[TOGGLE] After applyPreset - Config.ThemeConfig.metadata.oledClamp:", Config.ThemeConfig.metadata.oledClamp)
                            } else {
                                console.log("[TOGGLE] Not in curated mode, updating metadata directly")
                                // If no current theme or not in curated mode, just update the metadata directly
                                var currentMetadata = Config.ThemeConfig.metadata
                                console.log("[TOGGLE] Current metadata before update:", JSON.stringify(currentMetadata))
                                // Create a NEW metadata object to avoid reference issues
                                Config.ThemeConfig.metadata = {
                                    name: currentMetadata.name || "Unknown",
                                    source: currentMetadata.source || "manual",
                                    applied: new Date().toISOString(),
                                    oledClamp: newClampValue,
                                    matugenEnabled: currentMetadata.matugenEnabled || false
                                }
                                console.log("[TOGGLE] New metadata after update:", JSON.stringify(Config.ThemeConfig.metadata))
                            }

                            console.log("[TOGGLE] Final oledClampEnabled:", root.oledClampEnabled)
                            console.log("[TOGGLE] Final Config.ThemeConfig.metadata.oledClamp:", Config.ThemeConfig.metadata.oledClamp)
                            console.log("=== TOGGLE CLICK COMPLETE ===")
                        }
                    }
                }
            }
        }
    }

    // Removed aggressive Timer that was overwriting user actions
    // State is now bound directly to Config.ThemeConfig.metadata
}
