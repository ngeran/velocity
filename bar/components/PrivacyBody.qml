// =============================================================================
// PrivacyBody.qml — TrayCard privacy body (I8 extraction)
// =============================================================================
// Who is watching or listening: sleep inhibitors, then one section per active
// capture kind (mic/camera/screen) with the holding apps under it. Pure view
// over PrivacyService; visibility and the poll demand (bodyDemanded) are
// owned by TrayCard's loader wrapper.
// =============================================================================

import QtQuick
import QtQuick.Layouts
import bar.services as Services
import bar.config as Config

ColumnLayout {
    id: body

    Layout.fillWidth: true; spacing: 0

    readonly property var kindRows: {
        var defs = [
            { key: "mic", glyph: "󰋎", label: "MICROPHONE" },
            { key: "camera", glyph: "󰍛", label: "CAMERA" },
            { key: "screen", glyph: "󰍹", label: "SCREEN" }
        ]
        var out = []
        for (var i = 0; i < defs.length; i++) {
            var apps = Services.PrivacyService.appsFor(defs[i].key)
            if (apps.length > 0)
                out.push({ glyph: defs[i].glyph, label: defs[i].label, apps: apps })
        }
        return out
    }

    Text {
        visible: !Services.PrivacyService.hasActive && !Services.PrivacyService.hasInhibitors
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing is watching or listening."
        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(12)
        color: Config.BarConfig.colorTextDim
    }

    // ── SLEEP INHIBITORS — what is keeping the machine awake ──
    ColumnLayout {
        visible: Services.PrivacyService.hasInhibitors
        Layout.fillWidth: true
        spacing: Config.PopupMetrics.px(6)

        RowLayout {
            Layout.fillWidth: true; spacing: Config.PopupMetrics.px(8)
            Text {
                text: "󰌾"
                font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(13)
                color: Config.ThemeConfig.colors.warning
            }
            Text {
                text: "KEPT AWAKE"
                font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
                font.bold: true; font.letterSpacing: 1.5
                color: Config.BarConfig.colorTextDim
            }
            Item { Layout.fillWidth: true }
        }

        Repeater {
            model: Services.PrivacyService.inhibitors

            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true; Layout.leftMargin: Config.PopupMetrics.px(21); spacing: Config.PopupMetrics.px(8)
                Text {
                    text: modelData.who
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(12)
                    color: Config.BarConfig.colorText
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    visible: modelData.why !== ""
                    text: modelData.why
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(9)
                    color: Config.BarConfig.colorTextDim
                    elide: Text.ElideRight
                    Layout.maximumWidth: Config.PopupMetrics.px(140)
                }
            }
        }

        Item { height: 10 }
    }

    Repeater {
        model: body.kindRows

        delegate: ColumnLayout {
            id: kindSection
            required property var modelData
            Layout.fillWidth: true
            spacing: Config.PopupMetrics.px(6)

            RowLayout {
                Layout.fillWidth: true; spacing: Config.PopupMetrics.px(8)
                Text {
                    text: kindSection.modelData.glyph
                    font.family: Config.BarConfig.fontNerd; font.pixelSize: Config.PopupMetrics.px(13)
                    color: Config.ThemeConfig.colors.error
                }
                Text {
                    text: kindSection.modelData.label
                    font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(8)
                    font.bold: true; font.letterSpacing: 1.5
                    color: Config.BarConfig.colorTextDim
                }
                Item { Layout.fillWidth: true }
                Rectangle { width: Config.PopupMetrics.px(6); height: Config.PopupMetrics.px(6); radius: Config.PopupMetrics.px(3); color: Config.ThemeConfig.colors.error }
            }

            Repeater {
                model: kindSection.modelData.apps

                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; Layout.leftMargin: Config.PopupMetrics.px(21); spacing: Config.PopupMetrics.px(8)
                    Text {
                        text: modelData.app || "Unknown app"
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(12)
                        color: Config.BarConfig.colorText
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        visible: modelData.pid !== null
                        text: "pid " + modelData.pid
                        font.family: Config.BarConfig.fontFamily; font.pixelSize: Config.PopupMetrics.px(9)
                        color: Config.BarConfig.colorTextDim
                    }
                }
            }

            Item { height: 10 }
        }
    }
}
