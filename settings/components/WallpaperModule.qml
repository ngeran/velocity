// =============================================================================
// WallpaperModule.qml — Wallpaper Settings Module
// =============================================================================
//
// OLED-minimal wallpaper management interface.
// Features:
//   - Auto-cycle toggle with interval control
//   - Transition effect selection
//   - Directory selection with reload
//   - Visual thumbnail grid preview
//   - Manual wallpaper selection
//   - Real-time status display
//
// =============================================================================

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config
import "../utils" as Utils
import "../config" as SharedConfig

Item {
    id: root

    // =========================================================================
    // STATE
    // =========================================================================

    property var wallpaperList: []
    property string currentWallpaper: ""
    property int cycleInterval: 300        // seconds
    property bool cyclingEnabled: true
    property string wallpaperDir: ""
    property string transitionType: "outer"
    property bool scanInProgress: false
    property bool applyInProgress: false

    // =========================================================================
    // SHARED STATE UPDATES
    // =========================================================================

    function updateSharedState() {
        SharedConfig.SharedState.updateWallpaper(
            root.currentWallpaper,
            root.cyclingEnabled,
            root.cycleInterval,
            root.transitionType,
            root.wallpaperList.length
        )
    }

    // Start/stop/restart the auto-cycle timer to match the current state.
    // Called whenever cyclingEnabled / cycleInterval / the wallpaper list change.
    function _applyCycleTimer() {
        if (root.cyclingEnabled && root.wallpaperList.length > 1) {
            if (cycleTimer.running) cycleTimer.restart()
            else cycleTimer.start()
        } else {
            cycleTimer.stop()
        }
    }

    // Update shared state when these properties change
    onCurrentWallpaperChanged: updateSharedState()
    onCyclingEnabledChanged: { updateSharedState(); root._applyCycleTimer() }
    onCycleIntervalChanged: {
        updateSharedState()
        cycleTimer.interval = Math.max(10, root.cycleInterval) * 1000
        root._applyCycleTimer()
    }
    onTransitionTypeChanged: updateSharedState()
    onWallpaperListChanged: { updateSharedState(); root._applyCycleTimer() }

    // =========================================================================
    // CONFIG PERSISTENCE
    // =========================================================================

    Utils.ConfigPersistence {
        id: configPers

        Component.onCompleted: {
            // Set config path to ~/.config/quickshell/settings/wallpaper-config.json
            homePathGetter.running = true
        }
    }

    Process {
        id: homePathGetter
        command: ["sh", "-c", "echo $HOME"]

        property string buf: ""

        stdout: SplitParser {
            onRead: data => { homePathGetter.buf += data }
        }

        onRunningChanged: {
            if (!running) {
                configPers.configPath = homePathGetter.buf.trim() + "/.config/quickshell/settings/wallpaper-config.json"
                homePathGetter.buf = ""
                // Load settings after setting path
                loadSettings()
            }
        }
    }

    // Save settings when they change
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: saveSettings()
    }

    // Auto-cycle timer — rotates to a random wallpaper every cycleInterval when
    // cycling is enabled. Controlled imperatively via _applyCycleTimer() (running
    // is intentionally NOT bound, to avoid binding/restart() conflicts).
    Timer {
        id: cycleTimer
        interval: Math.max(10, root.cycleInterval) * 1000
        repeat: true
        running: false
        onTriggered: { console.log("[timer] auto-cycle fired"); root.cycleNow() }
    }

    function saveSettings() {
        var data = {
            cycleInterval: root.cycleInterval,
            cyclingEnabled: root.cyclingEnabled,
            transitionType: root.transitionType,
            wallpaperDir: root.wallpaperDir,
            currentWallpaper: root.currentWallpaper
        }
        configPers.save(data)
    }

    function loadSettings() {
        configPers.onLoaded = function(data) {
            if (data.cycleInterval !== undefined)
                root.cycleInterval = data.cycleInterval
            if (data.cyclingEnabled !== undefined)
                root.cyclingEnabled = data.cyclingEnabled
            if (data.transitionType !== undefined)
                root.transitionType = data.transitionType
            if (data.wallpaperDir !== undefined && data.wallpaperDir.length > 0) {
                root.wallpaperDir = data.wallpaperDir
                // Trigger refresh with loaded directory
                refreshWallpapers()
            }
            if (data.currentWallpaper !== undefined)
                root.currentWallpaper = data.currentWallpaper

            console.log("[WallpaperModule] Settings loaded")
            root._applyCycleTimer()
        }
        configPers.load()
    }

    // =========================================================================
    // BACKGROUND
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        homeGetter.running = true
    }

    // =========================================================================
    // HOME DIRECTORY RESOLVER
    // =========================================================================

    Process {
        id: homeGetter
        command: ["sh", "-c", "echo $HOME"]

        property string buf: ""

        stdout: SplitParser {
            onRead: data => { homeGetter.buf += data }
        }

        onRunningChanged: {
            if (!running) {
                root.wallpaperDir = homeGetter.buf.trim() + "/Pictures/Wallpapers/"
                homeGetter.buf = ""
                refreshWallpapers()
            }
        }
    }

    // =========================================================================
    // WALLPAPER DIRECTORY SCANNER
    // =========================================================================

    function refreshWallpapers() {
        if (root.scanInProgress) return
        if (root.wallpaperDir.length === 0) return
        console.log("[WallpaperModule] Scanning:", root.wallpaperDir)
        root.scanInProgress = true

        scanner.command = [
            "find", root.wallpaperDir,
            "-maxdepth", "1",
            "-type",     "f",
            "(", "-iname", "*.jpg",
                 "-o", "-iname", "*.jpeg",
                 "-o", "-iname", "*.png",
                 "-o", "-iname", "*.webp",
            ")"
        ]
        scanner.running = true
    }

    // =========================================================================
    // FILE WATCHER — Auto-refresh when wallpapers are added
    // =========================================================================

    Process {
        id: fileWatcher

        command: ["sh", "-c", "inotifywait -m -e create,delete,modify,move " + root.wallpaperDir + " 2>/dev/null || echo"]

        stdout: SplitParser {
            onRead: function(data) {
                // Debounce rapid file system events
                refreshTimer.restart()
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 1000  // 1 second debounce
        onTriggered: refreshWallpapers()
    }

    // =========================================================================
    // WALLPAPER SCANNER
    // =========================================================================

    Process {
        id: scanner

        property string buf: ""

        stdout: SplitParser {
            onRead: data => { scanner.buf += data + "\n" }
        }

        onRunningChanged: {
            if (!running) {
                root.scanInProgress = false
                var lines = scanner.buf.trim().split("\n").filter(function(l) {
                    return l.trim().length > 0
                })
                lines.sort()
                root.wallpaperList = lines
                scanner.buf = ""
                console.log("[WallpaperModule] Found", root.wallpaperList.length, "wallpaper(s)")

                if (root.currentWallpaper.length === 0 && root.wallpaperList.length > 0) {
                    applyWallpaper(root.wallpaperList[0])
                }
            }
        }
    }

    // =========================================================================
    // WALLPAPER FUNCTIONS
    // =========================================================================

    function applyWallpaper(path) {
        console.log("[apply] enter path=" + path)
        if (!path || path.length === 0) return

        console.log("[WallpaperModule] Applying:", path)

        applyProc.command = [
            "awww", "img",  path,
            "--transition-type", root.transitionType,
            "--transition-fps",  "60",
            "--transition-step", "90"
        ]
        applyProc.running     = true
        root.currentWallpaper = path
        saveTimer.restart()
    }

    Process {
        id: applyProc

        onExited: function(exitCode) {
            root.applyInProgress = false
            if (exitCode !== 0)
                console.log("[WallpaperModule] awww failed, exit code:", exitCode)
        }
    }

    function cycleNow() {
        console.log("[cycle] manual cycle called")
        if (root.wallpaperList.length === 0) return

        var newIndex
        var attempts   = 0
        var maxAttempts = Math.min(10, root.wallpaperList.length)

        do {
            newIndex = Math.floor(Math.random() * root.wallpaperList.length)
            attempts++
        } while (newIndex === root.wallpaperList.indexOf(root.currentWallpaper) &&
                 attempts < maxAttempts && root.wallpaperList.length > 1)

        applyWallpaper(root.wallpaperList[newIndex])
    }

    function basename(path) {
        var parts = path.split("/")
        return parts[parts.length - 1]
    }

    // =========================================================================
    // MAIN CONTENT COLUMN
    // =========================================================================

    Column {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 32
            leftMargin: 24
            rightMargin: 24
            bottomMargin: 24
        }
        spacing: 0

        // ── SECTION HEADER ─────────────────────────────────────

        Text {
            text: "WALLPAPERS"
            font.pixelSize: 9
            font.letterSpacing: 2.5
            color: "#2a2a2a"
        }

        Item { height: 16 }

        // ── CONTROLS ROW ──────────────────────────────────────

        Row {
            width: parent.width
            height: 32
            spacing: 8

            // Auto-cycle toggle
            Item {
                width: 80
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    text: root.cyclingEnabled ? "ON" : "OFF"
                    font.pixelSize: 9
                    font.letterSpacing: 1.8
                    color: root.cyclingEnabled ? "#34d399" : "#f87171"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -4
                        height: 1
                        color: root.cyclingEnabled ? "#34d399" : "#f87171"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.cyclingEnabled = !root.cyclingEnabled
                        saveTimer.restart()
                    }
                }
            }

            // Manual cycle button
            Item {
                width: 72
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    text: "CYCLE"
                    font.pixelSize: 9
                    font.letterSpacing: 1.8
                    color: cycleMouse.containsMouse ? "#cccccc" : "#2e2e2e"

                    Rectangle {
                        visible: cycleMouse.containsMouse
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -4
                        height: 1
                        color: "#00dfe5"
                    }
                }

                MouseArea {
                    id: cycleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cycleNow()
                }
            }

            Item { width: 16; height: 1 }

            // Interval control
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: "INTERVAL"
                    font.pixelSize: 9
                    font.letterSpacing: 1.8
                    color: "#2e2e2e"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Decrement button
                Item {
                    width: 24
                    height: 24

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        font.pixelSize: 11
                        color: minusMouse.containsMouse ? "#cccccc" : "#2e2e2e"
                    }

                    MouseArea {
                        id: minusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var steps = [1, 2, 5, 10, 15, 30, 60]
                            var minutes = root.cycleInterval / 60
                            var idx = steps.indexOf(minutes)
                            if (idx > 0) {
                                root.cycleInterval = steps[idx - 1] * 60
                                saveTimer.restart()
                            }
                        }
                    }
                }

                // Interval display
                Item {
                    width: 48
                    height: 24

                    Text {
                        anchors.centerIn: parent
                        text: (root.cycleInterval / 60) + "m"
                        font.pixelSize: 9
                        font.letterSpacing: 1.8
                        color: "#00dfe5"
                    }
                }

                // Increment button
                Item {
                    width: 24
                    height: 24

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 11
                        color: plusMouse.containsMouse ? "#cccccc" : "#2e2e2e"
                    }

                    MouseArea {
                        id: plusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var steps = [1, 2, 5, 10, 15, 30, 60]
                            var minutes = root.cycleInterval / 60
                            var idx = steps.indexOf(minutes)
                            if (idx < steps.length - 1) {
                                root.cycleInterval = steps[idx + 1] * 60
                                saveTimer.restart()
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        Item { height: 16 }

        // ── TRANSITION SELECTION ───────────────────────────────

        Row {
            width: parent.width
            height: 24
            spacing: 16

            Repeater {
                model: [
                    { name: "OUTER", value: "outer" },
                    { name: "FADE", value: "fade" },
                    { name: "WIPE", value: "wipe" },
                    { name: "WAVE", value: "wave" }
                ]

                Item {
                    width: transLabel.implicitWidth + 8
                    height: parent.height

                    Text {
                        id: transLabel
                        anchors.centerIn: parent
                        text: modelData.name
                        font.pixelSize: 9
                        font.letterSpacing: 1.8
                        color: root.transitionType === modelData.value ? "#00dfe5" : "#2e2e2e"

                        Rectangle {
                            visible: root.transitionType === modelData.value
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -4
                            height: 1
                            color: "#00dfe5"
                        }

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.transitionType = modelData.value
                            saveTimer.restart()
                        }
                    }
                }
            }
        }

        Item { height: 16 }

        // ── DIRECTORY ROW ────────────────────────────────────

        Row {
            width: parent.width
            height: 32
            spacing: 8

            // Path input
            Item {
                width: parent.width - 56
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    border.color: "#1a1a1a"
                    border.width: 1
                }

                TextInput {
                    id: dirInput
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 8
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    font.pixelSize: 10
                    font.family: "JetBrains Mono"
                    color: "#cccccc"
                    text: root.wallpaperDir
                    selectByMouse: true

                    onAccepted: {
                        var d = text.trim()
                        if (d.length > 0 && !d.endsWith("/")) d += "/"
                        root.wallpaperDir = d
                        root.wallpaperList = []
                        refreshWallpapers()
                        saveTimer.restart()
                    }
                }
            }

            // Reload button
            Item {
                width: 48
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    text: "LOAD"
                    font.pixelSize: 9
                    font.letterSpacing: 1.8
                    color: reloadMouse.containsMouse ? "#cccccc" : "#2e2e2e"

                    Rectangle {
                        visible: reloadMouse.containsMouse
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -4
                        height: 1
                        color: "#00dfe5"
                    }
                }

                MouseArea {
                    id: reloadMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var d = dirInput.text.trim()
                        if (d.length > 0 && !d.endsWith("/")) d += "/"
                        root.wallpaperDir = d
                        root.wallpaperList = []
                        refreshWallpapers()
                    }
                }
            }
        }

        Item { height: 16 }

        // ── STATUS ROW ────────────────────────────────────────

        Row {
            width: parent.width
            height: 20
            spacing: 16

            Text {
                text: "󰉩 " + root.wallpaperList.length
                font.pixelSize: 9
                font.letterSpacing: 1.8
                color: "#2e2e2e"
            }

            Text {
                visible: !root.cyclingEnabled && root.wallpaperList.length > 0
                text: "CLICK TO APPLY"
                font.pixelSize: 9
                font.letterSpacing: 1.8
                color: "#2e2e2e"
            }

            Text {
                visible: root.scanInProgress
                text: "SCANNING…"
                font.pixelSize: 9
                font.letterSpacing: 1.8
                color: "#00dfe5"
            }

            Item { width: 1; height: 1; Layout.fillWidth: true }

            Text {
                text: root.currentWallpaper.length > 0 ? basename(root.currentWallpaper) : ""
                font.pixelSize: 9
                font.letterSpacing: 1.8
                color: "#00dfe5"
            }
        }

        // ── DIVIDER ──────────────────────────────────────────

        Rectangle {
            width: parent.width
            height: 1
            color: "#1a1a1a"
        }

        Item { height: 16 }

        // ── PREVIEW GRID ──────────────────────────────────────

        Item {
            width: parent.width
            height: parent.height - y

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: root.wallpaperList.length === 0 && !root.scanInProgress
                text: "No images found\nCheck the directory path"
                font.pixelSize: 11
                color: "#2e2e2e"
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }

            // Grid
            GridView {
                anchors.fill: parent
                visible: root.wallpaperList.length > 0

                cellWidth: 200
                cellHeight: 144
                clip: true
                model: root.wallpaperList.length

                delegate: Item {
                    width: 192
                    height: 136

                    property bool isCurrent: root.currentWallpaper === root.wallpaperList[index]

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        color: "transparent"
                        border.color: parent.isCurrent ? "#00dfe5" : "#1a1a1a"
                        border.width: parent.isCurrent ? 2 : 1

                        Image {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                                bottom: nameLabel.top
                                margins: 3
                            }
                            source: "file://" + root.wallpaperList[index]
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true

                            Rectangle {
                                anchors.fill: parent
                                visible: parent.status === Image.Loading || parent.status === Image.Error
                                color: "#0a0a0a"

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.parent.status === Image.Error ? "?" : "…"
                                    font.pixelSize: 10
                                    color: "#2e2e2e"
                                }
                            }
                        }

                        Text {
                            id: nameLabel
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                margins: 3
                            }
                            height: 14
                            text: root.basename(root.wallpaperList[index])
                            font.pixelSize: 8
                            color: parent.parent.isCurrent ? "#00dfe5" : "#2e2e2e"
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // Active indicator dot
                        Rectangle {
                            anchors {
                                top: parent.top
                                right: parent.right
                                margins: 4
                            }
                            visible: parent.parent.isCurrent
                            width: 6
                            height: 6
                            radius: 3
                            color: "#00dfe5"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { console.log("[click] thumbnail idx=" + index); applyWallpaper(root.wallpaperList[index]) }
                    }
                }
            }
        }
    }
}
