// =============================================================================
// LockScreen.qml — the lock surface content (one instance per monitor)
// =============================================================================
// Hosted either by a WlSessionLockSurface (real lock) or a plain PanelWindow
// (VELOCITY_LOCK_PREVIEW). P6.4 glyph identity: hero Doto clock + date, a
// greeting, a dot password field, and a mono-caps metadata row (media ·
// power · unread · layout) over a dot rule — all on pure #000. Fonts come
// from the lock's Tokens copy (display = Doto, ui = Space Grotesk, mono =
// Space Mono); sizes stay explicit — the lock is a fixed full-screen design,
// nothing here scales with uiScale.
//
// QD-OLED doctrine on a surface that can sit for HOURS:
//   · nothing renders brighter than the accent at 0.55 alpha (typing dots —
//     transient, user-driven; the surface is EMPTY at rest except dim text)
//   · the accent appears ONLY on the input dots and errors — the metadata
//     row is always textDim (P6.4 spec)
//   · the clock block dims to 0.40 after 10 s without input (idleDim)
//   · a slow orbit (±2 px every 3 min) wanders the WHOLE stage — clock,
//     field and the metadata row — so no pixel row burns (skipped under
//     reduceMotion)
//   · the caret blink Timer runs only while the user is active
//   · entry fades in ≤ 250 ms; a successful auth fades the surface out
//     before the lock releases (reduceMotion → both collapse to instant)
// Data policy — the lock never probes while locked: one `cat` each for the
// weather cache and the notification store at startup, plus the one Hyprland
// socket2 stream for the keyboard layout (events only, no polling forks).
// Media and battery are NATIVE bindings (Quickshell.Services.Mpris / UPower)
// — event-driven, zero forks. Media shows only while playing (privacy: a
// paused title says what you were watching).
//
// AUTH: PamContext against the "velocity-lock" PAM service (NixOS module in
// omni-nix). Flow (per the PamContext contract): submit → start() (if not
// active) → respond() once responseRequired arrives → completed(result).
// Success fades out, then emits unlockRequested(); failure shakes the dots
// and counts the attempt. Preview mode never starts a conversation.
// =============================================================================

import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Io

Rectangle {
    id: root

    property bool preview: false
    signal unlockRequested()

    color: LockConfig.bg
    opacity: 0                    // fadeIn walks this to 1 on completion

    // Preview is a QA overlay, NOT a lock — it must always be escapable. A
    // preview left running grabbed exclusive keyboard focus, printed
    // "nothing is locked", and had no exit: the user typed their password
    // into it ("preview — auth disabled"), nothing else answered, and the
    // session had to be rebooted (2026-10-30 lockout). Escape ends it.
    // The REAL lock never gets this — its only exit is PAM success.
    Shortcut {
        sequences: ["Escape"]
        enabled: root.preview
        onActivated: Qt.quit()
    }

    // ── auth state ───────────────────────────────────────────────────────────
    property bool checking: false          // a PAM conversation is in flight
    property int _attempts: 0              // failed conversations this session
    property string _hint: ""              // bottom hint line (empty = nothing)
    property bool _hintIsError: false
    property string _queued: ""            // password waiting for responseRequired
    property string _kbLayout: ""          // from socket2 activelayout events only

    // ── idle / burn-in state ─────────────────────────────────────────────────
    property bool idleDimmed: false        // 10 s without input → clock at 0.40
    onIdleDimmedChanged: if (idleDimmed) caretTimer.stop()   // blink is "not while dimmed" (caretTimer uses restart(), so its running can't take a binding — the dim transition is the stop path; _bump restarts it)
    property int _orbitStep: 0             // 4-step ±2 px wander, 3 min per step

    // ── read-only data lines (one-shot cats at startup) ──────────────────────
    property string _weatherLine: ""
    property bool _weatherStale: false
    property int _unread: 0

    // ── media (Mpris, read-only) + power (UPower) — native bindings ─────────
    property var _players: []
    Connections {
        target: Mpris.players
        function onValuesChanged() { root._players = Mpris.players.values || [] }
    }
    // Reading each player's properties here wires the per-player notifies, so
    // track/play flips propagate without a timer (MprisService pattern).
    readonly property var _activePlayer: {
        const players = root._players
        let first = null
        for (let i = 0; i < players.length; i++) {
            const p = players[i]
            if (p.isPlaying) return p
            if (first === null) first = p
        }
        return first
    }
    readonly property bool _mediaPlaying: _activePlayer !== null && _activePlayer.isPlaying
    readonly property string _mediaTitle: _mediaPlaying && _activePlayer.trackTitle ? _activePlayer.trackTitle : ""
    readonly property string _mediaArtist: _mediaPlaying && _activePlayer.trackArtist ? _activePlayer.trackArtist : ""

    readonly property var _battery: {
        const devs = UPower.devices.values || []
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i]
            if (d.isPresent && d.powerSupply) return d
        }
        return null
    }
    readonly property string _powerLine: {
        if (_battery === null) return "AC POWER"
        const pct = Math.round(_battery.percentage) + "%"
        if (_battery.state === UPowerDevice.Charging) return "CHARGING · " + pct
        if (_battery.state === UPowerDevice.FullyCharged) return pct
        return pct
    }

    // The bottom metadata line — the glyph " · "-separated mono-caps row.
    // Media segment only while something is actually playing.
    function _metaLine() {
        let parts = []
        if (_mediaPlaying && _mediaTitle !== "")
            parts.push("NOW PLAYING · " + _mediaTitle +
                       (_mediaArtist !== "" ? " — " + _mediaArtist : ""))
        parts.push(_powerLine)
        if (_unread > 0) parts.push(_unread + " UNREAD")
        if (_kbLayout !== "") parts.push(_kbLayout)
        return parts.join("   ·   ")
    }

    // ── clock face (J4) — mirrors nikos.clock via LockConfig's settings read ──
    // Doto (ROND 100) on the hero clock only — the ≥ Tokens.minDisplayPx rule;
    // the dot grid is illegible smaller. Colon blink is the plugin's
    // `colonBlink` setting; opacity-only (no text swap → no reflow), resets to
    // visible when disabled.
    readonly property bool _clockDot: LockConfig.clockDot
    readonly property bool _clockBlink: LockConfig.clockBlink
    property bool _colonOn: true
    Timer {
        interval: 530; repeat: true
        running: root._clockBlink
        onRunningChanged: if (!running) root._colonOn = true
        onTriggered: root._colonOn = !root._colonOn
    }

    // Doto axes for the hero clock: ROND 100 = full round dots; wght 500 ≈
    // the regular-weight presence the plain face has at this size.
    readonly property var _dotAxes: ({ "ROND": 100, "wght": 500 })

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
        font.family: Tokens.fontMono
        onTextChanged: root._bump()
        Keys.onPressed: root._bump()
        onAccepted: root._submit()
    }

    Component.onCompleted: {
        root._players = Mpris.players.values || []
        field.forceActiveFocus()
        idleTimer.restart()
        caretTimer.restart()
        fadeIn.restart()
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
                root._unlock()
            } else {
                root._attempts += 1
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

    // Success: release IMMEDIATELY (P5 contract — proven live 2026-10-30
    // 13:19; a 180 ms fade-out on this path wedged the session for 90 min:
    // PAM reported success, the fade animation never delivered onStopped,
    // unlockRequested never fired, and the lock client sat alive holding the
    // ext_session_lock). Unlock is the last safety-critical act — it gets no
    // animation. The fade-in (entry polish) stays.
    function _unlock() {
        root.unlockRequested()
    }

    NumberAnimation {
        id: fadeIn
        target: root; property: "opacity"; from: 0; to: 1
        duration: LockConfig.dur(220)      // spec: fade-in under 250 ms
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

    property Timer idleTimer: Timer {      // 10 s to the burn-in dim (P6.4)
        interval: 10000
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

    // Keyboard layout — socket2 EVENT stream only (spec: no fork). The meta
    // segment stays absent until the first layout switch is observed.
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

    // The stage carries the orbit offsets so EVERY rendered block wanders
    // together (QD-OLED: the metadata row is static text at rest — it must
    // not sit on one pixel grid while the surface is locked for hours).
    Item {
        id: stage
        anchors.fill: parent

        // The offsets live on an INNER item: anchors beat x/y, so binding
        // them on the anchored stage itself was dead code (the two-grim
        // comparison in the P6 TEST caught it — four shots, zero shift).
        // Width/height (not anchors.fill) keeps this item's x/y free.
        Item {
            id: orbitStage
            width: parent.width
            height: parent.height
            x: [0, 2, 0, -2][root._orbitStep]
            y: [0, 1, 2, 1][root._orbitStep]

        // ── center block: clock / date / weather / greeting ─────────────────
        // The 10 s dim IS this whole block (clock spec: ≤ 40 % after idle) —
        // dimming once here, not per-child (nested factors multiply).
        Item {
            id: centerBlock
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -60   // hero sits a touch high; the field owns the lower half
            width: parent.width
            height: childrenRect.height

            Column {
                width: parent.width
                spacing: 18
                opacity: root.idleDimmed ? 0.40 : 1.0
                Behavior on opacity { NumberAnimation { duration: LockConfig.dur(600) } }

                // HH : MM as three Texts — the middle is the blinkable colon
                // (J4). Plain face falls back to the mono token.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0
                    Text {
                        text: Qt.formatDateTime(clock.date, "HH")
                        color: LockConfig.text
                        font.family: root._clockDot ? Tokens.fontDisplay : Tokens.fontMono
                        font.variableAxes: root._clockDot ? root._dotAxes : ({})
                        font.pixelSize: 104
                        font.letterSpacing: 6
                    }
                    Text {
                        text: ":"
                        color: LockConfig.text
                        opacity: root._clockBlink ? (root._colonOn ? 1 : 0.12) : 1
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        font.family: root._clockDot ? Tokens.fontDisplay : Tokens.fontMono
                        font.variableAxes: root._clockDot ? root._dotAxes : ({})
                        font.pixelSize: 104
                        font.letterSpacing: 6
                    }
                    Text {
                        text: Qt.formatDateTime(clock.date, "mm")
                        color: LockConfig.text
                        font.family: root._clockDot ? Tokens.fontDisplay : Tokens.fontMono
                        font.variableAxes: root._clockDot ? root._dotAxes : ({})
                        font.pixelSize: 104
                        font.letterSpacing: 6
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd  ·  d MMMM")
                    color: LockConfig.textDim
                    font.family: Tokens.fontMono
                    font.pixelSize: 20
                    font.letterSpacing: 4
                    font.capitalization: Font.AllUppercase
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root._weatherLine !== ""
                    text: root._weatherLine + (root._weatherStale ? "  ·  old" : "")
                    color: root._weatherStale ? LockConfig.textDim : LockConfig.text
                    opacity: 0.8
                    font.family: Tokens.fontMono
                    font.pixelSize: 16
                    font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase
                }
                // the greeting — the one prose line (Space Grotesk light)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        const h = new Date(clock.date).getHours()
                        const word = h < 5 ? "Good night" : h < 12 ? "Good morning"
                                   : h < 18 ? "Good afternoon" : "Good evening"
                        return word + ", " + Quickshell.env("USER") + "."
                    }
                    color: LockConfig.text
                    opacity: 0.9
                    font.family: Tokens.fontUi
                    font.variableAxes: ({ "wght": 300 })
                    font.pixelSize: 34
                }
            }
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        // ── field block: password dots + hint + attempts ─────────────────────
        // Empty at rest (nothing static to burn); dots exist only while there
        // is a buffer.
        Item {
            id: bottomBlock
            anchors.bottom: orbitStage.bottom
            anchors.bottomMargin: 190
            x: parent.width / 2 - width / 2
            width: parent.width
            height: 120

            SequentialAnimation {
                id: shakeAnim
                running: false
                NumberAnimation { target: bottomBlock; property: "anchors.bottomMargin"; from: 190; to: 196; duration: LockConfig.dur(60) }
                NumberAnimation { target: bottomBlock; property: "anchors.bottomMargin"; from: 196; to: 184; duration: LockConfig.dur(80) }
                NumberAnimation { target: bottomBlock; property: "anchors.bottomMargin"; from: 184; to: 190; duration: LockConfig.dur(60) }
            }

            Row {
                id: dots
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
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
                font.family: Tokens.fontMono
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
                font.family: Tokens.fontMono
                font.pixelSize: 17
                font.letterSpacing: 2
            }

            Text {
                visible: root._attempts > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: dots.bottom
                anchors.topMargin: root._hint !== "" ? 48 : 22
                text: "ATTEMPT · " + root._attempts
                color: LockConfig.textDim
                opacity: 0.8
                font.family: Tokens.fontMono
                font.pixelSize: 14
                font.letterSpacing: 3
                font.capitalization: Font.AllUppercase
                Behavior on anchors.topMargin { NumberAnimation { duration: LockConfig.dur(120) } }
            }

            Text {
                visible: root._hint === "" && root._attempts === 0 && !root.checking
                         && field.text.length === 0 && !root.preview
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: dots.bottom
                anchors.topMargin: 22
                text: "password"
                color: LockConfig.textDim
                opacity: root.idleDimmed ? 0.35 : 0.6
                font.family: Tokens.fontMono
                font.pixelSize: 17
                font.letterSpacing: 2
            }

            Text {
                visible: root.preview
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: dots.bottom
                anchors.topMargin: root._attempts > 0 ? 48 : 22
                text: "PREVIEW — nothing is locked · esc exits"
                color: LockConfig.textDim
                font.family: Tokens.fontMono
                font.pixelSize: 15
                font.letterSpacing: 2
            }
        }

        // ── metadata row: dot rule + media · power · unread · layout ────────
        // All textDim (the accent lives ONLY on the input dots and errors),
        // mono caps, glyph " · " separators. Fades with the idle dim.
        Item {
            id: metaBlock
            anchors.bottom: orbitStage.bottom
            anchors.bottomMargin: 56
            x: parent.width / 2 - width / 2
            width: parent.width
            height: 60
            opacity: root.idleDimmed ? 0.40 : 0.9
            Behavior on opacity { NumberAnimation { duration: LockConfig.dur(600) } }

            Text {
                id: metaText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                text: root._metaLine()
                visible: root._metaLine() !== ""
                color: LockConfig.textDim
                font.family: Tokens.fontMono
                font.pixelSize: 14
                font.letterSpacing: 3
                font.capitalization: Font.AllUppercase
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, root.width - 80)
            }

            DotRule {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: metaText.top
                anchors.bottomMargin: 20
                width: Math.min(root.width * 0.42, 460)
                dotColor: "#1c1c1c"        // ≤ 3 % luminance, palette-independent
            }
        }
    }
    }
}
