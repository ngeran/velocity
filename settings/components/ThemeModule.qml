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
    property string currentTheme:     Services.ThemeService.currentThemeName || "OLED Pure Black"
    property bool   oledClampEnabled: Services.ThemeService.isOledClampActive // Typo fixed from oedClamp

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
                            root.currentTheme = modelData
                            root.updateSharedState()
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
            // SECTION 4: HARDWARE ACCENT-OVERRIDE MONITORING CONSOLE
            // -----------------------------------------------------------------
            ColumnLayout {
                spacing: 6

                Text {
                    text:           "MANUAL ACCENT TOKENS"
                    font.pixelSize: 11
                    font.family:    "monospace"
                    color:          "#ffffff"
                }

                Text {
                    text:           "Each swatch sets ONE accent token to the shown color — primary, secondary, or accent. Pick a curated theme above to recolor the whole shell at once."
                    font.pixelSize: 9
                    font.family:    "monospace"
                    color:          Config.ThemeConfig.colors.textDim
                    Layout.fillWidth: true
                }

                Item { height: 4 }

                RowLayout {
                    spacing: 8

                    Text {
                        text:           "Token:"
                        font.pixelSize: 10
                        font.family:    "monospace"
                        color:          Config.ThemeConfig.colors.textDim
                    }

                    // One chip per accent token — each sets a DIFFERENT token,
                    // so they're individually meaningful (not all "secondary").
                    Repeater {
                        model: [
                            { name: "PRIMARY",   token: "primary",   hex: "#bd93f9" },
                            { name: "SECONDARY", token: "secondary", hex: "#50fa7b" },
                            { name: "ACCENT",    token: "accent",    hex: "#ff79c6" }
                        ]
                        delegate: Rectangle {
                            width:        54
                            height:       22
                            color:        "transparent"
                            border.color: Config.ThemeConfig.colors.border
                            border.width: 1
                            radius:       0

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 4
                                color: modelData.hex
                            }

                            Text {
                                anchors.centerIn: parent
                                text:            modelData.name.toUpperCase()
                                font.pixelSize:  8
                                font.family:    "monospace"
                                color:           "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    if (/^#[0-9A-Fa-f]{6}$/.test(modelData.hex)) {
                                        Services.ThemeService.applyManualOverride(modelData.token, modelData.hex)
                                        root.currentTheme = "Custom Modification"
                                        root.updateSharedState()
                                    }
                                }
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
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
                            root.oledClampEnabled = !root.oledClampEnabled
                            if (root.themeMode === "curated") {
                                Services.ThemeService.applyPreset(root.currentTheme, root.oledClampEnabled)
                            }
                            root.updateSharedState()
                        }
                    }
                }
            }
        }
    }

    // Baseline internal synchronization clock loop
    Timer {
        interval:    1000
        running:     true
        repeat:      true
        triggeredOnStart: true
        onTriggered: {
            root.currentTheme     = Services.ThemeService.currentThemeName
            root.oledClampEnabled = Services.ThemeService.isOledClampActive
            root.updateSharedState()
        }
    }
}
