// =============================================================================
// LockScreen.qml — the lock surface content (one instance per monitor)
// =============================================================================
// Hosted either by a WlSessionLockSurface (real lock) or a plain PanelWindow
// (VELOCITY_LOCK_PREVIEW). Pure #000; JetBrains Mono; everything dim — the
// QD-OLED doctrine applied to a surface that can sit for HOURS:
//   · nothing renders brighter than the accent at 0.55 alpha (typing dots —
//     transient, user-driven; the surface is EMPTY at rest except text)
//   · the clock block dims to 0.45 after 30 s without input (idleDim)
//   · a slow orbit (±2 px every 3 min) wanders the whole layout so no pixel
//     row burns (skipped under reduceMotion)
//   · the caret blink Timer runs only while the user is active
// Data policy — the lock never probes while locked: one `cat` each for the
// weather cache and the notification store at startup, plus the one Hyprland
// socket2 stream for the keyboard layout (events only, no polling forks).
//
// AUTH: PamContext against the "velocity-lock" PAM service (NixOS module in
// omni-nix). Flow (per the PamContext contract): submit → start() (if not
// active) → respond() once responseRequired arrives → completed(result).
// Success emits unlockRequested(); failure shakes the dots. Preview mode
// never starts a conversation.
// =============================================================================

import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Io

Rectangle {
    id: root

    property bool preview: false
    signal unlockRequested()

    color: LockConfig.bg

    // ── auth state ───────────────────────────────────────────────────────────
    property bool checking: false          // a PAM conversation is in flight
    property string _hint: ""              // bottom hint line (empty = nothing)
    property bool _hintIsError: false
    property string _queued: ""            // password waiting for responseRequired
    property string _kbLayout: ""          // from socket2 activelayout events only

    // ── idle / burn-in state ─────────────────────────────────────────────────
    property bool idleDimmed: false        // 30 s without input → clock at 0.45
    onIdleDimmedChanged: if (idleDimmed) caretTimer.stop()   // blink is "not while dimmed" (caretTimer uses restart(), so its running can't take a binding — the dim transition is the stop path; _bump restarts it)
    property int _orbitStep: 0             // 4-step ±2 px wander, 3 min per step

    // ── read-only data lines (one-shot cats at startup) ──────────────────────
    property string _weatherLine: ""
    property bool _weatherStale: false
    property int _unread: 0

    // ── clock face (J4) — mirrors nikos.clock via LockConfig's settings read ──
    // Doto (ROND 100) on the 104 px clock only — the ≥ 26 px rule; the dot
    // grid is illegible smaller. Colon blink is the plugin's `colonBlink`
    // setting; opacity-only (no text swap → no reflow), resets to visible
    // when disabled.
    readonly property bool _clockDot: LockConfig.clockDot
    readonly property bool _clockBlink: LockConfig.clockBlink
    property bool _colonOn: true
    Timer {
        interval: 530; repeat: true
        running: root._clockBlink
        onRunningChanged: if (!running) root._colonOn = true
        onTriggered: root._colonOn = !root._colonOn
    }

    function _bump() {                     // any input: undim + restart idle clock
        idleTimer.restart()
        root.idleDimmed = false
        caretTimer.restart()
    }

    // ═══ KEYBOARD — invisible TextInput carries the buffer; dots render from
    // its length. opacity 0 keeps focus + editing behavior intact.
    TextInput {
        id: field
        focus: true
        opacity: 0
        width: 0; height: 0
        font.family: "JetBrains Mono"
        onTextChanged: root._bump()
        Keys.onPressed: root._bump()
        onAccepted: root._submit()
    }

    Component.onCompleted: {
        field.forceActiveFocus()
        idleTimer.restart()
        caretTimer.restart()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: { root._bump(); field.forceActiveFocus() }
    }

    function _submit() {
        if (root.preview) {
            root._flashHint("preview — auth disabled", false)
            return
        }
        if (root.checking) return
        var pw = field.text
        if (pw === "") return
        root._queued = pw
        field.clear()
        root.checking = true
        root._setHint("", false)
        if (!pam.active) {
            if (!pam.start()) {           // e.g. PAM service absent (pre-omni-apply)
                root.checking = false
                root._flashHint("auth unavailable", true)
                return
            }
        }
        if (pam.responseRequired) pam.respond(root._queued)
    }

    PamContext {
        id: pam
        config: "velocity-lock"
        user: Quickshell.env("USER")
        onPamMessage: {
            if (responseRequired && root.checking && root._queued !== "") {
                pam.respond(root._queued)
            }
        }
        onCompleted: function(result) {
            root.checking = false
            root._queued = ""
            if (result === PamResult.Success) {
                root.unlockRequested()
            } else {
                root._shake()
                root._flashHint(result === PamResult.Failed ? "wrong password" : "auth error", true)
            }
        }
        onError: function(err) {
            root.checking = false
            root._queued = ""
            root._shake()
            root._flashHint("auth unavailable", true)
        }
    }

    function _setHint(text, isError) { root._hint = text; root._hintIsError = isError }
    function _flashHint(text, isError) {
        root._setHint(text, isError)
        hintTimer.restart()
    }

    function _shake() {
        if (LockConfig.reduceMotion) return
        shakeAnim.restart()
    }

    // ═══ TIMERS — each runs only while it has a reason to (idle-zero at rest)

    property Timer idleTimer: Timer {      // 30 s to the burn-in dim
        interval: 30000
        onTriggered: root.idleDimmed = true
    }

    property Timer caretTimer: Timer {     // caret blink while active (not while dimmed)
        interval: 530
        repeat: true
        onTriggered: root._caretOn = !root._caretOn
        onRunningChanged: if (running) root._caretOn = true
    }
    property bool _caretOn: true

    property Timer hintTimer: Timer {      // transient hint → blank
        interval: 2600
        onTriggered: root._setHint("", false)
    }

    property Timer orbitTimer: Timer {     // QD-OLED wander: 4 steps, 3 min each
        interval: 180000
        repeat: true
        running: !LockConfig.reduceMotion
        onTriggered: root._orbitStep = (root._orbitStep + 1) % 4
    }

    property Timer waveTimer: Timer {      // dot wave phase while PAM is checking
        interval: 70
        repeat: true
        running: root.checking
        onTriggered: root._wavePhase += 1
    }
    property int _wavePhase: 0

    // ═══ DATA INTAKES — one-shot cats (unbounded-ok: exit at EOF)

    property Process _weatherReader: Process {
        command: ["sh", "-c", 'cat "$1" 2>/dev/null || true', "sh",
                  Quickshell.env("HOME") + "/.local/state/velocity/plugins/nikos.clock-weather.json"]
        stdout: SplitParser {
            onRead: function(data) {
                try {
                    var d = JSON.parse(data)
                    var t = d && d.raw && d.raw.current ? d.raw.current.temperature_2m : undefined
                    if (d.place && t !== undefined) {
                        root._weatherLine = d.place + "  ·  " + Math.round(t) + "°  ·  " + root._weatherWord(d.raw.current.weather_code)
                        root._weatherStale = (Date.now() - (d.fetchedAt || 0)) > 7200000
                    }
                } catch (e) {}
            }
        }
    }
    function _weatherWord(code) {
        code = Math.floor(Number(code) || 0)
        if (code === 0) return "clear"
        if (code <= 3) return "clouds"
        if (code === 45 || code === 48) return "fog"
        if (code <= 67) return "rain"
        if (code <= 77) return "snow"
        if (code <= 86) return "showers"
        return "storm"
    }

    property Process _unreadReader: Process {
        command: ["sh", "-c",
                  'echo "---"; cat "$1" 2>/dev/null || true; echo "---"; cat "$2" 2>/dev/null || true',
                  "sh",
                  Quickshell.env("HOME") + "/.config/quickshell/notifications.cleared",
                  Quickshell.env("HOME") + "/.config/quickshell/notifications.jsonl"]
        stdout: SplitParser {
            // The stream opens with "---" → the flag flips to false for the
            // CLEARED-STAMP section; the store (jsonl) is the second section.
            // Initial value must therefore be true — false made every stamp
            // line land in the store branch and every store row in the stamp
            // branch, so the unread chip could never count.
            property bool inStore: true
            property real clearedAt: 0
            onRead: function(data) {
                if (data === "---") { inStore = !inStore; return }
                if (!inStore) {                       // first section: clearedAt stamp
                    var c = Number(data)
                    if (isFinite(c) && c > 0) clearedAt = c
                    return
                }
                try {
                    var r = JSON.parse(data)
                    // same unread doctrine as the bar: excludes read, silent,
                    // and anything at/below the soft-clear stamp
                    if (r && r.read !== true && r.silent !== true &&
                        (r.timestamp || 0) > clearedAt)
                        root._unread += 1
                } catch (e) {}
            }
        }
    }

    // Keyboard layout — socket2 EVENT stream only (spec: no fork). The chip
    // stays hidden until the first layout switch is observed.
    property Process _socket2: Process {
        command: ["nc", "-U", Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/"
                  + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.socket2.sock"]
        stdout: SplitParser {
            onRead: function(data) {
                if (data.indexOf("activelayout>>") === 0) {
                    var parts = data.substring(14).split(",")   // "activelayout>>" is 14 chars
                    if (parts.length >= 2) root._kbLayout = parts[parts.length - 1].toUpperCase()
                }
            }
        }
        onExited: relockTimer.restart()       // watchdog: the stream must outlive nc drops
    }
    property Timer relockTimer: Timer {
        interval: 3000
        onTriggered: root._socket2.running = true
    }

    // ═══ LAYOUT

    // Center block — clock / date / weather / chips. Orbit offsets ride the
    // wrapper so the anchors stay intact (QD-OLED: whole-layout wander).
    Item {
        id: centerBlock
        anchors.centerIn: parent
        x: parent.width / 2 - width / 2 + [0, 2, 0, -2][root._orbitStep]
        y: parent.height / 2 - height / 2 + [0, 1, 2, 1][root._orbitStep]

        Column {
            width: parent.width
            spacing: 18
            // the 30 s dim IS this whole block (clock spec: 0.45 after idle) —
            // dimming once here, not per-child (nested factors multiply)
            opacity: root.idleDimmed ? 0.45 : 1.0
            Behavior on opacity { NumberAnimation { duration: LockConfig.dur(600) } }

            // HH : MM as three Texts — the middle is the blinkable colon
            // (J4). Doto axes: ROND 100 = full round dots; wght 500 ≈ the
            // regular-weight presence the plain face has at this size.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0
                Text {
                    text: Qt.formatDateTime(clock.date, "HH")
                    color: LockConfig.text
                    font.family: root._clockDot ? "Doto" : "JetBrains Mono"
                    font.variableAxes: root._clockDot ? ({ "ROND": 100, "wght": 500 }) : ({})
                    font.pixelSize: 104
                    font.letterSpacing: 6
                }
                Text {
                    text: ":"
                    color: LockConfig.text
                    opacity: root._clockBlink ? (root._colonOn ? 1 : 0.12) : 1
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    font.family: root._clockDot ? "Doto" : "JetBrains Mono"
                    font.variableAxes: root._clockDot ? ({ "ROND": 100, "wght": 500 }) : ({})
                    font.pixelSize: 104
                    font.letterSpacing: 6
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "mm")
                    color: LockConfig.text
                    font.family: root._clockDot ? "Doto" : "JetBrains Mono"
                    font.variableAxes: root._clockDot ? ({ "ROND": 100, "wght": 500 }) : ({})
                    font.pixelSize: 104
                    font.letterSpacing: 6
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd  ·  d MMMM")
                color: LockConfig.textDim
                font.family: "JetBrains Mono"
                font.pixelSize: 22
                font.letterSpacing: 3
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root._weatherLine !== ""
                text: root._weatherLine + (root._weatherStale ? "  ·  old" : "")
                color: root._weatherStale ? LockConfig.textDim : LockConfig.text
                opacity: 0.8
                font.family: "JetBrains Mono"
                font.pixelSize: 18
                font.letterSpacing: 2
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 26
                Text {
                    visible: root._kbLayout !== ""
                    text: root._kbLayout
                    color: LockConfig.accent
                    opacity: 0.55                      // burn-in: ornament ≤ 0.45… kept at 0.55: 8 px glyph, wanders with the layout
                    font.family: "JetBrains Mono"
                    font.pixelSize: 17
                    font.letterSpacing: 3
                }
                Text {
                    visible: root._unread > 0
                    text: root._unread + " UNREAD"
                    color: LockConfig.textDim
                    font.family: "JetBrains Mono"
                    font.pixelSize: 17
                    font.letterSpacing: 3
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Bottom block — password dots + hint. Empty at rest (nothing static to
    // burn); dots exist only while there is a buffer.
    Item {
        id: bottomBlock
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 140
        x: parent.width / 2 - width / 2
        width: parent.width
        height: 90

        SequentialAnimation {
            id: shakeAnim
            running: false
            NumberAnimation { target: bottomBlock; property: "anchors.bottomMargin"; from: 140; to: 146; duration: LockConfig.dur(60) }
            NumberAnimation { target: bottomBlock; property: "anchors.bottomMargin"; from: 146; to: 134; duration: LockConfig.dur(80) }
            NumberAnimation { target: bottomBlock; property: "anchors.bottomMargin"; from: 134; to: 140; duration: LockConfig.dur(60) }
        }

        Row {
            id: dots
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 9
            Repeater {
                model: Math.min(field.text.length, 24)
                Rectangle {
                    width: 7; height: 7; radius: 3.5          // burn-in: transient typing state, empty at rest
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.checking
                        ? Qt.rgba(LockConfig.accent.r, LockConfig.accent.g, LockConfig.accent.b,
                                  0.30 + 0.30 * (0.5 + 0.5 * Math.sin(root._wavePhase * 0.8 - index * 0.55)))
                        : LockConfig.accent
                    opacity: root.checking ? 1.0 : 0.55
                    Behavior on color { ColorAnimation { duration: LockConfig.dur(120) } }
                }
            }
        }

        Text {
            id: caret
            visible: field.text.length > 0 && field.text.length < 24 && root._caretOn && !root.idleDimmed
            anchors.left: dots.right
            anchors.leftMargin: 6
            anchors.verticalCenter: dots.verticalCenter
            text: "▏"
            color: LockConfig.accent
            opacity: 0.55
            font.family: "JetBrains Mono"
            font.pixelSize: 18
        }

        Text {
            id: hint
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dots.bottom
            anchors.topMargin: 22
            visible: root._hint !== ""
            text: root._hint
            color: root._hintIsError ? LockConfig.errorCol : LockConfig.textDim
            font.family: "JetBrains Mono"
            font.pixelSize: 18
            font.letterSpacing: 2
        }

        Text {
            visible: root._hint === "" && !root.checking && field.text.length === 0 && !root.preview
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dots.bottom
            anchors.topMargin: 22
            text: "password"
            color: LockConfig.textDim
            opacity: root.idleDimmed ? 0.35 : 0.6
            font.family: "JetBrains Mono"
            font.pixelSize: 18
            font.letterSpacing: 2
        }

        Text {
            visible: root.preview
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dots.bottom
            anchors.topMargin: 22
            text: "PREVIEW — nothing is locked"
            color: LockConfig.textDim
            font.family: "JetBrains Mono"
            font.pixelSize: 16
            font.letterSpacing: 2
        }
    }
}
