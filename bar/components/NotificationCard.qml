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
//
// J1a (native server rows): the BODY is the one styled surface — StyledText
// with <img> tags stripped (markup is the notification's own formatting; no
// script executes in StyledText, and the strip closes the local-file <img>
// probe). appName/summary/glyph/action labels stay PlainText — untrusted.
// Native rows may also carry action chips (≤3), a progress track and an
// image preview; IPC-ingested rows render exactly as before.
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
        onClicked: {
            Services.NotificationService.markRead(model.id)
            Services.NotificationService.invokeAction(model.clickId)
        }
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
                textFormat: Text.PlainText   // notification text is untrusted — never render HTML
                anchors.centerIn: parent
                text: model.glyph !== undefined && model.glyph !== ""
                      ? model.glyph : "󰂚"
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
                    textFormat: Text.PlainText   // notification text is untrusted — never render HTML
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
                    textFormat: Text.PlainText   // notification text is untrusted — never render HTML
                    text: relativeTime(model.timestamp, Services.NotificationService.now)
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: 10
                    font.family: Config.BarConfig.fontFamily
                    opacity: 0.75
                }

                // Dismiss — revealed on card hover
                Text {
                    textFormat: Text.PlainText   // notification text is untrusted — never render HTML
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
                        onClicked: {
                            Services.NotificationService.dismissDbus(model.clickId)
                            Services.NotificationService.remove(model.id)
                        }
                    }
                }
            }

            // --- summary ---
            Text {
                textFormat: Text.PlainText   // notification text is untrusted — never render HTML
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

            // --- body (the one styled surface — see banner) ---
            Text {
                textFormat: Text.StyledText
                visible: model.body !== ""
                Layout.fillWidth: true
                text: stripImages(model.body)
                onLinkActivated: (link) => Qt.openUrlExternally(link)
                color: Config.ThemeConfig.colors.textDim
                font.pixelSize: 11
                font.family: Config.BarConfig.fontFamily
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 3
                opacity: 0.85
            }

            // --- progress (native hints.value) ---
            Rectangle {
                visible: model.progress !== undefined && model.progress >= 0
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                radius: 1
                color: Config.ThemeConfig.colors.border
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, model.progress || 0)) / 100
                    radius: parent.radius
                    height: parent.height
                    color: card.urgencyColor
                }
            }

            // --- image preview (native image hint) ---
            Image {
                visible: model.image !== undefined && model.image !== ""
                Layout.preferredWidth: 64
                Layout.preferredHeight: 44
                Layout.maximumHeight: 44
                fillMode: Image.PreserveAspectFit
                source: model.image !== undefined ? model.image : ""
                asynchronous: true
            }

            // --- action chips (native actions, default excluded — the card
            // click is the default action; ≤3, same cap as the service) ---
            Row {
                visible: model.actions !== undefined
                         && model.actions.filter(function(a) { return a.id !== "default" }).length > 0
                spacing: 6
                Repeater {
                    model: model.actions !== undefined
                           ? model.actions.filter(function(a) { return a.id !== "default" }).slice(0, 3)
                           : []
                    delegate: Rectangle {
                        // modelData is the Repeater's context property — a
                        // `required property var modelData` here breaks it
                        // (JS-array model; known Quickshell trap).
                        readonly property string label: (modelData && modelData.text) || ""
                        radius: 3
                        color: chipMa.containsMouse ? Config.ThemeConfig.colors.surfaceContainer
                                                    : Config.ThemeConfig.colors.background
                        border.width: 1
                        border.color: card.urgencyColor
                        implicitWidth: chipText.implicitWidth + 16
                        implicitHeight: 20
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            textFormat: Text.PlainText   // action labels are untrusted too
                            text: parent.label
                            color: Config.ThemeConfig.colors.text
                            font.pixelSize: 10
                            font.family: Config.BarConfig.fontFamily
                        }
                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Services.NotificationService.markRead(model.id)
                                Services.NotificationService.invokeActionKey(model.clickId,
                                                                             modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // <img> strip for the styled body: notifications are semi-trusted at best,
    // and a styled <img src="file:///…"> would render local-file pixels (an
    // exfil-free but still unintended read). Markup like <b>/<i>/<a> is kept.
    function stripImages(t) {
        return String(t || "").replace(/<img\b[^>]*>/gi, "")
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
