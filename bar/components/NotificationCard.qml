// =============================================================================
// NotificationCard.qml — a single notification row inside the center's list
// =============================================================================
// Uses the active theme tokens (Config.ThemeConfig.colors.*) so it adapts to the
// live palette / OLED-black automatically. Roles come from the ListView model:
//   model.id, model.appName, model.summary, model.body, model.urgency,
//   model.timestamp, model.read
//
// Modernized: app-icon swatch (urgency-tinted, zero-radius) replaces the old
// accent stripe; unread state reads as an inline dot next to the app name;
// hover lifts the card (surface + border shift) and reveals the dismiss action.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: card

    width: parent ? parent.width : 360
    implicitHeight: row.implicitHeight + 24
    color: cardMa.containsMouse ? Config.ThemeConfig.colors.surfaceVariant
                                 : Config.ThemeConfig.colors.surface
    border.width: 1
    border.color: model.urgency === 2
                  ? Config.ThemeConfig.colors.error
                  : (cardMa.containsMouse ? Config.ThemeConfig.colors.primary
                                          : Config.ThemeConfig.colors.border)
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    readonly property color urgencyColor: model.urgency === 2 ? Config.ThemeConfig.colors.error
                                          : model.urgency === 0 ? Config.ThemeConfig.colors.textDim
                                          : Config.ThemeConfig.colors.primary

    // Whole-card click: mark read
    MouseArea {
        id: cardMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Services.NotificationService.markRead(model.id)
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ---- app-icon swatch, tinted by urgency ----
        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignTop
            color: Config.ThemeConfig.colors.background
            border.width: 1
            border.color: card.urgencyColor

            Text {
                anchors.centerIn: parent
                text: "󰂚"
                font.family: Config.BarConfig.fontNerd
                font.pixelSize: 13
                color: card.urgencyColor
            }
        }

        ColumnLayout {
            id: content
            Layout.fillWidth: true
            spacing: 4

            // --- app name · time · dismiss ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    visible: !model.read
                    Layout.preferredWidth: 5
                    Layout.preferredHeight: 5
                    Layout.alignment: Qt.AlignVCenter
                    color: Config.ThemeConfig.colors.secondary
                }

                Text {
                    text: model.appName
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: 10
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.6
                    font.family: Config.BarConfig.fontFamily
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: relativeTime(model.timestamp, Services.NotificationService.now)
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: 10
                    font.family: Config.BarConfig.fontFamily
                    opacity: 0.75
                }

                // Dismiss — revealed on card hover
                Text {
                    text: "✕"
                    font.pixelSize: 11
                    font.family: Config.BarConfig.fontFamily
                    opacity: cardMa.containsMouse ? 1.0 : 0.0
                    color: dismissMa.containsMouse
                           ? Config.ThemeConfig.colors.error
                           : Config.ThemeConfig.colors.textDim
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: dismissMa
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.NotificationService.remove(model.id)
                    }
                }
            }

            // --- summary ---
            Text {
                visible: model.summary !== ""
                Layout.fillWidth: true
                text: model.summary
                color: model.read ? Config.ThemeConfig.colors.textDim
                                  : Config.ThemeConfig.colors.text
                font.pixelSize: 13
                font.bold: !model.read
                font.family: Config.BarConfig.fontFamily
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }

            // --- body ---
            Text {
                visible: model.body !== ""
                Layout.fillWidth: true
                text: model.body
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 11
                font.family: Config.BarConfig.fontFamily
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 3
                opacity: 0.85
            }
        }
    }

    // ----- helpers -----
    function relativeTime(ts, nowMs) {
        var diff = Math.max(0, Math.floor((nowMs - ts) / 1000))
        if (diff < 45)    return "now"
        if (diff < 90)    return "1m ago"
        if (diff < 3600)  return Math.floor(diff / 60) + "m ago"
        if (diff < 7200)  return "1h ago"
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
        return Math.floor(diff / 86400) + "d ago"
    }
}
