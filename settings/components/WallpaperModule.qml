import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config
import "../services" as Services

// =============================================================================
// WallpaperModule.qml — "Tactical Gallery" wallpaper command tab
// =============================================================================
// Redesign of the Wallpaper tab to a tactical-HUD layout: a bracketed controls
// bar (still source path / live library path / cycling / interval / effect), a
// real-info sidebar
// (library count, current wallpaper, system memory, matugen toggle), a
// scrollable thumbnail gallery with hover overlays + ACTIVE badges, and a
// status footer. Mirrors the Dashboard's anchored layout so it fits the panel's
// ~656×408 content area without overflow.
//
// HARD CONSTRAINT: every colour reads from Config.ThemeConfig.colors → the tab
// recolours live with the active theme. The mockup's blue/orange/yellow are
// placeholders only.
// =============================================================================

Item {
    id: root

    // =========================================================================
    // STATE (binds to the WallpaperService singleton — reactive)
    // =========================================================================
    readonly property var wallpaperList: Services.WallpaperService.wallpaperList
    readonly property string currentWallpaper: Services.WallpaperService.currentWallpaper
    readonly property int cycleInterval: Services.WallpaperService.cycleInterval > 0 ? Services.WallpaperService.cycleInterval / 1000 : 300
    readonly property bool cyclingEnabled: Services.WallpaperService.cyclingEnabled
    readonly property string transitionType: Services.WallpaperService.transitionType || "outer"
    readonly property string wallpaperDir: Services.WallpaperService.wallpaperDir || (Services.ThemeService.homeDir + "/Pictures/Wallpapers/")
    readonly property bool animPaused: Services.WallpaperService.animationPaused
    // Live library + engine (mpvpaper) state
    readonly property string libraryMode: Services.WallpaperService.libraryMode
    readonly property string liveDir: Services.WallpaperService.liveDir
    readonly property bool engineAvailable: Services.WallpaperService.engineAvailable
    readonly property bool engineRunning: Services.WallpaperService.engineRunning
    readonly property bool enginePaused: Services.WallpaperService.enginePaused
    readonly property int engineInstances: Services.WallpaperService.engineInstances
    readonly property var thumbMap: Services.WallpaperService.thumbMap

    // Editable path buffer (tracks the service dir until the user types).
    property string dirText: root.wallpaperDir
    property string liveDirText: root.liveDir

    // =========================================================================
    // GEOMETRY — panel clamps to 720×480 → content ~656×408. Anchored, with a
    // pinned sidebar width and a clipped gallery, so nothing overflows.
    // =========================================================================
    readonly property real _margin: 12
    readonly property real _gap: 10
    readonly property real _footerH: 24
    readonly property real _innerW: Math.max(0, root.width - 2 * root._margin)
    readonly property real _sidebarW: (root.width > 0)
        ? Math.max(130, Math.min(150, Math.round(root._innerW * 0.22))) : 140

    // Font aliases. (Colour refs use Config.ThemeConfig.colors.* directly — a
    // `var` colour alias does not resolve inside Repeater delegates.)
    readonly property string fMono: Config.ControlConfig.fontMono
    readonly property string fSans: Config.SettingsConfig.fontFamily

    anchors.fill: parent

    // =========================================================================
    // SERVICE FUNCTIONS (direct calls — no IPC)
    // =========================================================================
    function applyWallpaper(path) { Services.WallpaperService.setWallpaperByPath(path) }
    function toggleCycling()       { Services.WallpaperService.toggleCycling() }
    function setTransition(t)      { Services.WallpaperService.setTransition(t) }
    function setAnimPaused(p)      { Services.WallpaperService.setAnimationPaused(p) }
    function isLive(p)             { return Services.WallpaperService.isLive(p) }
    function isEngined(p)          { return Services.WallpaperService.isEngined(p) }
    function setIntervalSec(s)     { Services.WallpaperService.setInterval(s) }
    function refreshWallpapers()   { Services.WallpaperService.refreshList() }
    function setLibraryMode(m)     { Services.WallpaperService.setLibraryMode(m) }

    /// Image source for a gallery entry — delegates to the service's canonical
    /// resolver (§1 dedup; same logic the dashboard card uses).
    function thumbFor(p) {
        return Services.WallpaperService.previewSourceFor(p)
    }

    /// Anything that plays: still-library gif/apng or any live-library entry.
    function isAnimated(p) { return root.isLive(p) || root.isEngined(p) }
    function handleLoadDirectory(path) {
        if (path.length === 0) return
        Services.WallpaperService.setWallpaperDir(path)
        refreshDelay.start()
    }
    function handleLoadLiveDirectory(path) {
        if (path.length === 0) return
        Services.WallpaperService.setLiveDir(path)
        refreshDelay.start()
    }
    Timer { id: refreshDelay; interval: 400; onTriggered: refreshWallpapers() }

    function basename(p) { return (p || "").split('/').pop() }

    // =========================================================================
    // CONTROLS BAR (top) — source path + cycling + interval + effect
    // =========================================================================
    Card { variant: "hud";
        id: controlsBar
        accent: Config.ThemeConfig.colors.primary
        anchors.top: parent.top;    anchors.topMargin: root._margin
        anchors.left: parent.left;  anchors.leftMargin: root._margin
        anchors.right: parent.right; anchors.rightMargin: root._margin

        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 8

            // Row 1 — source path + LOAD_PATH
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "SOURCE_DIRECTORY_PATH"
                    color: Config.ThemeConfig.colors.primary
                    font.family: root.fMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 26
                    color: Config.ThemeConfig.colors.surfaceVariant
                    border.color: Config.ThemeConfig.colors.border; border.width: 1
                    TextInput {
                        id: dirInput
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: root.fMono; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.text
                        text: root.dirText
                        onTextEdited: root.dirText = dirInput.text
                        clip: true
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 26; Layout.preferredWidth: 84
                    color: Config.ThemeConfig.colors.primary
                    opacity: loadMa.containsMouse ? 0.88 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "LOAD_PATH"
                        color: Config.ThemeConfig.colors.background
                        font.family: root.fMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                    }
                    MouseArea {
                        id: loadMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.handleLoadDirectory(root.dirText)
                    }
                }
            }

            // Row 1b — live (mpvpaper) library path + APPLY
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "LIVE_DIRECTORY_PATH"
                    color: Config.ThemeConfig.colors.secondary
                    font.family: root.fMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 26
                    color: Config.ThemeConfig.colors.surfaceVariant
                    border.color: Config.ThemeConfig.colors.border; border.width: 1
                    TextInput {
                        id: liveDirInput
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: root.fMono; font.pixelSize: 10
                        color: Config.ThemeConfig.colors.text
                        text: root.liveDirText
                        onTextEdited: root.liveDirText = liveDirInput.text
                        clip: true
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 26; Layout.preferredWidth: 84
                    color: Config.ThemeConfig.colors.secondary
                    opacity: liveLoadMa.containsMouse ? 0.88 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "APPLY_LIVE"
                        color: Config.ThemeConfig.colors.background
                        font.family: root.fMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                    }
                    MouseArea {
                        id: liveLoadMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.handleLoadLiveDirectory(root.liveDirText)
                    }
                }
            }

            // Row 2 — cycling / interval / effect
            RowLayout {
                Layout.fillWidth: true
                spacing: 18

                // Cycling segmented [ON|OFF]
                ColumnLayout {
                    spacing: 3
                    Text { text: "CYCLING"; color: Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Row {
                        spacing: 0
                        Rectangle {
                            width: 44; height: 22
                            color: root.cyclingEnabled ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                            border.color: Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "ON"; color: root.cyclingEnabled ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (!root.cyclingEnabled) root.toggleCycling() } }
                        }
                        Rectangle {
                            width: 44; height: 22
                            color: !root.cyclingEnabled ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                            border.color: Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "OFF"; color: !root.cyclingEnabled ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.cyclingEnabled) root.toggleCycling() } }
                        }
                    }
                }

                // Interval stepper  [-] 5m [+]
                ColumnLayout {
                    spacing: 3
                    Text { text: "INTERVAL"; color: Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Row {
                        spacing: 4
                        Rectangle {
                            width: 22; height: 22; color: Config.ThemeConfig.colors.surfaceVariant
                            border.color: Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "−"; color: Config.ThemeConfig.colors.text; font.pixelSize: 13; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setIntervalSec(root.cycleInterval - 60) }
                        }
                        Rectangle {
                            width: 42; height: 22; color: Config.ThemeConfig.colors.background
                            border.color: Config.ThemeConfig.colors.border; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: (root.cycleInterval / 60).toFixed(0) + "m"
                                color: Config.ThemeConfig.colors.secondary; font.family: root.fMono; font.pixelSize: 10; font.bold: true
                            }
                        }
                        Rectangle {
                            width: 22; height: 22; color: Config.ThemeConfig.colors.surfaceVariant
                            border.color: Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "+"; color: Config.ThemeConfig.colors.text; font.pixelSize: 13; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setIntervalSec(root.cycleInterval + 60) }
                        }
                    }
                }

                // Effect segmented — awww's transition set. ANY = awww picks a
                // different random transition per apply.
                ColumnLayout {
                    spacing: 3
                    Text { text: "EFFECT"; color: Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Row {
                        spacing: 4
                        Rectangle {
                            width: 36; height: 22
                            color: root.transitionType === "fade" ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.20) : Config.ThemeConfig.colors.surfaceVariant
                            border.color: root.transitionType === "fade" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "FADE"; color: root.transitionType === "fade" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setTransition("fade") }
                        }
                        Rectangle {
                            width: 36; height: 22
                            color: root.transitionType === "wipe" ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.20) : Config.ThemeConfig.colors.surfaceVariant
                            border.color: root.transitionType === "wipe" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "WIPE"; color: root.transitionType === "wipe" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setTransition("wipe") }
                        }
                        Rectangle {
                            width: 36; height: 22
                            color: root.transitionType === "outer" ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.20) : Config.ThemeConfig.colors.surfaceVariant
                            border.color: root.transitionType === "outer" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "OUTER"; color: root.transitionType === "outer" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setTransition("outer") }
                        }
                        Rectangle {
                            width: 36; height: 22
                            color: root.transitionType === "wave" ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.20) : Config.ThemeConfig.colors.surfaceVariant
                            border.color: root.transitionType === "wave" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "WAVE"; color: root.transitionType === "wave" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setTransition("wave") }
                        }
                        Rectangle {
                            width: 36; height: 22
                            color: root.transitionType === "grow" ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.20) : Config.ThemeConfig.colors.surfaceVariant
                            border.color: root.transitionType === "grow" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "GROW"; color: root.transitionType === "grow" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setTransition("grow") }
                        }
                        Rectangle {
                            width: 36; height: 22
                            color: root.transitionType === "center" ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.20) : Config.ThemeConfig.colors.surfaceVariant
                            border.color: root.transitionType === "center" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "CENTER"; color: root.transitionType === "center" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setTransition("center") }
                        }
                        Rectangle {
                            width: 36; height: 22
                            color: root.transitionType === "any" ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.20) : Config.ThemeConfig.colors.surfaceVariant
                            border.color: root.transitionType === "any" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "ANY"; color: root.transitionType === "any" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setTransition("any") }
                        }
                    }
                }

                // Anim segmented [RUN|HOLD] — freezes/resumes gif/apng playback
                ColumnLayout {
                    spacing: 3
                    Text { text: "ANIM"; color: Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Row {
                        spacing: 0
                        Rectangle {
                            width: 44; height: 22
                            color: !root.animPaused ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.surfaceVariant
                            border.color: Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "RUN"; color: !root.animPaused ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.animPaused) root.setAnimPaused(false) } }
                        }
                        Rectangle {
                            width: 44; height: 22
                            color: root.animPaused ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.surfaceVariant
                            border.color: Config.ThemeConfig.colors.border; border.width: 1
                            Text { anchors.centerIn: parent; text: "HOLD"; color: root.animPaused ? Config.ThemeConfig.colors.background : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (!root.animPaused) root.setAnimPaused(true) } }
                        }
                    }
                }

                Item { Layout.fillWidth: true }   // keep the control group left-aligned
            }
        }
    }

    // =========================================================================
    // FOOTER (bottom) — tactical status strip
    // =========================================================================
    Rectangle {
        id: footer
        anchors.bottom: parent.bottom; anchors.bottomMargin: root._margin
        anchors.left: parent.left;     anchors.leftMargin: root._margin
        anchors.right: parent.right;   anchors.rightMargin: root._margin
        height: root._footerH
        color: Config.ThemeConfig.colors.background
        border.color: Config.ThemeConfig.colors.outlineVariant; border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 14

            Rectangle {
                width: 6; height: 6; radius: 3; color: Config.ThemeConfig.colors.success
                Layout.alignment: Qt.AlignVCenter
                SequentialAnimation on opacity {
                    running: Config.SharedState.dashboardVisible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 850 }
                    NumberAnimation { to: 1.0; duration: 850 }
                }
            }
            Text { text: "GALLERY_MANAGER: CONNECTED"; color: Config.ThemeConfig.colors.primary; font.family: root.fMono; font.pixelSize: 8; font.bold: true; Layout.alignment: Qt.AlignVCenter }
            Text { text: root.wallpaperDir; color: Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; elide: Text.ElideMiddle; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
            Text { text: "SYNC: 1000ms"; color: Config.ThemeConfig.colors.secondary; font.family: root.fMono; font.pixelSize: 8; font.bold: true; Layout.alignment: Qt.AlignVCenter }
            Text {
                // Engine badge: daemon + instance state from `wallpaper-engine status`
                text: !root.engineAvailable ? "ENG:—"
                    : !root.engineRunning   ? "ENG:OFF"
                    : root.engineInstances > 0 ? (root.enginePaused ? "ENG:HOLD" : "ENG:RUN")
                    : "ENG:IDLE"
                color: !root.engineAvailable || !root.engineRunning || root.engineInstances === 0
                       ? Config.ThemeConfig.colors.textDim
                    : root.enginePaused ? Config.ThemeConfig.colors.warning
                    : Config.ThemeConfig.colors.success
                font.family: root.fMono; font.pixelSize: 8; font.bold: true; Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: (root.currentWallpaper && root.isAnimated(root.currentWallpaper))
                      ? (root.animPaused ? "LIVE: HOLD" : "LIVE: RUN")
                      : "STATIC"
                color: (root.currentWallpaper && root.isAnimated(root.currentWallpaper) && !root.animPaused)
                       ? Config.ThemeConfig.colors.success
                       : (root.animPaused ? Config.ThemeConfig.colors.warning : Config.ThemeConfig.colors.textDim)
                font.family: root.fMono; font.pixelSize: 8; font.bold: true; Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // =========================================================================
    // SIDEBAR (left) — real info only (no fake collections/tags)
    // =========================================================================
    Card { variant: "hud";
        id: sidebar
        accent: Config.ThemeConfig.colors.secondary
        anchors.top: controlsBar.bottom;    anchors.topMargin: root._gap
        anchors.bottom: footer.top;         anchors.bottomMargin: root._gap
        anchors.left: parent.left;          anchors.leftMargin: root._margin
        width: root._sidebarW

        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 10

            // LIBRARY (+ VIEW selector — scopes the gallery AND rotation)
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { text: "󰊫  LIBRARY"; color: Config.ThemeConfig.colors.primary; font.family: root.fMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "ALL_WALLPAPERS"; color: Config.ThemeConfig.colors.text; font.family: root.fMono; font.pixelSize: 8; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: root.wallpaperList.length; color: Config.ThemeConfig.colors.primary; font.family: root.fMono; font.pixelSize: 9; font.bold: true }
                }
                Text { text: "VIEW"; color: Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Row {
                    spacing: 0
                    Rectangle {
                        width: 40; height: 20
                        color: root.libraryMode === "all" ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.20) : Config.ThemeConfig.colors.surfaceVariant
                        border.color: root.libraryMode === "all" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                        Text { anchors.centerIn: parent; text: "ALL"; color: root.libraryMode === "all" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setLibraryMode("all") }
                    }
                    Rectangle {
                        width: 40; height: 20
                        color: root.libraryMode === "still" ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.20) : Config.ThemeConfig.colors.surfaceVariant
                        border.color: root.libraryMode === "still" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                        Text { anchors.centerIn: parent; text: "STILL"; color: root.libraryMode === "still" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setLibraryMode("still") }
                    }
                    Rectangle {
                        width: 40; height: 20
                        color: root.libraryMode === "live" ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.secondary, 0.20) : Config.ThemeConfig.colors.surfaceVariant
                        border.color: root.libraryMode === "live" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border; border.width: 1
                        Text { anchors.centerIn: parent; text: "LIVE"; color: root.libraryMode === "live" ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setLibraryMode("live") }
                    }
                }
            }

            // CURRENT
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { text: "CURRENT"; color: Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }
                Text {
                    Layout.fillWidth: true
                    text: root.basename(root.currentWallpaper).toUpperCase() || "—"
                    color: Config.ThemeConfig.colors.text; font.family: root.fMono; font.pixelSize: 8; font.bold: true
                    elide: Text.ElideMiddle
                }
                Rectangle {   // ACTIVE chip
                    width: activeChipLabel.implicitWidth + 10; height: 12
                    color: Config.ThemeConfig.colors.secondary
                    Text { id: activeChipLabel; anchors.centerIn: parent; text: "ACTIVE"; color: Config.ThemeConfig.colors.background; font.family: root.fMono; font.pixelSize: 7; font.bold: true }
                }
            }

            // SYSTEM (live memory load)
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "SYSTEM"; color: Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(Services.SystemMetricsService.ramPct) + "%"; color: Config.ThemeConfig.colors.warning; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }
                Rectangle {
                    Layout.fillWidth: true; height: 3; color: Config.ThemeConfig.colors.outlineVariant
                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: parent.width * (Math.max(0, Math.min(100, Services.SystemMetricsService.ramPct)) / 100)
                        color: Config.ThemeConfig.colors.warning
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }
            }

            // THEME_SYNC (matugen auto-theme on wallpaper change)
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { text: "THEME_SYNC"; color: Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }
                Rectangle {
                    Layout.fillWidth: true; height: 22
                    color: Services.SettingsConfigService.matugenOnWallpaperChange ? Config.ThemeConfig.tint(Config.ThemeConfig.colors.success, 0.18) : Config.ThemeConfig.colors.surfaceVariant
                    border.color: Services.SettingsConfigService.matugenOnWallpaperChange ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.border; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: Services.SettingsConfigService.matugenOnWallpaperChange ? "AUTO-THEME: ON" : "AUTO-THEME: OFF"
                        color: Services.SettingsConfigService.matugenOnWallpaperChange ? Config.ThemeConfig.colors.success : Config.ThemeConfig.colors.textDim
                        font.family: root.fMono; font.pixelSize: 8; font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Services.SettingsConfigService.matugenOnWallpaperChange = !Services.SettingsConfigService.matugenOnWallpaperChange
                            Services.SettingsConfigService.saveSettings()
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }   // top-align the sections
        }
    }

    // =========================================================================
    // GALLERY (right) — header + scrollable thumbnail grid
    // =========================================================================
    Card { variant: "hud";
        id: gallery
        accent: Config.ThemeConfig.colors.primary
        anchors.top: controlsBar.bottom;    anchors.topMargin: root._gap
        anchors.bottom: footer.top;         anchors.bottomMargin: root._gap
        anchors.left: sidebar.right;        anchors.leftMargin: root._gap
        anchors.right: parent.right;        anchors.rightMargin: root._margin

        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 6

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: "󰊖"; color: Config.ThemeConfig.colors.primary; font.family: root.fMono; font.pixelSize: 12 }
                Text { text: "TACTICAL_GALLERY"; color: Config.ThemeConfig.colors.text; font.family: root.fMono; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5; Layout.fillWidth: true }
                Text { text: "ITEMS: " + root.wallpaperList.length; color: Config.ThemeConfig.colors.textDim; font.family: root.fMono; font.pixelSize: 8; font.bold: true }
                Text { text: "󰊫"; color: Config.ThemeConfig.colors.primary; font.family: root.fMono; font.pixelSize: 11; opacity: 0.6 }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Config.ThemeConfig.colors.outlineVariant }

            // Grid (scrollable) + empty-state overlay
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    clip: true
                    cellWidth: 108; cellHeight: 80
                    model: root.wallpaperList
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: grid.cellWidth - 6
                        height: grid.cellHeight - 6
                        color: Config.ThemeConfig.colors.background
                        border.color: modelData === root.currentWallpaper ? Config.ThemeConfig.colors.secondary : Config.ThemeConfig.colors.border
                        border.width: modelData === root.currentWallpaper ? 2 : 1
                        clip: true

                        Image {
                            // Stills load directly; engine content uses its
                            // cached poster frame ("" → placeholder glyph).
                            visible: root.thumbFor(modelData) !== ""
                            anchors.fill: parent; anchors.margins: 1
                            source: root.thumbFor(modelData)
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(220, 140)
                            asynchronous: true; cache: true
                            opacity: thumbMa.containsMouse ? 1.0 : 0.85
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        // Placeholder while an engine entry has no frame yet
                        Text {
                            visible: root.isEngined(modelData) && root.thumbFor(modelData) === ""
                            anchors.centerIn: parent
                            text: ""
                            color: Config.ThemeConfig.colors.textDim
                            font.family: root.fMono; font.pixelSize: 14
                        }

                        // ACTIVE badge
                        Rectangle {
                            visible: modelData === root.currentWallpaper
                            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 3
                            width: badgeLabel.implicitWidth + 8; height: 12
                            color: Config.ThemeConfig.colors.primary
                            Text { id: badgeLabel; anchors.centerIn: parent; text: "ACTIVE"; color: Config.ThemeConfig.colors.background; font.family: root.fMono; font.pixelSize: 7; font.bold: true }
                        }

                        // LIVE badge (gif/apng in the still library, or any
                        // live-library entry — plays in-place on apply)
                        Rectangle {
                            visible: root.isAnimated(modelData)
                            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 3
                            width: liveLabel.implicitWidth + 8; height: 12
                            color: Config.ThemeConfig.colors.background
                            border.color: Config.ThemeConfig.colors.secondary; border.width: 1
                            Text { id: liveLabel; anchors.centerIn: parent; text: "LIVE"; color: Config.ThemeConfig.colors.secondary; font.family: root.fMono; font.pixelSize: 7; font.bold: true }
                        }

                        // Hover overlay (gradient + filename)
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            height: parent.height * 0.5
                            visible: thumbMa.containsMouse
                            opacity: thumbMa.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Config.ThemeConfig.colors.background }
                            }
                            Text {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 3
                                text: root.basename(modelData).toUpperCase()
                                color: Config.ThemeConfig.colors.text
                                font.family: root.fMono; font.pixelSize: 7; font.bold: true
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            id: thumbMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applyWallpaper(modelData)
                        }
                    }
                }

                // Empty-state placeholder
                Text {
                    anchors.centerIn: parent
                    visible: root.wallpaperList.length === 0
                    text: "󰄈  NO WALLPAPERS FOUND\nLOAD A DIRECTORY PATH"
                    color: Config.ThemeConfig.colors.textDim
                    font.family: root.fMono; font.pixelSize: 9; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
