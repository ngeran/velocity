// =============================================================================
// CardSlider.qml — the ONE card volume/brightness slider (level-slider port)
// =============================================================================
// CANONICAL FILE — lives in shared/, synced byte-identical into
//   bar/components/CardSlider.qml       (tray-card bodies, Control Center)
//   settings/components/CardSlider.qml  (hosted pages that embed card sliders)
// by tools/sync-shared; drift fails tools/check-shared. Edit here only.
//
// Synced into roots with different singleton import URIs → imports nothing
// from either config tree; colors/scale arrive as properties (bar callers:
// `uiScale: Config.PopupMetrics.scale` + themed colors).
//
// Two signals, two policies: `dragged(v)` fires continuously while the user
// drags (live preview, debounced writers upstream); `committed(v)` fires once
// on release (the P1.5 law — commit only on a real interaction, never from a
// binding re-evaluation). A programmatic `value` change never emits either.
//
// DRAG-OWNERSHIP LAW (the trailing-handle bug): `value` is fed by a Binding
// gated on !pressed, NOT a plain `value:` binding. A plain binding re-applies
// the source on every async ack mid-drag — PipeWire volume round-trips land a
// frame+ late and int-rounded, so the handle kept snapping back under the
// cursor ("falls behind"). While pressed the drag owns value; on release the
// gate stays shut for RESYNC_MS so the stale pre-ack frame can't yank it
// either, then the source (settled by then) re-applies. RestoreNone makes the
// press-time deactivation a strict no-op; delayed coalesces ack bursts.
// OLED: groove is a hairline trough, the fill is the accent ONLY while the
// control is meaningfully interactive (caller can pass dim colors).
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root

    property real value: 0                  // 0..to
    property real from: 0
    property real to: 100
    property bool dim: false
    property string suffix: "%"             // readout tail; "" hides the readout
    property real uiScale: 1.0
    property int stepSize: 0                // 0 = continuous

    // Theme hooks (defaults = the bar's dark tokens; bind over them).
    property color accentColor: "#00dce5"
    property color dimColor: "#6a7a82"
    property color textColor: "#e8edf0"
    property color grooveColor: "#141414"

    signal dragged(real v)
    signal committed(real v)

    // Post-release hold (ms): how long the drag keeps ownership after the
    // press drops, covering the source's ack latency for the final commit.
    readonly property int resyncMs: 150

    spacing: 8 * root.uiScale

    Slider {
        id: s
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: Math.round(24 * root.uiScale)
        from: root.from
        to: root.to
        stepSize: root.stepSize
        opacity: root.dim ? 0.4 : 1.0

        // ── drag-ownership gate (see header) ──
        property bool _isFollowing: true
        Binding on value {
            when: s._isFollowing && !s.pressed
            value: root.value
            delayed: true
            restoreMode: Binding.RestoreNone
        }
        Timer {
            id: resync
            interval: root.resyncMs
            onTriggered: s._isFollowing = true
        }

        onMoved: root.dragged(value)
        onPressedChanged: if (!pressed) {
            root.committed(value)
            s._isFollowing = false
            resync.restart()
        }

        background: Rectangle {
            x: s.leftPadding
            y: s.topPadding + s.availableHeight / 2 - height / 2
            width: s.availableWidth
            implicitHeight: Math.round(6 * root.uiScale)
            radius: height / 2
            color: root.grooveColor
            clip: true

            Rectangle {
                width: s.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: root.dim ? root.dimColor : root.accentColor
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        handle: Rectangle {
            x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
            y: s.topPadding + s.availableHeight / 2 - height / 2
            width: Math.round(14 * root.uiScale)
            height: width
            radius: width / 2
            color: root.dim ? root.dimColor : root.textColor
            scale: s.pressed ? 1.15 : 1.0
            Behavior on scale { NumberAnimation { duration: 90 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    Text {
        visible: root.suffix !== ""
        // The slider's own value, not root.value: during a drag the source
        // lags the handle by its ack latency (drag-ownership law) — the
        // readout must track the handle, and both agree once idle.
        text: Math.round(s.value) + root.suffix
        font.family: "Space Mono"
        font.pixelSize: Math.round(9 * root.uiScale)
        color: root.dim ? root.dimColor : root.textColor
        Layout.preferredWidth: visible ? Math.round(34 * root.uiScale) : 0
        Layout.alignment: Qt.AlignVCenter
        horizontalAlignment: Text.AlignRight
    }
}
