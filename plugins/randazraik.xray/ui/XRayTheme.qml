import QtQuick

QtObject {
    // ── LIVE THEME SOURCE (C5 port) ─────────────────────────────────────
    // The roots inject the engine's api-2 ctx; the seven base tokens read
    // ctx.theme.colors (the bar's live palette — theme switches propagate),
    // falling back to the upstream Tokyo-Night constants when ctx is null
    // (degraded-load path). Everything below the base is derivation and
    // flows from whichever source is active. The old qs/Commons singletons
    // (Color/Theme/Style/Border) are folded into this file as constants +
    // flatBorder(); fonts/borders come from ctx.bar where available.
    property var ctx: null

    readonly property var _c: ctx && ctx.theme && ctx.theme.colors ? ctx.theme.colors : null
    readonly property var _b: ctx && ctx.bar ? ctx.bar : null

    function flatBorder(color, width) {
        return { color: color, width: width === undefined ? 1 : width }
    }

    // Old qs/Commons/Style.space() — the vendored scale was already 1:1 with
    // pixels, so this is the identity pass-through the callers expect.
    function space(n) { return n }

    function withAlpha(base, alpha) {
        return Qt.rgba(base.r, base.g, base.b, Math.max(0, Math.min(1, alpha)));
    }

    function blend(base, tint, amount) {
        var weight = Math.max(0, Math.min(1, Number(amount || 0)));
        return Qt.rgba(
            base.r * (1 - weight) + tint.r * weight,
            base.g * (1 - weight) + tint.g * weight,
            base.b * (1 - weight) + tint.b * weight,
            1
        );
    }

    function tintedSurface(tint) {
        return blend(panel, tint, tintedSurfaceMix);
    }

    function hoveredBorder(tint) {
        return blend(cardBorder, tint, hoverBorderMix);
    }

    function focusedSurface(tint) {
        return blend(surfaceHigh, tint, focusSurfaceAccentMix);
    }

    function focusedBorder(tint) {
        return blend(cardBorder, tint, focusBorderAccentMix);
    }

    function toneColor(tone) {
        var colors = {
            "cpu": cpuAccent,
            "process": processAccent,
            "memory": memoryAccent,
            "network": networkAccent,
            "storage": storageAccent,
            "device": deviceAccent,
            "runtime": runtimeAccent,
            "warning": storageAccent,
            "danger": danger,
            "neutral": text
        }
        return colors[String(tone || "")] || accent
    }

    function headingColor(tint) {
        return blend(text, tint, headingAccentMix);
    }

    function spectralColor(hue, saturation) {
        var darkTheme = canvas.hslLightness < 0.52;
        var value = darkTheme ? 0.96 : 0.62;
        var chroma = darkTheme ? saturation : Math.min(0.82, saturation * 1.1);
        return blend(Qt.hsva(hue, chroma, value, 1), accent, 0.08);
    }

    readonly property color canvas: _c ? _c.background : "#000000"
    readonly property color panel: blend(canvas, text, 0.018)
    readonly property color text: _c ? _c.text : "#c0caf5"
    readonly property color accent: _c ? _c.primary : "#BB9AF7"
    readonly property color danger: _c ? _c.error : "#4A6B80"
    readonly property color border: blend(panel, text, 0.18)
    readonly property color selected: _c ? _c.surfaceVariant : "#1a1c26"
    readonly property color scrim: withAlpha(canvas, 0.82)
    readonly property color transparent: withAlpha(panel, 0)

    // A restrained spectrum makes the instrument easier to read: a color
    // always means the same domain, while Omarchy's accent still anchors the
    // shell and selection state.
    readonly property color cpuAccent: spectralColor(0.61, 0.58)
    readonly property color processAccent: spectralColor(0.64, 0.62)
    readonly property color memoryAccent: spectralColor(0.77, 0.58)
    readonly property color networkAccent: spectralColor(0.51, 0.62)
    readonly property color storageAccent: spectralColor(0.105, 0.68)
    readonly property color deviceAccent: spectralColor(0.46, 0.56)
    readonly property color runtimeAccent: spectralColor(0.25, 0.62)
    readonly property color alertAccent: danger

    // Surface depth is derived from Omarchy's active background, foreground,
    // and accent. The dashboard stays calm while cards, navigation, and the
    // selected-target strip remain visually distinct in both dark and light
    // themes.
    readonly property real mutedTextMix: 0.48
    readonly property real quietSurfaceMix: 0.04
    readonly property real previewSurfaceMix: 0.045
    readonly property real controlFocusSurfaceMix: 0.085
    readonly property real controlFocusBorderMix: 0.32
    readonly property real controlActiveSurfaceMix: 0.075
    readonly property real controlHoverSurfaceMix: 0.055
    readonly property real tintedSurfaceMix: 0.075
    readonly property real dangerSurfaceMix: 0.085
    readonly property real cardBorderTextMix: 0.16
    readonly property real accentBorderMix: 0.32
    readonly property real sectionAccentMix: 0.28
    readonly property real metricAccentMix: 0.46
    readonly property real gridAccentMix: 0.24
    readonly property real hoverBorderMix: 0.34
    readonly property real cardHoverOverlayOpacity: 0.035
    readonly property real headingAccentMix: 0.58
    readonly property real focusSurfaceAccentMix: 0.12
    readonly property real focusBorderAccentMix: 0.5
    readonly property color muted: blend(_mutedBase, text, mutedTextMix)
    readonly property color _mutedBase: _c ? _c.textDim : "#a9b1d6"
    readonly property color quietSurface: blend(panel, text, quietSurfaceMix)
    readonly property color previewSurface: blend(quietSurface, accent, previewSurfaceMix)
    readonly property color controlFocusSurface: blend(
        quietSurface, accent, controlFocusSurfaceMix
    )
    readonly property color controlFocusBorder: blend(
        cardBorder, accent, controlFocusBorderMix
    )
    readonly property color controlActiveSurface: blend(
        quietSurface, text, controlActiveSurfaceMix
    )
    readonly property color controlHoverSurface: blend(
        quietSurface, text, controlHoverSurfaceMix
    )
    readonly property color dangerSurface: blend(panel, danger, dangerSurfaceMix)
    readonly property color cardBorder: blend(panel, text, cardBorderTextMix)
    readonly property color accentBorder: blend(border, accent, accentBorderMix)
    readonly property color sectionText: blend(text, accent, sectionAccentMix)
    readonly property color metricText: blend(text, accent, metricAccentMix)
    readonly property color grid: blend(panel, accent, gridAccentMix)
    readonly property color surfaceLow: blend(panel, text, 0.028)
    readonly property color surfaceMid: blend(panel, text, 0.052)
    readonly property color surfaceHigh: blend(panel, text, 0.082)
    readonly property color accentSurface: blend(panel, accent, 0.075)
    readonly property color accentGlow: withAlpha(accent, 0.17)
    readonly property color accentGlowSoft: withAlpha(accent, 0.075)
    readonly property color drawerScrim: withAlpha(canvas, 0.68)
    readonly property color busyScrim: withAlpha(panel, 0.88)
    readonly property color confirmationScrim: withAlpha(canvas, 0.84)
    readonly property color trace: cpuAccent
    readonly property color secondaryTrace: memoryAccent

    // Reserve semantic colors for abnormal process states.
    readonly property color inspectorAccent: processAccent
    readonly property color inspectorAccentText: headingColor(processAccent)
    readonly property color inspectorSelectedSurface: blend(panel, processAccent, 0.13)

    // One restrained chassis, with semantic color identifying each evidence
    // domain. This keeps the screen dense without turning it into a pile of
    // independent floating cards.
    readonly property color consoleSurface: blend(panel, text, 0.018)
    readonly property color consoleBorder: blend(panel, text, 0.24)
    readonly property int consoleRadius: 4
    readonly property int consoleGap: 4
    // Three evidence rows plus the card header must remain scannable at
    // native monitor scale.
    readonly property int consoleTopRowHeight: 164
    readonly property int consoleCommandHeight: 31
    readonly property int consoleTableHeaderHeight: 27
    readonly property int consoleProcessRowHeight: 31

    readonly property string displayFont: _b ? _b.fontFamily : "JetBrains Mono"
    readonly property string bodyFont: displayFont
    readonly property string dataFont: _b ? _b.fontNerd : "JetBrainsMono Nerd Font"   // nerd glyphs (launcher, data)
    readonly property int microFontSize: Math.max(10, 10)
    readonly property int captionFontSize: Math.max(10, 10)
    readonly property int bodyFontSize: Math.max(11, 11)
    readonly property int labelFontSize: Math.max(12, 12)
    readonly property int summaryFontSize: Math.max(13, 14)
    readonly property int sectionFontSize: Math.max(15, 16)
    readonly property int metricFontSize: Math.max(16, 16)
    readonly property int heroFontSize: Math.max(21, 20)
    readonly property int brandFontSize: Math.max(14, 14)
    readonly property int brandTaglineFontSize: Math.max(8, microFontSize - 1)
    readonly property real headingTracking: 0.45
    readonly property real utilityTracking: 0.65
    readonly property real labelTracking: 0.9
    readonly property real brandTracking: 1.35
    readonly property real taglineTracking: 0.85
    readonly property int radius: Math.max(6, Math.min(10, 6))
    readonly property int panelRadius: 8
    readonly property int cardRadius: 3
    readonly property int controlRadius: 3
    readonly property int pillRadius: 999
    readonly property int gap: 8
    readonly property int smallGap: 4
    readonly property int pad: 7
    readonly property int panelPadding: 7
    readonly property int panelMaxWidth: 1580
    readonly property int panelMaxHeight: 900
    readonly property int targetBrowserWidth: 264
    readonly property int targetBrowserContentPadding: 9
    readonly property int targetBrowserHeaderHeight: 34
    readonly property int targetBrowserCloseSize: 27
    readonly property int targetBrowserSearchHeight: 34
    readonly property int targetBrowserFilterHeight: 27
    readonly property int targetBrowserRowHeight: 38
    readonly property int targetBrowserSectionHeight: 25
    readonly property int targetBrowserChildIndent: pad * 2 + 1
    readonly property int targetBrowserBeamWidth: Math.max(2, borderWidth * 2)
    readonly property int cardHeaderHeight: 28
    readonly property int evidenceHeaderHeight: 24
    readonly property int evidenceRowHeight: 28
    readonly property int drawerMargin: 8
    readonly property int drawerPadding: 9
    readonly property int drawerHeaderHeight: 46
    readonly property int drawerSummaryHeight: 52
    readonly property int drawerSectionRowHeight: 32
    readonly property int drawerConnectionRowHeight: 50
    readonly property int connectionStatusWidth: 132
    readonly property int evidenceFactLabelWidth: 112
    readonly property int networkDrawerWidth: 820
    readonly property int networkFlowRowHeight: 54
    readonly property real networkOwnerColumn: 0.24
    readonly property int networkLinkWidth: 32
    readonly property int networkRateColumnWidth: 112
    readonly property int networkPlotHeight: 48
    readonly property int drawerResourceRowHeight: 52
    readonly property int drawerCauseRowHeight: 54
    readonly property int drawerFindingBaseHeight: 65
    readonly property int drawerFindingEvidenceHeight: 21
    readonly property int drawerFindingNextHeight: 31
    readonly property int drawerListInset: 8
    readonly property int drawerCauseBadgeSize: 24
    readonly property int drawerCauseConnectorX: pad + drawerCauseBadgeSize / 2
    readonly property int drawerCauseTextIndent: pad + drawerCauseBadgeSize + gap
    readonly property int compactRowHeight: 38
    readonly property int processEvidenceExpandedWidth: 660
    // Dense system data still has to be comfortably scannable at native
    // monitor scale. Keep these above the shell's caption-size defaults.
    readonly property int processEvidenceHeaderFontSize: Math.max(
        bodyFontSize, labelFontSize
    )
    readonly property int processEvidencePrimaryFontSize: Math.max(
        labelFontSize, summaryFontSize
    )
    readonly property int processEvidenceValueFontSize: Math.max(
        labelFontSize, summaryFontSize
    )
    readonly property int processEvidenceSecondaryFontSize: Math.max(
        bodyFontSize, labelFontSize
    )
    readonly property int processEvidenceBadgeFontSize: Math.max(
        microFontSize, bodyFontSize
    )
    readonly property int processEvidenceCommandHeight: 48
    readonly property int processEvidenceHeaderHeight: 28
    readonly property int processEvidenceRowHeight: 40
    readonly property int processEvidenceIndent: space(8)
    readonly property int processEvidenceBranchWidth: space(9)
    readonly property int processEvidenceMaximumDepth: 7
    readonly property int telemetryHeight: 78
    readonly property int telemetryTargetWidth: 330
    readonly property int telemetryTargetMinimumWidth: 280
    readonly property int telemetryTraceWidth: 260
    readonly property int telemetryTraceMinimumWidth: 220
    readonly property int telemetryTraceHeaderHeight: 18
    readonly property int telemetryTraceTimelineHeight: 12
    readonly property int telemetryMetricWidth: 112
    readonly property int telemetryMetricMinimumWidth: 78
    readonly property int telemetryModulePadding: 7
    readonly property int telemetryRailWidth: Math.max(2, borderWidth * 2)
    readonly property int telemetrySignalHeight: Math.max(2, borderWidth * 2)
    readonly property int performanceLegendHeight: space(24)
    readonly property int performanceLegendSwatchWidth: space(18)
    readonly property int performanceTimelineHeight: space(16)
    readonly property int performancePlotPadding: space(4)
    readonly property real performanceGridOpacity: 0.48
    readonly property real performanceFillOpacity: 0.16
    readonly property real performanceScaleHeadroom: 1.24
    readonly property real performanceMemoryPadding: 0.025
    readonly property real performancePrimaryTraceWidth: Math.max(2, borderWidth * 2)
    readonly property real performanceSecondaryTraceWidth: Math.max(1.5, borderWidth * 1.5)
    readonly property real performancePointRadius: Math.max(2, borderWidth * 2)
    readonly property real minimumCpuChartScale: 10
    readonly property int footerExpandedWidth: space(1120)
    readonly property int footerSidePadding: space(8)
    readonly property int footerSpacing: space(5)
    readonly property int outerGap: 8
    readonly property int borderWidth: 1
    readonly property int dividerWidth: 1
    readonly property real dividerOpacity: 0.58
    readonly property real subtleDividerOpacity: 0.32
    readonly property real connectorOpacity: 0.42
    readonly property real disabledOpacity: 0.3
    readonly property real previewOpacity: 0.72
    readonly property int fastMotionDuration: 110
}
