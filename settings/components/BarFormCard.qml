// =============================================================================
// BarFormCard.qml — one bar style as a pickable card with a live mini preview
// =============================================================================
// Shibumi "Bar form" pattern: preview of the style's silhouette on a desktop
// swatch, then "<NAME> · <form>" and a one-line description. The island
// preview blooms on hover so the card demonstrates the style's motion.
//
//   BarFormCard { styleName: "island"; active: …; onPicked: … }
//
// Known styles get a drawn silhouette + copy (`forms`); any other scanned
// style folder falls back to a plain full-width strip.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
    id: root

    // ── API ──────────────────────────────────────────────────────────────
    property string styleName: "vector"
    property bool active: false
    signal picked()

    readonly property var forms: ({
        "vector": { form: "Full",   desc: "Edge to edge strip" },
        "notch":  { form: "Notch",  desc: "Flowing shoulders" },
        "ryoku":  { form: "Frame",  desc: "Paper and ink strip" },
        "island": { form: "Island", desc: "Clock at rest, blooms on hover" }
    })
    readonly property var info: forms[styleName] || { form: "Custom", desc: "Style folder " + styleName }
    readonly property bool hovered: hit.containsMouse

    readonly property color accent: Config.ControlConfig.accent
    readonly property color ink: Config.ThemeConfig.colors.text
    readonly property color barFill: Config.ThemeConfig.colors.background

    implicitHeight: 112
    radius: Config.ControlConfig.radiusCard
    color: active ? Config.ThemeConfig.tint(accent, 0.08)
                  : hovered ? Config.ThemeConfig.tint(ink, 0.04) : "transparent"
    border.width: 1
    border.color: active ? accent : hovered ? Config.ThemeConfig.colors.outline : Config.ThemeConfig.colors.outlineVariant
    Behavior on color { ColorAnimation { duration: Config.MotionConfig.snap } }
    Behavior on border.color { ColorAnimation { duration: Config.MotionConfig.snap } }

    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!root.active) root.picked()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.ControlConfig.space2
        spacing: Config.ControlConfig.space2

        // ── preview: desktop swatch + silhouette ─────────────────────────
        Rectangle {
            id: swatch
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: Config.ControlConfig.radiusSmall
            color: Config.ThemeConfig.tint(root.ink, 0.06)
            clip: true

            readonly property int barH: 9

            // three dot groups (left / center / right widgets)
            component Dots: Row {
                property int count: 3
                spacing: 2
                Repeater {
                    model: count
                    Rectangle { width: 3; height: 3; radius: 1; color: Config.ThemeConfig.tint(root.ink, 0.7) }
                }
            }

            // vector / ryoku / custom: full-width strip
            Rectangle {
                visible: root.styleName !== "notch" && root.styleName !== "island"
                width: parent.width; height: swatch.barH
                color: root.barFill
                Rectangle {   // ryoku's hairline frame edge
                    visible: root.styleName === "ryoku"
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: Config.ThemeConfig.tint(root.ink, 0.35)
                }
                Dots { anchors.verticalCenter: parent.verticalCenter; x: 6 }
                Dots { anchors.centerIn: parent; count: 2 }
                Dots { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 6; count: 4 }
            }

            // notch: content-width lobe, round desktop-facing corners
            Rectangle {
                visible: root.styleName === "notch"
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.72; height: swatch.barH + 2
                color: root.barFill
                bottomLeftRadius: 6; bottomRightRadius: 6
                Dots { anchors.verticalCenter: parent.verticalCenter; x: 8 }
                Dots { anchors.centerIn: parent; count: 2 }
                Dots { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 8; count: 4 }
            }

            // island: clock pill that blooms on hover
            Rectangle {
                id: islandPill
                visible: root.styleName === "island"
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.hovered ? parent.width * 0.7 : 30
                height: swatch.barH + 1
                color: "#000000"   // the island is pure black on every theme
                bottomLeftRadius: height / 2; bottomRightRadius: height / 2
                clip: true
                Behavior on width {
                    SpringAnimation { spring: 4.2; damping: 0.42; epsilon: 0.4 }
                }
                Rectangle {   // the clock
                    anchors.centerIn: parent
                    width: 12; height: 3; radius: 1
                    color: Config.ThemeConfig.tint(root.ink, 0.7)
                }
                Dots {
                    anchors.verticalCenter: parent.verticalCenter; x: 6
                    opacity: root.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
                }
                Dots {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right; anchors.rightMargin: 6; count: 4
                    opacity: root.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Config.MotionConfig.swap } }
                }
            }
        }

        // ── caption ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.ControlConfig.space1
            Text {
                text: root.styleName.toUpperCase() + " · " + root.info.form
                font.family: Config.ControlConfig.fontMono
                font.pixelSize: Config.ControlConfig.fontLabel
                font.bold: true
                color: root.active ? root.accent : root.ink
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Rectangle {
                visible: root.active
                width: 6; height: 6; radius: 3
                color: root.accent
            }
        }
        Text {
            text: root.info.desc
            font.family: Config.ControlConfig.fontMono
            font.pixelSize: Config.ControlConfig.fontSmall
            color: Config.ThemeConfig.colors.textDim
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
}
