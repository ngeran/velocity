// =============================================================================
// Sidebar.qml — Settings Navigation Sidebar
// =============================================================================
//
// The sidebar provides navigation for different settings modules.
//
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root

    // =========================================================================
    // PROPERTIES
    // =========================================================================

    property int currentIndex: 0

    // =========================================================================
    // APPEARANCE
    // =========================================================================

    color: Config.SettingsConfig.surfaceVariant

    // =========================================================================
    // LAYOUT
    // =========================================================================

    ColumnLayout {
        anchors {
            fill: parent
            margins: Config.SettingsConfig.spacingMedium
        }
        spacing: Config.SettingsConfig.spacingSmall

        // Header
        Text {
            text: "Settings"
            font.pixelSize: Config.SettingsConfig.fontSizeTitle
            font.bold: true
            color: Config.SettingsConfig.text
            Layout.bottomMargin: Config.SettingsConfig.spacingMedium
        }

        // Divider
        Rectangle {
            height: 1
            Layout.fillWidth: true
            color: Config.SettingsConfig.border
            Layout.bottomMargin: Config.SettingsConfig.spacingMedium
        }

        // Navigation Items
        Repeater {
            model: [
                { name: "Theme & Wallpaper", icon: "", index: 0 },
                { name: "System", icon: "", index: 1 },
                { name: "Network", icon: "", index: 2 },
                { name: "Audio", icon: "", index: 3 },
            ]

            SidebarItem {
                text: modelData.name
                isActive: root.currentIndex === modelData.index
                onClicked: root.currentIndex = modelData.index

                Layout.fillWidth: true
            }
        }

        // Spacer
        Item { Layout.fillHeight: true }

        // Footer info
        Text {
            text: "QuickShell v1.0"
            font.pixelSize: Config.SettingsConfig.fontSizeSmall
            color: Config.SettingsConfig.textDim
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
    }

    // =========================================================================
    // BORDER
    // =========================================================================

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Config.SettingsConfig.border
    }
}
