// GENERATED from shared/components/CardSlider.qml by tools/sync-shared — do not edit
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
// DRAG-OWNERSHIP LAW (the trailing-handle bug): `value` follows the source
// through an IMPERATIVE gated write (the Connections inside the slider), NOT
// a plain `value:` binding and NOT a Binding{when;delayed} proxy. A plain
// binding re-applies the source on every async ack mid-drag — PipeWire volume
// round-trips land a frame+ late and int-rounded, so the handle kept snapping
// back under the cursor ("falls behind"). The proxy variant had its own bug:
// `delayed` retains a pending write queued mid-drag, and at release `pressed`
// flips false inside Qt input handling — `when` transiently re-evaluates true
// before `_isFollowing` shuts the gate on the next line, so the proxy flushed
// the stale echo and the handle slammed back off the cursor on every drag.
// The imperative follower guards with live values at signal time: mid-drag
// echoes are simply dropped, nothing is retained to flush. While pressed the
// drag owns value; after release the gate stays shut until the source ECHOES
// the committed value (the resync timer re-checks every RESYNC_MS, echo =
// within ±0.5 of the commit) — a fixed hold re-arms against a stale frame
// whenever the ack trails it, and Bluetooth/AVRCP acks trail by hundreds of
// ms. MAX_RESYNC_TRIES is the starvation cap (~1.65s worst-case hold): past
// it the source re-applies even unacked (a rejected/clamped write), so
// external changes never starve the control.
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
    // Ack-wait cap (resyncMs ticks) for sources that never echo the commit —
    // past it the source re-applies anyway so it can't starve the control.
    readonly property int maxResyncTries: 10

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

        // Pointer affordance — the repo idiom (HoverGlyph, ListRow,
        // CardToggle…) shows a pointing hand over every interactive element;
        // the bare QQC2 Slider shows none, so the popup's slider read as
        // non-interactive.
        HoverHandler { cursorShape: Qt.PointingHandCursor }

        // ── drag-ownership gate (see header) ──
        property bool _isFollowing: true
        // What the drag last committed — the re-arm gate waits for the source
        // to echo THIS value, not just any elapsed time.
        property real _lastCommit: 0
        // Imperative follower (probe-verified): see header — a Binding
        // {when;delayed} proxy retains a mid-drag pending write and flushes
        // it at release; an explicit write guarded with live values just
        // drops mid-drag echoes instead.
        Connections {
            target: root
            function onValueChanged() {
                console.log("[CardSlider:" + root.objectName + "] echo v=" + root.value.toFixed(1)
                            + " pressed=" + s.pressed + " following=" + s._isFollowing
                            + " s.value=" + s.value.toFixed(1))
                if (s._isFollowing && !s.pressed) s.value = root.value
            }
        }
        Component.onCompleted: {
            console.log("[CardSlider:" + root.objectName + "] completed v=" + root.value.toFixed(1))
            if (s._isFollowing && !s.pressed) s.value = root.value
        }
        Timer {
            id: resync
            interval: root.resyncMs
            property int _tries: 0
            onTriggered: {
                // TEMP TRACE (drag diagnosis) — remove once the bug is pinned.
                console.log("[CardSlider:" + root.objectName + "] resync tick root=" + root.value.toFixed(1)
                            + " lastCommit=" + s._lastCommit.toFixed(1)
                            + " tries=" + _tries)
                // Re-arm only once the source has acked the commit (or the
                // cap hits): re-arming against a stale frame is what yanked
                // the handle back off the user's value after release.
                // ±0.5 is tuned to 0–100 callers — a 0..1-scale source needs
                // a tighter threshold or the echo matches too early.
                if (Math.abs(root.value - s._lastCommit) <= 0.5 || _tries >= root.maxResyncTries) {
                    s._isFollowing = true
                    _tries = 0
                } else {
                    _tries++
                    restart()
                }
            }
        }

        onMoved: {
            root.dragged(value)
            // TEMP TRACE (drag diagnosis) — remove once the bug is pinned.
            console.log("[CardSlider:" + root.objectName + "] moved v=" + value.toFixed(1)
                        + " pos=" + s.position.toFixed(3)
                        + " w=" + s.width.toFixed(1)
                        + " avail=" + s.availableWidth.toFixed(1))
        }
        onWidthChanged: console.log("[CardSlider:" + root.objectName
                                    + "] WIDTH=" + s.width.toFixed(1))
        onPressedChanged: {
            console.log("[CardSlider:" + root.objectName + "] pressed=" + pressed
                        + " v=" + value.toFixed(1))
            if (!pressed) {
                root.committed(value)
                s._lastCommit = value
                s._isFollowing = false
                resync._tries = 0
                resync.restart()
            }
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
