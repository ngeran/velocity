// =============================================================================
// BarConfig.qml — Design tokens and configuration
// =============================================================================
//
// This singleton contains all visual design tokens for the bar.
// Colors are dynamically sourced from ThemeConfig for theme switching.
//
// SIZES
//   barHeight  - Total bar height in pixels (configurable via bar-config.json)
//   iconSize   - Size of each icon square (scales with barHeight)
//   iconSpacing - Space between icons
//
// BEHAVIOR
//   workspaceCount - Number of workspace dots to display (configurable via bar-config.json)
//   *_interval - Polling intervals for services (milliseconds)
// =============================================================================

pragma Singleton

import QtQuick
import Qt.labs.platform
import Quickshell.Io

Item {
    id: root
    visible: false
    // =========================================================================
    // CONFIGURABLE SETTINGS (loaded from bar-config.json)
    // =========================================================================

    // Default values - overridden by config file if present
    property int barHeight: 26
    property int workspaceCount: 5
    // Bar style (styles/<name>/Scene.qml). Validated: non-empty, no path
    // separators — anything else keeps the current style; the host's Loader
    // falls back to "vector" when the folder/Scene is missing or broken.
    property string barStyle: "vector"
    // Bar edge (UA 2.6 stage 1): "top" | "bottom". Scenes flip their window
    // anchors, popovers rise from the host's bottom edge, the notch mirrors
    // its lobe. Left/right placement is a follow-up, not modeled here.
    property string barPosition: "top"
    readonly property bool barAtBottom: root.barPosition === "bottom"
    // Track-and-readout OSDs (volume/brightness + plugin progress): "bar" =
    // the continuous fill; "segments" = Ui.SegmentTrack (Osd card + the
    // island's activity row). Writes route through the settings funnel
    // (SettingsWindow.setOsdStyle) like barStyle/barPosition.
    property string osdStyle: "segments"   // D5 default (P6.6: code now matches the writer's canonical default)
    // Island style QD-OLED guard (orbit drift + idle dim of the rest clock).
    property bool islandBurnGuard: true
    // Strip styles' QD-OLED guard: content orbit (BurnOrbit) on
    // vector/ryoku/notch so no static pixel column sits long enough to burn.
    property bool stripBurnGuard: true
    // Popup/dashboard scale (0.75–2.0). PopupMetrics mirrors this — BarConfig
    // is the one bar-config.json reader (DU13: this file used to carry its own
    // FileView + 15s timer for a single key).
    property real uiScale: 1.0
    // Gap between right-section widgets. What sits where is the engine's
    // layout (plugins-state.json); bar-config.json's old "rightLayout" is
    // read once by the engine's schema-2 migration and ignored after.
    // 8 → 18 (user call: the keyboard/wifi/bt/volume cluster felt cramped).
    readonly property int slotMargin: 18

    // =========================================================================
    // CONFIG FILE LOADING
    // =========================================================================

    property string configFilePath: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell/bar-config.json"
    property string _lastRaw: ""   // dedup: only re-apply when bar-config.json actually changes

    // =========================================================================
    // CONFIG FILE LOADING — FileView + 15s fallback reload() (zero forks)
    // -------------------------------------------------------------------------
    // Hybrid intake identical to ThemeConfig.qml: watchChanges gives instant
    // updates on same-inode writes; the settings writer's tmp+mv swap (which
    // cross-process watches can miss) is pushed via the `config reload` IPC
    // nudge; the slow Timer only backstops external writers. reload()+text()
    // re-read by path in C++, replacing the old `sh -c stat` gate.
    // FileView.text is a METHOD in this Quickshell build, not a property.
    // =========================================================================

    // Single ingest path for startup restore, inotify hits, and timer reloads.
    function ingestConfigText(raw) {
        var text = (raw || "").trim()
        if (text.length === 0 || text === _lastRaw) return  // dedup: skip empty/unchanged
        _lastRaw = text
        try {
            var data = JSON.parse(text)
            if (data.barHeight !== undefined)
                barHeight = Math.max(18, Math.min(64, Math.round(data.barHeight)))
            if (data.workspaceCount !== undefined && [3, 5, 7, 9].indexOf(data.workspaceCount) !== -1)
                workspaceCount = data.workspaceCount
            if (typeof data.barStyle === "string"
                && data.barStyle.length > 0
                && data.barStyle.indexOf("/") === -1)
                barStyle = data.barStyle
            if (data.barPosition === "top" || data.barPosition === "bottom")
                barPosition = data.barPosition
            if (data.osdStyle === "bar" || data.osdStyle === "segments" || data.osdStyle === "edge")
                osdStyle = data.osdStyle
            if (typeof data.islandBurnGuard === "boolean")
                islandBurnGuard = data.islandBurnGuard
            if (typeof data.stripBurnGuard === "boolean")
                stripBurnGuard = data.stripBurnGuard
            if (data.uiScale !== undefined) {
                var s = Number(data.uiScale)
                if (isFinite(s) && s >= 0.75 && s <= 2.0) uiScale = s
            }
            console.log("[BarConfig] Hot-reloaded bar-config.json")
        } catch (e) {
            console.log("[BarConfig] Failed to parse config:", e)
        }
    }

    FileView {
        id: configFile
        path: root.configFilePath
        watchChanges: true
        printErrors: false

        // Instant path (same-inode writes)
        onFileChanged: root.ingestConfigText(configFile.text())
        // Covers the timer's ASYNC reload() completions (see ThemeConfig).
        onTextChanged: root.ingestConfigText(text())

        // Startup load: text() does a blocking read of the existing file.
        Component.onCompleted: root.ingestConfigText(configFile.text())
    }

    // IPC nudge entry (config.reload); dedupes through _lastRaw.
    function reloadFromDisk() {
        configFile.reload()
        root.ingestConfigText(configFile.text())
    }

    // Backstop for writers that don't nudge (editor, CLI). Zero forks.
    // 60s: idle-cadence only — settings-side writes land instantly via the
    // `config reload` nudge and in-place writes via watchChanges; this catch
    // exists for tmp+mv writers (vim/tee) and costs one cheap reload a minute.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            configFile.reload()
            root.ingestConfigText(configFile.text())
        }
    }

    // =========================================================================
    // GEOMETRY
    // =========================================================================

    // barHeight is configurable — any int 18–64 (clamped on ingest). Every
    // visible item in the bar scales off this baseline so the bar stays
    // proportional at any height — icons, clock text, and workspace dots all
    // grow/shrink together instead of floating unchanged inside a taller bar.
    // Baseline = 26px (the default), so _contentScale is 1.0 at the default
    // and the default look is preserved.
    readonly property real _contentScale: root.barHeight / 26.0

    readonly property int barPadding: 12
    readonly property int iconSize: Math.round(32 * _contentScale)   // tray-icon slot
    readonly property int iconSpacing: 4
    readonly property int archLogoSize: Math.round(15 * _contentScale)

    // =========================================================================
    // COLOURS (Dynamic from ThemeConfig)
    // =========================================================================

    readonly property color colorBackground: ThemeConfig.colors.background
    readonly property color colorAccent: ThemeConfig.colors.secondary
    readonly property color colorText: ThemeConfig.colors.text
    readonly property color colorTextDim: ThemeConfig.colors.textDim
    readonly property color colorMuted: ThemeConfig.colors.textDim
    readonly property color colorBorder: ThemeConfig.colors.border

    // =========================================================================
    // TYPOGRAPHY
    // =========================================================================

    // P6.1 glyph identity — families come from Tokens (shared/Tokens.qml, the
    // synced canonical). Roles: mono = data + caps metadata, ui = prose,
    // display = Doto numerals (≥ Tokens.minDisplayPx only), nerd = icons.
    readonly property string fontFamily: Tokens.fontMono
    readonly property string fontNerd: Tokens.fontIcons
    readonly property string fontUi: Tokens.fontUi
    readonly property string fontDisplay: Tokens.fontDisplay
    readonly property int fontSizeClock: Math.max(10, Math.round(14 * _contentScale))
    readonly property int fontSizeDate: Math.max(7, Math.round(9 * _contentScale))
    readonly property int fontSizeIcon: Math.max(10, Math.round(14 * _contentScale))   // tray glyph
    readonly property int fontSizeLabel: Math.max(9, Math.round(11 * _contentScale))   // pill/hover labels
    readonly property int fontSizeBadge: Math.max(7, Math.round(8 * _contentScale))    // count badges
    // Exposed for the few one-off sizes that have no token (logo wordmark,
    // plugin pill text at their own baselines) — ctx.bar reaches this too.
    readonly property real contentScale: _contentScale

    // =========================================================================
    // WORKSPACES
    // =========================================================================

    readonly property int workspaceDotWidth: Math.max(3, Math.round(6 * _contentScale))
    readonly property int workspaceDotWidthActive: Math.round(14 * _contentScale)
    readonly property int workspaceDotHeight: Math.max(3, Math.round(6 * _contentScale))
    readonly property int workspaceButtonSize: Math.round(24 * _contentScale)
    readonly property int workspaceButtonFontSize: Math.max(8, Math.round(11 * _contentScale))

    // =========================================================================
    // POLLING INTERVALS (milliseconds)
    // =========================================================================

    readonly property int networkInterval: 3000
    readonly property int bluetoothInterval: 6000
    readonly property int audioInterval: 3000
    readonly property int workspaceInterval: 1500

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: console.log("[BarConfig] Loading config from:", configFilePath)
}
