// =============================================================================
// NotificationToast.qml — transient arrival banner (top-right, under the bar)
// =============================================================================
// When a notification ARRIVES it pops here for a few seconds (per-urgency
// timer), then slides away — the classic daemon banner this shell was
// missing: arrivals used to be silent (bell pulse + badge only). The store
// rules are unchanged: the row always lands in NotificationService; the
// toast is a VIEW of the arrival, never the record.
//
// Policy (all read off the NotificationService singleton — self-contained):
//   DnD on, panel open, or DnD-silent row → no toast (store only)
//   urgency 0 → 4s · urgency 1 → 6s · urgency 2 → sticky until clicked/✕
//   hover pauses the timer · card click opens the notification center
//   ✕ hides the toast only (row stays unread — badge truth untouched)
//
// Visual: pure black fill + hairline border + 2px urgency edge, radius 0 —
// same tokens as NotificationCard/NotificationCenter. Transient by nature
// (QD-OLED doctrine-lenient) but nothing bright ever sits still.
// =============================================================================

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

PanelWindow {
    id: root

    // ---- visibility control (mirrors NotificationCenter) ----
    property bool shown: false
    visible: false
    function show(row) {
        root.currentRow = row
        if (!root.visible) { root.visible = true; root.shown = true }
        else root.shown = true
        // Re-arm per notification: a replacement resets the clock; critical
        // (>=2) is sticky — it leaves only via click or ✕.
        if ((row.urgency || 0) < 2) {
            dismissTimer.interval = (row.urgency === 0) ? 4000 : 6000
            dismissTimer.restart()
        } else {
            dismissTimer.stop()
        }
        console.log("[toast] show:", (row.appName || "?"), "urgency", (row.urgency === undefined ? 1 : row.urgency))
    }
    function dismiss() {
        if (!root.shown) return
        root.shown = false
        dismissTimer.stop()
        hideTimer.restart()
    }

    signal centerRequested()

    // newest-wins: an arrival while one is showing replaces it (restart above)
    property var currentRow: null

    // What to clear below: injected by the shell as the TALLEST live style
    // window (island chrome runs 32 while barHeight stays 26) — a fixed
    // barHeight+8 left only a 2px gap under the island.
    property int topClearance: Config.BarConfig.barHeight

    anchors { top: true; right: true }
    margins {
        top: root.topClearance + 8
        right: 8
    }
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore   // never shift workspaces for a toast
    // deliberately NOT focusable — a banner must never grab keyboard focus

    // 360 logical, clamped to the output (same clamp math as NotificationCenter)
    readonly property int toastWidth: {
        var w = Config.PopupMetrics.px(360)
        var scr = root.screen
        if (scr && scr.width > 0) w = Math.min(w, scr.width - 16)
        return Math.max(220, w)
    }
    implicitWidth: root.toastWidth
    implicitHeight: toastCard.implicitHeight

    // ---- the card (slides + fades, same curves as the center panel) ----
    Rectangle {
        id: toastCard
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background          // OLED black
        border.width: 1
        border.color: root.currentRow && root.currentRow.urgency === 2
                      ? Config.ThemeConfig.colors.error
                      : Config.ThemeConfig.colors.border
        clip: true
        opacity: root.shown ? 1.0 : 0.0

        // urgency edge — 2px left strip, the card's only ornament
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: !root.currentRow ? Config.ThemeConfig.colors.border
                  : root.currentRow.urgency === 2 ? Config.ThemeConfig.colors.error
                  : root.currentRow.urgency === 0 ? Config.ThemeConfig.colors.textDim
                  : Config.ThemeConfig.colors.primary
        }

        property real hiddenOffset: width + 24
        transform: Translate {
            x: root.shown ? 0 : toastCard.hiddenOffset
            Behavior on x {
                NumberAnimation { duration: Config.MotionConfig.move; easing.type: Easing.OutExpo }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: root.shown ? Config.MotionConfig.swap : Config.MotionConfig.flap; easing.type: Config.MotionConfig.ease }
        }

        implicitHeight: contentRow.implicitHeight + Config.PopupMetrics.px(24)

        MouseArea {
            id: cardMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // hover pauses the clock (moves it to "read later", not "gone")
            onContainsMouseChanged: {
                if (cardMa.containsMouse) dismissTimer.stop()
                else if (root.shown && root.currentRow && (root.currentRow.urgency || 0) < 2) dismissTimer.restart()
            }
            onClicked: {
                root.dismiss()
                root.centerRequested()
            }
        }

        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.margins: Config.PopupMetrics.px(12)
            anchors.leftMargin: Config.PopupMetrics.px(14)   // clear the urgency strip
            spacing: Config.PopupMetrics.px(12)

            // ---- glyph swatch (urgency-tinted, mirrors NotificationCard) ----
            Rectangle {
                Layout.preferredWidth: Config.PopupMetrics.px(26)
                Layout.preferredHeight: Config.PopupMetrics.px(26)
                Layout.alignment: Qt.AlignTop
                color: Config.ThemeConfig.colors.background
                border.width: 1
                border.color: !root.currentRow ? Config.ThemeConfig.colors.border
                              : root.currentRow.urgency === 2 ? Config.ThemeConfig.colors.error
                              : root.currentRow.urgency === 0 ? Config.ThemeConfig.colors.textDim
                              : Config.ThemeConfig.colors.primary
                Text {
                    textFormat: Text.PlainText   // notification text is untrusted — never render HTML
                    anchors.centerIn: parent
                    text: root.currentRow && root.currentRow.glyph ? root.currentRow.glyph : "󰂚"
                    font.family: Config.BarConfig.fontNerd
                    font.pixelSize: Config.PopupMetrics.px(12)
                    color: toastCard.border.color === Config.ThemeConfig.colors.border
                           ? Config.ThemeConfig.colors.primary
                           : toastCard.border.color
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.PopupMetrics.px(3)

                Text {
                    textFormat: Text.PlainText   // notification text is untrusted — never render HTML
                    Layout.fillWidth: true
                    text: root.currentRow ? (root.currentRow.appName || "Notification") : ""
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: Config.PopupMetrics.px(9)
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.6
                    font.family: Config.BarConfig.fontFamily
                    elide: Text.ElideRight
                }
                Text {
                    textFormat: Text.PlainText   // notification text is untrusted — never render HTML
                    visible: root.currentRow && root.currentRow.summary !== ""
                    Layout.fillWidth: true
                    text: root.currentRow ? (root.currentRow.summary || "") : ""
                    color: Config.ThemeConfig.colors.text
                    font.pixelSize: Config.PopupMetrics.px(12)
                    font.bold: true
                    font.family: Config.BarConfig.fontFamily
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
                Text {
                    textFormat: Text.PlainText   // notification text is untrusted — never render HTML
                    visible: root.currentRow && root.currentRow.body !== ""
                    Layout.fillWidth: true
                    text: root.currentRow ? (root.currentRow.body || "") : ""
                    color: Config.ThemeConfig.colors.textDim
                    font.pixelSize: Config.PopupMetrics.px(10)
                    font.family: Config.BarConfig.fontFamily
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    opacity: 0.85
                }
            }

            // ---- ✕ hide (revealed on hover) — toast only, row stays unread ----
            Text {
                textFormat: Text.PlainText   // notification text is untrusted — never render HTML
                text: "✕"
                font.pixelSize: Config.PopupMetrics.px(11)
                font.family: Config.BarConfig.fontFamily
                opacity: cardMa.containsMouse ? 1.0 : 0.0
                color: xMa.containsMouse ? Config.ThemeConfig.colors.error
                                         : Config.ThemeConfig.colors.textDim
                Behavior on opacity { NumberAnimation { duration: 120 } }
                MouseArea {
                    id: xMa
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismiss()
                }
            }
        }
    }

    // per-urgency auto-dismiss (armed by show(); stopped on hover/dismiss)
    Timer {
        id: dismissTimer
        repeat: false
        onTriggered: root.dismiss()
    }
    // defer visible=false until the slide-out finishes (so it can animate)
    Timer {
        id: hideTimer
        interval: 330   // matches the slide duration + buffer (NC's value)
        onTriggered: if (!root.shown) root.visible = false
    }

    // ---- arrival wiring: the toast decides nothing about the store ----
    Connections {
        target: Services.NotificationService
        function onArrived(row) {
            if (Services.NotificationService.dnd) return          // silent mode: store only
            if (Services.NotificationService.panelOpen) return    // user is looking at the list
            if (row && row.silent) return                          // DnD arrival marked per-row
            root.show(row)
        }
    }
}
