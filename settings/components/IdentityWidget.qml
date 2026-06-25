// =============================================================================
// components/IdentityWidget.qml
// Identity / Profile Block Widget
//
// USAGE:
//   UI.IdentityWidget {
//       anchors.fill: parent
//       anchors.margins: 32
//       userName: "NIKOS"
//       statusText: "CORE ACTIVE"
//   }
//
// LAYOUT: Horizontal row — avatar box left, name + status column right.
//         Avatar is a bordered square placeholder (replace with Image{} when
//         you have a real asset; bind source to a string property).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

RowLayout {
    id: identityRoot

    // -------------------------------------------------------------------------
    // PUBLIC API
    // -------------------------------------------------------------------------
    property string userName:   "USER"
    property string statusText: "ACTIVE"
    property bool   online:     true   // Controls the status indicator color

    spacing: 24

    // -------------------------------------------------------------------------
    // AVATAR PLACEHOLDER
    // Replace the inner Text with Image { source: avatarPath } when ready.
    // The outer Rectangle handles the border — Image does not have border.color.
    // -------------------------------------------------------------------------
    Rectangle {
        width:  64
        height: 64

        color:        "transparent"
        border.color: Config.ThemeConfig.colors.outline
        border.width: 1
        radius:       0

        // Inner avatar image or initials fallback
        Text {
            anchors.centerIn: parent
            text:             identityRoot.userName.substring(0, 2)
            color:            Config.ThemeConfig.colors.textDim
            font.pixelSize:   18
            font.bold:        true
            font.family:      "monospace"
        }
    }

    // -------------------------------------------------------------------------
    // NAME + STATUS COLUMN
    // -------------------------------------------------------------------------
    ColumnLayout {
        spacing: 10

        // Username display
        Text {
            text:           identityRoot.userName
            color:          Config.ThemeConfig.colors.primary
            font.pixelSize: 22
            font.bold:      true
            font.family:    "monospace"
        }

        // Status row: colored dot + status label
        RowLayout {
            spacing: 8

            // Status indicator dot — green when online, muted when offline
            Rectangle {
                width:  8
                height: 8
                radius: 0   // Square dot — matches bento sharp-corner theme
                color:  identityRoot.online ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim
            }

            Text {
                text:           identityRoot.statusText
                color:          Config.ThemeConfig.colors.textDim
                font.pixelSize: 10
                font.family:    "monospace"
                font.letterSpacing: 1.2
            }
        }
    }

    // Push everything left — fills remaining horizontal space
    Item { Layout.fillWidth: true }
}
