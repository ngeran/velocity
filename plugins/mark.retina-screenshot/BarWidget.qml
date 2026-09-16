import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

QsBarWidget {
  id: root
  moduleName: "mark.retina-screenshot"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  // Compat QsPanel has no popout-switch plumbing — always false.
  readonly property bool popoutSwitchClosing: false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { /* no popout switching on the compat panel */ }

  function captureRegion() {
    if (!captureAction.running) captureAction.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Process {
    id: captureAction
    // Our IPC bridge — omarchy-shell is the Omarchy equivalent of this call.
    command: ["qs", "-c", "bar", "ipc", "call", "mark.retina-screenshot", "captureRegion"]
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf030"
    active: captureAction.running
    scaledHorizontalMargin: 7.5
    tooltipText: captureAction.running
      ? "Retina Screenshot: capturing…"
      : "Retina Screenshot\nLeft click: select region · Right click: options"

    onPressed: function(b) {
      if (b === Qt.RightButton) root.togglePanel()
      else if (b === Qt.LeftButton) root.captureRegion()
    }
  }
}
