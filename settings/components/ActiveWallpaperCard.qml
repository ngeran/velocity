// =============================================================================
// ActiveWallpaperCard.qml — dashboard identity card: the live wallpaper
// =============================================================================
// Recovered from the deleted bento OverviewTab (user request: bring the active
// wallpaper back, between Hardware Telemetry and Session) and restyled out of
// the old hud-Card look (brackets + gradient) into the SystemInfoTab card
// language: flat surface Rectangle, dot + caps header, hairline divider.
//
// Data: SharedState.wallpaperPath / wallpaperName, pushed by
// WallpaperService.applyWallpaper(), so it updates the moment a wallpaper is
// set from the Wallpaper tab or externally. Video (live-library) wallpapers
// can't be decoded by Qt — previewSourceFor() resolves them to the service's
// cached poster frame. Clicking the preview deep-links to the Wallpaper tab
// (changeRequested → shell.openWallpapersTab()).
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "../services" as Services

Rectangle {
    id: root

    // Emitted when the preview is clicked — the shell deep-links to the
    // Wallpaper tab (same affordance the old ActiveThemeCard had).
    signal changeRequested()

    // ── palette (mirrors SystemInfoTab) ─────────────────────────────────────
    readonly property color cText:    Config.ThemeConfig.colors.text
    readonly property color cDim:     Config.ThemeConfig.colors.textDim
    readonly property color cBorder:  Config.ThemeConfig.colors.border
    readonly property color cOutline: Config.ThemeConfig.colors.outlineVariant
    readonly property color cSurface: Config.ThemeConfig.colors.surface
    readonly property color cSuccess: Config.ThemeConfig.colors.success
    readonly property color cPrimary: Config.ThemeConfig.colors.primary
    readonly property string fontM:   Config.ControlConfig.fontMono

    color: Qt.rgba(cSurface.r, cSurface.g, cSurface.b, 0.35)
    border.color: cBorder; border.width: 1
    radius: 10
    clip: true

    // Corner brackets — the dashboard's hud-card chrome (SystemInfoTab's
    // HudTag, mirrored here so the wallpaper tile reads as the same family).
    component Tag: Item {
        property color tagColor: root.cSuccess
        property bool flip: false            // false = top-left, true = bottom-right
        width: 8; height: 8
        Rectangle {
            width: 8; height: 2; color: parent.tagColor; opacity: 0.9
            anchors.top: parent.flip ? undefined : parent.top
            anchors.bottom: parent.flip ? parent.bottom : undefined
            anchors.left: parent.flip ? parent.right : parent.left
        }
        Rectangle {
            width: 2; height: 8; color: parent.tagColor; opacity: 0.9
            anchors.top: parent.flip ? undefined : parent.top
            anchors.bottom: parent.flip ? parent.bottom : undefined
            anchors.left: parent.flip ? parent.right : parent.left
        }
    }
    Tag { anchors { top: parent.top; left: parent.left; margins: 2 } }
    Tag { flip: true; tagColor: root.cPrimary; anchors { bottom: parent.bottom; right: parent.right; margins: 2 } }

    function previewSource() {
        return Services.WallpaperService.previewSourceFor(Config.SharedState.wallpaperPath)
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 14
        spacing: Config.ControlConfig.space2

        // ── header — dot + title + cycling badge ────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.ControlConfig.space2
            Rectangle { width: 8; height: 8; radius: 2; color: root.cSuccess; Layout.alignment: Qt.AlignVCenter }
            Text {
                text: "ACTIVE WALLPAPER"
                color: root.cText
                font.family: root.fontM; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                // CYCLE (mockup: a real button, not a badge) — advances to a
                // random wallpaper now: the same one-liner the service's
                // auto-cycle tick and its wallpaper-service IPC cycleNow use.
                // SharedState.wallpaperPath follows, so preview + name update
                // through their bindings the moment it lands.
                id: cycBtn
                height: 16; width: cycLbl.implicitWidth + 12; radius: 3
                color: cycMa.containsMouse
                       ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.28)
                       : Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.12)
                border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b,
                                      cycMa.containsMouse ? 0.8 : 0.4)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
                Text {
                    id: cycLbl; anchors.centerIn: parent; text: "CYCLE"
                    color: root.cPrimary
                    font.family: root.fontM; font.pixelSize: 7; font.bold: true; font.letterSpacing: 1
                }
                MouseArea {
                    id: cycMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var svc = Services.WallpaperService
                        var next = svc.selectRandomWallpaper()
                        if (next) svc.applyWallpaper(next)
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder }

        // ── preview — fills the cell; clickable, deep-links to the tab ──────
        Rectangle {
            id: previewRect
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 60
            color: root.cSurface
            border.color: previewMa.containsMouse ? root.cSuccess : root.cBorder
            border.width: 1
            clip: true
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Image {
                anchors.fill: parent
                source: root.previewSource()
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                // Decode at the rendered size — crisp on the QD-OLED at
                // whatever the grid cell gives us, no oversized decode.
                sourceSize.width: Math.round(previewRect.width)
                sourceSize.height: Math.round(previewRect.height)
            }
            Text {
                anchors.centerIn: parent
                visible: root.previewSource() === ""
                text: "◌"
                color: root.cDim
                font.pixelSize: 22
                opacity: 0.4
            }
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 6
                height: 16; width: openLbl.implicitWidth + 12
                color: Config.ThemeConfig.colors.background
                border.color: root.cSuccess; border.width: 1
                opacity: previewMa.containsMouse ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Text {
                    id: openLbl; anchors.centerIn: parent; text: "OPEN"
                    color: root.cSuccess
                    font.family: root.fontM; font.pixelSize: 7; font.bold: true; font.letterSpacing: 1
                }
            }
            MouseArea {
                id: previewMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.changeRequested()
            }
        }

        // ── file name + path ────────────────────────────────────────────────
        Text {
            Layout.fillWidth: true
            text: Config.SharedState.wallpaperName || "NONE"
            color: root.cText
            font.pixelSize: 12; font.bold: true
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "PATH"
                color: root.cDim
                font.family: root.fontM; font.pixelSize: 7; font.bold: true; font.letterSpacing: 1
            }
            Text {
                text: Config.SharedState.wallpaperPath || "—"
                color: root.cDim
                font.family: root.fontM; font.pixelSize: 7
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
        }
    }
}
