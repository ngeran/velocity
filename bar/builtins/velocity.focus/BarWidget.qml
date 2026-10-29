// =============================================================================
// velocity.focus — bar pill (plugin ctx 2, service/view split)
// =============================================================================
// Idle: dim timer glyph (ornament ≤ 0.45 — QD-OLED doctrine). Running: the
// glyph lights up in the accent next to the MM:SS countdown, bound from
// ctx.service (the headless ServiceRoot owns all state — this per-output
// view is stateless). Click toggles the session: idle → start
// `defaultMinutes`, running → cancel. Passive handlers only (the
// MouseArea hover-steal trap — see nikos.clock's anchor).
// =============================================================================
import QtQuick

Item {
    id: root

    property var ctx: null

    readonly property var svc: ctx ? ctx.service : null
    readonly property bool isRunning: !!svc && svc.running

    // Idle-pill click starts this many minutes (plugin setting, set-path
    // coerced; falls back when the store hasn't loaded).
    readonly property int defaultMinutes: {
        var v = ctx && ctx.settings.values.defaultMinutes !== undefined
                ? Math.round(Number(ctx.settings.values.defaultMinutes)) : 25
        return (v >= 1 && v <= 180) ? v : 25
    }

    // Overflow contract (engine fit plan): compact keeps the countdown and
    // drops the glyph. A hidden probe measures the widest possible readout
    // ("88:88") in the real font without waiting for the state to change.
    Text {
        id: compactProbe
        visible: false
        text: "88:88"
        font.family: ctx ? ctx.bar.fontFamily : "monospace"
        font.pixelSize: Math.max(9, Math.round(12 * (ctx ? ctx.bar.contentScale : 1)))
        font.bold: true
    }
    readonly property real compactWidth: 8 + compactProbe.implicitWidth

    width: anchorRow.implicitWidth + 20
    height: ctx ? ctx.bar.barHeight : 30

    Rectangle {
        anchors.centerIn: parent
        implicitWidth: anchorRow.implicitWidth + 20
        height: ctx ? ctx.bar.barHeight - 6 : 20
        radius: 6
        // Hover highlight only while the pill is live — idle it reads inert.
        color: root.isRunning && pillHover.hovered
               ? (ctx ? ctx.theme.withAlpha(ctx.theme.colors.text, 0.06) : "transparent")
               : "transparent"
        HoverHandler { id: pillHover }
        TapHandler {
            onTapped: {
                if (!root.svc) return
                if (root.isRunning) root.svc.stop()
                else root.svc.start(String(root.defaultMinutes))
            }
        }

        Row {
            id: anchorRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰥔"
                font.family: ctx ? ctx.bar.fontNerd : "monospace"
                font.pixelSize: Math.max(10, Math.round(13 * (ctx ? ctx.bar.contentScale : 1)))
                // Idle = dim ornament (≤ 0.45); running = accent live readout.
                color: !root.isRunning
                       ? (ctx ? ctx.theme.withAlpha(ctx.theme.colors.text, 0.35) : "#555")
                       : (pillHover.hovered ? (ctx ? ctx.theme.colors.text : "#fff")
                                            : (ctx ? ctx.theme.colors.accent : "#0ff"))
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            Text {
                visible: root.isRunning
                anchors.verticalCenter: parent.verticalCenter
                text: root.svc ? root.svc.remainingLabel : ""
                font.family: ctx ? ctx.bar.fontFamily : "monospace"
                font.pixelSize: Math.max(9, Math.round(12 * (ctx ? ctx.bar.contentScale : 1)))
                font.bold: true
                color: pillHover.hovered ? (ctx ? ctx.theme.colors.text : "#fff")
                                         : (ctx ? ctx.theme.colors.accent : "#0ff")
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }
}
