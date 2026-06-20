// =============================================================================
// SettingsWindow.qml — Main Settings Container
// =============================================================================
//
// The main window container for the Settings Dashboard.
// Contains a sidebar navigation and content area.
//
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config

Item {
    id: root

    // =========================================================================
    // BACKGROUND
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: Config.SettingsConfig.background
    }

    // =========================================================================
    // MAIN LAYOUT
    // =========================================================================

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Sidebar
        Sidebar {
            id: sidebar
            Layout.preferredWidth: Config.SettingsConfig.sidebarWidth
            Layout.fillHeight: true
        }

        // Content Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Config.SettingsConfig.surface

            // Stack for different pages
            StackLayout {
                id: contentStack
                anchors.fill: parent
                anchors.margins: Config.SettingsConfig.contentPadding

                currentIndex: sidebar.currentIndex

                // Theme Module
                ThemeModule {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                // Other modules can be added here
                // SystemModule { }
                // NetworkModule { }
                // AudioModule { }
            }
        }
    }

    // =========================================================================
    // BORDER
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Config.SettingsConfig.border
        border.width: 1
    }
}
