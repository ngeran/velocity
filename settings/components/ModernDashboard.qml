// =============================================================================
// settings/components/ModernDashboard.qml
// Bento Grid Dashboard — Main Layout Orchestrator (Obsidian Vertical Edition)
// =============================================================================
//
// TAB ORDER (index-significant):
//   0 Dashboard | 1 Themes | 2 Wallpapers | 3 Control | 4 Settings
// (Control and Settings were swapped to match user request.)
//
// PURPOSE:
//   Main container for all tabs. Delegates tab-0 (Dashboard) to
//   DashboardOverviewTab (bento grid layout), other tabs to their
//   respective modules (ThemeModule, WallpaperModule, ControlModule, Settings).
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "." as Components
import "../config" as Config
import "../services" as Services

Item {
    id: root

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    property int currentTab: 0

    // =========================================================================
    // PUBLIC FUNCTIONS
    // =========================================================================

    // Open the Control tab and switch to a specific sub-section
    function openControlTab(section) {
        // Find Control by KEY, not hardcoded index — survives future reorders.
        var idx = -1
        for (var i = 0; i < navBar.tabModel.length; i++) {
            if (navBar.tabModel[i].key === "control") { idx = i; break }
        }
        if (idx >= 0) root.currentTab = idx
        controlModule.activeSection = section
    }

    // =========================================================================
    // BACKGROUND
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        radius: 0
    }

    // =========================================================================
    // TOP NAVIGATION HEADER
    // =========================================================================

    Components.TopNavBar {
        id: navBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: parent.height * (1.0 / 12.0)
        currentIndex: root.currentTab
        onTabSelected: function(index) {
            root.currentTab = index
        }
    }

    // =========================================================================
    // MAIN CONTENT AREA
    // =========================================================================

    Item {
        id: contentArea
        anchors {
            top: navBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        // =====================================================================
        // TAB 0: DASHBOARD OVERVIEW
        // =====================================================================

        Components.DashboardOverviewTab {
            id: overviewTab

            // Animate opacity and position on tab change
            visible: root.currentTab === 0
            opacity: root.currentTab === 0 ? 1.0 : 0.0
            x: root.currentTab === 0 ? 0 : -20
            anchors.fill: parent

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        // =====================================================================
        // TAB 1: THEME SELECTION
        // =====================================================================

        Components.ThemeModule {
            id: themeTab

            visible: root.currentTab === 1
            opacity: root.currentTab === 1 ? 1.0 : 0.0
            x: root.currentTab === 1 ? 0 : (root.currentTab < 1 ? 20 : -20)
            anchors.fill: parent
            anchors.margins: 24

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        // =====================================================================
        // TAB 2: WALLPAPER MANAGEMENT
        // =====================================================================

        Components.WallpaperModule {
            id: wallpaperTab

            visible: root.currentTab === 2
            opacity: root.currentTab === 2 ? 1.0 : 0.0
            x: root.currentTab === 2 ? 0 : (root.currentTab < 2 ? 20 : -20)
            anchors.fill: parent

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        // =====================================================================
        // TAB 3: CONTROL MODULE
        // =====================================================================

        Components.ControlModule {
            id: controlModule

            visible: root.currentTab === 3
            opacity: root.currentTab === 3 ? 1.0 : 0.0
            x: root.currentTab === 3 ? 0 : (root.currentTab < 3 ? 20 : -20)
            anchors.fill: parent

            // Expose activeSection for IPC deep-link
            property alias activeSection: controlModule.activeSection

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        // =====================================================================
        // TAB 4: SETTINGS
        // =====================================================================

        Item {
            id: settingsTab

            visible: root.currentTab === 4
            opacity: root.currentTab === 4 ? 1.0 : 0.0
            x: root.currentTab === 4 ? 0 : 20
            anchors.fill: parent

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: Config.SettingsConfig.animDurationNormal
                    easing.type: Easing.OutCubic
                }
            }

            // Scrollable settings container
            Flickable {
                anchors.fill: parent
                anchors.margins: 24
                contentHeight: settingsContent.implicitHeight + 48
                clip: true

                ColumnLayout {
                    id: settingsContent
                    width: parent.width
                    spacing: 20

                    // =================================================================
                    // KEYBOARD NAVIGATION HINT
                    // =================================================================

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: Config.ThemeConfig.colors.surfaceVariant
                        border.color: Config.ThemeConfig.colors.border
                        border.width: 1
                        radius: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Text {
                                text: "⌨"
                                color: Config.ThemeConfig.colors.primary
                                font.pixelSize: 16
                                font.family: "JetBrains Mono"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "KEYBOARD NAVIGATION"
                                    color: Config.ThemeConfig.colors.text
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.family: Config.SettingsConfig.fontFamily
                                }

                                Text {
                                    text: "Tab to navigate • Space/Enter to activate • Escape to close"
                                    color: Config.ThemeConfig.colors.textDim
                                    font.pixelSize: 9
                                    font.family: Config.SettingsConfig.fontFamily
                                }
                            }
                        }
                    }

                    // =================================================================
                    // APPEARANCE SECTION
                    // =================================================================

                    Components.WidgetHeader {
                        icon: "󰀯"
                        label: "APPEARANCE"
                        Layout.bottomMargin: 4
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    // Animation Speed
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "ANIMATION SPEED"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 10; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: Services.SettingsConfigService.animationSpeed === "fast" ? "FAST" : Services.SettingsConfigService.animationSpeed === "normal" ? "NORMAL" : "SLOW"
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 11
                            font.family: Config.SettingsConfig.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: ["FAST", "NORMAL", "SLOW"]
                            delegate: Rectangle {
                                Layout.preferredWidth: 60
                                Layout.preferredHeight: 24
                                radius: 0
                                color: Services.SettingsConfigService.animationSpeed === modelData.toLowerCase() ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: Config.ThemeConfig.colors.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: Services.SettingsConfigService.animationSpeed === modelData.toLowerCase() ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
                                    font.pixelSize: 9
                                    font.family: Config.SettingsConfig.fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.SettingsConfigService.animationSpeed = modelData.toLowerCase()
                                        Services.SettingsConfigService.saveSettings()
                                    }
                                }
                            }
                        }
                    }

                    // Corner Radius
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "CORNER RADIUS"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 10; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: Services.SettingsConfigService.cornerRadius + "px"
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 11
                            font.family: Config.SettingsConfig.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: [0, 4, 8, 12]
                            delegate: Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 24
                                radius: modelData  // Preview the actual radius
                                color: Services.SettingsConfigService.cornerRadius === modelData ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: Config.ThemeConfig.colors.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "px"
                                    color: Services.SettingsConfigService.cornerRadius === modelData ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
                                    font.pixelSize: 9
                                    font.family: Config.SettingsConfig.fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.SettingsConfigService.cornerRadius = modelData
                                        Services.SettingsConfigService.saveSettings()
                                    }
                                }
                            }
                        }
                    }

                    // =================================================================
                    // BAR SECTION
                    // =================================================================

                    Components.WidgetHeader {
                        icon: "󰖬"
                        label: "BAR"
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    // Bar Height
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "BAR HEIGHT"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 10; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: Services.SettingsConfigService.barHeight + "px"
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 11
                            font.family: Config.SettingsConfig.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: [20, 26, 32, 40]
                            delegate: Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 24
                                radius: 0
                                color: Services.SettingsConfigService.barHeight === modelData ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: Config.ThemeConfig.colors.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "px"
                                    color: Services.SettingsConfigService.barHeight === modelData ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
                                    font.pixelSize: 9
                                    font.family: Config.SettingsConfig.fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.SettingsConfigService.barHeight = modelData
                                        Services.SettingsConfigService.saveSettings()
                                    }
                                }
                            }
                        }
                    }

                    // Workspace Count
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "WORKSPACES"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 10; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: Services.SettingsConfigService.workspaceCount + " workspaces"
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 11
                            font.family: Config.SettingsConfig.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: [3, 5, 7, 9]
                            delegate: Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 24
                                radius: 0
                                color: Services.SettingsConfigService.workspaceCount === modelData ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: Config.ThemeConfig.colors.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: Services.SettingsConfigService.workspaceCount === modelData ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
                                    font.pixelSize: 9
                                    font.family: Config.SettingsConfig.fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.SettingsConfigService.workspaceCount = modelData
                                        Services.SettingsConfigService.saveSettings()
                                    }
                                }
                            }
                        }
                    }

                    // =================================================================
                    // CLOCK SECTION
                    // =================================================================

                    Components.WidgetHeader {
                        icon: "󰥔"
                        label: "CLOCK"
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    // City Name
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "CITY"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 10; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: Services.SettingsConfigService.clockCity
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 11
                            font.family: Config.SettingsConfig.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 26
                            radius: 0
                            color: Config.ThemeConfig.colors.surfaceVariant
                            border.color: Config.ThemeConfig.colors.border
                            border.width: 1

                            TextInput {
                                anchors.centerIn: parent
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                text: Services.SettingsConfigService.clockCity
                                color: Config.ThemeConfig.colors.text
                                font.pixelSize: 10
                                font.family: Config.SettingsConfig.fontFamily
                                selectByMouse: true
                                onAccepted: {
                                    Services.SettingsConfigService.clockCity = text
                                    Services.SettingsConfigService.saveSettings()
                                }
                                onFocusChanged: {
                                    if (!focus) {
                                        Services.SettingsConfigService.clockCity = text
                                        Services.SettingsConfigService.saveSettings()
                                    }
                                }
                            }
                        }
                    }

                    // Timezone Offset
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "TIMEZONE"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 10; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: Services.SettingsConfigService.clockOffset === 0 ? "LOCAL" : "UTC" + (Services.SettingsConfigService.clockOffset >= 0 ? "+" : "") + Services.SettingsConfigService.clockOffset
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 11
                            font.family: Config.SettingsConfig.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: [-12, -8, -5, -4, 0, 1, 2, 3, 8, 10, 12]
                            delegate: Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 24
                                radius: 0
                                visible: modelData === 0 || [-12, -8, -5, -4, 1, 2, 3, 8, 10, 12].indexOf(modelData) !== -1
                                color: Services.SettingsConfigService.clockOffset === modelData ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: Config.ThemeConfig.colors.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData === 0 ? "LOC" : (modelData > 0 ? "+" + modelData : modelData)
                                    color: Services.SettingsConfigService.clockOffset === modelData ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
                                    font.pixelSize: 8
                                    font.family: Config.SettingsConfig.fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.SettingsConfigService.clockOffset = modelData
                                        Services.SettingsConfigService.saveSettings()
                                    }
                                }
                            }
                        }
                    }

                    // =================================================================
                    // IDLE & LOCK SECTION
                    // =================================================================

                    Components.WidgetHeader {
                        icon: "󰌾"
                        label: "IDLE & LOCK"
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    // Dim Timeout
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "DIM AFTER"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 10; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: Math.round(Services.HypridleService.dimTimeout / 60) + " min"
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 11
                            font.family: Config.SettingsConfig.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: [1, 2, 3, 5, 10]
                            delegate: Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 24
                                radius: 0
                                color: Services.HypridleService.dimTimeout === modelData * 60 ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: Config.ThemeConfig.colors.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "m"
                                    color: Services.HypridleService.dimTimeout === modelData * 60 ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
                                    font.pixelSize: 9
                                    font.family: Config.SettingsConfig.fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.HypridleService.dimTimeout = modelData * 60
                                        Services.HypridleService.saveConfig()
                                    }
                                }
                            }
                        }
                    }

                    // Lock Timeout
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "LOCK AFTER"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 10; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: Math.round(Services.HypridleService.lockTimeout / 60) + " min"
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 11
                            font.family: Config.SettingsConfig.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: [2, 5, 10, 15, 30]
                            delegate: Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 24
                                radius: 0
                                color: Services.HypridleService.lockTimeout === modelData * 60 ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: Config.ThemeConfig.colors.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "m"
                                    color: Services.HypridleService.lockTimeout === modelData * 60 ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
                                    font.pixelSize: 9
                                    font.family: Config.SettingsConfig.fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.HypridleService.lockTimeout = modelData * 60
                                        Services.HypridleService.saveConfig()
                                    }
                                }
                            }
                        }
                    }

                    // Display Off Timeout
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "DISPLAY OFF"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 10; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: Math.round(Services.HypridleService.displayOffTimeout / 60) + " min"
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 11
                            font.family: Config.SettingsConfig.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: [5, 10, 15, 20, 30]
                            delegate: Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 24
                                radius: 0
                                color: Services.HypridleService.displayOffTimeout === modelData * 60 ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: Config.ThemeConfig.colors.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "m"
                                    color: Services.HypridleService.displayOffTimeout === modelData * 60 ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
                                    font.pixelSize: 9
                                    font.family: Config.SettingsConfig.fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.HypridleService.displayOffTimeout = modelData * 60
                                        Services.HypridleService.saveConfig()
                                    }
                                }
                            }
                        }
                    }

                    // Suspend Toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "SUSPEND"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 10; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: Services.HypridleService.suspendEnabled ? (Services.HypridleService.suspendTimeout / 60) + " min" : "OFF"
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 11
                            font.family: Config.SettingsConfig.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 24
                            radius: 0
                            color: Services.HypridleService.suspendEnabled ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                            border.color: Config.ThemeConfig.colors.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: Services.HypridleService.suspendEnabled ? "ON" : "OFF"
                                color: Services.HypridleService.suspendEnabled ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
                                font.pixelSize: 9
                                font.family: Config.SettingsConfig.fontFamily
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Services.HypridleService.suspendEnabled = !Services.HypridleService.suspendEnabled
                                    Services.HypridleService.saveConfig()
                                }
                            }
                        }
                    }

                    // Suspend Timeout (only when enabled)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: Services.HypridleService.suspendEnabled
                        Text {
                            text: "SUSPEND AFTER"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 10; font.bold: true
                            font.family: Config.SettingsConfig.fontFamily
                            font.letterSpacing: 1.5
                            Layout.preferredWidth: 120
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: [15, 30, 45, 60]
                            delegate: Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 24
                                radius: 0
                                color: Services.HypridleService.suspendTimeout === modelData * 60 ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                border.color: Config.ThemeConfig.colors.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "m"
                                    color: Services.HypridleService.suspendTimeout === modelData * 60 ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
                                    font.pixelSize: 9
                                    font.family: Config.SettingsConfig.fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.HypridleService.suspendTimeout = modelData * 60
                                        Services.HypridleService.saveConfig()
                                    }
                                }
                            }
                        }
                    }

                    // =================================================================
                    // AUTOSTART SECTION
                    // =================================================================

                    Components.WidgetHeader {
                        icon: "󰚜"
                        label: "AUTOSTART"
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    // Autostart entries list
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: Services.AutostartService.autostartEntries
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                // Enable/disable toggle
                                Rectangle {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 24
                                    radius: 0
                                    color: modelData.enabled ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                                    border.color: Config.ThemeConfig.colors.border
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.enabled ? "ON" : "OFF"
                                        color: modelData.enabled ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.text
                                        font.pixelSize: 8
                                        font.family: Config.SettingsConfig.fontFamily
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Services.AutostartService.toggleEntry(index)
                                    }
                                }

                                // Entry name
                                Text {
                                    text: modelData.name
                                    color: Config.ThemeConfig.colors.text
                                    font.pixelSize: 11
                                    font.family: Config.SettingsConfig.fontFamily
                                    Layout.fillWidth: true
                                }

                                // Command preview (truncated)
                                Text {
                                    text: modelData.command.length > 30 ? modelData.command.substring(0, 30) + "…" : modelData.command
                                    color: Config.ThemeConfig.colors.textDim
                                    font.pixelSize: 9
                                    font.family: "JetBrains Mono"
                                    Layout.preferredWidth: 200
                                    elide: Text.ElideRight
                                }

                                // Remove button
                                Rectangle {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    radius: 0
                                    color: Config.ThemeConfig.colors.surfaceVariant
                                    border.color: Config.ThemeConfig.colors.border
                                    border.width: 1
                                    visible: modelData.name !== "Bar" && modelData.name !== "Settings"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: Config.ThemeConfig.colors.text
                                        font.pixelSize: 12
                                        font.family: Config.SettingsConfig.fontFamily
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Services.AutostartService.removeEntry(index)
                                    }
                                }
                            }
                        }

                        // Add new entry hint
                        Text {
                            text: "Autostart entries are stored in ~/.config/quickshell/autostart.json"
                            color: Config.ThemeConfig.colors.textDim
                            font.pixelSize: 9
                            font.family: Config.SettingsConfig.fontFamily
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 4
                        }
                    }

                    // =================================================================
                    // KEYBINDS SECTION
                    // =================================================================

                    Components.WidgetHeader {
                        icon: "󱘣"
                        label: "KEYBINDS"
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    // Keybind categories
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // System
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Text {
                                text: "SYSTEM"
                                color: Config.ThemeConfig.colors.textDim
                                font.pixelSize: 9; font.bold: true
                                font.family: Config.SettingsConfig.fontFamily
                                font.letterSpacing: 1.5
                                Layout.preferredWidth: 80
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "SUPER + P\tPower Menu"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + L\tLock Screen"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + M\tLogout / Shutdown"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                            }
                        }

                        // Apps
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Text {
                                text: "APPS"
                                color: Config.ThemeConfig.colors.textDim
                                font.pixelSize: 9; font.bold: true
                                font.family: Config.SettingsConfig.fontFamily
                                font.letterSpacing: 1.5
                                Layout.preferredWidth: 80
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "SUPER + X\tTerminal"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + B\tBrowser"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + SPACE\tLauncher"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + F\tFile Manager"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                            }
                        }

                        // QuickShell
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Text {
                                text: "SHELL"
                                color: Config.ThemeConfig.colors.textDim
                                font.pixelSize: 9; font.bold: true
                                font.family: Config.SettingsConfig.fontFamily
                                font.letterSpacing: 1.5
                                Layout.preferredWidth: 80
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "SUPER + A\tSettings Dashboard"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + SHIFT + B\tToggle Bar"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + SHIFT + T\tNetwork Control"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                            }
                        }

                        // Windows
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Text {
                                text: "WINDOWS"
                                color: Config.ThemeConfig.colors.textDim
                                font.pixelSize: 9; font.bold: true
                                font.family: Config.SettingsConfig.fontFamily
                                font.letterSpacing: 1.5
                                Layout.preferredWidth: 80
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "SUPER + C\tClose Window"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + V\tToggle Float"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + J\tToggle Split"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                            }
                        }

                        // Navigation
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Text {
                                text: "FOCUS"
                                color: Config.ThemeConfig.colors.textDim
                                font.pixelSize: 9; font.bold: true
                                font.family: Config.SettingsConfig.fontFamily
                                font.letterSpacing: 1.5
                                Layout.preferredWidth: 80
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "SUPER + Arrows\tFocus Direction"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + 1-10\tSwitch Workspace"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + SHIFT + 1-10\tMove to Workspace"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                            }
                        }

                        // Screenshots
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Text {
                                text: "SCREEN"
                                color: Config.ThemeConfig.colors.textDim
                                font.pixelSize: 9; font.bold: true
                                font.family: Config.SettingsConfig.fontFamily
                                font.letterSpacing: 1.5
                                Layout.preferredWidth: 80
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "SUPER + S\tScreenshot Region (File)"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "SUPER + SHIFT + S\tScreenshot Region (Clipboard)"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                            }
                        }

                        // Hardware
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Text {
                                text: "MEDIA"
                                color: Config.ThemeConfig.colors.textDim
                                font.pixelSize: 9; font.bold: true
                                font.family: Config.SettingsConfig.fontFamily
                                font.letterSpacing: 1.5
                                Layout.preferredWidth: 80
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "Volume Keys\tVolume Control"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "Brightness Keys\tBrightness Control"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                                Text { text: "Media Keys\tPlay/Pause/Next"; color: Config.ThemeConfig.colors.text; font.pixelSize: 10; font.family: "JetBrains Mono" }
                            }
                        }
                    }

                    // =================================================================
                    // SYSTEM / ABOUT SECTION
                    // =================================================================

                    Components.WidgetHeader {
                        icon: "󰒋"
                        label: "SYSTEM"
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

                    Repeater {
                        model: [
                            { label: "OS",     value: Services.SysInfoService.osPrettyName },
                            { label: "KERNEL", value: Services.SysInfoService.kernel },
                            { label: "HOST",   value: Services.SysInfoService.hostname },
                            { label: "UPTIME", value: Services.SysInfoService.uptime },
                            { label: "USER",   value: Services.SysInfoService.userName },
                            { label: "THEME",  value: Config.ThemeConfig.metadata.name + " · " + Config.ThemeConfig.metadata.source }
                        ]
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Text {
                                text: modelData.label
                                color: Config.ThemeConfig.colors.textDim
                                font.pixelSize: 10; font.bold: true
                                font.family: Config.SettingsConfig.fontFamily
                                font.letterSpacing: 1.5
                                Layout.preferredWidth: 80
                            }
                            Text {
                                text: modelData.value
                                color: Config.ThemeConfig.colors.text
                                font.pixelSize: 12
                                font.family: Config.SettingsConfig.fontFamily
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        text: "QUICKSHELL · OBSIDIAN CORE"
                        color: Config.ThemeConfig.colors.textDim
                        font.pixelSize: 9; font.letterSpacing: 2.5
                        font.family: Config.SettingsConfig.fontFamily
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 16
                        opacity: 0.4
                    }
                }
            }

            // Settings are managed by SettingsConfigService singleton
            // All changes are automatically persisted to ~/.config/quickshell/settings-config.json
        }
    }
}
