import QtQuick
import "qs/Ui"
import "ui"
import "ui/Format.js" as Format

BarWidget {
    id: root
    objectName: "xrayBarWidget"

    XRayTheme { id: theme }

    // moduleName comes from the vendored base, which defaults it to the
    // host-injected pluginId (manifest id) — see qs/Ui/BarWidget.qml.
    implicitWidth: launcher.implicitWidth
    implicitHeight: launcher.implicitHeight

    BarIconButton {
        id: launcher
        objectName: "xrayBarLauncher"

        anchors.fill: parent
        bar: root.bar
        text: Format.icon("xray")
        label: "X-RAY"                     // hover-reveal, like NET / VOL / EN
        fontFamily: theme.dataFont
        fontPixelSize: 14                  // = BarConfig.fontSizeIcon (house tray glyphs)
        tooltipText: "Trace system activity"
        onPressed: function(button) {
            if (!root.bar || !root.bar.shell)
                return;
            root.bar.shell.toggle(root.moduleName, "{}")
        }
    }
}
